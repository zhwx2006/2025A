%% verify_Q3.m —— 第 3 题冠军验证（防漏低速盆地 + 邻域局部最优确认）
% 冠军：θ=0.28°, v=140, t0=[0, 2.416, 4.888], τ=[3.548, 4.708, 5.852], 并集 7.136 s
% ① 低速区细网格安全网：θ∈[-2,6], v∈[70,95], t0 步长 0.5, τ 步长 0.25，
%    组合阈值 4.5，前 10 名块精修 —— 检查有没有被粗网格漏掉的更优低速盆地
% ② 冠军邻域确认：微小步长块搜索，确认无更优点
clear; clc;

champ = [0.280, 140, 0, 3.548, 2.416, 4.708, 4.888, 5.852];
G_champ = objective3(champ);
fprintf('champion union = %.4f s\n\n', G_champ);

%% ① 低速区安全网（细 τ 网格，防窄山脊漏检）
fprintf('===== 1) low-v safety net (fine tau grid) =====\n');
tic;
th_g = -2:1:6;
v_g  = 70:5:95;
t0_g = 0:0.5:12;
tau_g = 1:0.25:6;
bombs = struct('th',{},'v',{},'t0',{},'tau',{},'iv',{},'dur',{});
nb = 0;
for a = 1:numel(th_g)
    for b = 1:numel(v_g)
        for c = 1:numel(t0_g)
            for e = 1:numel(tau_g)
                iv = one_cloud_interval(th_g(a), v_g(b), t0_g(c), tau_g(e));
                dur = union_length(iv);
                if dur > 0.3
                    nb = nb + 1;
                    bombs(nb) = struct('th', th_g(a), 'v', v_g(b), ...
                        't0', t0_g(c), 'tau', tau_g(e), 'iv', {iv}, 'dur', dur);
                end
            end
        end
    end
end
fprintf('bombs kept: %d (%.1f s)\n', nb, toc);
best_G = 0; best_X = [];
top = zeros(0, 9);
for a = 1:numel(th_g)
    for b = 1:numel(v_g)
        sel = find([bombs.th] == th_g(a) & [bombs.v] == v_g(b));
        N = numel(sel);
        if N < 3, continue; end
        t0s = [bombs(sel).t0];
        for i = 1:N
            for j = 1:N
                if t0s(j) < t0s(i) + 1, continue; end
                for k = 1:N
                    if t0s(k) < t0s(j) + 1, continue; end
                    G = union_length([bombs(sel(i)).iv; bombs(sel(j)).iv; bombs(sel(k)).iv]);
                    if G > 4.5
                        X = [th_g(a), v_g(b), bombs(sel(i)).t0, bombs(sel(i)).tau, ...
                             bombs(sel(j)).t0, bombs(sel(j)).tau, bombs(sel(k)).t0, bombs(sel(k)).tau];
                        top(end+1, :) = [G, X]; %#ok<AGROW>
                        if G > best_G, best_G = G; best_X = X; end
                    end
                end
            end
        end
    end
end
fprintf('low-v coarse best = %.3f s\n', best_G);
[top, o] = sortrows(top, -1); top = top(o, :);
[~, uq] = unique(round(top(:,2:end)*1e6), 'rows', 'stable');
top = top(sort(uq), :);
top = top(1:min(10, size(top,1)), :);
step_th  = [1,   0.2,  0.04, 0.008];
step_v   = [5,   1,    0.2,  0.04];
step_t0  = [0.5, 0.1,  0.02, 0.004];
step_tau = [0.25,0.05, 0.01, 0.002];
G_low = -1; X_low = [];
for s = 1:size(top, 1)
    X = top(s, 2:end);
    for round = 1:4
        X = refine_block_v(X, 1, step_th(round),  [-180, 180]);
        X = refine_block_v(X, 2, step_v(round),   [70, 140]);
        for bomb = 1:3
            X = refine_bomb_v(X, bomb, step_t0(round), step_tau(round));
        end
    end
    G = objective3(X);
    fprintf('low-v start%2d -> (th=%.3f, v=%.3f, t0=[%.3f %.3f %.3f], tau=[%.3f %.3f %.3f]) %.4f s\n', ...
            s, X(1), X(2), X(3), X(5), X(7), X(4), X(6), X(8), G);
    if G > G_low, G_low = G; X_low = X; end
end
if G_low > G_champ + 1e-4
    fprintf('!!! LOW-V BASIN BEATS CHAMPION: %.4f s\n', G_low);
else
    fprintf('-> no low-v basin beats champion (%.4f vs %.4f)\n', G_low, G_champ);
end

%% ② 冠军邻域确认（微小步长）
fprintf('\n===== 2) champion neighborhood check =====\n');
X = champ;
G0 = G_champ;
step_th  = [0.04, 0.008];
step_v   = [0.4,  0.08];
step_t0  = [0.02, 0.004];
step_tau = [0.01, 0.002];
for round = 1:2
    X = refine_block_v(X, 1, step_th(round),  [-180, 180]);
    X = refine_block_v(X, 2, step_v(round),   [70, 140]);
    for bomb = 1:3
        X = refine_bomb_v(X, bomb, step_t0(round), step_tau(round));
    end
end
G1 = objective3(X);
fprintf('after tiny-step climb: %.4f s (champion %.4f, delta %+.5f)\n', G1, G0, G1-G0);
if G1 > G0 + 1e-4
    fprintf('!!! champion is NOT locally optimal, refined point:\n');
    fprintf('    th=%.4f, v=%.4f, t0=[%.4f %.4f %.4f], tau=[%.4f %.4f %.4f]\n', ...
            X(1), X(2), X(3), X(5), X(7), X(4), X(6), X(8));
else
    fprintf('-> champion confirmed locally optimal\n');
end

%% ================= 局部函数（与 main_Q3 相同）=================
function X = refine_block_v(X, dim, step, lim)
    cands = X(dim) + (-2:2)*step;
    cands = max(lim(1), min(lim(2), cands));
    best_f = objective3(X);
    for c = cands
        Xt = X;  Xt(dim) = c;
        f = objective3(Xt);
        if f > best_f
            best_f = f;  X = Xt;
        end
    end
end

function X = refine_bomb_v(X, bomb, step_t0, step_tau)
    i0 = 3 + (bomb-1)*2;
    c_t0  = max(0, X(i0) + (-2:2)*step_t0);
    c_tau = max(0.2, X(i0+1) + (-2:2)*step_tau);
    best_f = objective3(X);
    for ct = c_t0
        if bomb > 1 && ct < X(i0-2) + 1, continue; end
        if bomb < 3 && ct > X(i0+2) - 1, continue; end
        for cu = c_tau
            Xt = X;  Xt(i0) = ct;  Xt(i0+1) = cu;
            f = objective3(Xt);
            if f > best_f
                best_f = f;  X = Xt;
            end
        end
    end
end
