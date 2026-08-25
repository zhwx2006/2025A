%% main_Q1.m —— 2025 国赛 A 题 · 问题 1（编程手 day1 主脚本）
% 严格按建模手《编程手任务交接包_第1题》实现（§1~§3）。
% 产出三样（交接包 §0）：
%   ① 遮蔽窗口 [t1, t2]（精确到 0.001 s）
%   ② 遮蔽时长（秒，保留 1 位小数）
%   ③ d(t) vs t 曲线 + d=10 水平参考线（进论文用，保存为 d(t)_曲线图.png）
%
% 位置函数统一出处（公式只此一份，改动请改函数文件）：
%   M1.m  —— 导弹位置（精确单位向量，勿手工舍入）
%   CloudC.m —— 云团中心位置
%   point_to_segment_dist.m —— 投影法（λ 截断 [0,1]）
%   shield.m —— 判定函数（输入时刻，输出是否遮蔽 + 距离）
%
% 运行方法：MATLAB 中打开本文件，直接点"运行"。
% 末尾附与建模手 Block4 加密采样表的逐点对答案。

clear; clc; close all;

T_pt   = [0, 200, 5];    % 真目标简化点（固定）
t_det  = 5.1;            % 起爆时刻 (s)
T_life = 20;             % 起爆后有效时长 (s) → 时间窗 [5.1, 25.1]
R_eff  = 10;             % 有效遮蔽半径 (m)

%% ========== ① 粗扫（步长 0.1 s）：0~30 s 每时刻是否遮蔽 ==========
t_coarse  = 0:0.1:30;
d_coarse  = arrayfun(@(x) point_to_segment_dist(CloudC(x), M1(x), T_pt), t_coarse);
covered   = d_coarse <= R_eff & t_coarse >= t_det & t_coarse <= t_det + T_life;

fprintf('========== 粗扫结果（步长 0.1 s）==========\n');
fprintf('被判"挡住"的时刻(s)：');
fprintf('%.1f ', t_coarse(covered));
fprintf('\n');

%% ========== ② 精算边界（步长 0.01 s + 边界线性插值，交接包 §3）==========
t_fine = 0:0.01:30;
d_fine = arrayfun(@(x) point_to_segment_dist(CloudC(x), M1(x), T_pt), t_fine);
inside = d_fine <= R_eff & t_fine >= t_det & t_fine <= t_det + T_life;

crossings  = diff(inside);           % +1 = 进入窗口，-1 = 离开窗口
boundaries = zeros(1, nnz(crossings));
k = 0;
for i = find(crossings ~= 0)
    a  = t_fine(i);   b  = t_fine(i+1);
    da = d_fine(i);   db = d_fine(i+1);   % 紧贴 d=10 的两点
    k = k + 1;
    boundaries(k) = a + (R_eff - da) * (b - a) / (db - da);  % 线性插值到 d=10
end

% boundaries 成对出现：[进入时刻, 离开时刻]（第 1 题只有一对）
t1 = boundaries(1);
t2 = boundaries(2);
T_shield = t2 - t1;

fprintf('\n========== 问题 1 最终结果（交接包 §0 三样产出）==========\n');
fprintf('① 遮蔽窗口：[%.3f, %.3f] s\n', t1, t2);
fprintf('② 遮蔽时长：%.3f s ≈ %.1f 秒  ← 第 1 题答案 ★\n', T_shield, T_shield);

% 验收标准核对（交接包 §4）：t1=8.015、t2=9.448，误差要求 < 0.5 s
fprintf('\n验收核对：建模手手算 t1=8.015 s（本代码 %.3f，偏差 %.3f）；', t1, abs(t1-8.015));
fprintf('t2=9.448 s（本代码 %.3f，偏差 %.3f）\n', t2, abs(t2-9.448));
if abs(t1-8.015) < 0.5 && abs(t2-9.448) < 0.5
    fprintf('→ 与手算一致，通过验收。\n');
else
    fprintf('→ 偏差超过 0.5 s，请检查 M1(t)/C(t) 表达式与 λ 截断！\n');
end

%% ========== ③ d(t) 曲线图 + d=10 参考线（进论文用）==========
figure('Color', 'w', 'Position', [200 200 860 520]);
plot(t_coarse, d_coarse, 'b-', 'LineWidth', 1.8); hold on;
yline(R_eff, 'r--', 'LineWidth', 1.5);
ymax = max(d_coarse(1:151)) * 1.05;       % 取前 15 s 的最大 d 定 y 轴上限
patch([t1 t2 t2 t1], [0 0 ymax ymax], [0.8 0.9 1], ...
      'EdgeColor', 'none', 'FaceAlpha', 0.5);
xline(t1, 'm:', 'LineWidth', 1.2);
xline(t2, 'm:', 'LineWidth', 1.2);
plot(t_coarse(covered), d_coarse(covered), 'go', 'MarkerFaceColor', 'g');
xlabel('时间 t (s)'); ylabel('距离 d(t) (m)');
title(sprintf('问题 1：云团中心到视线段的距离 d(t)，遮蔽窗口 [%.3f, %.3f] s', t1, t2));
legend('d(t) 曲线', 'd = 10（遮蔽边界）', ...
       sprintf('遮蔽窗口（时长 %.1f s）', T_shield), '窗口边界', ...
       '粗扫判定点', 'Location', 'northeast');
xlim([0 30]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'd(t)_曲线图.png'));
fprintf('\nd(t) 曲线图已保存：day1/d(t)_曲线图.png（发建模手进论文）\n');

%% ========== 附：3D 轨迹图（发全队用，公式同上）==========
tt = t_coarse';
u  = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
M1_pts   = [20000, 0, 2000] + 300 * (tt * u);
idx_c    = t_coarse >= t_det;
cloud    = [17188*ones(nnz(idx_c),1), zeros(nnz(idx_c),1), ...
            1736.5 - 3*(t_coarse(idx_c)' - t_det)];
FY1_pts  = [17800 - 120*tt, zeros(length(tt),1), 1800*ones(length(tt),1)];

figure('Color', 'w', 'Position', [220 220 900 650]);
plot3(M1_pts(:,1), M1_pts(:,2), M1_pts(:,3), 'r-', 'LineWidth', 1.6); hold on;
plot3(20000, 0, 2000, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(0, 0, 0, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y');
plot3(T_pt(1), T_pt(2), T_pt(3), 'g^', 'MarkerSize', 9, 'MarkerFaceColor', 'g');
plot3(FY1_pts(:,1), FY1_pts(:,2), FY1_pts(:,3), 'b--', 'LineWidth', 1.2);
plot3(17620, 0, 1800, 'cv', 'MarkerSize', 8, 'MarkerFaceColor', 'c');
plot3(17188, 0, 1736.5, 'ms', 'MarkerSize', 9, 'MarkerFaceColor', 'm');
plot3(cloud(:,1), cloud(:,2), cloud(:,3), 'm:', 'LineWidth', 1.4);
xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)');
title('2025 A 题问题 1：M1 导弹轨迹与云团位置');
legend('M1 轨迹', 'M1 起点', '假目标 (0,0,0)', '真目标 (0,200,5)', ...
       'FY1 轨迹', '投放点 (1.5 s)', '起爆点 (5.1 s)', '云团中心轨迹', ...
       'Location', 'best');
grid on; box on; view(35, 18);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'M1轨迹图.png'));
fprintf('轨迹图已保存：day1/M1轨迹图.png（发全队）\n');

%% ========== 附：与建模手 Block4 加密采样表逐点对答案 ==========
% 表内 11 个采样点（t 与表内 d 列），检验 M1/C/投影法是否逐项一致
tb = [7, 7.5, 8, 8.2, 8.5, 9, 9.2, 9.4, 9.44, 9.45, 9.5];
db = [14.2369062569, 12.138279247, 10.0571842982, 9.23542482679, ...
      8.02342360286, 6.10696844217, 5.40742463277, 4.77501293885, ...
      7.94780173046, 10.5108508797, 24.8298174677];
fprintf('\n========== Block4 加密采样表逐点核对 ==========\n');
fprintf('   t(s)   代码 d(m)      采样表 d(m)     绝对偏差\n');
max_err = 0;
for j = 1:length(tb)
    dj = point_to_segment_dist(CloudC(tb(j)), M1(tb(j)), T_pt);
    err = abs(dj - db(j));
    max_err = max(max_err, err);
    fprintf('%6.2f   %12.8f   %12.8f   %.2e\n', tb(j), dj, db(j), err);
end
fprintf('最大偏差 = %.2e m（<1e-6 即逐项一致）\n', max_err);
