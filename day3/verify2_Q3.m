%% verify2_Q3.m —— 第 3 题新冠军邻域核验（微小步长 + 验证轮）
% 冠军：θ=0.3801, v=140, t0=[0, 2.416, 4.9287], τ=[3.7181, 4.7180, 5.8098], 并集 7.468 s
% ① 微小步长爬坡两轮（步长比 finalize 末级再细），看有无改进
% ② 验证轮：末级步长邻域内中心是否即 argmax
% ③ 联合移动探测：同时微调 (τ1, t02) 与 (t02, τ2) 等组合方向（块爬山可能卡住的关节）
clear; clc;

champ = [0.3801, 140, 0, 3.7181, 2.4160, 4.7180, 4.9287, 5.8098];
G0 = objective3(champ);
fprintf('champion: %.5f s\n\n', G0);

%% ① 微小步长爬坡
X = champ;
step_th0 = 0.002; step_v0 = 0.05; step_t0_0 = 0.001; step_tau0 = 0.0005;
for round = 1:3
    f = 1/3^(round-1);
    X = rb(X, 1, step_th0*f, [-180, 180]);
    X = rb(X, 2, step_v0*f,  [70, 140]);
    for bomb = 1:3
        X = rbomb(X, bomb, step_t0_0*f, step_tau0*f);
    end
    fprintf('climb round %d: %.5f s (%+.5f)\n', round, objective3(X), objective3(X)-G0);
end

%% ② 验证轮
d = [step_th0/9, step_v0/9, step_t0_0/9, step_tau0/9];
Xv = X;
for extra = 1:3
    Xt = rb(Xv, 1, d(1), [-180,180]);
    Xt = rb(Xt, 2, d(2), [70,140]);
    for bomb = 1:3, Xt = rbomb(Xt, bomb, d(3), d(4)); end
    if objective3(Xt) > objective3(Xv) + 1e-9
        fprintf('verify round %d: improved to %.5f s\n', extra, objective3(Xt));
        Xv = Xt;
    else
        fprintf('verify round %d: center is argmax, converged.\n', extra);
        break;
    end
end
Gv = objective3(Xv);

%% ③ 联合移动探测（关节方向，步长 0.02/0.004）
fprintf('\njoint-move probe:\n');
best_j = Gv; X_j = Xv;
pairs = {[3 4], [4 5], [5 6], [6 7], [7 8], [4 7], [3 6], [5 8]};  % (dim_i, dim_j) 组合
for s = 1:numel(pairs)
    pr = pairs{s};
    for sc = [0.02, 0.004]
        di = pr(1); dj = pr(2);
        for si = -2:2
            for sj = -2:2
                if si == 0 && sj == 0, continue; end
                Xt = Xv;
                Xt(di) = Xt(di) + si*sc;
                Xt(dj) = Xt(dj) + sj*sc;
                % 约束修复
                if Xt(3) < 0, Xt(3) = 0; end
                if Xt(5) < 0, Xt(5) = 0; end
                if Xt(7) < 0, Xt(7) = 0; end
                f = objective3(Xt);
                if f > best_j
                    best_j = f; X_j = Xt;
                    fprintf('  pair (%d,%d) step %.3f (%+d,%+d): %.5f s\n', di, dj, sc, si, sj, f);
                end
            end
        end
    end
end
if best_j > Gv + 1e-6
    fprintf('!!! joint move found better point: %.5f s\n', best_j);
    fprintf('    th=%.4f v=%.3f t0=[%.4f %.4f %.4f] tau=[%.4f %.4f %.4f]\n', ...
            X_j(1), X_j(2), X_j(3), X_j(5), X_j(7), X_j(4), X_j(6), X_j(8));
else
    fprintf('-> no joint move improves; point confirmed.\n');
end

fprintf('\nFINAL CHECK: champion %.5f s vs verified %.5f s (delta %+.5f)\n', ...
        G0, max(Gv, best_j), max(Gv, best_j)-G0);

%% ================= 局部函数 =================
function X = rb(X, dim, step, lim)
    cands = max(lim(1), min(lim(2), X(dim) + (-2:2)*step));
    best_f = objective3(X);
    for c = cands
        Xt = X; Xt(dim) = c;
        f = objective3(Xt);
        if f > best_f, best_f = f; X = Xt; end
    end
end

function X = rbomb(X, bomb, step_t0, step_tau)
    i0 = 3 + (bomb-1)*2;
    c_t0  = max(0, X(i0) + (-2:2)*step_t0);
    c_tau = max(0.2, X(i0+1) + (-2:2)*step_tau);
    best_f = objective3(X);
    for ct = c_t0
        if bomb > 1 && ct < X(i0-2) + 1, continue; end
        if bomb < 3 && ct > X(i0+2) - 1, continue; end
        for cu = c_tau
            Xt = X; Xt(i0) = ct; Xt(i0+1) = cu;
            f = objective3(Xt);
            if f > best_f, best_f = f; X = Xt; end
        end
    end
end
