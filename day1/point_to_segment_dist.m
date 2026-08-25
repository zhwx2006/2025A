function d = point_to_segment_dist(P, A, B)
% 点 P 到线段 AB 的最短距离 —— 投影法（交接包 §2 四步）
%   1) λ = (P−A)·(B−A) / |B−A|²
%   2) λ 截断到 [0,1] —— 垂足落在线段外则取最近端点（最容易漏的一步！）
%   3) Q = A + λ·(B−A)
%   4) d = |P − Q|
% ⚠ 不截断会把「点到直线」当成「点到线段」，距离算小、窗口被严重高估。
    v = B - A;
    w = P - A;
    lam = dot(w, v) / dot(v, v);
    lam = max(0, min(1, lam));        % 关键：截断到 [0,1]
    Q = A + lam * v;
    d = norm(P - Q);
end
