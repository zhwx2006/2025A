function [flag, d] = shield(t)
% shield(t) —— 问题 1 遮蔽判定（按建模手交接包 §2 实现）
% 输入 : t —— 时刻 (s)，t = 0 为警戒雷达发现导弹、受领任务的时刻
% 输出 : flag = 1  该时刻云团挡住了「导弹 → 真目标」的视线；否则 0
%        d    = 云团中心到视线段的最短距离 (m)；云团不存在时 d = NaN
%
% 遮蔽判定（两条同时满足，交接包 §2）：
%   ① d(t) ≤ 10        —— 视线段 L(t) = [M1(t), T]，投影法见 point_to_segment_dist.m
%   ② 5.1 ≤ t ≤ 25.1   —— 起爆后 20 s 有效时间窗
%
% 位置函数统一出处（改动只需改一处）：
%   M1.m   —— 导弹位置（精确单位向量）
%   CloudC.m —— 云团中心位置
    T_pt   = [0, 200, 5];   % 真目标简化点，固定
    t_det  = 5.1;           % 起爆时刻 (s)
    T_life = 20;            % 起爆后有效时长 (s)
    R      = 10;            % 有效遮蔽半径 (m)

    d = NaN; flag = 0;
    if t < t_det || t > t_det + T_life
        return;             % 云团未形成 / 已消散 → 不遮蔽
    end
    d = point_to_segment_dist(CloudC(t), M1(t), T_pt);
    flag = double(d <= R);
end
