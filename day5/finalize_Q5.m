%% finalize_Q5.m —— 第 5 题定型精修：Q3 锚点初始化 + 全机精细抛光
% 起点 = main_Q5 最优指派：M1←FY1；M2←FY2,FY4,FY3；M3←FY5
% 修复两点：
%   ① FY1 打 M1 直接用 Q3 最优弹组初始化（Q3 单机三弹 7.627 s，本处应接近）；
%   ② 每机贪心补弹：增量阈值 0.05→0.01，采样加密（td 0.5 s、τ 0.25 s），
%      让每机尽量多投弹填满可覆盖时段。
% 抛光：炸弹块爬山 × 航线块爬山 × 跨参数联合移动，交替到收敛。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];
% 最优指派（main_Q5 结果）：M1←FY1；M2←FY2,FY4,FY3；M3←FY5
assign = {1, [2, 4, 3], 5};
plan0_th = [0.3665; -82.814; 28.072; -84.347; 63.717];
plan0_v  = [140.00; 140.00; 138.62; 134.49; 119.27];
% FY1 用 Q3 最优弹组初始化（Q3 三弹并集 7.627 s）
bombs0 = cell(5,1);
bombs0{1} = [0, 3.7109; 2.9588, 5.0976; 5.2427, 5.9255];

%% ---------- 逐导弹组精修 ----------
G_each = zeros(1,3);
routes = zeros(5,2);
bombs  = cell(5,1);
for m = 1:3
    group = assign{m};
    for pi = 1:numel(group)
        p = group(pi);
        routes(p,:) = [plan0_th(p), plan0_v(p)];
        if isempty(bombs0{p})
            bombs{p} = zeros(0,2);
        else
            bombs{p} = bombs0{p};
        end
    end
end

for m = 1:3
    group = assign{m};
    fprintf('--- refining M%d (planes FY%s) ---\n', m, mat2str(group));
    for iter = 1:6
        % A) 每机贪心补弹（低阈值、细采样）
        for pi = 1:numel(group)
            p = group(pi);
            U = bombs_of_others(m, group, pi, S_all, routes, bombs);
            bombs{p} = gen_bombs5_fine(m, S_all(p,:), routes(p,1), routes(p,2), 3, U);
        end
        % B) 每机航线爬坡
        for pi = 1:numel(group)
            p = group(pi);
            U = bombs_of_others(m, group, pi, S_all, routes, bombs);
            [thn, vn] = climb_route5_fine(m, S_all(p,:), routes(p,1), routes(p,2), ...
                                          bombs{p}, U);
            routes(p,:) = [thn, vn];
        end
    end
    % C) 该组汇总
    U = zeros(0,2);
    for pi = 1:numel(group)
        p = group(pi);
        ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
        end
    end
    G_each(m) = union_length(U);
    fprintf('M%d union = %.3f s\n', m, G_each(m));
end
fprintf('\nTotal = %.3f s\n', sum(G_each));

%% ---------- 输出 ----------
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    fprintf('FY%d (M%d): th=%.3f, v=%.2f, %d bombs: ', p, m, routes(p,1), routes(p,2), size(bombs{p},1));
    for j = 1:numel(ivp)
        if isempty(ivp{j})
            fprintf('[EMPTY] ');
        else
            for k = 1:size(ivp{j},1)
                fprintf('[%.2f,%.2f] ', ivp{j}(k,1), ivp{j}(k,2));
            end
        end
    end
    fprintf('\n');
end

%% ---------- 图 ----------
figure('Color','w','Position',[120 120 1000 780]);
for m = 1:3
    subplot(3,1,m); hold on;
    group = assign{m};
    U = zeros(0,2);
    ci = 0;
    cols = {'b', [0 0.6 0], [0.8 0.4 0], [0.6 0 0.6]};
    for pi = 1:numel(group)
        p = group(pi);
        ci = ci + 1;
        ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for j = 1:numel(ivp)
            if ~isempty(ivp{j})
                for k = 1:size(ivp{j},1)
                    plot(ivp{j}(k,1)*[1 1], [0, 1], '-', 'Color', cols{ci}, 'LineWidth', 4);
                end
                U = [U; ivp{j}];
            end
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
            patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], [0 0 1.2 1.2], ...
                  [0.85 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.6);
        end
    end
    xline(t_hit5(m), 'r:', 'LineWidth', 1.2);
    ylabel(sprintf('M%d', m)); ylim([-0.1, 1.3]); yticks([]);
    xlim([0, 70]); grid on;
    title(sprintf('M%d relay (union=%.3f s, planes FY%s)', m, G_each(m), mat2str(group)));
    xlabel('t (s)');
end
saveas(gcf, fullfile(here, 'Q5_三导弹遮蔽接力图.png'));
fprintf('\nfigure saved\n');

%% ---------- result3.xlsx ----------
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)','干扰的导弹编号'};
rows = cell(0, 12);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    th_p = routes(p,1)*pi/180;  u_p = [-cos(th_p), sin(th_p), 0];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    for j = 1:3
        if j <= size(bombs{p},1)
            drop = S_all(p,:) + routes(p,2)*bombs{p}(j,1)*u_p;
            det  = drop + routes(p,2)*bombs{p}(j,2)*u_p + [0, 0, -4.9*bombs{p}(j,2)^2];
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
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
          fullfile(here, 'result3.xlsx'), 'Sheet', 1, 'Range', 'A17');
sum_hdr = {'导弹','分配飞机','并集遮蔽时长(s)'};
sum_rows = cell(3, 3);
for m = 1:3
    sum_rows(m, :) = {sprintf('M%d', m), sprintf('FY%s', mat2str(assign{m})), G_each(m)};
end
sum_rows(end+1, :) = {'合计', '', sum(G_each)};
writecell([sum_hdr; sum_rows], fullfile(here, 'result3.xlsx'), 'Sheet', 2);
fprintf('table saved: result3.xlsx\n');

%% ================= 局部函数 =================
function U = bombs_of_others(m, group, pi, S_all, routes, bombs)
    U = zeros(0, 2);
    for q = setdiff(group, group(pi))
        ivq = bomb_ivs5(m, S_all(q,:), routes(q,1), routes(q,2), bombs{q});
        for k = 1:numel(ivq)
            if ~isempty(ivq{k}), U = [U; ivq{k}]; end
        end
    end
end

function ivs = bomb_ivs5(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end

function bombs = gen_bombs5_fine(m, S, th, v, nb_max, U_bg)
% 固定航线贪心补弹（低阈值 0.01、细采样 td 0.5 s / τ 0.25 s）
    cap = t_hit5(m);
    tau_max = min(cap, sqrt(max(0.01, S(3)/4.9)));
    U = zeros(0, 2);
    bombs = zeros(0, 2);
    U_len = union_length([U_bg; U]);
    for j = 1:nb_max
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

function [th, v] = climb_route5_fine(m, S, th, v, bombs, U)
    lev_steps = [10, 2, 0.4, 0.08];
    lev_v     = [5, 1, 0.2, 0.04];
    for lev = 1:4
        best_f = glen(m, S, th, v, bombs, U);
        for a = th + (-2:2)*lev_steps(lev)
            for b = max(70, min(140, v + (-2:2)*lev_v(lev)))
                f = glen(m, S, a, b, bombs, U);
                if f > best_f, best_f = f; th = a; v = b; end
            end
        end
    end
end

function f = glen(m, S, th, v, bombs, U)
    iv = U;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), iv = [iv; ivj]; end
    end
    f = union_length(iv);
end
