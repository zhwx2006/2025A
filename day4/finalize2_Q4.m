%% finalize2_Q4.m —— 第 4 题收敛定型：坐标爬坡 × 联合移动交替（物理截断口径）
% 起点 = compare_cap_Q4 找到的截断口径最优（15.985 s）。
% 口径：遮蔽只计到导弹命中假目标时刻 t_hit ≈ 67.0 s（导弹被诱偏后无遮蔽意义）。
% 交替迭代直到两种爬山都无改进，收敛后重新出图出表。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700];
N_plane = 3;
T_pt = [0 200 5];
uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
t_hit = norm([20000, 0, 2000]) / 300;

% 起点：compare_cap_Q4 的截断口径最优
X = [0.559, 120.77, 0.965, 3.861, ...
     -101.152, 135.33, 4.382, 5.797, ...
     28.072, 135.87, 38.490, 11.550];
G = objective4(X, t_hit);
fprintf('start (cut at t_hit=%.3f s): %.5f s\n', t_hit, G);

% 联合移动参数对：机内 (θ,v)(θ,t0)(θ,τ)(v,t0)(v,τ)(t0,τ) + 跨机 (t0_i, t0_j) 等
pairs = zeros(0, 2);
for p = 1:3
    i0 = 1 + (p-1)*4;
    pairs = [pairs; i0 i0+1; i0 i0+2; i0 i0+3; i0+1 i0+2; i0+1 i0+3; i0+2 i0+3];
end
pairs = [pairs; 3 7; 3 11; 7 11; 4 8; 8 12; 4 12; 2 6; 6 10];   % 跨机关联对

for it = 1:25
    improved = false;
    Ga = G;

    % A) 坐标块爬坡（每机轮流，三级步长）
    for p = 1:N_plane
        others = union_others(X, p, S_all, t_hit);
        X = refine_plane(X, p, S_all(p,:), others, t_hit);
    end
    G = objective4(X, t_hit);
    if G > Ga + 1e-6
        fprintf('iter %2d coord climb: %.5f s (+%.5f)\n', it, G, G-Ga);
        improved = true;
    end

    % B) 联合移动（三级步长）
    Gb = G;
    for sc = [0.1, 0.02, 0.004]
        for r = 1:size(pairs, 1)
            di = pairs(r, 1);  dj = pairs(r, 2);
            for si = -2:2
                for sj = -2:2
                    if si == 0 && sj == 0, continue; end
                    Xt = X;
                    Xt(di) = Xt(di) + si*sc*scale_dim(di);
                    Xt(dj) = Xt(dj) + sj*sc*scale_dim(dj);
                    % 约束修复
                    for p = 1:3
                        i0 = 1 + (p-1)*4;
                        Xt(i0+1) = max(70, min(140, Xt(i0+1)));
                        Xt(i0+2) = max(0, Xt(i0+2));
                        Xt(i0+3) = max(0.05, Xt(i0+3));
                    end
                    f = objective4(Xt, t_hit);
                    if f > G + 1e-9
                        X = Xt;  G = f;  improved = true;
                    end
                end
            end
        end
    end
    if G > Gb + 1e-6
        fprintf('iter %2d joint move:   %.5f s (+%.5f)\n', it, G, G-Gb);
    end

    if ~improved
        fprintf('iter %2d: no improvement, converged.\n', it);
        break;
    end
end

%% ---------- 最终评估 ----------
iv_each = cell(N_plane, 1);
iv_all = zeros(0, 2);
for p = 1:N_plane
    iv_each{p} = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                     X(3+(p-1)*4), X(4+(p-1)*4), [], t_hit);
    if ~isempty(iv_each{p}), iv_all = [iv_all; iv_each{p}]; end
end
G_final = union_length(iv_all);
G_full = objective4(X);     % 全时域口径（供对照）
fprintf('\n========== Q4 FINAL ==========\n');
for p = 1:N_plane
    fprintf('FY%d: th=%.3f deg, v=%.2f m/s, t0=%.3f s, tau=%.3f s | ', ...
            p, X(1+(p-1)*4), X(2+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4));
    if isempty(iv_each{p})
        fprintf('EMPTY');
    else
        for k = 1:size(iv_each{p},1)
            fprintf('[%.3f, %.3f] ', iv_each{p}(k,1), iv_each{p}(k,2));
        end
    end
    fprintf('\n');
end
fprintf('UNION (cut at t_hit) = %.3f s  |  UNION (full 70 s domain) = %.3f s\n', ...
        G_final, G_full);

%% ---------- 图：三机 d(t) ----------
t_plt = (0:0.02:t_hit)';
Mp = [20000, 0, 2000] + 300 * t_plt * uM;
figure('Color','w','Position',[140 140 920 540]); hold on;
cols = {'b', [0 0.6 0], [0.8 0.4 0]};
leg = cell(N_plane,1); ymax = 40;
for p = 1:N_plane
    th_p = X(1+(p-1)*4)*pi/180;  v_p = X(2+(p-1)*4);
    t0_p = X(3+(p-1)*4);  tau_p = X(4+(p-1)*4);
    u_p = [-cos(th_p), sin(th_p), 0];
    B = S_all(p,:) + v_p*(t0_p+tau_p)*u_p + [0,0,-4.9*tau_p^2];
    tdet = t0_p + tau_p;
    Cp = B + [zeros(size(t_plt)), zeros(size(t_plt)), -3*(t_plt - tdet)];
    V = T_pt - Mp;  W = Cp - Mp;
    lam = max(0, min(1, sum(W.*V,2) ./ sum(V.*V,2)));
    Q = Mp + lam .* V;
    d = sqrt(sum((Cp-Q).^2, 2));
    mask = t_plt >= tdet & t_plt <= min(tdet+20, t_hit);
    d(~mask) = NaN;
    plot(t_plt, d, '-', 'Color', cols{p}, 'LineWidth', 1.6);
    leg{p} = sprintf('FY%d d(t)', p);
end
yline(10, 'r--', 'LineWidth', 1.5);
xline(t_hit, 'k:', 'LineWidth', 1.2);
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
title(sprintf('Q4: FY1/FY2/FY3 vs M1, union = %.3f s (cut at missile hit %.1f s)', ...
      G_final, t_hit));
legend([leg{:}, 'd=10 boundary', 'missile hit', 'union intervals'], 'Location','northeast');
xlim([0, t_hit]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q4_三机d(t)_曲线图.png'));
fprintf('\nfigure saved: Q4_三机d(t)_曲线图.png\n');

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
fprintf('table saved: result2.xlsx (Sheet1 official, Sheet2 details)\n');

%% ================= 局部函数 =================
function s = scale_dim(dim)
% 各维度的量纲缩放（θ 用度、v 用 m/s、t0/τ 用秒）
    k = mod(dim-1, 4);
    if k == 0, s = 1;        % θ (°)
    elseif k == 1, s = 1;    % v (m/s)
    else, s = 0.2; end       % t0 / τ (s)
end

function U = union_others(X, p, S_all, t_cap)
    iv = zeros(0, 2);
    for q = setdiff(1:size(S_all,1), p)
        ivq = one_cloud_interval4(S_all(q,:), X(1+(q-1)*4), X(2+(q-1)*4), ...
                                  X(3+(q-1)*4), X(4+(q-1)*4), [], t_cap);
        if ~isempty(ivq), iv = [iv; ivq]; end
    end
    U = iv;
end

function X = refine_plane(X, p, S, U, t_cap)
    lev_steps = [10, 2, 0.4, 0.08;
                 10, 2, 0.4, 0.08;
                 0.5,0.1,0.02,0.004;
                 0.5,0.1,0.02,0.004];
    i0 = 1 + (p-1)*4;
    best_f = eval_u(X, p, S, U, t_cap);
    for lev = 1:4
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
                        f = eval_u(Xt, p, S, U, t_cap);
                        if f > best_f, best_f = f; X = Xt; end
                    end
                end
            end
        end
    end
end

function f = eval_u(X, p, S, U, t_cap)
    iv = one_cloud_interval4(S, X(1+(p-1)*4), X(2+(p-1)*4), ...
                             X(3+(p-1)*4), X(4+(p-1)*4), [], t_cap);
    f = union_length([U; iv]);
end
