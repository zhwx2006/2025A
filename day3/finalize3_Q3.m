%% finalize3_Q3.m —— 第 3 题最终交付：从终审确认点生成图与表
clear; clc; close all;
here = fileparts(mfilename('fullpath'));

X = [0.3665, 140, 0, 3.7109, 2.9588, 5.0976, 5.2427, 5.9255];
th_star = X(1); v_star = X(2);
t0s = [X(3), X(5), X(7)]; taus = [X(4), X(6), X(8)];

iv_all = zeros(0, 2); iv_each = cell(3,1);
for i = 1:3
    iv_each{i} = one_cloud_interval(th_star, v_star, t0s(i), taus(i));
    if ~isempty(iv_each{i}), iv_all = [iv_all; iv_each{i}]; end
end
G_final = union_length(iv_all);
fprintf('========== Q3 FINAL DELIVERY ==========\n');
fprintf('th* = %.4f deg, v* = %.3f m/s\n', th_star, v_star);
for i = 1:3
    fprintf('bomb %d: t0=%.4f, tau=%.4f, intervals: ', i, t0s(i), taus(i));
    for k = 1:size(iv_each{i},1)
        fprintf('[%.4f, %.4f] ', iv_each{i}(k,1), iv_each{i}(k,2));
    end
    fprintf('\n');
end
fprintf('UNION TOTAL = %.3f s\n', G_final);

%% 图 1：三弹 d(t)
t_plt = (0:0.02:30)';
u  = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
Mp = [20000, 0, 2000] + 300 * t_plt * u;
figure('Color','w','Position',[140 140 900 540]); hold on;
cols = {'b', [0 0.6 0], [0.8 0.4 0]};
leg = cell(3,1); ymax = 40;
th = th_star*pi/180;
for i = 1:3
    B = [17800 - v_star*cos(th)*(t0s(i)+taus(i)), v_star*sin(th)*(t0s(i)+taus(i)), ...
         1800 - 4.9*taus(i)^2];
    tdet = t0s(i) + taus(i);
    Cp = B + [zeros(size(t_plt)), zeros(size(t_plt)), -3*(t_plt - tdet)];
    V = [0 200 5] - Mp;  W = Cp - Mp;
    lam = max(0, min(1, sum(W.*V,2) ./ sum(V.*V,2)));
    Q = Mp + lam .* V;
    d = sqrt(sum((Cp-Q).^2, 2));
    d(t_plt < tdet | t_plt > min(tdet+20,30)) = NaN;
    plot(t_plt, d, '-', 'Color', cols{i}, 'LineWidth', 1.6);
    leg{i} = sprintf('bomb %d d(t)', i);
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
title(sprintf('Q3 optimal: 3 bombs d(t), union = %.3f s (th=%.3f deg, v=%.1f m/s)', ...
      G_final, th_star, v_star));
legend([leg{:}, 'd=10 boundary', 'union intervals'], 'Location','northeast');
xlim([0 30]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q3_三弹d(t)_曲线图.png'));
fprintf('figure saved: Q3_三弹d(t)_曲线图.png\n');

%% 图 2：热力图 t01×t02
t01_h = max(0, t0s(1)-2):0.2:t0s(1)+4;
t02_h = max(0, t0s(2)-2):0.2:t0s(2)+4;
[T1, T2] = ndgrid(t01_h, t02_h);
Fh = nan(size(T1));
for i = 1:numel(T1)
    if T2(i) >= T1(i) + 1 && t0s(3) >= T2(i) + 1
        Fh(i) = objective3([th_star, v_star, T1(i), taus(1), T2(i), taus(2), t0s(3), taus(3)]);
    end
end
figure('Color','w','Position',[160 160 820 560]);
imagesc(t02_h, t01_h, Fh); axis xy; colormap(jet);
cb = colorbar; cb.Label.String = 'union duration (s)';
hold on; plot(t0s(2), t0s(1), 'kp', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('t02 (s)'); ylabel('t01 (s)');
title(sprintf('union heatmap (th=%.3f deg, v=%.1f, tau=[%.3f %.3f %.3f], t03=%.3f fixed)', ...
      th_star, v_star, taus, t0s(3)));
saveas(gcf, fullfile(here, 'Q3_热力图_t01-t02.png'));
fprintf('figure saved: Q3_热力图_t01-t02.png\n');

%% result1.xlsx
dir_official = mod(atan2d(v_star*sin(th), -v_star*cos(th)), 360);
hdr = {'无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)'};
data = zeros(3, 10);
for i = 1:3
    drop = [17800 - v_star*cos(th)*t0s(i), v_star*sin(th)*t0s(i), 1800];
    det  = drop + [-v_star*cos(th)*taus(i), v_star*sin(th)*taus(i), -4.9*taus(i)^2];
    data(i, :) = [dir_official, v_star, i, drop(1), drop(2), drop(3), ...
                  det(1), det(2), det(3), G_final];
end
writecell([hdr; num2cell(data)], fullfile(here, 'result1.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
            fullfile(here, 'result1.xlsx'), 'Sheet', 1, 'Range', 'A5');
det_hdr = {'弹编号','t0(s)','tau(s)','起爆时刻(s)','区间','并集总时长(s)'};
det_data = cell(3, 6);
for i = 1:3
    if isempty(iv_each{i})
        ivstr = '空';
    else
        ivstr = strjoin(arrayfun(@(k) sprintf('[%.3f,%.3f]', iv_each{i}(k,1), iv_each{i}(k,2)), ...
                1:size(iv_each{i},1), 'UniformOutput', false), ' ');
    end
    det_data(i, :) = {i, t0s(i), taus(i), t0s(i)+taus(i), ivstr, G_final};
end
writecell([det_hdr; det_data], fullfile(here, 'result1.xlsx'), 'Sheet', 2);
fprintf('table saved: result1.xlsx\n');
fprintf('official direction = %.3f deg (internal th = %.4f deg)\n', dir_official, th_star);
