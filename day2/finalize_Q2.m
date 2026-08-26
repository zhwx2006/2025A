%% finalize_Q2.m —— 问题 2 最终定型：从已知最优点再做一次精细爬坡并生成全部交付物
% 起点 = 2D 细网格找到的脊顶 (θ=3.074°, v=72.4, t0=0, τ=2.505)
% 做 4 维精细收缩爬坡（步长缩到 1e-4 量级），锁定脊顶后重出图与表。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));

climb = [3.074, 72.4, 0.0, 2.505];
lev_steps = [0.02  0.004  0.0008  0.00016;   % θ (°)
             0.1   0.02   0.004   0.0008;    % v (m/s)
             0.01  0.002  0.0004  0.00008;   % t0 (s)
             0.02  0.004  0.0008  0.00016];  % τ (s)
fprintf('---------- 最终精细爬坡（4 维）----------\n');
for lev = 1:4
    d = lev_steps(:, lev);
    th_g  = climb(1) + (-2:2)*d(1);
    v_g   = max(70, min(140, climb(2) + (-2:2)*d(2)));
    t0_g  = max(0,  climb(3) + (-2:2)*d(3));
    tau_g = max(0.2, climb(4) + (-2:2)*d(4));
    [A,B,C,D] = ndgrid(th_g, v_g, t0_g, tau_g);
    F = reshape(arrayfun(@obscure, A(:), B(:), C(:), D(:)), size(A));
    [fm, ix] = max(F(:));
    ii = cell(4,1);  [ii{:}] = ind2sub(size(F), ix);  ii = [ii{:}];
    climb = [th_g(ii(1)), v_g(ii(2)), t0_g(ii(3)), tau_g(ii(4))];
    fprintf('级 %d：(θ=%.5f, v=%.5f, t0=%.5f, τ=%.5f) → %.6f s\n', lev, climb, fm);
end
% 验证：末级步长邻域内中心即 argmax
d = lev_steps(:, 4);
th_g  = climb(1) + (-2:2)*d(1);
v_g   = max(70, min(140, climb(2) + (-2:2)*d(2)));
t0_g  = max(0,  climb(3) + (-2:2)*d(3));
tau_g = max(0.2, climb(4) + (-2:2)*d(4));
[A,B,C,D] = ndgrid(th_g, v_g, t0_g, tau_g);
F = reshape(arrayfun(@obscure, A(:), B(:), C(:), D(:)), size(A));
[fm, ix] = max(F(:));
ii = cell(4,1);  [ii{:}] = ind2sub(size(F), ix);  ii = [ii{:}];
cand = [th_g(ii(1)), v_g(ii(2)), t0_g(ii(3)), tau_g(ii(4))];
if fm > obscure(climb(1),climb(2),climb(3),climb(4)) + 1e-12
    climb = cand;
    fprintf('验证轮再更新：%.6f s\n', fm);
else
    fprintf('验证轮：中心即脊顶，收敛。\n');
end

th_star = climb(1);  v_star = climb(2);  t0_star = climb(3);  tau_star = climb(4);

%% 最终评估（高分辨率）
[T_max, info] = obscure(th_star, v_star, t0_star, tau_star, 0.001);
fprintf('\n========== 问题 2 最终结果 ==========\n');
fprintf('最优策略：θ* = %.4f°，v* = %.3f m/s，t0* = %.4f s，τ* = %.4f s\n', ...
        th_star, v_star, t0_star, tau_star);
fprintf('最大遮蔽时长：%.3f s（高分辨率 %.5f）\n', T_max, T_max);
fprintf('爆点 B = (%.1f, %.1f, %.1f)；起爆时刻 = %.4f s\n', info.B, info.t_det);
fprintf('遮蔽区间：');
for k = 1:size(info.intervals,1)
    fprintf('[%.4f, %.4f] ', info.intervals(k,1), info.intervals(k,2));
end
fprintf('\n');

%% 图 1：d(t) 曲线
figure('Color','w','Position',[150 150 860 520]);
plot(info.t, info.d, 'b-', 'LineWidth', 1.8); hold on;
yline(10, 'r--', 'LineWidth', 1.5);
ymax = min(max(info.d)*1.1, 60);
for i = 1:size(info.intervals,1)
    patch([info.intervals(i,1) info.intervals(i,2) info.intervals(i,2) info.intervals(i,1)], ...
          [0 0 ymax ymax], [0.8 0.9 1], 'EdgeColor','none','FaceAlpha',0.5);
end
xlabel('时间 t (s)'); ylabel('d(t) (m)');
title(sprintf('问题 2 最优策略下 d(t)：θ=%.3f°, v=%.2f, t0=%.3f, τ=%.3f → 时长 %.3f s', ...
      th_star, v_star, t0_star, tau_star, T_max));
legend('d(t)', 'd=10（遮蔽边界）', '遮蔽区间', 'Location','northeast');
xlim([info.t_det-1, info.t_end]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q2_d(t)_曲线图.png'));

%% 图 2：热力图 时长 vs v×t0
v_h  = 70:2:140;
t0_h = 0:0.5:10;
[VV, TT] = ndgrid(v_h, t0_h);
Fh = arrayfun(@(vv, tt) obscure(th_star, vv, tt, tau_star), VV, TT);
figure('Color','w','Position',[170 170 820 560]);
imagesc(t0_h, v_h, Fh); axis xy; colormap(jet);
cb = colorbar; cb.Label.String = '遮蔽时长 (s)';
hold on; plot(t0_star, v_star, 'kp', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('投放时刻 t0 (s)'); ylabel('飞行速度 v (m/s)');
title(sprintf('遮蔽时长热力图（θ = %.3f°，τ = %.3f s 固定）', th_star, tau_star));
saveas(gcf, fullfile(here, 'Q2_热力图_v-t0.png'));

%% result1.xlsx
Tbl = table(th_star, v_star, t0_star, tau_star, T_max, ...
    'VariableNames', {'theta_deg','v_m_s','t0_s','tau_s','max_shield_s'});
writetable(Tbl, fullfile(here, 'result1.xlsx'));
fprintf('\n图与表已重新生成：Q2_d(t)_曲线图.png / Q2_热力图_v-t0.png / result1.xlsx\n');
