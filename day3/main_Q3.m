%% main_Q3.m —— 2025 国赛 A 题 · 问题 3（FY1 单机三弹时序协同）
% 严格按建模手《编程手任务交接包_第3题》：
%   决策变量 X = (θ, v, t01, τ1, t02, τ2, t03, τ3)，θ/v 三弹共享
%   目标 = 三团云遮蔽区间的并集长度（重叠只算一次）
%   约束：70≤v≤140；相邻投放间隔 ≥1 s；每弹平抛 τi 起爆；云团 10 m/20 s 有效
% 求解（先粗后细）：
%   L1 单弹区间表（θ×v×t0×τ 网格，只保留有遮蔽的弹）
%   L2 同 (θ,v) 下三弹组合枚举（间隔约束），并集取最优
%   L3 多起点块坐标精修（θ、v、每弹 (t0,τ) 逐块收缩爬山）
%   L4 最终评估 + 图 + 官方格式 result1.xlsx
% 运行方法：MATLAB 中打开本文件，直接点"运行"。
% （控制台输出用英文，避免 batch 模式中文乱码）

clear; clc; close all;
here = fileparts(mfilename('fullpath'));

%% ========== ① 回归快检（交接包 §4）==========
assert(abs(union_length([8 9.4; 9.2 10.5]) - 2.5) < 1e-9, 'union test failed');
iv0 = one_cloud_interval(0, 120, 1.5, 3.6);
assert(abs(iv0(1,1) - 8.013) < 0.01 && abs(iv0(1,2) - 9.448) < 0.01, 'single-bomb sanity failed');
fprintf('Regression passed (union 2.5 s; single bomb [%.3f, %.3f])\n\n', iv0(1,1), iv0(1,2));

%% ========== ② L1 单弹区间表 ==========
th_grid  = -10:5:20;       % θ (°)
v_grid   = 70:5:140;       % v (m/s)
t0_grid  = 0:1:12;         % t0 (s)
tau_grid = 1:0.5:5;        % τ (s)
fprintf('========== L1 single-bomb interval table ==========\n');
tic;
bombs = struct('th',{},'v',{},'t0',{},'tau',{},'iv',{},'dur',{});
nb = 0;
for a = 1:numel(th_grid)
    for b = 1:numel(v_grid)
        for c = 1:numel(t0_grid)
            for e = 1:numel(tau_grid)
                iv = one_cloud_interval(th_grid(a), v_grid(b), t0_grid(c), tau_grid(e));
                dur = union_length(iv);
                if dur > 0.3          % 只保留有明显遮蔽的弹，供组合枚举
                    nb = nb + 1;
                    bombs(nb) = struct('th', th_grid(a), 'v', v_grid(b), ...
                        't0', t0_grid(c), 'tau', tau_grid(e), 'iv', {iv}, 'dur', dur);
                end
            end
        end
    end
end
fprintf('grid %d pts, bombs with shielding (>0.3 s): %d, %.1f s\n\n', ...
        numel(th_grid)*numel(v_grid)*numel(t0_grid)*numel(tau_grid), nb, toc);

%% ========== ③ L2 三弹组合枚举（同 θ、v，间隔 ≥1 s）==========
fprintf('========== L2 three-bomb combination ==========\n');
tic;
best_G = 0;  best_X = [];
top_list = zeros(0, 9);
for a = 1:numel(th_grid)
    for b = 1:numel(v_grid)
        sel = find([bombs.th] == th_grid(a) & [bombs.v] == v_grid(b));
        N = numel(sel);
        if N < 3, continue; end
        t0s = [bombs(sel).t0];
        for i = 1:N
            for j = 1:N
                if t0s(j) < t0s(i) + 1, continue; end
                for k = 1:N
                    if t0s(k) < t0s(j) + 1, continue; end
                    G = union_length([bombs(sel(i)).iv; bombs(sel(j)).iv; bombs(sel(k)).iv]);
                    X = [th_grid(a), v_grid(b), bombs(sel(i)).t0, bombs(sel(i)).tau, ...
                         bombs(sel(j)).t0, bombs(sel(j)).tau, bombs(sel(k)).t0, bombs(sel(k)).tau];
                    if G > best_G
                        best_G = G;  best_X = X;
                    end
                    if G > 5.0      % 只收高质量候选，供多起点精修
                        top_list(end+1, :) = [G, X]; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
% 保证粗扫最优一定在候选里
top_list(end+1, :) = [best_G, best_X];
[top_list, oidx] = sortrows(top_list, -1);
top_list = top_list(oidx, :);
[~, uq] = unique(round(top_list(:,2:end)*1e6), 'rows', 'stable');
top_list = top_list(sort(uq), :);
top_list = top_list(1:min(15, size(top_list,1)), :);
fprintf('coarse best union = %.3f s, X = (%.1f, %.0f, t0=[%.1f %.1f %.1f], tau=[%.1f %.1f %.1f])\n', ...
        best_G, best_X(1), best_X(2), best_X(3), best_X(5), best_X(7), best_X(4), best_X(6), best_X(8));
fprintf('candidates for multi-start: %d, %.1f s\n\n', size(top_list,1), toc);

%% ========== ④ L3 多起点块坐标精修 ==========
fprintf('========== L3 multi-start block refinement ==========\n');
tic;
step_th  = [5,   1,   0.2,  0.04];
step_v   = [5,   1,   0.2,  0.04];
step_t0  = [1,   0.2, 0.04, 0.008];
step_tau = [0.5, 0.1, 0.02, 0.004];
G_global = -1;  X_global = [];
for s = 1:size(top_list, 1)
    X = top_list(s, 2:end);
    for round = 1:4
        X = refine_block(X, 1, step_th(round),  [-180, 180]);   % θ
        X = refine_block(X, 2, step_v(round),   [70, 140]);     % v
        for bomb = 1:3
            X = refine_bomb(X, bomb, step_t0(round), step_tau(round));
        end
    end
    G = objective3(X);
    fprintf('start%2d -> (th=%.3f, v=%.3f, t0=[%.3f %.3f %.3f], tau=[%.3f %.3f %.3f]) union=%.4f s\n', ...
            s, X(1), X(2), X(3), X(5), X(7), X(4), X(6), X(8), G);
    if G > G_global
        G_global = G;  X_global = X;
    end
end
fprintf('global best after refinement: %.4f s, %.1f s\n\n', G_global, toc);

%% ========== ⑤ L4 最终评估 ==========
X = X_global;
th_star = X(1);  v_star = X(2);
t0s = [X(3), X(5), X(7)];  taus = [X(4), X(6), X(8)];
iv_all = zeros(0, 2);
iv_each = cell(3, 1);
for i = 1:3
    iv_each{i} = one_cloud_interval(th_star, v_star, t0s(i), taus(i));
    if ~isempty(iv_each{i})
        iv_all = [iv_all; iv_each{i}];
    end
end
G_final = union_length(iv_all);
fprintf('========== Q3 FINAL RESULT ==========\n');
fprintf('optimal: th* = %.3f deg, v* = %.3f m/s\n', th_star, v_star);
for i = 1:3
    fprintf('bomb %d: t0 = %.3f s, tau = %.3f s, intervals: ', i, t0s(i), taus(i));
    if isempty(iv_each{i})
        fprintf('EMPTY');
    else
        for k = 1:size(iv_each{i},1)
            fprintf('[%.3f, %.3f] ', iv_each{i}(k,1), iv_each{i}(k,2));
        end
    end
    fprintf('\n');
end
fprintf('UNION TOTAL = %.3f s\n', G_final);

%% ========== ⑥ 图 1：三弹 d(t) 曲线 + 并集区间 ==========
t_plt = (0:0.02:30)';
u  = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
Mp = [20000, 0, 2000] + 300 * t_plt * u;
figure('Color','w','Position',[140 140 900 540]); hold on;
cols = {'b', [0 0.6 0], [0.8 0.4 0]};
leg = cell(3,1);
ymax = 40;
th = th_star*pi/180;
for i = 1:3
    B = [17800 - v_star*cos(th)*(t0s(i)+taus(i)), v_star*sin(th)*(t0s(i)+taus(i)), ...
         1800 - 4.9*taus(i)^2];
    tdet = t0s(i) + taus(i);
    Cp = B + [zeros(size(t_plt)), zeros(size(t_plt)), -3*(t_plt - tdet)];
    V = [0 200 5] - Mp;  W = Cp - Mp;
    lam = max(0, min(1, sum(W.*V,2) ./ sum(V.*V,2)));
    Q = Mp + lam .* V;
    d = sqrt(sum((Cp-Q).^2, 2));
    d(t_plt < tdet | t_plt > min(tdet+20,30)) = NaN;
    plot(t_plt, d, '-', 'Color', cols{i}, 'LineWidth', 1.6);
    leg{i} = sprintf('bomb %d d(t)', i);
end
yline(10, 'r--', 'LineWidth', 1.5);
A_u = sortrows(iv_all, 1);
cs = A_u(1,1); ce = A_u(1,2);
segs = zeros(0,2);
for i = 2:size(A_u,1)
    if A_u(i,1) <= ce
        ce = max(ce, A_u(i,2));
    else
        segs(end+1,:) = [cs ce]; cs = A_u(i,1); ce = A_u(i,2);
    end
end
segs(end+1,:) = [cs ce];
for i = 1:size(segs,1)
    patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], [0 0 ymax ymax], ...
          [0.8 0.9 1], 'EdgeColor','none','FaceAlpha',0.45);
end
xlabel('t (s)'); ylabel('d(t) (m)');
title(sprintf('Q3 optimal: 3 bombs d(t), union = %.3f s (th=%.2f deg, v=%.1f m/s)', ...
      G_final, th_star, v_star));
legend([leg{:}, 'd=10 boundary', 'union intervals'], 'Location','northeast');
xlim([0 30]); ylim([0 ymax]); grid on; box on;
saveas(gcf, fullfile(here, 'Q3_三弹d(t)_曲线图.png'));
fprintf('\nfigure saved: Q3_三弹d(t)_曲线图.png\n');

%% ========== ⑦ 图 2：热力图（并集时长 vs t01×t02，其余固定）==========
t01_h = max(0, t0s(1)-2):0.2:t0s(1)+4;
t02_h = max(0, t0s(2)-2):0.2:t0s(2)+4;
[T1, T2] = ndgrid(t01_h, t02_h);
Fh = nan(size(T1));
for i = 1:numel(T1)
    if T2(i) >= T1(i) + 1 && t0s(3) >= T2(i) + 1
        Fh(i) = objective3([th_star, v_star, T1(i), taus(1), T2(i), taus(2), t0s(3), taus(3)]);
    end
end
figure('Color','w','Position',[160 160 820 560]);
imagesc(t02_h, t01_h, Fh); axis xy; colormap(jet);
cb = colorbar; cb.Label.String = 'union duration (s)';
hold on; plot(t0s(2), t0s(1), 'kp', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('t02 (s)'); ylabel('t01 (s)');
title(sprintf('union heatmap (th=%.2f deg, v=%.1f, tau=[%.2f %.2f %.2f], t03=%.2f fixed)', ...
      th_star, v_star, taus, t0s(3)));
saveas(gcf, fullfile(here, 'Q3_热力图_t01-t02.png'));
fprintf('figure saved: Q3_热力图_t01-t02.png\n');

%% ========== ⑧ result1.xlsx（官方模板格式）==========
% 官方方向约定：以 x 轴正向为基准、逆时针为正、0~360°
dir_official = mod(atan2d(v_star*sin(th), -v_star*cos(th)), 360);
hdr = {'无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)'};
data = zeros(3, 10);
for i = 1:3
    drop = [17800 - v_star*cos(th)*t0s(i), v_star*sin(th)*t0s(i), 1800];
    det  = drop + [-v_star*cos(th)*taus(i), v_star*sin(th)*taus(i), -4.9*taus(i)^2];
    data(i, :) = [dir_official, v_star, i, drop(1), drop(2), drop(3), ...
                  det(1), det(2), det(3), G_final];
end
writecell([hdr; num2cell(data)], fullfile(here, 'result1.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
            fullfile(here, 'result1.xlsx'), 'Sheet', 1, 'Range', 'A5');
% Sheet2 明细（内部约定 θ 与每弹区间）
det_hdr = {'弹编号','t0(s)','tau(s)','起爆时刻(s)','区间','并集总时长(s)'};
det_data = cell(3, 6);
for i = 1:3
    if isempty(iv_each{i})
        ivstr = '空';
    else
        ivstr = arrayfun(@(k) sprintf('[%.3f,%.3f]', iv_each{i}(k,1), iv_each{i}(k,2)), ...
                         1:size(iv_each{i},1), 'UniformOutput', false);
        ivstr = strjoin(ivstr, ' ');
    end
    det_data(i, :) = {i, t0s(i), taus(i), t0s(i)+taus(i), ivstr, G_final};
end
writecell([det_hdr; det_data], fullfile(here, 'result1.xlsx'), 'Sheet', 2);
fprintf('table saved: result1.xlsx (Sheet1 official, Sheet2 details)\n');
fprintf('official direction = %.3f deg (internal th = %.3f deg)\n', dir_official, th_star);

%% ================= 局部函数 =================
function X = refine_block(X, dim, step, lim)
% 沿单一维度做 ±2 步候选搜索（保持约束由 objective3 检查，违规返回 -1）
    cands = X(dim) + (-2:2)*step;
    cands = max(lim(1), min(lim(2), cands));
    best_f = objective3(X);
    for c = cands
        Xt = X;  Xt(dim) = c;
        f = objective3(Xt);
        if f > best_f
            best_f = f;  X = Xt;
        end
    end
end

function X = refine_bomb(X, bomb, step_t0, step_tau)
% 对第 bomb 枚弹的 (t0, τ) 做 5×5 联合块搜索，过滤间隔约束
    i0 = 3 + (bomb-1)*2;
    c_t0  = max(0, X(i0) + (-2:2)*step_t0);
    c_tau = max(0.2, X(i0+1) + (-2:2)*step_tau);
    best_f = objective3(X);
    for ct = c_t0
        if bomb > 1 && ct < X(i0-2) + 1, continue; end
        if bomb < 3 && ct > X(i0+2) - 1, continue; end
        for cu = c_tau
            Xt = X;  Xt(i0) = ct;  Xt(i0+1) = cu;
            f = objective3(Xt);
            if f > best_f
                best_f = f;  X = Xt;
            end
        end
    end
end
