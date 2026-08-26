%% test_Q3.m —— 第 3 题回归测试（跑通再搜索）
% 按建模手交接包 §4 + 用户提示：
%   ① 并集逻辑：[8,9.4] ∪ [9.2,10.5] = 2.5（重叠只算一次）
%   ② 单弹 sanity：θ=0, v=120, t0=1.5, τ=3.6 → [8.013, 9.448]，时长 1.4 s
%   ③ 锚点三弹：θ=0, v=120, t0=(1.5,3.0,4.5), τ=3.6 → 观察并集，
%      预期只有第 1 弹有遮蔽、后两弹空区间
clear; clc;

%% ① 并集逻辑
L = union_length([8 9.4; 9.2 10.5]);
fprintf('① 并集测试：[8,9.4] ∪ [9.2,10.5] = %.3f s（期望 2.5）', L);
if abs(L - 2.5) < 1e-9, fprintf(' → 通过\n'); else, fprintf(' → 失败!\n'); end
L2 = union_length([1 3; 5 7; 2 6]);       % 交叉用例 → 6
fprintf('   交叉用例 [1,3]∪[5,7]∪[2,6] = %.3f s（期望 6）\n', L2);
L3 = union_length(zeros(0,2));            % 空输入 → 0
fprintf('   空输入 = %.3f s（期望 0）\n', L3);

%% ② 单弹 sanity（与第 1 题一致）
iv = one_cloud_interval(0, 120, 1.5, 3.6);
fprintf('\n② 单弹 sanity θ=0, v=120, t0=1.5, τ=3.6：\n');
if ~isempty(iv)
    fprintf('   区间 = [%.3f, %.3f]，时长 %.3f s（期望 ≈ [8.013, 9.448]，1.4 s）\n', ...
            iv(1,1), iv(1,2), iv(1,2)-iv(1,1));
else
    fprintf('   无遮蔽区间 → 失败!\n');
end
% 与 Q2 obscure 交叉验证（第 2 题同参数应得相同时长）
addpath('..\day2');
T_q2 = obscure(0, 120, 1.5, 3.6);
fprintf('   与 Q2 obscure 交叉验证：%.3f s（应一致）\n', T_q2);

%% ③ 锚点三弹
G = objective3([0 120 1.5 3.6 3.0 3.6 4.5 3.6]);
fprintf('\n③ 锚点三弹 θ=0, v=120, t0=(1.5,3.0,4.5), τ=3.6：并集 = %.3f s\n', G);
for i = 1:3
    ivi = one_cloud_interval(0, 120, 1.5+(i-1)*1.5, 3.6);
    if ~isempty(ivi)
        fprintf('   第 %d 弹区间：', i);
        for k = 1:size(ivi,1)
            fprintf('[%.3f, %.3f] ', ivi(k,1), ivi(k,2));
        end
        fprintf('\n');
    else
        fprintf('   第 %d 弹：空区间（无遮蔽）\n', i);
    end
end

%% ④ 病态用例回归：起爆瞬间即遮蔽时，区间起点应为起爆时刻（不得为负/超大）
fprintf('\n④ 病态用例回归（区间端点必须在 [0, 50] 内）：\n');
bad = 0;
test_X = [0 70 1.0 3.0 3.6 4.0 5.3 4.2;    % 曾产生 [-2246, 9.1] 的策略
          0 70 0 0.2 2 3 4.5 4.5;           % 小 τ（起爆点高、易起爆即遮蔽）
          0 100 0 1 1.5 5 3 5;
          0 140 0 5 1.2 5 2.4 5];
for r = 1:size(test_X,1)
    X = test_X(r,:);
    for i = 1:3
        ivi = one_cloud_interval(X(1), X(2), X(2*i+1), X(2*i+2));
        if ~isempty(ivi) && (any(ivi(:) < -1) || any(ivi(:) > 50))
            fprintf('   !!! 异常区间：第 %d 弹 [%s]（策略行 %d）\n', i, mat2str(ivi,4), r);
            bad = bad + 1;
        end
    end
end
if bad == 0, fprintf('   → 全部正常，无负起点/超大端点。\n'); end
fprintf('\n→ 回归测试完成。\n');
