function intervals = one_cloud_interval(theta_deg, v, t0, tau, dt)
% one_cloud_interval —— 单枚烟幕弹的遮蔽区间列表（第 3 题核心）
% 输入：theta_deg 投放方向角(°，θ=0 朝假目标 −x)；v 飞行速度(m/s)；
%       t0 投放时刻(s)；tau 投出后起爆时间(s)；dt 时间步长(默认 0.01)
% 输出：intervals —— K×2 矩阵，每行一个遮蔽区间 [a,b]；无遮蔽时返回 0×2。
%
% 公式（与第 2 题 obscure 同约定）：
%   爆点 B = (17800 − v·cosθ·(t0+τ),  v·sinθ·(t0+τ),  1800 − ½·9.8·τ²)
%   云团 C(t) = B + (0,0,−3·(t−tdet))，tdet = t0+τ，起爆后 20 s 有效
%   遮蔽：d(t)=dist(C(t), 线段[M1(t),T]) ≤ 10，投影法 λ 截断 [0,1]
%
% 边界处理（重要）：只在云团存活窗口 [tdet, tdet+20] 内扫描。
%   - 起爆瞬间已遮蔽（d(tdet)≤10）→ 区间起点直接取 tdet，不做插值；
%   - 窗口结束时仍在遮蔽 → 区间终点直接取 tdet+20；
%   - 只有 d 真正穿越 10 的翻转点才做线性插值（避免除以近零斜率爆炸）。

    if nargin < 5, dt = 0.01; end
    th = theta_deg * pi / 180;
    tdet = t0 + tau;                                   % 起爆时刻
    tend = min(tdet + 20, 30);                         % 窗口上界（对齐参考实现：30 s）
    if tdet >= tend                                    % 起爆已超出评估时域
        intervals = zeros(0, 2);
        return;
    end
    % 爆点：投放点 + 平抛 τ 秒（水平位移按总时间 t0+τ，竖直自由落体按 τ）
    B = [17800 - v*cos(th)*(t0+tau), ...
         v*sin(th)*(t0+tau), ...
         1800 - 0.5*9.8*tau^2];

    t = (tdet:dt:tend)';                               % 只扫存活窗口
    % ---- 导弹位置 M1(t)（精确单位向量，向量化）----
    u  = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
    Mp = [20000, 0, 2000] + 300 * t * u;
    % ---- 云团位置 C(t)：起爆后只下沉 ----
    Cp = B + [zeros(size(t)), zeros(size(t)), -3*(t - tdet)];
    % ---- 投影法：点 C 到线段 [M1, T] 的距离，λ 截断 [0,1] ----
    T_pt = [0 200 5];
    V   = T_pt - Mp;  W = Cp - Mp;
    lam = sum(W.*V, 2) ./ sum(V.*V, 2);
    lam = max(0, min(1, lam));
    Q   = Mp + lam .* V;
    d   = sqrt(sum((Cp - Q).^2, 2));

    % ---- 状态机收集连续遮蔽段（与 Q2 obscure 相同，已验证）----
    inside = d <= 10;
    intervals = zeros(0, 2);
    in_now = inside(1);
    if in_now
        st = t(1);                                     % 起爆即遮蔽 → 起点 = tdet
    end
    for i = 2:numel(t)
        if inside(i) ~= in_now
            % d 穿越 10 的翻转点：在紧贴两点间线性插值
            tc = t(i-1) + (10 - d(i-1)) * dt / (d(i) - d(i-1));
            if in_now
                intervals(end+1, :) = [st, tc];        %#ok<AGROW>
            else
                st = tc;
            end
            in_now = inside(i);
        end
    end
    if in_now
        intervals(end+1, :) = [st, t(end)];            % 窗口结束仍遮蔽 → 终点 = tdet+20
    end
end
