%% main_Q1.m —— 2025 国赛 A 题 · 问题 1（编程手 day1 主脚本）
% 任务：无人机 FY1 投放 1 枚烟幕干扰弹干扰导弹 M1，
%       计算有效遮蔽时长（即第 1 题答案）。
%
% 运行方法：MATLAB 中打开本文件，直接点"运行"。
%   ① 命令行窗口输出：起爆位置、被遮蔽的时刻、有效遮蔽时长；
%   ② 自动弹出 3D 轨迹图，并保存为同目录下 M1轨迹图.png。
%
% 判定逻辑在 shield.m 中（输入时刻 t，输出 1=挡住 / 0=没挡住）。
% ⚠ 本文件顶部参数与 shield.m 内参数必须一致，改动请两边同步。

clear; clc; close all;

%% ========== 统一参数表（与"全队必读"已知条件表一致）==========
vM    = 300;                 % 导弹速度 (m/s)
M1_0  = [20000, 0, 2000];    % 导弹 M1 起点 (m)
fake  = [0, 0, 0];           % 假目标：导弹直飞的点（坐标原点）
real_pt = [0, 200, 5];       % 真目标代表点：圆柱中心
                             % （下底面圆心 (0,200,0)，半径 7、高 10，取中心点，见任务单提示）
FY1_0 = [17800, 0, 1800];    % 无人机 FY1 起点 (m)
vFY   = 120;                 % FY1 飞行速度 (m/s)，朝向假目标、等高度
t_drop  = 1.5;               % 投弹时刻 (s)：受领任务后 1.5 s 投放
t_det   = t_drop + 3.6;      % 起爆时刻 (s) = 1.5 + 3.6 = 5.1
g       = 9.8;               % 重力加速度 (m/s^2)【建模手若用 9.81，请两边统一】
v_sink  = 3;                 % 云团中心下沉速度 (m/s)，起爆后匀速
R_eff   = 10;                % 有效遮蔽半径 (m)：云团中心 10 m 范围内
T_life  = 20;                % 起爆后有效遮蔽时长 (s)

dt = 0.1;                    % 时间步长 (s)
t  = 0:dt:30;                % 第 0~30 秒，每 0.1 秒，共 301 个时刻

%% ========== 第 1 步：导弹 M1 轨迹 ==========
% 方向 = (假目标 − 起点) ÷ 长度；位置 = 起点 + 速度×时间×方向
dirM = (fake - M1_0) / norm(fake - M1_0);   % M1 飞行单位方向
M1   = M1_0 + vM * (t' * dirM);             % 301×3，每行一个时刻的位置

%% ========== 第 3 步：无人机 FY1 轨迹（等高度直线飞行）==========
dirFY    = fake - FY1_0;
dirFY(3) = 0;                               % 高度不变 → 只取水平方向
dirFY    = dirFY / norm(dirFY);             % 本例中 = (-1, 0, 0)
FY1      = FY1_0 + vFY * (t' * dirFY);      % z 始终 = 1800

%% ========== 第 4 步：烟幕干扰弹投放 → 起爆位置 ==========
% 1.5 s 时在无人机所在位置抛出，抛出速度 = 无人机速度，之后仅受重力
pos_drop = FY1_0 + vFY * t_drop * dirFY;                  % 投放点 (17620, 0, 1800)
v_bomb   = vFY * dirFY;                                   % 抛出初速度 (-120, 0, 0)
tau      = t_det - t_drop;                                % 投出到起爆历时 3.6 s
pos_det  = pos_drop + v_bomb * tau + [0, 0, -0.5*g*tau^2];% 起爆位置 = 云团中心起点

%% ========== 第 5 步：云团中心轨迹 ==========
% 起爆瞬间形成，此后中心以 3 m/s 匀速下沉；5.1 s 前云团不存在（记 NaN）
cloud = NaN(length(t), 3);
idx   = t >= t_det;
cloud(idx, :) = pos_det + [zeros(nnz(idx),2), -v_sink * (t(idx) - t_det)'];

%% ========== 第 6、7 步：逐时刻判定并累计遮蔽时长 ==========
flag = zeros(size(t));
for k = 1:length(t)
    flag(k) = shield(t(k));      % 1=挡住，0=没挡住（规则见 shield.m）
end
T_shield = sum(flag) * dt;       % 遮蔽时长 = Σflag × 0.1（任务单第 7 步）

%% ========== 输出（发给建模手核对用）==========
fprintf('\n========== 问题 1 计算结果 ==========\n');
fprintf('M1 到达假目标需要 %.2f s（>30 s，故 0~30 s 内一直在飞）\n', norm(fake-M1_0)/vM);
fprintf('投放点   = (%.3f, %.3f, %.3f) m\n', pos_drop);
fprintf('起爆位置 = (%.3f, %.3f, %.3f) m（t = %.1f s）\n', pos_det, t_det);
fprintf('云团有效时间窗 = [%.1f, %.1f] s\n', t_det, t_det + T_life);
fprintf('被判"挡住"的时刻(s)：');
fprintf('%.1f ', t(flag == 1));
fprintf('\n★ 有效遮蔽时长 = %.1f 秒  ← 第 1 题答案 ★\n', T_shield);

%% ========== 第 2 步：画 3D 轨迹图并发全队 ==========
figure('Color', 'w', 'Position', [200 200 900 650]);
plot3(M1(:,1), M1(:,2), M1(:,3), 'r-', 'LineWidth', 1.6); hold on;
plot3(M1_0(1), M1_0(2), M1_0(3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(fake(1), fake(2), fake(3), 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y');
plot3(real_pt(1), real_pt(2), real_pt(3), 'g^', 'MarkerSize', 9, 'MarkerFaceColor', 'g');
plot3(FY1(:,1), FY1(:,2), FY1(:,3), 'b--', 'LineWidth', 1.2);
plot3(pos_drop(1), pos_drop(2), pos_drop(3), 'cv', 'MarkerSize', 8, 'MarkerFaceColor', 'c');
plot3(pos_det(1), pos_det(2), pos_det(3), 'ms', 'MarkerSize', 9, 'MarkerFaceColor', 'm');
plot3(cloud(:,1), cloud(:,2), cloud(:,3), 'm:', 'LineWidth', 1.4);
xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)');
title('2025 A 题问题 1：M1 导弹轨迹与云团位置');
legend('M1 轨迹', 'M1 起点', '假目标 (0,0,0)', '真目标 (0,200,5)', ...
       'FY1 轨迹', '投放点 (1.5 s)', '起爆点 (5.1 s)', '云团中心轨迹', ...
       'Location', 'best');
grid on; box on; view(35, 18);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'M1轨迹图.png'));
fprintf('轨迹图已保存：day1/M1轨迹图.png\n');
