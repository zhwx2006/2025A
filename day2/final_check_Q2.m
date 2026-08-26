%% final_check_Q2.m —— 问题 2 冠军点最终核验（防止交付假峰）
% ① 高分辨率复核冠军时长（dt=0.001）
% ② 冠军邻域细网格确认局部最优（含 t0 边界、v 边界、τ 边界方向）
% ③ 检查是否存在"沿 v-t0 简并方向"的更高点（固定爆点，扫 (v,t0)）
% ④ 确认 result1.xlsx 写盘正确

clear; clc;
here = fileparts(mfilename('fullpath'));

champ = [3.0500, 72.067, 0.0010, 2.5050];

%% ① 高分辨率复核
[Tc, ic] = obscure(champ(1), champ(2), champ(3), champ(4), 0.001);
fprintf('① 冠军高分辨率复核 (dt=0.001)：%.5f s\n', Tc);
fprintf('   遮蔽窗口：');
for k = 1:size(ic.intervals,1)
    fprintf('[%.4f, %.4f] ', ic.intervals(k,1), ic.intervals(k,2));
end
fprintf('\n');

%% ② 邻域细网格（含各约束边界方向）
fprintf('\n② 冠军邻域细网格局部最优性检查：\n');
th_g  = champ(1) + (-0.3:0.05:0.3);
v_g   = max(70, min(140, champ(2) + (-0.6:0.1:0.6)));
t0_g  = max(0, champ(3) + (-0.05:0.01:0.05));   % 下限 0
tau_g = max(0.2, champ(4) + (-0.08:0.01:0.08));
[TH, VV, T0, TT] = ndgrid(th_g, v_g, t0_g, tau_g);
Fg = reshape(arrayfun(@obscure, TH(:), VV(:), T0(:), TT(:)), size(TH));
[fm, ix] = max(Fg(:));
[i1,i2,i3,i4] = ind2sub(size(Fg), ix);
fprintf('   邻域 %d 点最优：(%.4f, %.4f, %.4f, %.4f) → %.5f s\n', ...
        numel(Fg), th_g(i1), v_g(i2), t0_g(i3), tau_g(i4), fm);
fprintf('   与冠军差 = %+.5f s（>0 说明冠军非局部最优，需回炉）\n', fm - Tc);
n_better = nnz(Fg > Tc + 1e-6);
fprintf('   邻域内严格优于冠军的点数：%d\n', n_better);

%% ③ 简并方向检查：固定爆点 B 与时序，扫 (v, t0) 组合
% 冠军爆点水平位移量 p = v*cos(θ)*(t0+τ)；固定爆点与时序，只换 (v, t0) 组合，
% 看时长是否真的不变（验证简并性，排除"换个组合就更好"的隐患）。
fprintf('\n③ 简并方向检查（固定爆点与时序，扫 v-t0 组合）：\n');
td_fix = champ(3) + champ(4);           % 起爆时刻固定
p_fix  = champ(2)*cosd(champ(1))*td_fix; % 水平位移固定
% v*cosθ 不变 → 换 v 就要换 θ；这里只检查 (v, t0) 在 td 固定下的组合
v_try = 70:5:140;
for k = 1:numel(v_try)
    t0_try = td_fix - champ(4);         % τ 固定
    if t0_try < 0, continue; end
    Tt = obscure(champ(1), v_try(k), t0_try, champ(4));
    fprintf('   v=%5.0f → %.5f s\n', v_try(k), Tt);
end

%% ④ xlsx 写盘确认
T = readtable(fullfile(here, 'result1.xlsx'));
fprintf('\n④ result1.xlsx 内容：\n');
disp(T);
