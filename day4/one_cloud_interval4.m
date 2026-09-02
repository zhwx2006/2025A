function intervals = one_cloud_interval4(S, theta_deg, v, t0, tau, dt, t_cap)
% one_cloud_interval4 —— 单枚烟幕弹的遮蔽区间列表（Q4 版：起点参数化）
% 输入：S 无人机起点 [x,y,z]（FY1/FY2/FY3 各不相同）；
%       theta_deg 航向角(°，θ=0 朝假目标 −x，水平单位向量 (−cosθ, sinθ, 0))；
%       v 飞行速度(m/s)；t0 投放时刻(s)；tau 投出后起爆时间(s)；dt 步长(默认 0.01)
% 输出：intervals —— K×2 矩阵，每行一个遮蔽区间 [a,b]；无遮蔽时返回 0×2。
%
% 公式（Q4 模型一页纸）：
%   投放点 = S + v·t0·u，u = (−cosθ, sinθ, 0)（z 不变，等高飞行）
%   爆点 B = 投放点 + v·τ·u + (0,0,−½·9.8·τ²)  = S + v·(t0+τ)·u + (0,0,−4.9τ²)
%   云团 C(t) = B + (0,0,−3·(t−tdet))，tdet = t0+τ，起爆后 20 s 有效
%   遮蔽：d(t)=dist(C(t), 线段[M1(t),T]) ≤ 10，投影法 λ 截断 [0,1]
%   其中 M1(t) 为导弹位置（精确单位向量），T=(0,200,5)。
%   扫描时域 [0, 70]：Q4 中远机（FY2/FY3）爆点飞抵视线需 20~40 s，
%   tdet 可超过 30；导弹飞抵假目标约 67 s，取 70 s 覆盖（Q1–Q3 中 tdet≤10，不受影响）。
%   可选参数 t_cap：时域上限截断（如导弹命中假目标时刻 67 s）；
%   缺省 70 表示不额外截断（模型一页纸口径）。
% 边界处理与 Q3 one_cloud_interval 相同（起爆即遮蔽取 tdet、窗口末端取 tend）。
% 回归基准：one_cloud_interval4([17800,0,1800], 0, 120, 1.5, 3.6) = [8.013, 9.448]。

    if nargin < 6 || isempty(dt), dt = 0.01; end
    if nargin < 7 || isempty(t_cap), t_cap = 70; end
    th = theta_deg * pi / 180;
    tdet = t0 + tau;                                   % 起爆时刻
    tend = min([tdet + 20, 70, t_cap]);                % 窗口上界（受时域与 t_cap 双重约束）
    if tdet >= tend
        intervals = zeros(0, 2);
        return;
    end
    u = [-cos(th), sin(th), 0];                        % 水平单位向量
    B = S + v*(t0+tau)*u + [0, 0, -0.5*9.8*tau^2];     % 爆点

    t = (tdet:dt:tend)';
    % ---- 导弹位置 M1(t)（精确单位向量，向量化）----
    uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
    Mp = [20000, 0, 2000] + 300 * t * uM;
    % ---- 云团位置 C(t)：起爆后只下沉 ----
    Cp = B + [zeros(size(t)), zeros(size(t)), -3*(t - tdet)];
    % ---- 投影法：点 C 到线段 [M1, T] 的距离，λ 截断 [0,1] ----
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
        st = t(1);                                     % 起爆即遮蔽 → 起点 = tdet
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
