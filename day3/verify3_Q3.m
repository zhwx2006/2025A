%% verify3_Q3.m —— 第 3 题 7.627 s 冠军的独立终审
% ① 细步长联合移动探测（0.01/0.002/0.0004），覆盖全部相邻与跨弹对
% ② 细步长坐标爬坡
% ③ 结论：若均无 >1e-4 改进 → 确认为局部最优
clear; clc;

champ = [0.3665, 140, 0, 3.7110, 2.9580, 5.0960, 5.2419, 5.9253];
G0 = objective3(champ);
fprintf('champion: %.5f s\n', G0);

X = champ; G = G0;
pairs = {[3 4],[4 5],[5 6],[6 7],[7 8],[4 7],[3 6],[5 8],[4 6],[6 8],[3 5],[3 7],[3 8]};

%% ① 联合移动三级
for sc = [0.01, 0.002, 0.0004]
    Gb = G;
    for s = 1:numel(pairs)
        pr = pairs{s}; di = pr(1); dj = pr(2);
        for si = -2:2
            for sj = -2:2
                if si == 0 && sj == 0, continue; end
                Xt = X; Xt(di) = Xt(di) + si*sc; Xt(dj) = Xt(dj) + sj*sc;
                Xt(3) = max(0, Xt(3)); Xt(5) = max(0, Xt(5)); Xt(7) = max(0, Xt(7));
                f = objective3(Xt);
                if f > G + 1e-9, X = Xt; G = f; end
            end
        end
    end
    fprintf('joint step %.4f: %.5f s (+%.5f)\n', sc, G, G-Gb);
end

%% ② 坐标爬坡三级
for lev = 1:3
    sc = 1/5^(lev-1);
    Ga = G;
    X = rb3(X, 1, 0.01*sc, [-180, 180]);
    X = rb3(X, 2, 0.2*sc,  [70, 140]);
    for bomb = 1:3
        X = rbomb3(X, bomb, 0.005*sc, 0.002*sc);
    end
    G = objective3(X);
    fprintf('coord level %d: %.5f s (+%.5f)\n', lev, G, G-Ga);
end

%% ③ 联合再扫一遍收尾
for sc = [0.002, 0.0004]
    Gb = G;
    for s = 1:numel(pairs)
        pr = pairs{s}; di = pr(1); dj = pr(2);
        for si = -2:2
            for sj = -2:2
                if si == 0 && sj == 0, continue; end
                Xt = X; Xt(di) = Xt(di) + si*sc; Xt(dj) = Xt(dj) + sj*sc;
                Xt(3) = max(0, Xt(3)); Xt(5) = max(0, Xt(5)); Xt(7) = max(0, Xt(7));
                f = objective3(Xt);
                if f > G + 1e-9, X = Xt; G = f; end
            end
        end
    end
    fprintf('joint final %.4f: %.5f s (+%.5f)\n', sc, G, G-Gb);
end

fprintf('\nFINAL: champion %.5f s -> verified %.5f s (delta %+.5f)\n', G0, G, G-G0);
if G > G0 + 1e-4
    fprintf('!!! still improving, new point:\n');
    fprintf('    th=%.4f v=%.3f t0=[%.4f %.4f %.4f] tau=[%.4f %.4f %.4f]\n', ...
            X(1), X(2), X(3), X(5), X(7), X(4), X(6), X(8));
else
    fprintf('-> 7.627 s champion CONFIRMED locally optimal.\n');
end

%% ================= 局部函数 =================
function X = rb3(X, dim, step, lim)
    cands = max(lim(1), min(lim(2), X(dim) + (-2:2)*step));
    best_f = objective3(X);
    for c = cands
        Xt = X; Xt(dim) = c;
        f = objective3(Xt);
        if f > best_f, best_f = f; X = Xt; end
    end
end

function X = rbomb3(X, bomb, step_t0, step_tau)
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
