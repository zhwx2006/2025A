%% q5_full.m —— Q5 全量（任务单 2026-09-02：默认指派 + z>=0 约束）
% 指派：M1←FY1；M2←FY2+FY4；M3←FY3+FY5
% 口径：同弹内多弹并集去重；跨弹相加不去重；云中心 z>=0 不许钻地（函数内置）
% 起步：FY1 从 Q3 最优（θ=0.367°, v=140, 3 弹）；两机机组先各机 1 弹再补弹
% 输出：每机 (θ, v) + 每弹 (t0, τ, 区间)；obscure_1/2/3；Total
%       result3.xlsx（官方模板）+ Q5_segments.txt（供 Python 画图）
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];
T_pt = [0 200 5];
assign = {1, [2, 4], [3, 5]};             % 任务单默认指派

%% ========== ① 回归自检（任务单 §3）==========
iv_dup = union_length([8.013 9.448; 8.013 9.448]);
assert(abs(iv_dup - 1.435) < 0.01, 'union dedup failed');
fprintf('[reg] duplicated clouds on same missile counted once: %.3f s (expect ~1.435)\n', iv_dup);
iv_q1 = single_bomb5(S_all(1,:), 0, 120, 1.5, 3.6, 1);
assert(abs(iv_q1(1,1) - 8.013) < 0.01 && abs(iv_q1(1,2) - 9.448) < 0.01, 'Q1 regression failed');
fprintf('[reg] FY1 single bomb vs M1 = [%.3f, %.3f] (~1.4 s, = Q1)\n\n', iv_q1(1,1), iv_q1(1,2));

%% ========== ② 起步参数 ==========
routes = zeros(5, 2);
bombs  = cell(5, 1);
% M1: FY1 从 Q3 最优起步
routes(1,:) = [0.3665, 140];
bombs{1} = [0, 3.7109; 2.9588, 5.0976; 5.2427, 5.9255];
% M2: FY2/FY4 用此前 Q5 的中段接力解起步
routes(2,:) = [-80.974, 139.48];
bombs{2} = [2.9724, 4.0916; 3.9880, 3.3200];
routes(4,:) = [-41.336, 126.57];
bombs{4} = [7.3052, 12.6148];
% M3: FY5 用此前解；FY3 几何预热
routes(5,:) = [62.917, 120.87];
bombs{5} = [13.5894, 1.3306];
% FY3 打 M3 几何预热：沿 [M3(tdet), T] 采爆点，反解可行投放（含爆点不钻地）
cand3 = zeros(0, 5);
cap3 = t_hit5(3);
for td = 3:1:ceil(cap3)
    Mm = missile_pos5(3, td);
    for f = 0:0.1:1
        Bxy = Mm(1:2) + f*(T_pt(1:2) - Mm(1:2));
        zdes = Mm(3) + f*(T_pt(3) - Mm(3));
        D = Bxy - S_all(3,1:2);
        R = norm(D);
        if R < 1, continue; end
        v_req = R / td;
        if v_req < 70 || v_req > 140, continue; end
        th = atan2d(D(2)/R, -D(1)/R);
        tau_req = sqrt(max(0, (S_all(3,3) - zdes)/4.9));
        tau_req = min(tau_req, td);
        if 4.9*tau_req^2 >= S_all(3,3), continue; end      % 爆点不钻地
        t0_req = max(0, td - tau_req);
        iv = single_bomb5(S_all(3,:), th, v_req, t0_req, tau_req, 3);
        dur = union_length(iv);
        if dur > 0.01
            cand3(end+1, :) = [th, v_req, t0_req, tau_req, dur]; %#ok<AGROW>
        end
    end
end
if isempty(cand3)
    routes(3,:) = [0, 100];  bombs{3} = [0, 2];
    fprintf('FY3 vs M3 warm-start: no feasible candidate (fallback)\n');
else
    cand3 = sortrows(cand3, -5);
    fprintf('FY3 vs M3 warm-start: %d candidates, best single = %.3f s (th=%.1f, v=%.1f, t0=%.1f, tau=%.1f)\n', ...
            size(cand3,1), cand3(1,5), cand3(1,1:4));
    routes(3,:) = cand3(1, 1:2);
    bombs{3} = cand3(1, 3:4);
end

%% ========== ③ 逐导弹组优化（先各机 1 弹 → 补弹 → 逐弹爬山 → 航线爬坡）==========
for m = 1:3
    group = assign{m};
    cap = t_hit5(m);
    fprintf('\n--- M%d group (FY%s), cap=%.2f s ---\n', m, mat2str(group), cap);
    for iter = 1:6
        % A) 贪心补弹（背景 = 组内其他机，增量 >0.01 才投，最多 3 弹/机）
        for pi = 1:numel(group)
            p = group(pi);
            U = others(m, group, pi, S_all, routes, bombs);
            bombs{p} = fill(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        % B) 逐弹块爬山（保留接力结构）
        for pi = 1:numel(group)
            p = group(pi);
            U = others(m, group, pi, S_all, routes, bombs);
            bombs{p} = climb_bombs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        % C) 航线爬坡 (θ, v)
        for pi = 1:numel(group)
            p = group(pi);
            U = others(m, group, pi, S_all, routes, bombs);
            [thn, vn] = climb_route(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
            routes(p,:) = [thn, vn];
        end
        fprintf('  iter %d: obscure_%d = %.4f s\n', iter, m, grp(m, group, S_all, routes, bombs));
    end
end

%% ========== ④ 最终评估 ==========
G_each = zeros(1, 3);
for m = 1:3
    G_each(m) = grp(m, assign{m}, S_all, routes, bombs);
end
total = sum(G_each);
fprintf('\n========== Q5 FINAL (default assignment, z>=0) ==========\n');
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = ivs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    fprintf('FY%d (M%d): th=%.3f deg, v=%.2f m/s, %d bombs\n', ...
            p, m, routes(p,1), routes(p,2), size(bombs{p},1));
    for j = 1:numel(ivp)
        th = routes(p,1)*pi/180;  u = [-cos(th), sin(th), 0];
        B = S_all(p,:) + routes(p,2)*(bombs{p}(j,1)+bombs{p}(j,2))*u + [0,0,-4.9*bombs{p}(j,2)^2];
        fprintf('   bomb %d: t0=%.3f s, tau=%.3f s | blast z=%.1f m | window ', ...
                j, bombs{p}(j,1), bombs{p}(j,2), B(3));
        if isempty(ivp{j})
            fprintf('EMPTY');
        else
            for k = 1:size(ivp{j},1)
                fprintf('[%.3f, %.3f] ', ivp{j}(k,1), ivp{j}(k,2));
            end
        end
        fprintf(' -> %.3f s\n', union_length(ivp{j}));
    end
end
fprintf('obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f\n', G_each);
fprintf('TOTAL = %.3f s\n', total);

%% ========== ⑤ 附注：此前改派方案（M2 加 FY3）在 z>=0 下的对照 ==========
% 供建模手参考：FY3 调去 M2 曾得 M2=20.10 s；z>=0 约束下重估（不重新优化）
X_old2 = [-80.974, 139.48, 2.9724, 4.0916; 3.9880, 3.3200, 0, 0];   % FY2
U_m2 = zeros(0,2);
iv2a = ivs(2, S_all(2,:), X_old2(1,1), X_old2(1,2), X_old2(1:2,3:4));
for k = 1:numel(iv2a)
    if ~isempty(iv2a{k}), U_m2 = [U_m2; iv2a{k}]; end
end
iv2b = ivs(2, S_all(4,:), -41.336, 126.57, [7.3052, 12.6148]);
for k = 1:numel(iv2b)
    if ~isempty(iv2b{k}), U_m2 = [U_m2; iv2b{k}]; end
end
iv2c = ivs(2, S_all(3,:), 28.072, 138.78, [37.1865, 11.8135; 36.1820, 11.3780]);
for k = 1:numel(iv2c)
    if ~isempty(iv2c{k}), U_m2 = [U_m2; iv2c{k}]; end
end
fprintf('\n[note] previous re-assignment (M2 + FY3) under z>=0: M2 = %.3f s (was 20.102)\n', ...
        union_length(U_m2));

%% ========== ⑥ result3.xlsx（官方模板：无人机 × 弹号 15 行）==========
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)','干扰的导弹编号'};
rows = cell(0, 12);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    th = routes(p,1)*pi/180;  u = [-cos(th), sin(th), 0];
    dir_official = mod(atan2d(u(2), u(1)), 360);
    ivp = ivs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    for j = 1:3
        if j <= size(bombs{p},1)
            drop = S_all(p,:) + routes(p,2)*bombs{p}(j,1)*u;
            det  = drop + routes(p,2)*bombs{p}(j,2)*u + [0, 0, -4.9*bombs{p}(j,2)^2];
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, routes(p,2), j, ...
                drop(1), drop(2), drop(3), det(1), det(2), det(3), ...
                union_length(ivp{j}), sprintf('M%d', m)}; %#ok<AGROW>
        else
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, routes(p,2), j, ...
                '', '', '', '', '', '', '', sprintf('M%d', m)}; %#ok<AGROW>
        end
    end
end
writecell([hdr; rows], fullfile(here, 'result3.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。云中心z>=0（不许钻地）。'}, ...
          fullfile(here, 'result3.xlsx'), 'Sheet', 1, 'Range', 'A17');
sum_hdr = {'导弹','分配飞机','并集遮蔽时长(s)'};
sum_rows = cell(3, 3);
for m = 1:3
    sum_rows(m, :) = {sprintf('M%d', m), sprintf('FY%s', mat2str(assign{m})), G_each(m)};
end
sum_rows(end+1, :) = {'合计', '', total};
writecell([sum_hdr; sum_rows], fullfile(here, 'result3.xlsx'), 'Sheet', 2);
fprintf('\nresult3.xlsx saved\n');

%% ========== ⑦ Q5_segments.txt（供 Python 画接力图）==========
fid = fopen(fullfile(here, 'Q5_segments.txt'), 'w');
for m = 1:3
    fprintf(fid, 'HIT %d %.6f\n', m, t_hit5(m));
end
fprintf(fid, 'GEACH %.6f %.6f %.6f\n', G_each);
fprintf(fid, 'TOTAL %.6f\n', total);
for m = 1:3
    fprintf(fid, 'PLANES %d %s\n', m, mat2str(assign{m}));
end
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = ivs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    for j = 1:numel(ivp)
        if ~isempty(ivp{j})
            for k = 1:size(ivp{j},1)
                fprintf(fid, 'BOMB %d %d %.6f %.6f\n', m, p, ivp{j}(k,1), ivp{j}(k,2));
            end
        end
    end
end
for m = 1:3
    U = zeros(0,2);
    for pi = 1:numel(assign{m})
        p = assign{m}(pi);
        ivp = ivs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for j = 1:numel(ivp)
            if ~isempty(ivp{j}), U = [U; ivp{j}]; end
        end
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
            fprintf(fid, 'UNION %d %.6f %.6f\n', m, segs(i,1), segs(i,2));
        end
    end
end
fclose(fid);
fprintf('Q5_segments.txt saved\n');
save(fullfile(here, 'Q5_plan_full.mat'), 'assign', 'routes', 'bombs', 'G_each', 'total');
fprintf('plan saved: Q5_plan_full.mat\n');

%% ================= 局部函数 =================
function U = others(m, group, pi, S_all, routes, bombs)
    U = zeros(0, 2);
    for q = setdiff(group, group(pi))
        ivq = ivs(m, S_all(q,:), routes(q,1), routes(q,2), bombs{q});
        for k = 1:numel(ivq)
            if ~isempty(ivq{k}), U = [U; ivq{k}]; end
        end
    end
end

function ivs_ = ivs(m, S, th, v, bombs)
    ivs_ = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs_{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end

function G = grp(m, group, S_all, routes, bombs)
    U = zeros(0,2);
    for pi = 1:numel(group)
        p = group(pi);
        ivp = ivs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
        end
    end
    G = union_length(U);
end

function bombs = fill(m, S, th, v, bombs, U_bg)
% 固定航线贪心补弹（低阈值 0.01、采样 τ 0.25 s；爆点不钻地由函数保证）
    cap = t_hit5(m);
    tau_max = min(cap, sqrt(max(0.01, S(3)/4.9)));
    U = zeros(0, 2);
    for j = 1:size(bombs,1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), U = [U; ivj]; end
    end
    U_len = union_length([U_bg; U]);
    while size(bombs,1) < 3
        best_inc = 0.01;
        best_b = [];
        for td = 0.5:0.5:ceil(cap)
            for tau = 0.25:0.25:min(td, tau_max)
                t0 = td - tau;
                if t0 < 0, continue; end
                if ~isempty(bombs) && any(abs(t0 - bombs(:,1)) < 1), continue; end
                iv = single_bomb5(S, th, v, t0, tau, m);
                if isempty(iv), continue; end
                inc = union_length([U_bg; U; iv]) - U_len;
                if inc > best_inc
                    best_inc = inc;  best_b = [t0, tau];
                end
            end
        end
        if isempty(best_b), break; end
        bombs(end+1, :) = best_b; %#ok<AGROW>
        iv = single_bomb5(S, th, v, best_b(1), best_b(2), m);
        U = [U; iv];
        U_len = union_length([U_bg; U]);
    end
end

function bombs = climb_bombs(m, S, th, v, bombs, U_bg)
    lev_steps = [2, 0.4, 0.08, 0.016;
                 2, 0.4, 0.08, 0.016];
    tau_max = min(t_hit5(m), sqrt(max(0.01, S(3)/4.9)));
    for j = 1:size(bombs, 1)
        Uj = U_bg;
        for k = setdiff(1:size(bombs,1), j)
            ivk = single_bomb5(S, th, v, bombs(k,1), bombs(k,2), m);
            if ~isempty(ivk), Uj = [Uj; ivk]; end
        end
        for lev = 1:4
            st0 = lev_steps(1, lev);  stau = lev_steps(2, lev);
            best_f = union_length([Uj; single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m)]);
            for c = max(0, bombs(j,1) + (-2:2)*st0)
                if any(abs(c - bombs(setdiff(1:size(bombs,1),j),1)) < 1), continue; end
                for e = max(0.05, min(tau_max, bombs(j,2) + (-2:2)*stau))
                    iv = single_bomb5(S, th, v, c, e, m);
                    if isempty(iv), continue; end
                    f = union_length([Uj; iv]);
                    if f > best_f
                        best_f = f;  bombs(j,:) = [c, e];
                    end
                end
            end
        end
    end
end

function [th, v] = climb_route(m, S, th, v, bombs, U)
    lev_steps = [10, 2, 0.4, 0.08];
    lev_v     = [5, 1, 0.2, 0.04];
    for lev = 1:4
        best_f = gl(m, S, th, v, bombs, U);
        for a = th + (-2:2)*lev_steps(lev)
            for b = max(70, min(140, v + (-2:2)*lev_v(lev)))
                f = gl(m, S, a, b, bombs, U);
                if f > best_f, best_f = f; th = a; v = b; end
            end
        end
    end
end

function f = gl(m, S, th, v, bombs, U)
    iv = U;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), iv = [iv; ivj]; end
    end
    f = union_length(iv);
end
