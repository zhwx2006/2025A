%% finalize2_Q5.m —— 第 5 题定型精修（只算数，结果存 Q5_plan.mat）
% 与 finalize_Q5 相同的起点，改进：
%   ① 每轮加「逐弹块爬山」：保留链式弹组并精修，不被贪心重建拆散；
%   ② FY1 打 M1 用 Q3 最优弹组做保底对照；
%   ③ 结果存 Q5_plan.mat，出图出表交给 deliver_Q5.m（拆开防批处理崩溃）。
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];
assign = {1, [2, 4, 3], 5};
plan0_th = [0.3665; -82.734; 28.072; -84.347; 63.797];
plan0_v  = [140.00; 140.00; 138.74; 134.45; 119.19];
bombs0 = cell(5,1);
bombs0{1} = [0, 3.7109; 2.9588, 5.0976; 5.2427, 5.9255];   % Q3 最优三弹

routes = zeros(5,2);
bombs  = cell(5,1);
for p = 1:5
    routes(p,:) = [plan0_th(p), plan0_v(p)];
    if isempty(bombs0{p})
        bombs{p} = zeros(0,2);
    else
        bombs{p} = bombs0{p};
    end
end

for m = 1:3
    group = assign{m};
    fprintf('--- refining M%d (planes FY%s) ---\n', m, mat2str(group));
    for iter = 1:6
        % A) 每机贪心补弹（低阈值、细采样；只增不删）
        for pi = 1:numel(group)
            p = group(pi);
            U = bombs_of_others(m, group, pi, S_all, routes, bombs);
            bn = gen_fill5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
            if size(bn,1) > size(bombs{p},1)
                bombs{p} = bn;
            end
        end
        % B) 每机逐弹块爬山（保留链式结构）
        for pi = 1:numel(group)
            p = group(pi);
            U = bombs_of_others(m, group, pi, S_all, routes, bombs);
            bombs{p} = climb_bombs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        % C) 每机航线爬坡
        for pi = 1:numel(group)
            p = group(pi);
            U = bombs_of_others(m, group, pi, S_all, routes, bombs);
            [thn, vn] = climb_route5b(m, S_all(p,:), routes(p,1), routes(p,2), ...
                                      bombs{p}, U);
            routes(p,:) = [thn, vn];
        end
        Gnow = group_union5(m, group, S_all, routes, bombs);
        fprintf('  iter %d: M%d union = %.4f s\n', iter, m, Gnow);
    end
end

G_each = zeros(1,3);
for m = 1:3
    G_each(m) = group_union5(m, assign{m}, S_all, routes, bombs);
end
total = sum(G_each);
fprintf('\nobscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f\n', G_each);
fprintf('TOTAL = %.3f s\n', total);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    fprintf('FY%d (M%d): th=%.3f, v=%.2f, %d bombs: ', p, m, routes(p,1), routes(p,2), size(bombs{p},1));
    for j = 1:numel(ivp)
        if isempty(ivp{j})
            fprintf('[EMPTY] ');
        else
            for k = 1:size(ivp{j},1)
                fprintf('[%.3f,%.3f] ', ivp{j}(k,1), ivp{j}(k,2));
            end
        end
    end
    fprintf('\n');
end

save(fullfile(here, 'Q5_plan.mat'), 'assign', 'routes', 'bombs', 'G_each', 'total');
fprintf('\nplan saved: Q5_plan.mat\n');

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

function G = group_union5(m, group, S_all, routes, bombs)
    U = zeros(0,2);
    for pi = 1:numel(group)
        p = group(pi);
        ivp = bomb_ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
        end
    end
    G = union_length(U);
end

function bombs = gen_fill5(m, S, th, v, bombs, U_bg)
% 在现有弹组基础上贪心增弹（只增不删，阈值 0.01，采样 τ 0.25 s）
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

function bombs = climb_bombs5(m, S, th, v, bombs, U_bg)
% 逐弹块爬山：第 j 弹 (t0, τ) 在其余弹与背景固定下做收缩块搜索
    lev_steps = [2, 0.4, 0.08, 0.016;        % t0 (s)
                 2, 0.4, 0.08, 0.016];       % τ (s)
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
                    bt = bombs;  bt(j,:) = [c, e];
                    iv = single_bomb5(S, th, v, c, e, m);
                    if isempty(iv), continue; end
                    f = union_length([Uj; iv]);
                    if f > best_f
                        best_f = f;  bombs = bt;
                    end
                end
            end
        end
    end
end

function [th, v] = climb_route5b(m, S, th, v, bombs, U)
    lev_steps = [10, 2, 0.4, 0.08];
    lev_v     = [5, 1, 0.2, 0.04];
    for lev = 1:4
        best_f = glen5(m, S, th, v, bombs, U);
        for a = th + (-2:2)*lev_steps(lev)
            for b = max(70, min(140, v + (-2:2)*lev_v(lev)))
                f = glen5(m, S, a, b, bombs, U);
                if f > best_f, best_f = f; th = a; v = b; end
            end
        end
    end
end

function f = glen5(m, S, th, v, bombs, U)
    iv = U;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), iv = [iv; ivj]; end
    end
    f = union_length(iv);
end
