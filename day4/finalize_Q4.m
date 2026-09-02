%% finalize_Q4.m —— 第 4 题定型：从 16.148 s 冠军点继续交替爬坡到收敛
% 起点 = main_Q4 的最优点（16.148 s）。时域已扩到 70 s。
% 交替块爬山（每机轮流优化）迭代到无改进，然后重新出图出表。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700];
N_plane = 3;

% 冠军起点（main_Q4 输出）
X = [0.559, 120.80, 0.965, 3.861, ...
     -101.088, 135.23, 4.384, 5.800, ...
     28.072, 138.68, 37.316, 11.713];
G = objective4(X);
fprintf('start: %.5f s\n', G);

for it = 1:30
    Xold = X;
    for p = 1:N_plane
        others = union_others(X, p, S_all);
        X = refine_plane(X, p, S_all(p,:), others);
    end
    Gnew = objective4(X);
    fprintf('iter %2d: %.5f s%s\n', it, Gnew, ternary(Gnew > G + 1e-6, '  *', ''));
    if Gnew > G + 1e-6
        G = Gnew;
    else
        if norm(X - Xold) < 1e-4, break; end
    end
    if it > 2 && Gnew <= G + 1e-8, break; end
end

%% ---------- 最终评估 ----------
iv_each = cell(N_plane, 1);
iv_all = zeros(0, 2);
for p = 1:N_plane
    iv_each{p} = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                     X(3+(p-1)*4), X(4+(p-1)*4));
    if ~isempty(iv_each{p}), iv_all = [iv_all; iv_each{p}]; end
end
G_final = union_length(iv_all);
fprintf('\n========== Q4 FINAL (finalize) ==========\n');
for p = 1:N_plane
    fprintf('FY%d: th=%.3f, v=%.2f, t0=%.3f, tau=%.3f | ', ...
            p, X(1+(p-1)*4), X(2+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4));
    for k = 1:size(iv_each{p},1)
        fprintf('[%.3f, %.3f] ', iv_each{p}(k,1), iv_each{p}(k,2));
    end
    fprintf('\n');
end
fprintf('UNION TOTAL = %.3f s\n', G_final);

%% ---------- 图：三机 d(t) ----------
uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
t_plt = (0:0.02:70)';
Mp = [20000, 0, 2000] + 300 * t_plt * uM;
figure('Color','w','Position',[140 140 920 540]); hold on;
cols = {'b', [0 0.6 0], [0.8 0.4 0]};
leg = cell(N_plane,1); ymax = 40; tmax = 0;
for p = 1:N_plane
    th_p = X(1+(p-1)*4)*pi/180;  v_p = X(2+(p-1)*4);
    t0_p = X(3+(p-1)*4);  tau_p = X(4+(p-1)*4);
    u_p = [-cos(th_p), sin(th_p), 0];
    B = S_all(p,:) + v_p*(t0_p+tau_p)*u_p + [0,0,-4.9*tau_p^2];
    tdet = t0_p + tau_p;
    Cp = B + [zeros(size(t_plt)), zeros(size(t_plt)), -3*(t_plt - tdet)];
    V = [0 200 5] - Mp;  W = Cp - Mp;
    lam = max(0, min(1, sum(W.*V,2) ./ sum(V.*V,2)));
    Q = Mp + lam .* V;
    d = sqrt(sum((Cp-Q).^2, 2));
    mask = t_plt >= tdet & t_plt <= min(tdet+20, 70);
    if any(mask), tmax = max(tmax, max(t_plt(mask))); end
    d(~mask) = NaN;
    plot(t_plt, d, '-', 'Color', cols{p}, 'LineWidth', 1.6);
    leg{p} = sprintf('FY%d d(t)', p);
end
yline(10, 'r--', 'LineWidth', 1.5);
A_u = sortrows(iv_all, 1);
cs = A_u(1,1); ce = A_u(1,2); segs = zeros(0,2);
for i = 2:size(A_u,1)
    if A_u(i,1) <= ce, ce = max(ce, A_u(i,2));
    else, segs(end+1,:) = [cs ce]; cs = A_u(i,1); ce = A_u(i,2); end
end
segs(end+1,:) = [cs ce];
for i = 1:size(segs,1)
    patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], [0 0 ymax ymax], ...
          [0.8 0.9 1], 'EdgeColor','none','FaceAlpha',0.45);
end
xlabel('t (s)'); ylabel('d(t) (m)');
title(sprintf('Q4: 3 planes vs M1, union = %.3f s', G_final));
legend([leg{:}, 'd=10 boundary', 'union intervals'], 'Location','northeast');
xlim([0, min(70, tmax+2)]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q4_三机d(t)_曲线图.png'));
fprintf('\nfigure saved\n');

%% ---------- result2.xlsx ----------
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)'};
rows = cell(N_plane, 10);
for p = 1:N_plane
    th_p = X(1+(p-1)*4)*pi/180;  v_p = X(2+(p-1)*4);
    t0_p = X(3+(p-1)*4);  tau_p = X(4+(p-1)*4);
    u_p = [-cos(th_p), sin(th_p), 0];
    drop = S_all(p,:) + v_p*t0_p*u_p;
    det  = drop + v_p*tau_p*u_p + [0, 0, -4.9*tau_p^2];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    rows(p, :) = {sprintf('FY%d', p), dir_official, v_p, drop(1), drop(2), drop(3), ...
                  det(1), det(2), det(3), G_final};
end
writecell([hdr; rows], fullfile(here, 'result2.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
          fullfile(here, 'result2.xlsx'), 'Sheet', 1, 'Range', 'A5');
det_hdr = {'无人机','内部θ(°)','t0(s)','tau(s)','起爆时刻(s)','区间','并集总时长(s)'};
det_rows = cell(N_plane, 7);
for p = 1:N_plane
    if isempty(iv_each{p})
        ivstr = '空';
    else
        ivstr = strjoin(arrayfun(@(k) sprintf('[%.3f,%.3f]', iv_each{p}(k,1), iv_each{p}(k,2)), ...
                1:size(iv_each{p},1), 'UniformOutput', false), ' ');
    end
    det_rows(p, :) = {sprintf('FY%d', p), X(1+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4), ...
                      X(3+(p-1)*4)+X(4+(p-1)*4), ivstr, G_final};
end
writecell([det_hdr; det_rows], fullfile(here, 'result2.xlsx'), 'Sheet', 2);
fprintf('table saved: result2.xlsx\n');

%% ================= 局部函数 =================
function U = union_others(X, p, S_all)
    iv = zeros(0, 2);
    for q = setdiff(1:size(S_all,1), p)
        ivq = one_cloud_interval4(S_all(q,:), X(1+(q-1)*4), X(2+(q-1)*4), ...
                                  X(3+(q-1)*4), X(4+(q-1)*4));
        if ~isempty(ivq), iv = [iv; ivq]; end
    end
    U = iv;
end

function X = refine_plane(X, p, S, U)
    lev_steps = [20, 4, 0.8, 0.16, 0.032;
                 10, 2, 0.4, 0.08, 0.016;
                 1,  0.2, 0.04, 0.008, 0.0016;
                 1,  0.2, 0.04, 0.008, 0.0016];
    i0 = 1 + (p-1)*4;
    best_f = eval_with_union(X, p, S, U);
    for lev = 1:5
        sth = lev_steps(1, lev); sv = lev_steps(2, lev);
        st0 = lev_steps(3, lev); stau = lev_steps(4, lev);
        th_c  = X(i0)   + (-2:2)*sth;
        v_c   = max(70, min(140, X(i0+1) + (-2:2)*sv));
        t0_c  = max(0, X(i0+2) + (-2:2)*st0);
        tau_c = max(0.05, X(i0+3) + (-2:2)*stau);
        for a = th_c
            for b = v_c
                for c = t0_c
                    for e = tau_c
                        Xt = X; Xt(i0:i0+3) = [a, b, c, e];
                        f = eval_with_union(Xt, p, S, U);
                        if f > best_f, best_f = f; X = Xt; end
                    end
                end
            end
        end
    end
end

function f = eval_with_union(X, p, S, U)
    iv = one_cloud_interval4(S, X(1+(p-1)*4), X(2+(p-1)*4), ...
                             X(3+(p-1)*4), X(4+(p-1)*4));
    f = union_length([U; iv]);
end

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
