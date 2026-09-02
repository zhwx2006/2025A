%% compare_cap_Q4.m —— 第 4 题口径对比 + FY3 早时段补搜
% ① 导弹命中假目标精确时刻 + 当前冠军两种口径并集对比
% ② FY3 早时段补搜：把 FY3 云团放到 15~50 s（紧跟 FY2），看能否超过当前解
%    （当前解 FY3 在 60+ s，疑似局部最优；且 67 s 后导弹已命中，遮蔽无意义）
% ③ 以截断口径（导弹到达时刻）为准重新定型
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700];

% 当前冠军（finalize_Q4 输出）
X = [0.559, 120.77, 0.965, 3.861, ...
     -101.152, 135.33, 4.382, 5.797, ...
     28.072, 138.66, 37.516, 11.518];

%% ① 口径对比
uM = [-20000, 0, -2000] / sqrt(20000^2 + 2000^2);
t_hit = norm([20000, 0, 2000]) / 300;        % M1 命中假目标时刻
fprintf('M1 hits decoy at t = %.3f s\n', t_hit);
G70 = objective4(X);
Ghit = objective4(X, t_hit);
fprintf('current champion: 70 s domain union = %.3f s | cut at %.1f s union = %.3f s\n\n', ...
        G70, t_hit, Ghit);

%% ② FY3 早时段补搜（FY1、FY2 固定，目标按截断口径）
% FY1/FY2 区间都在 15 s 内，不受截断影响，固定它们只重搜 FY3
U12 = zeros(0, 2);
for p = 1:2
    ivp = one_cloud_interval4(S_all(p,:), X(1+(p-1)*4), X(2+(p-1)*4), ...
                              X(3+(p-1)*4), X(4+(p-1)*4), [], t_hit);
    if ~isempty(ivp), U12 = [U12; ivp]; end
end
S3 = S_all(3, :);

% 几何预热：对 t_target = 16:2:52，在视线段上采爆点，反解 FY3 可行投放
T_pt = [0 200 5];
cands = zeros(0, 5);
for t_target = 16:2:52
    M = [20000, 0, 2000] + 300 * t_target * uM;
    for f = 0:0.1:1
        Bxy = M(1:2) + f * (T_pt(1:2) - M(1:2));
        zdes = M(3) + f * (T_pt(3) - M(3));
        D = Bxy - S3(1:2);
        R = norm(D);
        if R < 1, continue; end
        v_req = R / t_target;
        if v_req < 70 || v_req > 140, continue; end
        th = atan2d(D(2)/R, -D(1)/R);
        tau_req = sqrt(max(0, (S3(3) - zdes) / 4.9));
        tau_req = min(tau_req, t_target);
        t0_req = max(0, t_target - tau_req);
        iv = one_cloud_interval4(S3, th, v_req, t0_req, tau_req, [], t_hit);
        dur = union_length([U12; iv]);
        if dur > 9.5            % 只要比 FY1+FY2 基线（约 9.45 s）有增益就保留
            cands(end+1, :) = [th, v_req, t0_req, tau_req, dur]; %#ok<AGROW>
        end
    end
end
if isempty(cands)
    fprintf('FY3 early-slot: NO geometric feasible candidate (all v_req out of [70,140] or tau too long)\n');
    fprintf('=> FY3 late placement (60-67 s) stands as best.\n');
    G_best = Ghit; X_best = X;
else
cands = sortrows(cands, -5);
fprintf('FY3 early-slot warm-starts kept: %d (best union %.3f s)\n', ...
        size(cands,1), cands(1,5));

% 对前 4 个候选做交替爬山（只动 FY3，FY1/2 固定）
G_best = Ghit;  X_best = X;
for s = 1:min(4, size(cands,1))
    Xs = X;
    Xs(9:12) = cands(s, 1:4);
    for it = 1:20
        Xold = Xs;
        Xs = refine_plane_cap(Xs, 3, S3, U12, t_hit);
        if norm(Xs - Xold) < 1e-4, break; end
    end
    Gs = objective4(Xs, t_hit);
    fprintf('warm-start %d -> union (cut) = %.4f s\n', s, Gs);
    if Gs > G_best
        G_best = Gs;  X_best = Xs;
    end
end
% 也拿早时段候选在全时域口径下爬山，看哪种口径更优
for s = 1:min(2, size(cands,1))
    Xs = X;
    Xs(9:12) = cands(s, 1:4);
    for it = 1:20
        Xold = Xs;
        Xs = refine_plane_cap(Xs, 3, S3, U12, 70);
        if norm(Xs - Xold) < 1e-4, break; end
    end
    Gs = objective4(Xs);
    fprintf('warm-start %d (full domain) -> union = %.4f s\n', s, Gs);
    if Gs > objective4(X_best) && Gs > G_best
        G_best = Gs;  X_best = Xs;
    end
end
end     % 闭合 if isempty(cands) / else 分支

%% ③ 最终对比输出
fprintf('\n========== FINAL COMPARISON ==========\n');
fprintf('old champion (70 s): %.3f s | old champion (cut %.1f s): %.3f s\n', ...
        G70, t_hit, Ghit);
fprintf('after FY3 early-slot re-search: best = %.3f s\n', objective4(X_best));
fprintf('after cut: %.3f s\n', objective4(X_best, t_hit));
for p = 1:3
    ivp = one_cloud_interval4(S_all(p,:), X_best(1+(p-1)*4), X_best(2+(p-1)*4), ...
                              X_best(3+(p-1)*4), X_best(4+(p-1)*4), [], t_hit);
    fprintf('FY%d: th=%.3f, v=%.2f, t0=%.3f, tau=%.3f | ', ...
            p, X_best(1+(p-1)*4), X_best(2+(p-1)*4), X_best(3+(p-1)*4), X_best(4+(p-1)*4));
    if isempty(ivp)
        fprintf('EMPTY');
    else
        for k = 1:size(ivp,1)
            fprintf('[%.3f, %.3f] ', ivp(k,1), ivp(k,2));
        end
    end
    fprintf('\n');
end

%% ================= 局部函数 =================
function X = refine_plane_cap(X, p, S, U, t_cap)
% 固定另外两机（并集区间 U），对第 p 机 4 参数做收缩块爬山（带截断口径）
    lev_steps = [20, 4, 0.8, 0.16, 0.032;
                 10, 2, 0.4, 0.08, 0.016;
                 1,  0.2, 0.04, 0.008, 0.0016;
                 1,  0.2, 0.04, 0.008, 0.0016];
    i0 = 1 + (p-1)*4;
    best_f = eval_u(X, p, S, U, t_cap);
    for lev = 1:5
        sth = lev_steps(1, lev); sv = lev_steps(2, lev);
        st0 = lev_steps(3, lev); stau = lev_steps(4, lev);
        th_c  = X(i0)   + (-2:2)*sth;
        v_c   = max(70, min(140, X(i0+1) + (-2:2)*sv));
        t0_c  = max(0, X(i0+2) + (-2:2)*st0);
        tau_c = max(0.05, X(i0+3) + (-2:2)*stau);
        for a = th_c
            for b = v_c
                for c = t0_c
                    for e = tau_c
                        Xt = X; Xt(i0:i0+3) = [a, b, c, e];
                        f = eval_u(Xt, p, S, U, t_cap);
                        if f > best_f, best_f = f; X = Xt; end
                    end
                end
            end
        end
    end
end

function f = eval_u(X, p, S, U, t_cap)
    iv = one_cloud_interval4(S, X(1+(p-1)*4), X(2+(p-1)*4), ...
                             X(3+(p-1)*4), X(4+(p-1)*4), [], t_cap);
    f = union_length([U; iv]);
end
