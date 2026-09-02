function dur = objective4(X, t_cap)
% objective4 —— 第 4 题目标函数：三机各投一弹、遮 M1 的并集总时长
% 输入：X = [θ1,v1,t01,τ1, θ2,v2,t02,τ2, θ3,v3,t03,τ3]（12 维）
%        每机 (θᵢ, vᵢ, t0ᵢ, τᵢ) 独立；三机起点不同（FY1/FY2/FY3）
%        t_cap：可选时域上限截断（如导弹命中假目标时刻 ~67 s）；缺省 70
% 输出：dur —— 三团云遮蔽区间的并集长度（秒）；参数违反约束时返回 -1
%
% 约束（Q4 模型一页纸）：70 ≤ vᵢ ≤ 140；三机之间无间隔约束。
% 起点：FY1 (17800,0,1800)，FY2 (12000,1400,1400)，FY3 (6000,−3000,700)。

    if nargin < 2 || isempty(t_cap), t_cap = 70; end

    S = [17800, 0, 1800;          % FY1
         12000, 1400, 1400;       % FY2
         6000, -3000, 700];       % FY3

    % ---- 约束检查（每机速度 70~140，投放/引信非负）----
    for i = 1:3
        v_i  = X(2 + (i-1)*4);
        t0_i = X(3 + (i-1)*4);
        tau_i = X(4 + (i-1)*4);
        if v_i < 70 || v_i > 140 || t0_i < 0 || tau_i < 0
            dur = -1;
            return;
        end
    end

    all_iv = zeros(0, 2);
    for i = 1:3
        th_i  = X(1 + (i-1)*4);
        v_i   = X(2 + (i-1)*4);
        t0_i  = X(3 + (i-1)*4);
        tau_i = X(4 + (i-1)*4);
        iv = one_cloud_interval4(S(i,:), th_i, v_i, t0_i, tau_i, [], t_cap);
        if ~isempty(iv)
            all_iv = [all_iv; iv];
        end
    end
    dur = union_length(all_iv);
end
