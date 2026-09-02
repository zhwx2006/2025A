%% verify_final_Q4.m —— 第 4 题 16.360 s 冠军终审（细步长独立核验）
% ① 细步长联合移动探测（0.02/0.004/0.0008）
% ② 细步长坐标爬坡
% ③ 结论：若均无 >1e-4 改进 → 确认为局部最优
clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'day3'));

t_hit = norm([20000, 0, 2000]) / 300;
champ = [1.139, 139.81, 0, 3.577, ...
         -101.152, 135.33, 4.382, 5.797, ...
         28.072, 136.05, 38.420, 11.552];
G0 = objective4(champ, t_hit);
fprintf('champion: %.5f s (cut at %.3f s)\n', G0, t_hit);

X = champ; G = G0;
pairs = zeros(0, 2);
for p = 1:3
    i0 = 1 + (p-1)*4;
    pairs = [pairs; i0 i0+1; i0 i0+2; i0 i0+3; i0+1 i0+2; i0+1 i0+3; i0+2 i0+3];
end
pairs = [pairs; 3 7; 3 11; 7 11; 4 8; 8 12; 4 12; 2 6; 6 10];

%% ① 联合移动三级
for sc = [0.02, 0.004, 0.0008]
    Gb = G;
    for r = 1:size(pairs, 1)
        di = pairs(r, 1);  dj = pairs(r, 2);
        for si = -2:2
            for sj = -2:2
                if si == 0 && sj == 0, continue; end
                Xt = X;
                Xt(di) = Xt(di) + si*sc*scale_dim(di);
                Xt(dj) = Xt(dj) + sj*sc*scale_dim(dj);
                for p = 1:3
                    i0 = 1 + (p-1)*4;
                    Xt(i0+1) = max(70, min(140, Xt(i0+1)));
                    Xt(i0+2) = max(0, Xt(i0+2));
                    Xt(i0+3) = max(0.05, Xt(i0+3));
                end
                f = objective4(Xt, t_hit);
                if f > G + 1e-9, X = Xt; G = f; end
            end
        end
    end
    fprintf('joint step %.4f: %.5f s (+%.5f)\n', sc, G, G-Gb);
end

%% ② 坐标爬坡三级
for lev = 1:3
    sth = 0.2/5^(lev-1); sv = 0.2/5^(lev-1); st0 = 0.02/5^(lev-1); stau = 0.02/5^(lev-1);
    Ga = G;
    for p = 1:3
        i0 = 1 + (p-1)*4;
        for c_th = X(i0) + (-2:2)*sth
            for c_v = max(70, min(140, X(i0+1) + (-2:2)*sv))
                for c_t0 = max(0, X(i0+2) + (-2:2)*st0)
                    for c_tau = max(0.05, X(i0+3) + (-2:2)*stau)
                        Xt = X; Xt(i0:i0+3) = [c_th, c_v, c_t0, c_tau];
                        f = objective4(Xt, t_hit);
                        if f > G, G = f; X = Xt; end
                    end
                end
            end
        end
    end
    fprintf('coord level %d: %.5f s (+%.5f)\n', lev, G, G-Ga);
end

%% ③ 联合收尾
for sc = [0.004, 0.0008]
    Gb = G;
    for r = 1:size(pairs, 1)
        di = pairs(r, 1);  dj = pairs(r, 2);
        for si = -2:2
            for sj = -2:2
                if si == 0 && sj == 0, continue; end
                Xt = X;
                Xt(di) = Xt(di) + si*sc*scale_dim(di);
                Xt(dj) = Xt(dj) + sj*sc*scale_dim(dj);
                for p = 1:3
                    i0 = 1 + (p-1)*4;
                    Xt(i0+1) = max(70, min(140, Xt(i0+1)));
                    Xt(i0+2) = max(0, Xt(i0+2));
                    Xt(i0+3) = max(0.05, Xt(i0+3));
                end
                f = objective4(Xt, t_hit);
                if f > G + 1e-9, X = Xt; G = f; end
            end
        end
    end
    fprintf('joint final %.4f: %.5f s (+%.5f)\n', sc, G, G-Gb);
end

fprintf('\nFINAL: champion %.5f s -> verified %.5f s (delta %+.5f)\n', G0, G, G-G0);
if G > G0 + 1e-4
    fprintf('!!! still improving, new point:\n');
    fprintf('    (%.4f, %.3f, %.4f, %.4f | %.4f, %.3f, %.4f, %.4f | %.4f, %.3f, %.4f, %.4f)\n', X);
else
    fprintf('-> 16.360 s champion CONFIRMED locally optimal.\n');
end

function s = scale_dim(dim)
    k = mod(dim-1, 4);
    if k == 0, s = 1;
    elseif k == 1, s = 1;
    else, s = 0.2; end
end
