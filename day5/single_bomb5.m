function intervals = single_bomb5(S, theta_deg, v, t0, tau, m, dt, t_cap)
% single_bomb5 —— 单枚烟幕弹对第 m 枚导弹的遮蔽区间列表（Q5 版）
% 输入：S 无人机起点 [x,y,z]；theta_deg 航向角(°，θ=0 朝假目标 −x，
%       水平单位向量 u=(−cosθ, sinθ, 0))；v 飞行速度；t0 投放时刻；
%       tau 投出后起爆时间；m 目标导弹编号(1/2/3)；dt 步长(默认 0.01)；
%       t_cap 时域上限截断（缺省 = 该导弹命中假目标时刻 t_hit5(m)）。
% 输出：intervals —— K×2 矩阵，每行一个遮蔽区间 [a,b]；无遮蔽时返回 0×2。
%
% 公式（Q5 模型一页纸）：
%   投放点 = S + v·t0·u（z 不变）
%   爆点 B = S + v·(t0+τ)·u + (0,0,−4.9τ²)
%   云团 C(t) = B + (0,0,−3·(t−tdet))，tdet = t0+τ，起爆后 20 s 有效
%   遮蔽：d(t)=dist(C(t), 线段[M_m(t), T=(0,200,5)]) ≤ 10，投影法 λ 截断 [0,1]
%   窗口截断到 min(tdet+20, t_hit5(m), t_cap)（导弹被诱偏后无遮蔽意义）。
% 边界处理与 Q3/Q4 相同（起爆即遮蔽取 tdet、窗口末端取 tend）。
% 回归基准：single_bomb5([17800,0,1800], 0, 120, 1.5, 3.6, 1) = [8.013, 9.448]。

    if nargin < 7 || isempty(dt), dt = 0.01; end
    if nargin < 8 || isempty(t_cap), t_cap = t_hit5(m); end
    th = theta_deg * pi / 180;
    tdet = t0 + tau;                                   % 起爆时刻
    tend = min([tdet + 20, t_hit5(m), t_cap]);         % 窗口上界
    if tdet >= tend
        intervals = zeros(0, 2);
        return;
    end
    u = [-cos(th), sin(th), 0];                        % 水平单位向量
    B = S + v*(t0+tau)*u + [0, 0, -0.5*9.8*tau^2];     % 爆点

    t = (tdet:dt:tend)';
    % ---- 导弹位置 M_m(t)（向量化）----
    Mp = missile_pos5(m, t);
    % ---- 云团位置 C(t)：起爆后只下沉 ----
    Cp = B + [zeros(size(t)), zeros(size(t)), -3*(t - tdet)];
    % ---- 投影法：点 C 到线段 [M_m, T] 的距离，λ 截断 [0,1] ----
    T_pt = [0 200 5];
    V   = T_pt - Mp;  W = Cp - Mp;
    lam = sum(W.*V, 2) ./ sum(V.*V, 2);
    lam = max(0, min(1, lam));
    Q   = Mp + lam .* V;
    d   = sqrt(sum((Cp - Q).^2, 2));

    % ---- 状态机收集连续遮蔽段 ----
    inside = d <= 10;
    intervals = zeros(0, 2);
    in_now = inside(1);
    if in_now
        st = t(1);
    end
    for i = 2:numel(t)
        if inside(i) ~= in_now
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
        intervals(end+1, :) = [st, t(end)];
    end
end
