%% main_Q2.m —— 2025 国赛 A 题 · 问题 2（单机单弹最优投放策略）
% 严格按建模手《编程手任务交接包_第2题》：
%   目标函数 = obscure(θ, v, t0, tau)（第 1 题逻辑封装，见 obscure.m）
%   求解 = 先粗后细（三层，专治"又尖又窄的山脊"地形）：
%     L1 粗网格（必含锚点）
%     L2 每个非零粗扫点坐标多起点细化（步长缩 5 倍）→ 找出所有山脊盆地
%     L3 爆点参数空间 (p,θ,τ,td) 多起点精修 + 二次抛光（去除 (v,t0) 简并）
%     L4 安全网补扫（τ 扩到 6.5、t0 扩到 8），防止粗扫漏掉盆地
%   时长精算：步长 0.01 s + 边界线性插值（obscure 内部已实现）
% 输出四样（§5）：最优策略+最大时长、d(t) 曲线图、热力图、result1.xlsx
% 运行方法：MATLAB 中打开本文件，直接点"运行"。

clear; clc; close all;
here = fileparts(mfilename('fullpath'));

%% ========== ① 回归测试（§3，先跑通再搜索！）==========
TA = obscure(0, 120, 1.5, 3.6);   % 期望 ≈ 1.434（第 1 题答案）
TB = obscure(0, 140, 1.5, 3.6);   % 期望 = 0
fprintf('========== 回归测试（交接包 §3）==========\n');
fprintf('用例 A: obscure(0,120,1.5,3.6) = %.3f s（期望 ≈ 1.4）\n', TA);
fprintf('用例 B: obscure(0,140,1.5,3.6) = %.3f s（期望 = 0）\n', TB);
assert(abs(TA - 1.434) < 0.15, '回归 A 失败：函数封装或第 1 题代码有 bug');
assert(TB == 0,               '回归 B 失败：检查爆点公式或 λ 截断');
fprintf('→ 回归测试通过，开始搜索。\n\n');

%% ========== ② L1 粗网格搜索（§4，务必包含锚点 (0,120,1.5,3.6)）==========
th_c  = -40:20:40;    % θ (°)
v_c   = 70:10:140;    % v (m/s)
t0_c  = 0:2:10;       % t0 (s)
tau_c = 1:1:5;        % τ (s)
[TH, V, T0, TAU] = ndgrid(th_c, v_c, t0_c, tau_c);
F = reshape(arrayfun(@obscure, TH(:), V(:), T0(:), TAU(:)), size(TH));
fprintf('========== L1 粗网格 ==========\n');
fprintf('网格点数 %d，非零点 %d 个；锚点验证 F(0,120,1.5,3.6) = %.3f s（应 ≈ 1.435）\n', ...
        numel(F), nnz(F>0), obscure(0, 120, 1.5, 3.6));

%% ========== ③ L2 坐标多起点细化（找出所有山脊盆地）==========
steps0 = [20, 10, 2, 1];              % 粗网格各维步长
seed_ids = find(F > 0);
fprintf('\n========== L2 坐标多起点细化（%d 个种子）==========\n', numel(seed_ids));
refined = zeros(numel(seed_ids), 5);   % [θ, v, t0, τ, F]
for s = 1:numel(seed_ids)
    [i1,i2,i3,i4] = ind2sub(size(F), seed_ids(s));
    best  = [th_c(i1), v_c(i2), t0_c(i3), tau_c(i4)];
    steps = steps0;
    fmax  = F(seed_ids(s));
    for r = 1:6
        steps = steps / 5;
        th_g  = unique(best(1) + (-1:1)*steps(1));
        v_g   = max(70,  min(140, unique(best(2) + (-1:1)*steps(2))));
        t0_g  = max(0,   unique(best(3) + (-1:1)*steps(3)));
        tau_g = max(0.2, unique(best(4) + (-1:1)*steps(4)));
        [TH2, V2, T02, TAU2] = ndgrid(th_g, v_g, t0_g, tau_g);
        F2 = reshape(arrayfun(@obscure, TH2(:), V2(:), T02(:), TAU2(:)), size(TH2));
        [fmax, ix] = max(F2(:));
        ii = cell(4,1);  [ii{:}] = ind2sub(size(F2), ix);  ii = [ii{:}];
        best = [th_g(ii(1)), v_g(ii(2)), t0_g(ii(3)), tau_g(ii(4))];
    end
    refined(s, :) = [best, fmax];
end
[~, od] = sort(refined(:,5), 'descend');
refined = refined(od, :);
fprintf('细化后前 8 名（坐标空间）：\n');
for k = 1:min(8, size(refined,1))
    fprintf('  (%.2f°, %.2f, %.3f, %.3f) → %.4f s\n', refined(k,1:4), refined(k,5));
end

%% ========== ④ L3 爆点参数空间多起点精修（去 (v,t0) 简并，收敛后抛光）==========
% 同一爆点可由多组 (v, t0) 到达（v·(t0+τ) 不变），坐标细化会沿山脊边缘爬行；
% 改搜爆点参数：p = v·td（水平位移），td = t0+τ（起爆时刻），
% B = (17800 − p·cosθ, p·sinθ, 1800 − 4.9·τ²)，约束 v = p/td ∈ [70,140]，t0 ≥ 0。
% 对细化后 F ≥ 3.0 的种子逐个精修；收敛后再用小步长抛光一轮防过冲。
kseed = find(refined(:,5) >= 3.0);
fprintf('\n========== L3 爆点空间多起点精修（%d 个种子）==========\n', numel(kseed));
best_global = [0 0 0 0];  f_global = -1;
for s = kseed(:)'
    th_p = refined(s,1);  v_p = refined(s,2);
    t0_p = refined(s,3);  tau_p = refined(s,4);
    td = t0_p + tau_p;  p = v_p * td;
    [p, th_p, tau_p, td, fmax_p] = burst_ladder(p, th_p, tau_p, td);
    v_s = p/td;  t0_s = td - tau_p;
    fprintf('种子%2d → (θ=%.4f°, v=%.3f, t0=%.4f, τ=%.4f) %.4f s\n', ...
            s, th_p, v_s, t0_s, tau_p, fmax_p);
    if fmax_p > f_global
        f_global = fmax_p;
        best_global = [th_p, v_s, t0_s, tau_p];
    end
end
fprintf('→ L3 全局最优 %.4f s\n', f_global);

%% ========== ⑤ L4 安全网补扫（τ 扩到 6.5、t0 扩到 8，防粗扫漏盆地）==========
th_w  = -2:1:6;
v_w   = 70:10:140;
t0_w  = 0:1:8;
tau_w = 0.5:0.5:6.5;
[THw, Vw, T0w, TAUw] = ndgrid(th_w, v_w, t0_w, tau_w);
Fw = reshape(arrayfun(@obscure, THw(:), Vw(:), T0w(:), TAUw(:)), size(THw));
fprintf('\n========== L4 安全网补扫 ==========\n');
fprintf('网格点数 %d，非零 %d 个，最大 %.3f s\n', numel(Fw), nnz(Fw>0), max(Fw(:)));
[Fs, ord] = sort(Fw(:), 'descend');
if Fs(1) > f_global - 0.3          % 与当前最优差距 0.3 s 内的点都补一次精修
    nt = nnz(Fs > f_global - 0.3);
    fprintf('有 %d 个点接近当前最优，逐个爆点精修补漏：\n', nt);
    for k = 1:nt
        [i1,i2,i3,i4] = ind2sub(size(Fw), ord(k));
        th_p = th_w(i1);  v_p = v_w(i2);  t0_p = t0_w(i3);  tau_p = tau_w(i4);
        td = t0_p + tau_p;  p = v_p * td;
        [p, th_p, tau_p, td, fmax_p] = burst_ladder(p, th_p, tau_p, td);
        v_s = p/td;  t0_s = td - tau_p;
        fprintf('  补漏%2d (θ=%.1f°,v=%3.0f,t0=%2.0f,τ=%.1f) → (%.4f°, %.3f, %.4f, %.4f) %.4f s\n', ...
                k, th_w(i1), v_w(i2), t0_w(i3), tau_w(i4), th_p, v_s, t0_s, tau_p, fmax_p);
        if fmax_p > f_global
            f_global = fmax_p;
            best_global = [th_p, v_s, t0_s, tau_p];
        end
    end
else
    fprintf('→ 无接近当前最优的点，跳过补漏。\n');
end

%% ========== ⑤b L5 局部爬山抛光（最终保险）==========
% 对当前冠军做收缩步长爬山：每级以邻域 argmax 重新对中，步长逐级缩 5 倍；
% 爬完再验证：若末级步长邻域内仍有更优点则继续爬，防止停在平台边缘。
fprintf('\n========== L5 局部爬山抛光 ==========\n');
climb = best_global;  f_climb = f_global;
lev_steps = [0.3  0.06  0.012  0.0024  0.0005;    % θ (°)
             3    0.6   0.12   0.024   0.005;     % v (m/s)
             0.05 0.01  0.002  0.0004  0.0001;    % t0 (s)
             0.3  0.06  0.012  0.0024  0.0005];   % τ (s)
for lev = 1:5
    d = lev_steps(:, lev);
    th_g  = climb(1) + (-2:2)*d(1);
    v_g   = max(70, min(140, climb(2) + (-2:2)*d(2)));
    t0_g  = max(0,  climb(3) + (-2:2)*d(3));
    tau_g = max(0.2, climb(4) + (-2:2)*d(4));
    [THc, Vc, T0c, TUc] = ndgrid(th_g, v_g, t0_g, tau_g);
    Fc = reshape(arrayfun(@obscure, THc(:), Vc(:), T0c(:), TUc(:)), size(THc));
    [fm, ix] = max(Fc(:));
    ii = cell(4,1);  [ii{:}] = ind2sub(size(Fc), ix);  ii = [ii{:}];
    climb = [th_g(ii(1)), v_g(ii(2)), t0_g(ii(3)), tau_g(ii(4))];
    f_climb = fm;
    fprintf('第 %d 级（半宽 ±θ%.4g ±v%.4g ±t0%.4g ±τ%.4g）：(%.5f, %.5f, %.5f, %.5f) → %.5f s\n', ...
            lev, 2*d(1), 2*d(2), 2*d(3), 2*d(4), climb, fm);
end
for extra = 1:3                      % 验证轮：末级步长邻域内不再有更好点才收敛
    d = lev_steps(:, 5);
    th_g  = climb(1) + (-2:2)*d(1);
    v_g   = max(70, min(140, climb(2) + (-2:2)*d(2)));
    t0_g  = max(0,  climb(3) + (-2:2)*d(3));
    tau_g = max(0.2, climb(4) + (-2:2)*d(4));
    [THc, Vc, T0c, TUc] = ndgrid(th_g, v_g, t0_g, tau_g);
    Fc = reshape(arrayfun(@obscure, THc(:), Vc(:), T0c(:), TUc(:)), size(THc));
    [fm, ix] = max(Fc(:));
    ii = cell(4,1);  [ii{:}] = ind2sub(size(Fc), ix);  ii = [ii{:}];
    cand = [th_g(ii(1)), v_g(ii(2)), t0_g(ii(3)), tau_g(ii(4))];
    if fm > f_climb + 1e-9
        fprintf('验证轮 %d：仍有更优点 → (%.5f, %.5f, %.5f, %.5f) %.5f s\n', ...
                extra, cand, fm);
        climb = cand;  f_climb = fm;
    else
        fprintf('验证轮 %d：中心即邻域 argmax，爬山收敛。\n', extra);
        break;
    end
end
if f_climb > f_global
    fprintf('★ L5 更新冠军：%.5f s\n', f_climb);
    f_global = f_climb;  best_global = climb;
else
    fprintf('L5 冠军不变（%.5f s）\n', f_global);
end

th_star = best_global(1);  v_star = best_global(2);
t0_star = best_global(3);  tau_star = best_global(4);
[T_max, info] = obscure(th_star, v_star, t0_star, tau_star);
fprintf('\n========== 问题 2 最终结果（§5 产出 1）==========\n');
fprintf('最优策略：θ* = %.4f°，v* = %.3f m/s，t0* = %.4f s，τ* = %.4f s\n', ...
        th_star, v_star, t0_star, tau_star);
fprintf('最大遮蔽时长：%.3f s\n', T_max);
fprintf('投放点 = (%.1f, %.1f, %.1f)\n', info.drop_pt);
fprintf('爆点 B = (%.1f, %.1f, %.1f)\n', info.B);
fprintf('起爆时刻 = %.4f s；遮蔽区间：\n', info.t_det);
for i = 1:size(info.intervals, 1)
    fprintf('  [%.3f, %.3f] s（%.3f s）\n', info.intervals(i,1), ...
            info.intervals(i,2), info.intervals(i,2)-info.intervals(i,1));
end

%% ========== ⑦ 图 1：最优策略下 d(t) 曲线（§5 产出 2）==========
figure('Color','w','Position',[150 150 860 520]);
plot(info.t, info.d, 'b-', 'LineWidth', 1.8); hold on;
yline(10, 'r--', 'LineWidth', 1.5);
ymax = min(max(info.d)*1.1, 60);
for i = 1:size(info.intervals,1)
    patch([info.intervals(i,1) info.intervals(i,2) info.intervals(i,2) info.intervals(i,1)], ...
          [0 0 ymax ymax], [0.8 0.9 1], 'EdgeColor','none','FaceAlpha',0.5);
end
xlabel('时间 t (s)'); ylabel('d(t) (m)');
title(sprintf('问题 2 最优策略下 d(t)：θ=%.3f°, v=%.2f, t0=%.3f, τ=%.3f → 时长 %.3f s', ...
      th_star, v_star, t0_star, tau_star, T_max));
legend('d(t)', 'd=10（遮蔽边界）', '遮蔽区间', 'Location','northeast');
xlim([info.t_det-1, info.t_end]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q2_d(t)_曲线图.png'));
fprintf('\n图已保存：Q2_d(t)_曲线图.png\n');

%% ========== ⑧ 图 2：热力图 时长 vs v×t0（θ、τ 固定在最优点）==========
v_h  = 70:2:140;
t0_h = 0:0.5:10;
[VV, TT] = ndgrid(v_h, t0_h);
Fh = arrayfun(@(vv, tt) obscure(th_star, vv, tt, tau_star), VV, TT);
figure('Color','w','Position',[170 170 820 560]);
imagesc(t0_h, v_h, Fh); axis xy; colormap(jet);
cb = colorbar; cb.Label.String = '遮蔽时长 (s)';
hold on; plot(t0_star, v_star, 'kp', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('投放时刻 t0 (s)'); ylabel('飞行速度 v (m/s)');
title(sprintf('遮蔽时长热力图（θ = %.3f°，τ = %.3f s 固定）', th_star, tau_star));
saveas(gcf, fullfile(here, 'Q2_热力图_v-t0.png'));
fprintf('图已保存：Q2_热力图_v-t0.png\n');

%% ========== ⑨ result1.xlsx（§5 产出 4，第 3 题沿用此格式）==========
Tbl = table(th_star, v_star, t0_star, tau_star, T_max, ...
    'VariableNames', {'theta_deg','v_m_s','t0_s','tau_s','max_shield_s'});
writetable(Tbl, fullfile(here, 'result1.xlsx'));
fprintf('表格已保存：result1.xlsx\n');

%% ================= 局部函数：爆点空间收缩阶梯精修 =================
function [p, th, tau, td, fmax] = burst_ladder(p, th, tau, td)
% 爆点参数空间收缩阶梯精修：固定 7 级，每级步长缩 5 倍、始终以当前最优
% 重新对中，不提前停止 —— 避免「高原上邻域内部 argmax（等值并列）」
% 提前停在假峰的问题。末级结束后，各坐标与真峰距离不超过一个末级步长。
% 步长向量对应 (p, θ, τ, td)。
    steps0 = [30, 1, 0.5, 1.0];
    fmax = -1;
    for lev = 1:7
        steps = steps0 / 5^(lev-1);
        p_g   = unique(p   + (-1:1)*steps(1));
        th_g  = unique(th  + (-1:1)*steps(2));
        tau_g = max(0.2, unique(tau + (-1:1)*steps(3)));
        td_g  = unique(td  + (-1:1)*steps(4));
        [P2, TH2, TAU2, TD2] = ndgrid(p_g, th_g, tau_g, td_g);
        V2f  = P2 ./ TD2;               % v = p/td
        T02f = TD2 - TAU2;              % t0 = td − τ
        feas = V2f >= 70 & V2f <= 140 & T02f >= 0;
        Fp = nan(size(P2));
        idx = find(feas);
        Fp(idx) = arrayfun(@(k) obscure(TH2(k), V2f(k), T02f(k), TAU2(k)), idx);
        [fmax, ix] = max(Fp(:));
        ii = cell(4,1);  [ii{:}] = ind2sub(size(Fp), ix);  ii = [ii{:}];
        p = p_g(ii(1));  th = th_g(ii(2));  tau = tau_g(ii(3));  td = td_g(ii(4));
    end
end
