%% main_Q5.m —— 2025 国赛 A 题 · 问题 5（五机多弹 · 遮 M1/M2/M3）
% 严格按建模手《Q5 模型一页纸》快攻简化版：
%   每机一条航线 (θᵢ, vᵢ) 不转向；每机至多 3 弹；弹指派给导弹；
%   目标 = Σ_m obscure_m（导弹内并集去重，导弹间相加）
% 指派（一页纸 Step 1）：M1←FY1；M2←FY2,FY4；M3←FY3,FY5
% 优化（一页纸 Step 2）：每枚导弹组 = 「Q4 扩展」（多机、每机多弹共享航线）
% 运行方法：MATLAB 中打开本文件，直接点"运行"。（控制台英文防乱码）

clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));      % union_length

S_all = [17800, 0, 1800;                    % FY1
         12000, 1400, 1400;                 % FY2
         6000, -3000, 700;                  % FY3
         11000, 2000, 1800;                 % FY4
         13000, -2000, 1300];               % FY5
assign0 = {1, [2, 4], [3, 5]};              % 一页纸指派：M1←FY1；M2←FY2,4；M3←FY3,5

%% ========== ① 回归测试（一页纸要求）==========
iv1 = single_bomb5(S_all(1,:), 0, 120, 1.5, 3.6, 1);
assert(abs(iv1(1,1) - 8.013) < 0.01 && abs(iv1(1,2) - 9.448) < 0.01, ...
       'regression 1 failed');
fprintf('regression 1 passed: FY1 vs M1 [%.3f, %.3f] (= Q1)\n', iv1(1,1), iv1(1,2));
% 同区间两弹 → 并集只算一次
ivd = union_length([iv1; iv1]);
assert(abs(ivd - union_length(iv1)) < 1e-9, 'regression 2 failed');
fprintf('regression 2 passed: duplicated bombs union = %.3f (counted once)\n', ivd);

%% ========== ② 几何预热：每机 × 每导弹，沿视线采爆点反解可行投放 ==========
% 每个 (机, 导弹) 对：对 tdet 采样、在视线段 [M_m(tdet), T] 采爆点，
% 反解 θ、v（= R/tdet，须 ∈[70,140]）、τ（由高度差反解）、t0，
% 得该弹的候选投放参数（只保留有遮蔽的）。
fprintf('\n========== geometric warm-start ==========\n');
tic;
T_pt = [0 200 5];
cand5 = cell(5, 3);                          % {plane, missile} 候选弹表
for p = 1:5
    S = S_all(p, :);
    for m = 1:3
        cap = t_hit5(m);
        cand = zeros(0, 5);                  % [θ, v, t0, τ, dur]
        for tdet = 1:1:ceil(cap)
            Mm = missile_pos5(m, tdet);
            for f = 0:0.1:1
                Bxy = Mm(1:2) + f * (T_pt(1:2) - Mm(1:2));
                zdes = Mm(3) + f * (T_pt(3) - Mm(3));
                D = Bxy - S(1:2);
                R = norm(D);
                if R < 1, continue; end
                v_req = R / tdet;
                if v_req < 70 || v_req > 140, continue; end
                th = atan2d(D(2)/R, -D(1)/R);
                tau_req = sqrt(max(0, (S(3) - zdes) / 4.9));
                tau_req = min(tau_req, tdet);        % 保证 t0 ≥ 0
                if tau_req^2 * 4.9 > S(3), continue; end  % 爆点不钻地
                t0_req = max(0, tdet - tau_req);
                iv = single_bomb5(S, th, v_req, t0_req, tau_req, m);
                dur = union_length(iv);
                if dur > 0.05
                    cand(end+1, :) = [th, v_req, t0_req, tau_req, dur]; %#ok<AGROW>
                end
            end
        end
        if ~isempty(cand)
            cand = sortrows(cand, -5);
        end
        cand5{p, m} = cand;
        if ~isempty(cand)
            fprintf('FY%d vs M%d: %d candidates, best single = %.3f s\n', ...
                    p, m, size(cand,1), cand(1,5));
        end
    end
end
fprintf('warm-start time %.1f s\n\n', toc);

%% ========== ③ 按一页纸指派分组优化 ==========
fprintf('========== per-missile optimization (base assignment) ==========\n');
tic;
[plan5, G_each] = solve_assignment5(assign0, S_all, cand5);
G_total = sum(G_each);
fprintf('BASE assignment: obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f, Total=%.3f (%.1f s)\n\n', ...
        G_each, G_total, toc);

%% ========== ④ 调机备选方案（一页纸：指派赛后当离散变量调）==========
fprintf('========== alternative assignments ==========\n');
alts = {{1, [2, 4], [3, 5]},                    % 一页纸基准
        {[1, 2], [4], [3, 5]},                  % FY2 调去打 M1
        {[1, 5], [2, 4], [3]},                  % FY5 调去打 M1
        {[1], [2, 4, 3], [5]},                  % FY3 支援 M2（上轮最优）
        {[1], [2], [3, 4, 5]},                  % FY4 支援 M3
        {[1, 4], [2], [3, 5]},                  % FY4 支援 M1
        {[1], [2, 4], [3, 5]},                  % 基准（重算确认稳定性）
        {[1], [2, 3, 4], [5]},                  % FY2,3,4 全打 M2
        {[1], [2, 4], [5, 3]}};                 % 同基准不同序
best_total = G_total;  best_plan = plan5;  best_G_each = G_each;  best_assign = assign0;
for a = 2:numel(alts)
    [pl, Ge] = solve_assignment5(alts{a}, S_all, cand5);
    Gt = sum(Ge);
    fprintf('alt %d: %.3f s  (M1=%.3f, M2=%.3f, M3=%.3f)\n', a, Gt, Ge);
    if Gt > best_total
        best_total = Gt;  best_plan = pl;  best_G_each = Ge;  best_assign = alts{a};
    end
end
fprintf('\n========== Q5 FINAL RESULT ==========\n');
fprintf('best assignment: M1<-FY%s; M2<-FY%s; M3<-FY%s\n', ...
        mat2str(best_assign{1}), mat2str(best_assign{2}), mat2str(best_assign{3}));
for p = 1:5
    pm = best_plan{p};
    fprintf('FY%d: missile=M%d, th=%.3f deg, v=%.2f m/s, %d bombs:\n', ...
            p, pm.m, pm.th, pm.v, size(pm.bombs,1));
    for j = 1:size(pm.bombs,1)
        fprintf('     bomb %d: t0=%.3f s, tau=%.3f s | ', j, pm.bombs(j,1), pm.bombs(j,2));
        for k = 1:size(pm.iv{j},1)
            fprintf('[%.3f, %.3f] ', pm.iv{j}(k,1), pm.iv{j}(k,2));
        end
        fprintf('\n');
    end
end
fprintf('obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f\n', best_G_each);
fprintf('TOTAL = %.3f s\n', best_total);

%% ========== ⑤ 图：三枚导弹的遮蔽接力图（每导弹一张子图）==========
figure('Color','w','Position',[120 120 1000 780]);
cols = {'b', [0 0.6 0], [0.8 0.4 0], [0.6 0 0.6], [0 0.7 0.7]};
for m = 1:3
    subplot(3,1,m); hold on;
    cap = t_hit5(m);
    group = best_assign{m};
    U = zeros(0,2);
    for pi = 1:numel(group)
        p = group(pi);
        pm = best_plan{p};
        for j = 1:size(pm.bombs,1)
            ivj = pm.iv{j};
            if ~isempty(ivj)
                for k = 1:size(ivj,1)
                    plot(ivj(k,1)*[1 1], [0, 1], '-', 'Color', cols{mod(pi-1,4)+1}, ...
                         'LineWidth', 3, 'DisplayName', '');
                end
                U = [U; ivj];
            end
        end
    end
    % 并集段（灰色底纹）
    U = sortrows(U, 1);
    if ~isempty(U)
        cs = U(1,1); ce = U(1,2); segs = zeros(0,2);
        for i = 2:size(U,1)
            if U(i,1) <= ce, ce = max(ce, U(i,2));
            else, segs(end+1,:) = [cs ce]; cs = U(i,1); ce = U(i,2); end
        end
        segs(end+1,:) = [cs ce];
        for i = 1:size(segs,1)
            patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], ...
                  [0 0 1.2 1.2], ...
                  [0.85 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.6);
        end
    end
    xline(cap, 'r:', 'LineWidth', 1.2);
    ylabel(sprintf('M%d', m));
    ylim([-0.1, 1.3]); yticks([]);
    xlim([0, 70]); grid on;
    title(sprintf('M%d shielding relay (union = %.3f s, planes: FY%s)', ...
          m, best_G_each(m), mat2str(group)));
    xlabel('t (s)');
end
saveas(gcf, fullfile(here, 'Q5_三导弹遮蔽接力图.png'));
fprintf('\nfigure saved: Q5_三导弹遮蔽接力图.png\n');

%% ========== ⑥ result3.xlsx（官方模板：无人机 × 弹号，共 15 行）==========
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)','干扰的导弹编号'};
rows = cell(0, 12);
for p = 1:5
    pm = best_plan{p};
    th_p = pm.th*pi/180;  u_p = [-cos(th_p), sin(th_p), 0];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    for j = 1:3                                   % 模板固定 3 行/机
        if j <= size(pm.bombs,1)
            drop = S_all(p,:) + pm.v*pm.bombs(j,1)*u_p;
            det  = drop + pm.v*pm.bombs(j,2)*u_p + [0, 0, -4.9*pm.bombs(j,2)^2];
            ivj_dur = union_length(pm.iv{j});
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, pm.v, j, ...
                drop(1), drop(2), drop(3), det(1), det(2), det(3), ...
                ivj_dur, sprintf('M%d', pm.m)}; %#ok<AGROW>
        else
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, pm.v, j, ...
                '', '', '', '', '', '', '', sprintf('M%d', pm.m)}; %#ok<AGROW>
        end
    end
end
writecell([hdr; rows], fullfile(here, 'result3.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
          fullfile(here, 'result3.xlsx'), 'Sheet', 1, 'Range', 'A17');
% Sheet2 汇总
sum_hdr = {'导弹','分配飞机','并集遮蔽时长(s)'};
sum_rows = cell(3, 3);
for m = 1:3
    sum_rows(m, :) = {sprintf('M%d', m), sprintf('FY%s', mat2str(best_assign{m})), best_G_each(m)};
end
sum_rows(end+1, :) = {'合计', '', best_total};
writecell([sum_hdr; sum_rows], fullfile(here, 'result3.xlsx'), 'Sheet', 2);
fprintf('table saved: result3.xlsx (Sheet1 official, Sheet2 summary)\n');

%% ================= 局部函数 =================
function [plan, G_each] = solve_assignment5(assign, S_all, cand5)
% 按指派方案分组优化：每枚导弹组独立求最优，返回每机方案与每弹并集
    plan = cell(5, 1);
    G_each = zeros(1, 3);
    for m = 1:3
        group = assign{m};
        [Gm, bombs_m, routes_m] = optimize_group5(m, group, S_all, cand5);
        G_each(m) = Gm;
        for pi = 1:numel(group)
            p = group(pi);
            plan{p} = struct('m', m, 'th', routes_m(pi,1), 'v', routes_m(pi,2), ...
                             'bombs', {bombs_m{pi}}, 'iv', {bomb_ivs(m, S_all(p,:), ...
                             routes_m(pi,1), routes_m(pi,2), bombs_m{pi})});
        end
    end
end

function ivs = bomb_ivs(m, S, th, v, bombs)
% 每弹区间列表（cell，与 bombs 行对应）
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end

function [G, bombs_all, routes] = optimize_group5(m, group, S_all, cand5)
% 优化一枚导弹的机群（每机共享一条航线、至多 3 弹）：
%   预热定航线 → 逐轮：每机固定航线贪心补弹（背景增量）→ 逐机航线爬坡
    n = numel(group);
    routes = zeros(n, 2);   bombs_all = cell(n, 1);
    % --- 预热：每机用最优候选定航线（FY1 打 M1 用 Q3 锚点）---
    for pi = 1:n
        p = group(pi);
        if m == 1 && p == 1
            routes(pi, :) = [0.367, 140];          % Q3 成熟锚点
        else
            cand = cand5{p, m};
            if isempty(cand)
                routes(pi, :) = [0, 100];
            else
                routes(pi, :) = cand(1, 1:2);
            end
        end
        bombs_all{pi} = zeros(0, 2);
    end
    % --- 交替爬坡 ---
    for iter = 1:3
        % A) 每机：固定航线，贪心补弹（背景 = 其余机的并集）
        for pi = 1:n
            p = group(pi);
            U = zeros(0, 2);
            for q = setdiff(1:n, pi)
                qq = group(q);
                ivq = bomb_ivs(m, S_all(qq,:), routes(q,1), routes(q,2), bombs_all{q});
                for k = 1:numel(ivq)
                    if ~isempty(ivq{k}), U = [U; ivq{k}]; end
                end
            end
            bombs_all{pi} = gen_bombs5(m, S_all(p,:), routes(pi,1), routes(pi,2), 3, U);
        end
        % B) 每机：固定弹组，块爬坡航线 (θ, v)
        for pi = 1:n
            p = group(pi);
            U = zeros(0, 2);
            for q = setdiff(1:n, pi)
                qq = group(q);
                ivq = bomb_ivs(m, S_all(qq,:), routes(q,1), routes(q,2), bombs_all{q});
                for k = 1:numel(ivq)
                    if ~isempty(ivq{k}), U = [U; ivq{k}]; end
                end
            end
            [thn, vn] = climb_route5(m, S_all(p,:), routes(pi,1), routes(pi,2), ...
                                     bombs_all{pi}, U);
            routes(pi, :) = [thn, vn];
        end
    end
    % --- 汇总并集 ---
    U = zeros(0, 2);
    for pi = 1:n
        p = group(pi);
        ivp = bomb_ivs(m, S_all(p,:), routes(pi,1), routes(pi,2), bombs_all{pi});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
        end
    end
    G = union_length(U);
end

function [th, v] = climb_route5(m, S, th, v, bombs, U)
% 固定弹组，块爬坡优化航线 (θ, v)
    lev_steps = [20, 4, 0.8, 0.16];             % θ (°)
    lev_v     = [10, 2, 0.4, 0.08];             % v (m/s)
    for lev = 1:4
        best_f = group_len5(m, S, th, v, bombs, U);
        for a = th + (-2:2)*lev_steps(lev)
            for b = max(70, min(140, v + (-2:2)*lev_v(lev)))
                f = group_len5(m, S, a, b, bombs, U);
                if f > best_f
                    best_f = f;  th = a;  v = b;
                end
            end
        end
    end
end

function f = group_len5(m, S, th, v, bombs, U)
% 该机弹组与背景 U 合并后的并集时长
    iv = U;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), iv = [iv; ivj]; end
    end
    f = union_length(iv);
end
