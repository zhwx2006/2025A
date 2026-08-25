%% main_Q1.m —— 2025 国赛 A 题 · 问题 1（编程手 day1 主脚本）
% 严格按建模手《遮蔽规则·一页纸》实现：
%   §1 视线段   L(t) = [M1(t), T]，M1(t) = (20000−298.5t, 0, 2000−29.85t)，T = (0,200,5)
%   §2 距离函数 d(t) = 点 C(t) 到线段 [M1(t), T] 的最短距离（投影法，λ 截断 [0,1]）
%   §3 遮蔽条件 d(t) ≤ 10 且 5.1 ≤ t ≤ 25.1（两条同时满足）
%   §4 遮蔽时长 = 遮蔽集合 W 中所有连续子区间长度之和
%
% 运行方法：MATLAB 中打开本文件，直接点"运行"。
%   ① 命令行输出：被遮蔽的时刻、连续段统计、有效遮蔽时长、边界距离诊断；
%   ② 自动保存 3D 轨迹图 M1轨迹图.png（供发全队）。
% 判定函数见 shield.m（输入时刻，输出 1=挡住/0=没挡住 + 距离）。
% ⚠ 本文件公式与 shield.m、一页纸三方必须一致，改动请同步。

clear; clc; close all;

%% ========== 常数（与一页纸一致）==========
t_det  = 5.1;        % 起爆时刻 (s) = 1.5 + 3.6
T_life = 20;         % 起爆后有效时长 (s) → 时间窗 [5.1, 25.1]
R_eff  = 10;         % 有效遮蔽半径 (m)

%% ========== §5 伪代码：逐时刻判定 ==========
t_list  = 0:0.1:30;                    % 第 0~30 秒，每 0.1 秒，共 301 个时刻
covered = false(1, length(t_list));    % 记录每个时刻是否遮蔽
d_list  = NaN(1, length(t_list));      % 记录每个时刻的距离（云团不存在时为 NaN）

for i = 1:length(t_list)
    t = t_list(i);
    [covered(i), d_list(i)] = shield(t);   % 规则见 shield.m
end

%% ========== §4 遮蔽时长：连续 true 段统计 ==========
% 每段 = 连续点数 × 0.1 s（一页纸 §4、§5 的统计口径）
dt = 0.1;
runs = {};                          % 记录每段连续遮蔽的起止
i = 1;
while i <= length(covered)
    if covered(i)
        j = i;
        while j < length(covered) && covered(j+1), j = j + 1; end
        runs{end+1} = [i, j];       %#ok<AGROW>
        i = j + 1;
    else
        i = i + 1;
    end
end

if isempty(runs)
    T_shield = 0;
    fprintf('0~30 s 内没有遮蔽时刻。\n');
else
    T_shield = 0;
    for r = 1:length(runs)
        seg = runs{r};
        len = (seg(2) - seg(1) + 1) * dt;
        T_shield = T_shield + len;
        fprintf('连续遮蔽段 %d：t = %.1f ~ %.1f s，共 %d 个点，长度 %.1f s\n', ...
                r, t_list(seg(1)), t_list(seg(2)), seg(2)-seg(1)+1, len);
    end
end

%% ========== 输出（发给建模手核对用）==========
fprintf('\n========== 问题 1 计算结果（按一页纸公式）==========\n');
fprintf('云团有效时间窗 = [%.1f, %.1f] s\n', t_det, t_det + T_life);
fprintf('被判"挡住"的时刻(s)：');
fprintf('%.1f ', t_list(covered));
fprintf('\n★ 有效遮蔽时长 = %.1f 秒  ← 第 1 题答案 ★\n', T_shield);

% 边界距离诊断：8.0/8.1 附近逐 0.01 s 列出距离，供建模手核对边界判定
fprintf('\n边界诊断（t = 8.00 ~ 8.15 s，步长 0.01 s）：\n');
for tb = 8.00:0.01:8.15
    [~, db] = shield(tb);
    fprintf('  t = %.2f s : d = %.4f m %s\n', tb, db, ...
            ternary(db <= R_eff, '(≤10，遮蔽)', '(>10，不遮蔽)'));
end

%% ========== 画 3D 轨迹图并发全队 ==========
% 轨迹用一页纸解析式直接画出（0~30 s 内 M1 尚未到达假目标，67.00 s > 30 s）
tt = t_list';
M1    = [20000 - 298.5*tt, zeros(length(tt),1), 2000 - 29.85*tt];   % §1 M1(t)
cloud = [17188*ones(sum(tt>=t_det),1), zeros(sum(tt>=t_det),1), ...
         1736.5 - 3*(tt(tt>=t_det) - t_det)];                        % §2 C(t)
FY1   = [17800 - 120*tt, zeros(length(tt),1), 1800*ones(length(tt),1)]; % 等高度 (假设1)
fake    = [0, 0, 0];
real_pt = [0, 200, 5];
pos_det = [17188, 0, 1736.5];

figure('Color', 'w', 'Position', [200 200 900 650]);
plot3(M1(:,1), M1(:,2), M1(:,3), 'r-', 'LineWidth', 1.6); hold on;
plot3(20000, 0, 2000, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(fake(1), fake(2), fake(3), 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'y');
plot3(real_pt(1), real_pt(2), real_pt(3), 'g^', 'MarkerSize', 9, 'MarkerFaceColor', 'g');
plot3(FY1(:,1), FY1(:,2), FY1(:,3), 'b--', 'LineWidth', 1.2);
plot3(17620, 0, 1800, 'cv', 'MarkerSize', 8, 'MarkerFaceColor', 'c');  % 投放点 (1.5 s)
plot3(pos_det(1), pos_det(2), pos_det(3), 'ms', 'MarkerSize', 9, 'MarkerFaceColor', 'm');
plot3(cloud(:,1), cloud(:,2), cloud(:,3), 'm:', 'LineWidth', 1.4);
xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)');
title('2025 A 题问题 1：M1 导弹轨迹与云团位置（按一页纸公式）');
legend('M1 轨迹', 'M1 起点', '假目标 (0,0,0)', '真目标 (0,200,5)', ...
       'FY1 轨迹', '投放点 (1.5 s)', '起爆点 (5.1 s)', '云团中心轨迹', ...
       'Location', 'best');
grid on; box on; view(35, 18);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'M1轨迹图.png'));
fprintf('轨迹图已保存：day1/M1轨迹图.png\n');

%% ========== 辅助：三元运算（边界诊断显示用）==========
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
