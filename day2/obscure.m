function [T_shield, info] = obscure(theta_deg, v, t0, tau, dt)
% obscure(θ, v, t0, tau) —— 第 2 题目标函数：单枚烟幕弹的遮蔽时长 (s)
% 严格按建模手《编程手任务交接包_第2题》§2 公式实现：
%   θ 约定：θ=0 表示朝假目标方向（−x），逆时针为正
%   FY1 在 z=1800 等高度匀速直线飞行，速度 v，方向由 θ 给定
%   投放点 = (17800 − v·cosθ·t0,  v·sinθ·t0,  1800)
%   爆点 B = 投放点 + (−v·cosθ·τ,  v·sinθ·τ,  −½·9.8·τ²)   （平抛 τ 秒起爆）
%   云团 C(t) = B + (0, 0, −3·(t − t_det))，t ≥ t_det = t0+τ，起爆后 20 s 有效
%   导弹 M1(t)：与第 1 题完全相同（300 m/s 直线飞向假目标，精确单位向量）
%   真目标 T = (0, 200, 5)
%   遮蔽判定：d(t) = dist(C(t), 线段[M1(t), T]) ≤ 10，投影法、λ 截断到 [0,1]
%   遮蔽时长 = 所有连续遮蔽段长度之和，段边界用线性插值精确到 d=10 处
%
% 输入：theta_deg 投放方向角(°)；v 飞行速度(m/s)；t0 投放时刻(s)；
%       tau 投出后起爆时间(s)；dt 时间步长(默认 0.01 s)
% 输出：T_shield 遮蔽时长(s)；info 结构体（t、d、遮蔽区间、爆点等，画图用）

    if nargin < 5, dt = 0.01; end

    th = theta_deg * pi/180;
    vx = -v*cos(th);  vy = v*sin(th);                    % FY1 速度（θ=0 为 −x）
    drop_pt = [17800 + vx*t0, vy*t0, 1800];              % 投放点
    B = [drop_pt(1) + vx*tau, ...                        % 爆点（平抛 τ 秒）
         drop_pt(2) + vy*tau, ...
         1800 - 0.5*9.8*tau^2];
    t_det = t0 + tau;  t_end = t_det + 20;               % 起爆时刻 / 云团消散时刻
    t = (t_det:dt:t_end)';

    % ---- M1(t)：与第 1 题相同（day1/M1.m 的精确单位向量，勿手工舍入）----
    u  = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
    Mp = [20000, 0, 2000] + 300 * t * u;

    % ---- C(t)：爆点正下方以 3 m/s 下沉 ----
    Cp = [B(1) + zeros(size(t)), B(2) + zeros(size(t)), B(3) - 3*(t - t_det)];

    % ---- 投影法：点 C 到线段 [M1, T] 的距离，λ 截断到 [0,1] ----
    Tp  = [0, 200, 5];
    V   = Tp - Mp;  W = Cp - Mp;
    lam = sum(W.*V, 2) ./ sum(V.*V, 2);
    lam = max(0, min(1, lam));                           % 关键截断（交接包 §2）
    Q   = Mp + lam .* V;
    d   = sqrt(sum((Cp - Q).^2, 2));

    % ---- 收集连续遮蔽段，边界线性插值到 d=10 ----
    inside = d <= 10;
    intervals = zeros(0, 2);
    in_now = inside(1);  st = t(1);
    for i = 2:numel(t)
        if inside(i) ~= in_now
            tc = t(i-1) + (10 - d(i-1)) * dt / (d(i) - d(i-1));
            if in_now
                intervals(end+1, :) = [st, tc];          %#ok<AGROW>
            else
                st = tc;
            end
            in_now = inside(i);
        end
    end
    if in_now
        intervals(end+1, :) = [st, t(end)];
    end
    T_shield = sum(intervals(:,2) - intervals(:,1));

    if nargout > 1
        info.t = t;  info.d = d;  info.intervals = intervals;
        info.B = B;  info.drop_pt = drop_pt;
        info.t_det = t_det;  info.t_end = t_end;
    end
end
