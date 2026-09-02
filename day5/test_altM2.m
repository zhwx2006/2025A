%% test_altM2.m —— 验证假设：FY4/FY2 换中段航线能否填补 M2 中段空洞
% 假设：FY4 从 (11000,2000,1800) 以 θ≈−35°、v≈85 飞，可在 ~35 s 覆盖
%       M2 中段视线（LOS z≈950 m 附近），当前解卡在早段航线孤岛。
% 方法：M2 组用多种初始化（早/中/晚簇）分别优化，取全局最优。
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));        % 当前最优（Total=28.267）
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];
T_pt = [0 200 5];
m = 2;
group = [2, 4, 3];

%% ---------- 为每机生成「早/中/晚」三类航线初始化 ----------
% 对每个 (起爆时刻簇)，找几何可行且单弹时长最大的投放
cap = t_hit5(m);
init_sets = struct('name', {}, 'routes', {}, 'bombs', {});
for cluster = 1:3          % 1=早(≤20)，2=中(20~45)，3=晚(>45)
    rt = zeros(3, 2);  bm = cell(3, 1);
    for pi = 1:3
        p = group(pi);
        S = S_all(p, :);
        best_dur = -1;
        if cluster == 1, tds = 2:1:20;
        elseif cluster == 2, tds = 20:1:45;
        else, tds = 45:1:ceil(cap); end
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
                    best_dur = dur;
                    rt(pi, :) = [th, v_req];
                    bm{pi} = [t0_req, tau_req];
                end
            end
        end
        if best_dur < 0          % 该簇无几何可行解 → 用当前解
            rt(pi, :) = routes(p, :);
            bm{pi} = bombs{p}(1, :);
        end
    end
    init_sets(end+1) = struct('name', sprintf('cluster%d', cluster), ...
                              'routes', {rt}, 'bombs', {bm}); %#ok<AGROW>
end
% 混合簇组合（关键假设：FY2 早 + FY4 中 + FY3 晚；及 FY2 中 + FY4 早 + FY3 晚）
mix = struct('name', {}, 'pick', {});
mix(end+1) = struct('name', 'FY2早+FY4中+FY3晚', 'pick', {[1 2 3]});
mix(end+1) = struct('name', 'FY2中+FY4早+FY3晚', 'pick', {[2 1 3]});
mix(end+1) = struct('name', 'FY2早+FY4中+FY3中', 'pick', {[1 2 2]});
mix(end+1) = struct('name', 'FY2中+FY4中+FY3晚', 'pick', {[2 2 3]});
mix(end+1) = struct('name', 'FY2早+FY4晚+FY3晚', 'pick', {[1 3 3]});
mix(end+1) = struct('name', 'FY2晚+FY4中+FY3晚', 'pick', {[3 2 3]});

best_total2 = G_each(2);  best_rt = zeros(5,2);  best_bm = cell(5,1);
for i = 1:numel(mix)
    rt5 = zeros(5,2);  bm5 = cell(5,1);
    for pi = 1:3
        p = group(pi);
        c = mix(i).pick(pi);
        rt5(p, :) = init_sets(c).routes(pi, :);
        bm5{p} = init_sets(c).bombs{pi};
    end
    % 快速优化（3 轮：补弹 + 逐弹爬山 + 航线爬坡）
    [G2, bm5, rt5] = opt_group_fast(m, group, S_all, rt5, bm5, 2);
    fprintf('%s: M2 union = %.4f s\n', mix(i).name, G2);
    if G2 > best_total2
        best_total2 = G2;
        for pi = 1:3
            p = group(pi);
            best_rt(p, :) = rt5(p, :);
            best_bm{p} = bm5{p};
        end
    end
end

fprintf('\nbaseline M2 = %.4f; best alt M2 = %.4f\n', G_each(2), best_total2);
if best_total2 > G_each(2) + 0.05
    fprintf('!!! better M2 found, updating plan\n');
    for pi = 1:3
        p = group(pi);
        routes(p, :) = best_rt(p, :);
        bombs{p} = best_bm{p};
    end
    G_each(2) = best_total2;
    total = sum(G_each);
    save(fullfile(here, 'Q5_plan.mat'), 'assign', 'routes', 'bombs', 'G_each', 'total');
    fprintf('new Total = %.3f s, plan saved\n', total);
else
    fprintf('baseline stands\n');
end

%% ================= 局部函数 =================
function [G, bombs, routes] = opt_group_fast(m, group, S_all, routes, bombs, n_iter)
    for iter = 1:n_iter
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            bombs{p} = fill5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            bombs{p} = climb_bombs(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
        end
        for pi = 1:numel(group)
            p = group(pi);
            U = others5(m, group, pi, S_all, routes, bombs);
            [thn, vn] = climb_route(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p}, U);
            routes(p,:) = [thn, vn];
        end
    end
    G = grp_union(m, group, S_all, routes, bombs);
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
    for pi = 1:numel(group)
        p = group(pi);
        ivp = ivs5(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for k = 1:numel(ivp)
            if ~isempty(ivp{k}), U = [U; ivp{k}]; end
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
