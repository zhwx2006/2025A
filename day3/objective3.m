function dur = objective3(X)
% objective3 —— 第 3 题目标函数：三弹遮蔽并集总时长
% 输入：X = [theta_deg, v, t01, tau1, t02, tau2, t03, tau3]
%        θ、v 三弹共享（同一架飞机）；(t0ᵢ, τᵢ) 每弹各自不同
% 输出：dur —— 三团云遮蔽区间的并集长度（秒）；参数违反约束时返回 -1（供搜索惩罚）
%
% 约束（建模手交接包 §1）：
%   70 ≤ v ≤ 140；相邻投放间隔 ≥ 1 s（t02−t01≥1，t03−t02≥1）；t0ᵢ ≥ 0；τᵢ > 0

    % ---- 约束检查（违反返回 -1，搜索时作为惩罚）----
    if X(2) < 70 || X(2) > 140 || ...
       X(3) < 0 || X(5) < 0 || X(7) < 0 || ...
       X(5) - X(3) < 1 || X(7) - X(5) < 1
        dur = -1;
        return;
    end

    all_iv = zeros(0, 2);
    for i = 1:3
        iv = one_cloud_interval(X(1), X(2), X(3+(i-1)*2), X(4+(i-1)*2));
        if ~isempty(iv)
            all_iv = [all_iv; iv];
        end
    end
    dur = union_length(all_iv);
end
