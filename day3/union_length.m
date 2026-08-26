function L = union_length(all_iv)
% union_length —— 多个区间并集总长（排序 + 合并重叠，重叠只算一次）
% 输入：all_iv —— K×2 矩阵，每行一个区间 [a,b]（可为空 0×2）
% 输出：L —— 并集总长度（秒）
% 测试：union_length([8 9.4; 9.2 10.5]) 应得 2.5（不是 2.7）。

    if isempty(all_iv), L = 0; return; end
    A = sortrows(all_iv, 1);           % 按左端点排序
    L = 0;
    cur_s = A(1,1); cur_e = A(1,2);
    for i = 2:size(A,1)
        if A(i,1) <= cur_e             % 与当前段重叠（含端点相接）
            cur_e = max(cur_e, A(i,2));
        else                           % 不重叠：结算当前段，开新段
            L = L + (cur_e - cur_s);
            cur_s = A(i,1); cur_e = A(i,2);
        end
    end
    L = L + (cur_e - cur_s);           % 结算最后一段
end
