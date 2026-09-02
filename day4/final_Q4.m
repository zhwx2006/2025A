%% final_Q4.m —— 第 4 题定稿：按物理口径（截断到导弹命中时刻）优化并交付
% 物理口径：遮蔽只在导弹尚在飞行时有效，即 t ≤ t_hit（M1 命中假目标时刻）。
%   t_hit = |M1_0 − 假目标| / 300 ≈ 66.999 s。导弹命中后即被诱偏，此后无遮蔽意义。
%   单弹窗口 = [tdet, min(tdet+20, t_hit)]。
% 求解：几何预热启动（沿视线采爆点反解三机可行投放）→ 交替块爬山收敛。
% 产出：最优策略 + 并集时长 + d(t) 图 + result2.xlsx。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));      % union_length

S_all = [17800, 0, 1800;                    % FY1
         12000, 1400, 1400;                 % FY2
         6000, -3000, 700];                 % FY3
N_plane = 3;
T_pt = [0 200 5];
uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
M1_at = @(t) [20000, 0, 2000] + 300 * t * uM;
t_hit = norm([20000, 0, 2000]) / 300;       % 导弹命中假目标时刻 ≈ 66.999 s
fprintf('physical cutoff: M1 hits decoy at t_hit = %.3f s\n\n', t_hit);

%% ========== ① 回归测试（一页纸要求，时域截断不影响 Q1 场景）==========
iv1 = one_cloud_interval4(S_all(1,:), 0, 120, 1.5, 3.6, [], t_hit);
assert(abs(iv1(1,1) - 8.013) < 0.01 && abs(iv1(1,2) - 9.448) < 0.01, 'FY1 regression failed');
fprintf('regression passed: FY1 single bomb [%.3f, %.3f] (= Q1 answer)\n\n', iv1(1,1), iv1(1,2));

%% ========== ② 几何预热启动：沿视线采爆点反解每机可行投放 ==========
fprintf('========== geometric warm-start ==========\n');
tic;
cand_each = cell(N_plane, 1);
for p = 1:N_plane
    S = S_all(p, :);
    cand = zeros(0, 5);
    for tdet = 2:1:ceil(t_hit)
        if tdet > t_hit, break; end
        M = M1_at(tdet);
        for f = 0:0.1:1
            Bxy = M(1:2) + f * (T_pt(1:2) - M(1:2));
            zdes = M(3) + f * (T_pt(3) - M(3));
            D = Bxy - S(1:2);
            R = norm(D);
            if R < 1, continue; end
            v_req = R / tdet;
            if v_req < 70 || v_req > 140, continue; end
            th = atan2d(D(2)/R, -D(1)/R);
            tau_req = sqrt(max(0, (S(3) - zdes) / 4.9));
            tau_req = min(tau_req, tdet);
            t0_req = max(0, tdet - tau_req);
            iv = one_cloud_interval4(S, th, v_req, t0_req, tau_req, [], t_hit);
            dur = union_length(iv);
            if dur > 0.05
                cand(end+1, :) = [th, v_req, t0_req, tau_req, dur]; %#ok<AGROW>
            end
        end
    end
    if isempty(cand)
        cand = [0, 100, 0, 2, 0.001];
        fprintf('FY%d: no feasible warm-start, fallback\n', p);
    end
    cand = sortrows(cand, -5);
    cand_each{p} = cand(1:min(6, size(cand,1)), :);
    fprintf('FY%d: %d warm-starts; best single = %.3f s (th=%.1f, v=%.1f, t0=%.2f, tau=%.2f)\n', ...
            p, size(cand,1), cand_each{p}(1,5), cand_each{p}(1,1:4));
end
fprintf('warm-start time %.1f s\n\n', toc);

%% ========== ③ 多起点交替块爬山（按物理截断口径）==========
starts = zeros(0, 12);
starts(end+1, :) = [cand_each{1}(1,1:4), cand_each{2}(1,1:4), cand_each{3}(1,1:4)];
starts(end+1, :) = [0.367, 140, 0, 3.711, cand_each{2}(1,1:4), cand_each{3}(1,1:4)];
if size(cand_each{1},1) >= 2
    starts(end+1, :) = [cand_each{1}(2,1:4), cand_each{2}(1,1:4), cand_each{3}(1,1:4)];
end
if size(cand_each{2},1) >= 2
    starts(end+1, :) = [cand_each{1}(1,1:4), cand_each{2}(2,1:4), cand_each{3}(1,1:4)];
end
if size(cand_each{3},1) >= 2
    starts(end+1, :) = [cand_each{1}(1,1:4), cand_each{2}(1,1:4), cand_each{3}(2,1:4)];
    starts(end+1, :) = [cand_each{1}(1,1:4), cand_each{2}(2,1:4), cand_each{3}(2,1:4)];
end
fprintf('========== alternating block ascent (%d starts) ==========\n', size(starts,1));
tic;
G_global = -1;  X_global = [];
for s = 1:size(starts, 1)
    X = starts(s, :);
    for it = 1:25
        Xold = X;
        for p = 1:N_plane
            others = union_others(X, p, S_all, t_hit);
            X = refine_plane(X, p, S_all(p,:), others, t_hit);
        end
        if norm(X - Xold) < 1e-4, break; end
    end
    G = objective4(X, t_hit);
    fprintf('start %d: union(cut) = %.4f s\n', s, G);
    if G > G_global
        G_global = G;  X_global = X;
    end
end
fprintf('best: %.4f s (%.1f s)\n\n', G_global, toc);

%% ========== ④ 最终评估 ==========
X = X_global;
iv_each = cell(N_plane, 1);
iv_all = zeros(0, 2);
for p = 1:N_plane
    iv_each{p} = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                     X(3+(p-1)*4), X(4+(p-1)*4), [], t_hit);
    if ~isempty(iv_each{p}), iv_all = [iv_all; iv_each{p}]; end
end
G_final = union_length(iv_all);
fprintf('========== Q4 FINAL RESULT (physical caliber) ==========\n');
for p = 1:N_plane
    fprintf('FY%d: th=%.3f deg, v=%.2f m/s, t0=%.3f s, tau=%.3f s | ', ...
            p, X(1+(p-1)*4), X(2+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4));
    if isempty(iv_each{p})
        fprintf('EMPTY');
    else
        for k = 1:size(iv_each{p},1)
            fprintf('[%.3f, %.3f] ', iv_each{p}(k,1), iv_each{p}(k,2));
        end
    end
    fprintf('\n');
end
fprintf('UNION TOTAL = %.3f s\n', G_final);

%% ========== ⑤ 图：三机 d(t) 曲线 + 并集区间 ==========
t_plt = (0:0.02:t_hit)';
Mp = [20000, 0, 2000] + 300 * t_plt * uM;
figure('Color','w','Position',[140 140 920 540]); hold on;
cols = {'b', [0 0.6 0], [0.8 0.4 0]};
leg = cell(N_plane,1); ymax = 40;
for p = 1:N_plane
    th_p = X(1+(p-1)*4)*pi/180;  v_p = X(2+(p-1)*4);
    t0_p = X(3+(p-1)*4);  tau_p = X(4+(p-1)*4);
    u_p = [-cos(th_p), sin(th_p), 0];
    B = S_all(p,:) + v_p*(t0_p+tau_p)*u_p + [0,0,-4.9*tau_p^2];
    tdet = t0_p + tau_p;
    Cp = B + [zeros(size(t_plt)), zeros(size(t_plt)), -3*(t_plt - tdet)];
    V = T_pt - Mp;  W = Cp - Mp;
    lam = max(0, min(1, sum(W.*V,2) ./ sum(V.*V,2)));
    Q = Mp + lam .* V;
    d = sqrt(sum((Cp-Q).^2, 2));
    mask = t_plt >= tdet & t_plt <= min(tdet+20, t_hit);
    d(~mask) = NaN;
    plot(t_plt, d, '-', 'Color', cols{p}, 'LineWidth', 1.6);
    leg{p} = sprintf('FY%d d(t)', p);
end
yline(10, 'r--', 'LineWidth', 1.5);
xline(t_hit, 'k:', 'LineWidth', 1.2);
A_u = sortrows(iv_all, 1);
if ~isempty(A_u)
    cs = A_u(1,1); ce = A_u(1,2); segs = zeros(0,2);
    for i = 2:size(A_u,1)
        if A_u(i,1) <= ce, ce = max(ce, A_u(i,2));
        else, segs(end+1,:) = [cs ce]; cs = A_u(i,1); ce = A_u(i,2); end
    end
    segs(end+1,:) = [cs ce];
    for i = 1:size(segs,1)
        patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], [0 0 ymax ymax], ...
              [0.8 0.9 1], 'EdgeColor','none','FaceAlpha',0.45);
    end
end
xlabel('t (s)'); ylabel('d(t) (m)');
title(sprintf('Q4: 3 planes vs M1, union = %.3f s (cut at missile hit %.1f s)', G_final, t_hit));
legend([leg{:}, 'd=10 boundary', 'missile hit', 'union intervals'], 'Location','northeast');
xlim([0, t_hit]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q4_三机d(t)_曲线图.png'));
fprintf('\nfigure saved: Q4_三机d(t)_曲线图.png\n');

%% ========== ⑥ result2.xlsx（官方模板格式：每机一行）==========
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)'};
rows = cell(N_plane, 10);
for p = 1:N_plane
    th_p = X(1+(p-1)*4)*pi/180;  v_p = X(2+(p-1)*4);
    t0_p = X(3+(p-1)*4);  tau_p = X(4+(p-1)*4);
    u_p = [-cos(th_p), sin(th_p), 0];
    drop = S_all(p,:) + v_p*t0_p*u_p;
    det  = drop + v_p*tau_p*u_p + [0, 0, -4.9*tau_p^2];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    rows(p, :) = {sprintf('FY%d', p), dir_official, v_p, drop(1), drop(2), drop(3), ...
                  det(1), det(2), det(3), G_final};
end
writecell([hdr; rows], fullfile(here, 'result2.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
          fullfile(here, 'result2.xlsx'), 'Sheet', 1, 'Range', 'A5');
det_hdr = {'无人机','内部θ(°)','t0(s)','tau(s)','起爆时刻(s)','区间','并集总时长(s)'};
det_rows = cell(N_plane, 7);
for p = 1:N_plane
    if isempty(iv_each{p})
        ivstr = '空';
    else
        ivstr = strjoin(arrayfun(@(k) sprintf('[%.3f,%.3f]', iv_each{p}(k,1), iv_each{p}(k,2)), ...
                1:size(iv_each{p},1), 'UniformOutput', false), ' ');
    end
    det_rows(p, :) = {sprintf('FY%d', p), X(1+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4), ...
                      X(3+(p-1)*4)+X(4+(p-1)*4), ivstr, G_final};
end
writecell([det_hdr; det_rows], fullfile(here, 'result2.xlsx'), 'Sheet', 2);
fprintf('table saved: result2.xlsx (Sheet1 official, Sheet2 details)\n');

%% ================= 局部函数 =================
function U = union_others(X, p, S_all, t_cap)
    iv = zeros(0, 2);
    for q = setdiff(1:size(S_all,1), p)
        ivq = one_cloud_interval4(S_all(q,:), X(1+(q-1)*4), X(2+(q-1)*4), ...
                                  X(3+(q-1)*4), X(4+(q-1)*4), [], t_cap);
        if ~isempty(ivq), iv = [iv; ivq]; end
    end
    U = iv;
end

function X = refine_plane(X, p, S, U, t_cap)
    lev_steps = [20, 4, 0.8, 0.16, 0.032;
                 10, 2, 0.4, 0.08, 0.016;
                 1,  0.2, 0.04, 0.008, 0.0016;
                 1,  0.2, 0.04, 0.008, 0.0016];
    i0 = 1 + (p-1)*4;
    best_f = eval_u(X, p, S, U, t_cap);
    for lev = 1:5
        sth = lev_steps(1, lev); sv = lev_steps(2, lev);
        st0 = lev_steps(3, lev); stau = lev_steps(4, lev);
        th_c  = X(i0)   + (-2:2)*sth;
        v_c   = max(70, min(140, X(i0+1) + (-2:2)*sv));
        t0_c  = max(0, X(i0+2) + (-2:2)*st0);
        tau_c = max(0.05, X(i0+3) + (-2:2)*stau);
        for a = th_c
            for b = v_c
                for c = t0_c
                    for e = tau_c
                        Xt = X; Xt(i0:i0+3) = [a, b, c, e];
                        f = eval_u(Xt, p, S, U, t_cap);
                        if f > best_f, best_f = f; X = Xt; end
                    end
                end
            end
        end
    end
end

function f = eval_u(X, p, S, U, t_cap)
    iv = one_cloud_interval4(S, X(1+(p-1)*4), X(2+(p-1)*4), ...
                             X(3+(p-1)*4), X(4+(p-1)*4), [], t_cap);
    f = union_length([U; iv]);
end
