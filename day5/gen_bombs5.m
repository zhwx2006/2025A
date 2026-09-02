function bombs = gen_bombs5(m, S, th, v, nb_max, U_bg)
% gen_bombs5 —— 固定航线 (θ, v) 下，贪心生成最多 nb_max 枚弹（Q5 专用）
% 对每个候选 (起爆时刻 tdet, 引信 τ)，算单弹遮蔽区间，
% 贪心选取「对并集增量最大」的弹，直到无正增量或满额。
% U_bg：其他飞机/弹的遮蔽背景区间（增量相对整体并集计算，默认空）。
% 约束：同机相邻投放间隔 ≥ 1 s；爆点不钻地（τ ≤ √(S_z/4.9)）；t0 ≥ 0。
% 说明：解决「预热候选来自不同航线、强行共享后不匹配」的问题——
%       弹必须沿当前航线重新生成才能贴合。

    if nargin < 6, U_bg = zeros(0, 2); end
    cap = t_hit5(m);
    tau_max = min(cap, sqrt(max(0.01, S(3)/4.9)));
    U = zeros(0, 2);
    bombs = zeros(0, 2);
    U_len = union_length([U_bg; U]);
    for j = 1:nb_max
        best_inc = 0.05;               % 增量低于 0.05 s 不值得再投
        best_b = [];
        for td = 1:1:ceil(cap)
            for tau = 0.5:0.5:min(td, tau_max)
                t0 = td - tau;
                if t0 < 0, continue; end
                if ~isempty(bombs) && any(abs(t0 - bombs(:,1)) < 1)
                    continue;          % 同机投放间隔 < 1 s
                end
                iv = single_bomb5(S, th, v, t0, tau, m);
                if isempty(iv), continue; end
                inc = union_length([U_bg; U; iv]) - U_len;
                if inc > best_inc
                    best_inc = inc;  best_b = [t0, tau];
                end
            end
        end
        if isempty(best_b), break; end
        bombs(end+1, :) = best_b;      %#ok<AGROW>
        iv = single_bomb5(S, th, v, best_b(1), best_b(2), m);
        U = [U; iv];
        U_len = union_length([U_bg; U]);
    end
end
