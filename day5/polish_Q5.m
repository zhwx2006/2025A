%% polish_Q5.m —— 第 5 题深度抛光：从 Q5_plan.mat 载入，三组各再爬 4 轮
% 也包含 M3 的混合簇初始化试探（FY5 单机三弹能否拉开接力）。
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];
T_pt = [0 200 5];
fprintf('loaded: Total = %.3f s\n\n', total);

%% ---------- M3 混合簇试探（FY5 单机，早/中/晚三簇各起一次）----------
m = 3;
cap = t_hit5(m);
p = 5;  S = S_all(5, :);
best3 = G_each(3);
best3_iv = bombs{5};  best3_rt = routes(5, :);
for cluster = 1:3
    if cluster == 1, tds = 2:1:20;
    elseif cluster == 2, tds = 20:1:40;
    else, tds = 40:1:ceil(cap); end
    best_dur = -1;  th0 = routes(5,1);  v0 = routes(5,2);  b0 = bombs{5};
    for td = tds
        Mm = missile_pos5(m, td);
        for f = 0:0.1:1
            Bxy = Mm(1:2) + f*(T_pt(1:2) - Mm(1:2));
            zdes = Mm(3) + f*(T_pt(3) - Mm(3));
            D = Bxy - S(1:2);
            R = norm(D);
            if R < 1, continue; end
            v_req = R / td;
            if v_req < 70 || v_req > 140, continue; end
            th = atan2d(D(2)/R, -D(1)/R);
            tau_req = sqrt(max(0, (S(3) - zdes)/4.9));
            tau_req = min(tau_req, td);
            if tau_req^2*4.9 > S(3), continue; end
            t0_req = max(0, td - tau_req);
            iv = single_bomb5(S, th, v_req, t0_req, tau_req, m);
            dur = union_length(iv);
            if dur > best_dur
                best_dur = dur;  th0 = th;  v0 = v_req;  b0 = [t0_req, tau_req];
            end
        end
    end
    if best_dur > 0
        [G3, b_out, rt_out] = opt_group_p(3, 5, S_all, [th0, v0], {b0}, 4);
        fprintf('M3 cluster %d start: union = %.4f s\n', cluster, G3);
        if G3 > best3
            best3 = G3;
            bombs{5} = b_out;              % 应用到主方案
            routes(5, :) = rt_out;
            fprintf('  -> applied to plan (FY5)\n');
        end
    end
end
fprintf('M3 baseline = %.4f (cluster test best shown above)\n\n', G_each(3));

%% ---------- 三组深度抛光（各 4 轮：补弹 + 逐弹爬山 + 航线爬坡）----------
for m = 1:3
    group = assign{m};
    for iter = 1:4
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            bombs{p} = fill5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            bombs{p} = climb_bombs5p(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            [thn, vn] = climb_route5p(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
            routes(p,:) = [thn, vn];
        end
        fprintf('M%d polish iter %d: %.4f s\n', m, iter, grp_union(m, group, S_all, routes, bombs));
    end
end

for m = 1:3
    G_each(m) = grp_union(m, assign{m}, S_all, routes, bombs);
end
total = sum(G_each);
fprintf('\nobscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f\n', G_each);
fprintf('TOTAL = %.3f s\n', total);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
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
fprintf('\nplan saved\n');

%% ================= 局部函数 =================
function [G, bombs_out, routes_out] = opt_group_p(m, p, S_all, route0, bombs0, n_iter)
% 单机组快速优化（供 M3 试探用）：航线单行、弹组矩阵，直接算并集
    routes_out = route0;  bombs_out = bombs0{1};
    for iter = 1:n_iter
        U = zeros(0,2);
        bombs_out = fill5(m, S_all(p,:), routes_out(1), routes_out(2), bombs_out, U);
        bombs_out = climb_bombs5p(m, S_all(p,:), routes_out(1), routes_out(2), bombs_out, U);
        [thn, vn] = climb_route5p(m, S_all(p,:), routes_out(1), routes_out(2), bombs_out, U);
        routes_out = [thn, vn];
    end
    ivs = ivs5(m, S_all(p,:), routes_out(1), routes_out(2), bombs_out);
    U = zeros(0,2);
    for k = 1:numel(ivs)
        if ~isempty(ivs{k}), U = [U; ivs{k}]; end
    end
    G = union_length(U);
end

function U = others5(m, group, pi, S_all, routes, bombs)
    U = zeros(0, 2);
    for q = setdiff(group, group(pi))
        ivq = ivs5(m, S_all(q,:), routes(q,1), routes(q,2), bombs{q});
        for k = 1:numel(ivq)
            if ~isempty(ivq{k}), U = [U; ivq{k}]; end
        end
    end
end

function ivs = ivs5(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end

function G = grp_union(m, group, S_all, routes, bombs)
    U = zeros(0,2);
    if numel(group) == 1
        ivp = ivs5(m, S_all(group,:), routes(group,1), routes(group,2), bombs{group});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
        end
    else
        for pi = 1:numel(group)
            p = group(pi);
            ivp = ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
            for k = 1:numel(ivp)
                if ~isempty(ivp{k}), U = [U; ivp{k}]; end
            end
        end
    end
    G = union_length(U);
end

function bombs = fill5(m, S, th, v, bombs, U_bg)
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

function bombs = climb_bombs5p(m, S, th, v, bombs, U_bg)
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

function [th, v] = climb_route5p(m, S, th, v, bombs, U)
    lev_steps = [10, 2, 0.4, 0.08];
    lev_v     = [5, 1, 0.2, 0.04];
    for lev = 1:4
        best_f = gl5p(m, S, th, v, bombs, U);
        for a = th + (-2:2)*lev_steps(lev)
            for b = max(70, min(140, v + (-2:2)*lev_v(lev)))
                f = gl5p(m, S, a, b, bombs, U);
                if f > best_f, best_f = f; th = a; v = b; end
            end
        end
    end
end

function f = gl5p(m, S, th, v, bombs, U)
    iv = U;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj), iv = [iv; ivj]; end
    end
    f = union_length(iv);
end
