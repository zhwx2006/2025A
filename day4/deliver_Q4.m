%% deliver_Q4.m —— 第 4 题最终交付：从终审确认点生成图与表
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

% 终审确认的最优点
X = [1.1398, 139.810, 0.0000, 3.5767, ...
     -101.1536, 135.330, 4.3818, 5.7975, ...
     28.0736, 136.043, 38.4195, 11.5557];

%% 最终评估
iv_each = cell(N_plane, 1);
iv_all = zeros(0, 2);
for p = 1:N_plane
    iv_each{p} = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                                     X(3+(p-1)*4), X(4+(p-1)*4), [], t_hit);
    if ~isempty(iv_each{p}), iv_all = [iv_all; iv_each{p}]; end
end
G_final = union_length(iv_all);
G_full = objective4(X);
fprintf('========== Q4 FINAL DELIVERY ==========\n');
for p = 1:N_plane
    fprintf('FY%d: th=%.3f deg, v=%.2f m/s, t0=%.3f s, tau=%.3f s | ', ...
            p, X(1+(p-1)*4), X(2+(p-1)*4), X(3+(p-1)*4), X(4+(p-1)*4));
    for k = 1:size(iv_each{p},1)
        fprintf('[%.3f, %.3f] ', iv_each{p}(k,1), iv_each{p}(k,2));
    end
    fprintf('\n');
end
fprintf('UNION (cut at t_hit=%.1f s) = %.3f s | UNION (full domain) = %.3f s\n', ...
        t_hit, G_final, G_full);

%% 图：三机 d(t)
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
title(sprintf('Q4: FY1/FY2/FY3 vs M1, union = %.3f s', G_final));
legend([leg{:}, 'd=10 boundary', 'missile hit', 'union intervals'], 'Location','northeast');
xlim([0, t_hit]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q4_三机d(t)_曲线图.png'));
fprintf('figure saved: Q4_三机d(t)_曲线图.png\n');

%% result2.xlsx
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
