function [th, v, bombs, G] = optimize_plane5(m, S, U_fixed, th0, v0, bombs0)
% optimize_plane5 —— 单架飞机对导弹 m 的多弹优化（θ/v 全机共享 + 3 弹）
% 输入：m 导弹编号；S 飞机起点；U_fixed 其他弹的固定并集区间（可为 0×2）；
%       th0, v0 初始航线；bombs0 初始 3×2 弹表（每行 [t0, τ]）
% 输出：th, v 最优航线；bombs 最优 3×2 弹表；G 该弹组与 U_fixed 合并的并集时长
%
% 方法：交替爬坡 —— A) 固定航线，逐弹块爬山优化 (t0, τ)；
%                    B) 固定弹，块爬山优化航线 (θ, v)；迭代到收敛。
% 目标 = union_length([U_fixed; 本机 3 弹区间])（并集在导弹内去重）。

    th = th0;  v = v0;  bombs = bombs0;
    G = eval_plane5(m, S, th, v, bombs, U_fixed);

    for iter = 1:8
        % A) 固定 (θ, v)，逐弹优化 (t0, τ)
        for j = 1:size(bombs, 1)
            bombs = refine_bomb5(m, S, th, v, bombs, j, U_fixed);
        end
        % B) 固定弹，优化航线 (θ, v)
        [th, v] = refine_route5(m, S, th, v, bombs, U_fixed);
        Gnew = eval_plane5(m, S, th, v, bombs, U_fixed);
        if Gnew <= G + 1e-6
            G = Gnew;
            break;
        end
        G = Gnew;
    end
end

%% ---------- 子函数 ----------
function f = eval_plane5(m, S, th, v, bombs, U_fixed)
% 该机全部弹与 U_fixed 合并后的并集时长
    iv = U_fixed;
    for j = 1:size(bombs, 1)
        ivj = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
        if ~isempty(ivj)
            iv = [iv; ivj];
        end
    end
    f = union_length(iv);
end

function bombs = refine_bomb5(m, S, th, v, bombs, j, U_fixed)
% 优化第 j 弹的 (t0, τ)，固定其他弹与航线
% 约束：同机相邻投放间隔 ≥ 1 s；爆点不钻地（τ ≤ √(S_z/4.9)，一页纸软约束）
    Uj = U_fixed;
    for k = setdiff(1:size(bombs,1), j)
        ivk = single_bomb5(S, th, v, bombs(k,1), bombs(k,2), m);
        if ~isempty(ivk), Uj = [Uj; ivk]; end
    end
    lev_steps = [1,  0.2, 0.04, 0.008;      % t0 (s)
                 1,  0.2, 0.04, 0.008];     % τ (s)
    tau_max = sqrt(max(0.01, S(3)/4.9));    % 爆点高度 ≥ 0
    others = setdiff(1:size(bombs,1), j);
    best_f = eval_plane5(m, S, th, v, bombs, U_fixed);
    for lev = 1:4
        st0 = lev_steps(1, lev);  stau = lev_steps(2, lev);
        t0_c  = max(0, bombs(j,1) + (-2:2)*st0);
        tau_c = max(0.05, min(tau_max, bombs(j,2) + (-2:2)*stau));
        for c = t0_c
            if ~isempty(others) && any(abs(c - bombs(others,1)) < 1)
                continue;                    % 同机投放间隔 < 1 s，跳过
            end
            for e = tau_c
                bt = bombs;  bt(j,:) = [c, e];
                f = eval_plane5(m, S, th, v, bt, U_fixed);
                if f > best_f
                    best_f = f;  bombs = bt;
                end
            end
        end
    end
end

function [th, v] = refine_route5(m, S, th, v, bombs, U_fixed)
% 优化航线 (θ, v)，固定全部弹
    lev_steps = [20, 4, 0.8, 0.16;          % θ (°)
                 10, 2, 0.4, 0.08];         % v (m/s)
    best_f = eval_plane5(m, S, th, v, bombs, U_fixed);
    for lev = 1:4
        sth = lev_steps(1, lev);  sv = lev_steps(2, lev);
        th_c = th + (-2:2)*sth;
        v_c  = max(70, min(140, v + (-2:2)*sv));
        for a = th_c
            for b = v_c
                f = eval_plane5(m, S, a, b, bombs, U_fixed);
                if f > best_f
                    best_f = f;  th = a;  v = b;
                end
            end
        end
    end
end
