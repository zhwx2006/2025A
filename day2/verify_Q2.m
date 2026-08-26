%% verify_Q2.m —— 问题 2 结果验证（确认全局最优，防漏盆地）
% 三步：
%   1) 冠军策略复核（时长 + 窗口）
%   2) 从次优盆地（多起点种子 21，4.63 s）独立做爆点参数空间精修
%   3) 扩大快扫（τ 扩到 7、t0 扩到 10），确认没有漏掉的更高盆地

clear; clc;

%% 1) 冠军复核
[Tx, info] = obscure(2.9153, 70.0, 0.0, 2.25);
fprintf('① 冠军复核：%.4f s，窗口 [%.3f, %.3f]\n', Tx, ...
        info.intervals(1,1), info.intervals(end,2));

%% 2) 次优盆地独立精修（起点 = 种子 21 细化结果 (1.0, 127.5, 0, 3.25)）
p = 127.5*3.25;  th = 1.0;  tau = 3.25;  td = 3.25;
steps = [50, 1, 0.4, 0.1];
fprintf('\n② 次优盆地爆点精修（起点 p=%.1f, θ=%.1f, τ=%.2f, td=%.2f）\n', p, th, tau, td);
for r = 1:8
    steps = steps / 5;
    p_g   = unique(p   + (-1:1)*steps(1));
    th_g  = unique(th  + (-1:1)*steps(2));
    tau_g = max(0.2, unique(tau + (-1:1)*steps(3)));
    td_g  = unique(td  + (-1:1)*steps(4));
    [P2, TH2, TAU2, TD2] = ndgrid(p_g, th_g, tau_g, td_g);
    V2f  = P2 ./ TD2;
    T02f = TD2 - TAU2;
    feas = V2f >= 70 & V2f <= 140 & T02f >= 0;
    Fp = nan(size(P2));
    idx = find(feas);
    Fp(idx) = arrayfun(@(k) obscure(TH2(k), V2f(k), T02f(k), TAU2(k)), idx);
    [fmax, ix] = max(Fp(:));
    ii = cell(4,1);  [ii{:}] = ind2sub(size(Fp), ix);  ii = [ii{:}];
    p = p_g(ii(1));  th = th_g(ii(2));  tau = tau_g(ii(3));  td = td_g(ii(4));
    at_edge = ii(1)==1 || ii(1)==numel(p_g) || ii(2)==1 || ii(2)==numel(th_g) ...
           || ii(3)==1 || ii(3)==numel(tau_g) || ii(4)==1 || ii(4)==numel(td_g);
    if ~at_edge, break; end
end
fprintf('→ 次优盆地精修结果：%.4f s，(θ=%.3f°, v=%.3f, t0=%.4f, τ=%.4f)\n', ...
        fmax, th, p/td, td-tau, tau);
if fmax > Tx + 1e-4
    fprintf('!!! 次优盆地更优，需回主程序更新冠军！\n');
else
    fprintf('→ 未超过冠军，冠军保持。\n');
end

%% 3) 扩大快扫：τ ∈ [1,7]，t0 ∈ [0,10]，θ ∈ [-20,20]，v ∈ [70,140]
th_w  = -20:10:20;
v_w   = 70:10:140;
t0_w  = 0:2:10;
tau_w = 1:1:7;
[THw, Vw, T0w, TAUw] = ndgrid(th_w, v_w, t0_w, tau_w);
Fw = reshape(arrayfun(@obscure, THw(:), Vw(:), T0w(:), TAUw(:)), size(THw));
fprintf('\n③ 扩大快扫：%d 点，非零 %d 个，最大 %.3f s\n', ...
        numel(Fw), nnz(Fw>0), max(Fw(:)));
[Fs, ord] = sort(Fw(:), 'descend');
fprintf('前 6 名：\n');
for k = 1:6
    [i1,i2,i3,i4] = ind2sub(size(Fw), ord(k));
    fprintf('  (θ=%5.1f°, v=%4.0f, t0=%4.1f, τ=%2.0f) → %.3f s\n', ...
        th_w(i1), v_w(i2), t0_w(i3), tau_w(i4), Fs(k));
end
if max(Fw(:)) > Tx + 0.05
    fprintf('!!! 扩大快扫发现显著更高点，需回主程序补细化！\n');
else
    fprintf('→ 未发现超过冠军的盆地，4.652 s 可作为全局最优交付。\n');
end
