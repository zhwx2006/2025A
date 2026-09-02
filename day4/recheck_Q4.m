%% recheck_Q4.m —— Q4 复核（任务单 2026-09-02：云中心 z≥0 不许钻地）
% ① 回归 + FY1 用 Q2 最优锚点验证（预期单弹 4.737 s）
% ② 现冠军在新约束下重算每机窗口（FY3 末段触地截断）
% ③ FY3 中段可行性验证（任务单建议参数 + 几何搜索），对比中段 vs 末段
% ④ z 约束下重新优化（多起点：冠军 / 冠军+Q2锚点 / 冠军+FY3中段候选）
% ⑤ 输出：控制台报告 + result2.xlsx + Q4_segments.txt（图由 Python 画）
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));      % union_length

S_all = [17800, 0, 1800;                    % FY1
         12000, 1400, 1400;                 % FY2
         6000, -3000, 700];                 % FY3
T_pt = [0 200 5];
uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
M1_at = @(t) [20000, 0, 2000] + 300 * t * uM;
t_hit = norm([20000, 0, 2000]) / 300;       % M1 命中假目标时刻

%% ========== ① 回归 + Q2 锚点 ==========
iv_q1 = one_cloud_interval4(S_all(1,:), 0, 120, 1.5, 3.6);
assert(abs(iv_q1(1,1) - 8.013) < 0.01 && abs(iv_q1(1,2) - 9.448) < 0.01, ...
       'regression failed');
fprintf('[1] regression passed: FY1 Q1 scenario [%.3f, %.3f]\n', iv_q1(1,1), iv_q1(1,2));
% Q2 最优锚点：th=3.074, v=72.4, t0=0, tau=2.505
iv_q2 = one_cloud_interval4(S_all(1,:), 3.074, 72.4, 0, 2.505);
dur_q2 = union_length(iv_q2);
fprintf('[1] FY1 with Q2 anchor (3.074 deg, 72.4, 0, 2.505): interval ');
for k = 1:size(iv_q2,1)
    fprintf('[%.3f, %.3f] ', iv_q2(k,1), iv_q2(k,2));
end
fprintf('-> %.3f s (task expects 4.737)\n', dur_q2);

%% ========== ② 现冠军在新约束下重算 ==========
champ = [1.1398, 139.810, 0.0000, 3.5767, ...
         -101.1536, 135.330, 4.3818, 5.7975, ...
         28.0736, 136.043, 38.4195, 11.5557];
fprintf('\n[2] old champion re-evaluated under z>=0 constraint:\n');
G_champ_new = 0;
for p = 1:3
    iv = one_cloud_interval4(S_all(p,:), champ(1+(p-1)*4), champ(2+(p-1)*4), ...
                             champ(3+(p-1)*4), champ(4+(p-1)*4), [], t_hit);
    dur = union_length(iv);
    G_champ_new = G_champ_new + dur;
    % 爆点高度与触地时刻
    th = champ(1+(p-1)*4)*pi/180;
    B = S_all(p,:) + champ(2+(p-1)*4)*(champ(3+(p-1)*4)+champ(4+(p-1)*4))* ...
        [-cos(th), sin(th), 0] + [0,0,-4.9*champ(4+(p-1)*4)^2];
    t_ground = champ(3+(p-1)*4) + champ(4+(p-1)*4) + B(3)/3;
    fprintf('    FY%d: blast z=%.1f m, touches ground at t=%.2f s, window ', ...
            p, B(3), t_ground);
    if isempty(iv)
        fprintf('EMPTY');
    else
        for k = 1:size(iv,1)
            fprintf('[%.3f, %.3f] ', iv(k,1), iv(k,2));
        end
    end
    fprintf(' -> %.3f s\n', dur);
end
fprintf('    old champion under constraint: %.3f s (was 16.360)\n', G_champ_new);

%% ========== ③ FY3 中段可行性 ==========
fprintf('\n[3] FY3 mid-slot feasibility (t_det ~ 22-27):\n');
% 任务单建议：th=90, t0=18, tau=3.9, v=140（y≈66, z≈625）
iv_sugg = one_cloud_interval4(S_all(3,:), 90, 140, 18, 3.9, [], t_hit);
fprintf('    task suggestion (th=90, v=140, t0=18, tau=3.9): window ');
if isempty(iv_sugg)
    fprintf('EMPTY -> no shielding');
else
    for k = 1:size(iv_sugg,1)
        fprintf('[%.3f, %.3f] ', iv_sugg(k,1), iv_sugg(k,2));
    end
    fprintf('-> %.3f s', union_length(iv_sugg));
end
fprintf('\n');
% 几何搜索：tdet ∈ [15,35]，爆点取视线段上，反解可行投放
cand_mid = zeros(0, 5);
for td = 15:1:35
    M = M1_at(td);
    for f = 0:0.05:1
        Bxy = M(1:2) + f*(T_pt(1:2) - M(1:2));
        zdes = M(3) + f*(T_pt(3) - M(3));
        D = Bxy - S_all(3,1:2);
        R = norm(D);
        if R < 1, continue; end
        v_req = R / td;
        if v_req < 70 || v_req > 140, continue; end
        th = atan2d(D(2)/R, -D(1)/R);
        tau_req = sqrt(max(0, (S_all(3,3) - zdes)/4.9));
        tau_req = min(tau_req, td);
        if 4.9*tau_req^2 >= S_all(3,3), continue; end   % 爆点不钻地
        t0_req = max(0, td - tau_req);
        iv = one_cloud_interval4(S_all(3,:), th, v_req, t0_req, tau_req, [], t_hit);
        dur = union_length(iv);
        if dur > 0.01
            cand_mid(end+1, :) = [th, v_req, t0_req, tau_req, dur]; %#ok<AGROW>
        end
    end
end
if isempty(cand_mid)
    fprintf('    geometric search: NO feasible mid-slot bomb for FY3\n');
    mid_best = [];
else
    cand_mid = sortrows(cand_mid, -5);
    fprintf('    geometric search: %d feasible candidates, best raw single = %.3f s\n', ...
            size(cand_mid,1), cand_mid(1,5));
    % 对前 3 个候选做单弹块爬山精修
    mid_best = [];  mid_dur = -1;
    for c = 1:min(3, size(cand_mid,1))
        b4 = cand_mid(c, 1:4);
        for lev = 1:4
            steps = [20, 4, 0.8, 0.16] / 5^(lev-1);          % th
            steps_v = [10, 2, 0.4, 0.08] / 5^(lev-1);        % v
            steps_t = [1, 0.2, 0.04, 0.008] / 5^(lev-1);     % t0, tau
            best_f = union_length(one_cloud_interval4(S_all(3,:), b4(1), b4(2), b4(3), b4(4), [], t_hit));
            for a = b4(1) + (-2:2)*steps(lev)
                for b = max(70, min(140, b4(2) + (-2:2)*steps_v(lev)))
                    for cc = max(0, b4(3) + (-2:2)*steps_t(lev))
                        for e = max(0.05, b4(4) + (-2:2)*steps_t(lev))
                            f = union_length(one_cloud_interval4(S_all(3,:), a, b, cc, e, [], t_hit));
                            if f > best_f
                                best_f = f;  b4 = [a, b, cc, e];
                            end
                        end
                    end
                end
            end
        end
        ivm = one_cloud_interval4(S_all(3,:), b4(1), b4(2), b4(3), b4(4), [], t_hit);
        fprintf('    candidate %d refined: (th=%.2f, v=%.2f, t0=%.3f, tau=%.3f) window ', ...
                c, b4);
        if isempty(ivm)
            fprintf('EMPTY');
        else
            for k = 1:size(ivm,1)
                fprintf('[%.3f, %.3f] ', ivm(k,1), ivm(k,2));
            end
        end
        fprintf(' -> %.3f s\n', union_length(ivm));
        if union_length(ivm) > mid_dur
            mid_dur = union_length(ivm);  mid_best = b4;
        end
    end
end

%% ========== ④ z 约束下重新优化（多起点）==========
fprintf('\n[4] re-optimization under z>=0 constraint:\n');
starts = zeros(0, 12);
starts(end+1, :) = champ;                                     % A: 现冠军
starts(end+1, :) = [3.074, 72.4, 0, 2.505, champ(5:12)];      % B: FY1 换 Q2 锚点
starts(end+1, :) = [3.074, 72.4, 0, 2.505, champ(5:8), ...    % C: Q2锚点+FY3中段
                    90, 140, 18, 3.9];
if ~isempty(mid_best)
    starts(end+1, :) = [champ(1:8), mid_best];                % D: 冠军+FY3中段精修解
    starts(end+1, :) = [3.074, 72.4, 0, 2.505, champ(5:8), mid_best]; % E
end
G_best = -1;  X_best = [];
for s = 1:size(starts, 1)
    X = starts(s, :);
    G = obj4c(X, S_all, t_hit);
    for it = 1:15
        improved = false;
        Ga = G;
        % 坐标块爬坡（每机 4 参数）
        for p = 1:3
            X = climb_plane4(X, p, S_all, t_hit);
        end
        G = obj4c(X, S_all, t_hit);
        if G > Ga + 1e-6, improved = true; end
        % 联合移动（斜脊方向）
        Gb = G;
        pairs4 = build_pairs4();
        for sc = [0.2, 0.04, 0.008]
            for r = 1:size(pairs4, 1)
                di = pairs4(r,1);  dj = pairs4(r,2);
                for si = -2:2
                    for sj = -2:2
                        if si == 0 && sj == 0, continue; end
                        Xt = X;
                        Xt(di) = Xt(di) + si*sc*scale4(di);
                        Xt(dj) = Xt(dj) + sj*sc*scale4(dj);
                        for q = 1:3
                            i0 = 1 + (q-1)*4;
                            Xt(i0+1) = max(70, min(140, Xt(i0+1)));
                            Xt(i0+2) = max(0, Xt(i0+2));
                            Xt(i0+3) = max(0.05, Xt(i0+3));
                        end
                        f = obj4c(Xt, S_all, t_hit);
                        if f > G + 1e-9
                            G = f;  X = Xt;  improved = true;
                        end
                    end
                end
            end
        end
        if ~improved
            fprintf('    start %d converged at iter %d: %.4f s\n', s, it, G);
            break;
        end
        if it == 15
            fprintf('    start %d hit iter cap: %.4f s\n', s, G);
        end
    end
    if G > G_best
        G_best = G;  X_best = X;
    end
end

%% ========== ⑤ 最终评估与输出 ==========
X = X_best;
fprintf('\n[5] Q4 FINAL under z>=0 constraint:\n');
G_total = 0;
iv_each = cell(3,1);
for p = 1:3
    iv_each{p} = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                     X(3+(p-1)*4), X(4+(p-1)*4), [], t_hit);
    dur = union_length(iv_each{p});
    G_total = G_total + dur;
    th = X(1+(p-1)*4)*pi/180;
    B = S_all(p,:) + X(2+(p-1)*4)*(X(3+(p-1)*4)+X(4+(p-1)*4))* ...
        [-cos(th), sin(th), 0] + [0,0,-4.9*X(4+(p-1)*4)^2];
    fprintf('    FY%d: th=%.3f deg, v=%.2f m/s, t0=%.3f s, tau=%.3f s | blast z=%.1f m | window ', ...
            p, X(1+(p-1)*4), X(2+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4), B(3));
    if isempty(iv_each{p})
        fprintf('EMPTY');
    else
        for k = 1:size(iv_each{p},1)
            fprintf('[%.3f, %.3f] ', iv_each{p}(k,1), iv_each{p}(k,2));
        end
    end
    fprintf(' -> %.3f s\n', dur);
end
fprintf('    Q4 TOTAL (z>=0) = %.3f s  (old 16.360, task estimate ~14.8)\n', G_total);

%% ---------- result2.xlsx ----------
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)'};
rows = cell(3, 10);
for p = 1:3
    th = X(1+(p-1)*4)*pi/180;  u = [-cos(th), sin(th), 0];
    dir_official = mod(atan2d(u(2), u(1)), 360);
    drop = S_all(p,:) + X(2+(p-1)*4)*X(3+(p-1)*4)*u;
    det  = drop + X(2+(p-1)*4)*X(4+(p-1)*4)*u + [0, 0, -4.9*X(4+(p-1)*4)^2];
    rows(p, :) = {sprintf('FY%d', p), dir_official, X(2+(p-1)*4), ...
                  drop(1), drop(2), drop(3), det(1), det(2), det(3), ...
                  union_length(iv_each{p})};
end
writecell([hdr; rows], fullfile(here, 'result2.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。云中心z>=0（不许钻地）。'}, ...
          fullfile(here, 'result2.xlsx'), 'Sheet', 1, 'Range', 'A5');
det_hdr = {'无人机','内部θ(°)','t0(s)','tau(s)','起爆时刻(s)','爆点z(m)','窗口','时长(s)'};
det_rows = cell(3, 8);
for p = 1:3
    th = X(1+(p-1)*4)*pi/180;
    B = S_all(p,:) + X(2+(p-1)*4)*(X(3+(p-1)*4)+X(4+(p-1)*4))* ...
        [-cos(th), sin(th), 0] + [0,0,-4.9*X(4+(p-1)*4)^2];
    if isempty(iv_each{p})
        ivstr = '空';
    else
        ivstr = strjoin(arrayfun(@(k) sprintf('[%.3f,%.3f]', iv_each{p}(k,1), iv_each{p}(k,2)), ...
                1:size(iv_each{p},1), 'UniformOutput', false), ' ');
    end
    det_rows(p, :) = {sprintf('FY%d', p), X(1+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4), ...
                      X(3+(p-1)*4)+X(4+(p-1)*4), B(3), ivstr, union_length(iv_each{p})};
end
det_rows(end+1, :) = {'合计', '', '', '', '', '', '', G_total};
writecell([det_hdr; det_rows], fullfile(here, 'result2.xlsx'), 'Sheet', 2);
fprintf('\nresult2.xlsx saved\n');

%% ---------- Q4_segments.txt（供 Python 画接力图）----------
fid = fopen(fullfile(here, 'Q4_segments.txt'), 'w');
fprintf(fid, 'HIT %.6f\n', t_hit);
fprintf(fid, 'TOTAL %.6f\n', G_total);
for p = 1:3
    for k = 1:size(iv_each{p},1)
        fprintf(fid, 'BOMB %d %.6f %.6f\n', p, iv_each{p}(k,1), iv_each{p}(k,2));
    end
end
% 并集段
U = zeros(0,2);
for p = 1:3
    if ~isempty(iv_each{p}), U = [U; iv_each{p}]; end
end
U = sortrows(U, 1);
if ~isempty(U)
    cs = U(1,1); ce = U(1,2); segs = zeros(0,2);
    for i = 2:size(U,1)
        if U(i,1) <= ce, ce = max(ce, U(i,2));
        else, segs(end+1,:) = [cs ce]; cs = U(i,1); ce = U(i,2); end
    end
    segs(end+1,:) = [cs ce];
    for i = 1:size(segs,1)
        fprintf(fid, 'UNION %.6f %.6f\n', segs(i,1), segs(i,2));
    end
end
fclose(fid);
fprintf('Q4_segments.txt saved (figure by plot_q4.py)\n');

%% ================= 局部函数 =================
function G = obj4c(X, S_all, t_cap)
    iv = zeros(0, 2);
    for p = 1:3
        ivp = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                  X(3+(p-1)*4), X(4+(p-1)*4), [], t_cap);
        if ~isempty(ivp), iv = [iv; ivp]; end
    end
    G = union_length(iv);
end

function X = climb_plane4(X, p, S_all, t_cap)
% 对第 p 机 4 参数做收缩块爬山（其余机固定，目标为三机并集）
    lev_th  = [20, 4, 0.8, 0.16];
    lev_v   = [10, 2, 0.4, 0.08];
    lev_t   = [1, 0.2, 0.04, 0.008];
    i0 = 1 + (p-1)*4;
    for lev = 1:4
        best_f = obj4c(X, S_all, t_cap);
        for a = X(i0) + (-2:2)*lev_th(lev)
            for b = max(70, min(140, X(i0+1) + (-2:2)*lev_v(lev)))
                for c = max(0, X(i0+2) + (-2:2)*lev_t(lev))
                    for e = max(0.05, X(i0+3) + (-2:2)*lev_t(lev))
                        Xt = X;  Xt(i0:i0+3) = [a, b, c, e];
                        f = obj4c(Xt, S_all, t_cap);
                        if f > best_f
                            best_f = f;  X = Xt;
                        end
                    end
                end
            end
        end
    end
end

function pairs = build_pairs4()
% 联合移动参数对：机内 6 对 + 跨机 t0/τ 对
    pairs = zeros(0, 2);
    for p = 1:3
        i0 = 1 + (p-1)*4;
        pairs = [pairs; i0 i0+1; i0 i0+2; i0 i0+3; i0+1 i0+2; i0+1 i0+3; i0+2 i0+3];
    end
    pairs = [pairs; 3 7; 3 11; 7 11; 4 8; 8 12; 4 12];
end

function s = scale4(dim)
% 各维度量纲缩放（θ 度、v m/s、t0/τ 秒）
    k = mod(dim-1, 4);
    if k == 0, s = 1;
    elseif k == 1, s = 1;
    else, s = 0.2; end
end
