%% verify2_Q2.m —— 问题 2 冠军点最终核验
% ① 冠军策略在 dt=0.01 与 dt=0.001 两种分辨率下复核（交叉验证时长精度）
% ② 冠军邻域网格复扫（θ±0.2°, v±1, t0 0~0.2, τ±0.1），确认无更优点
% ③ 读回 result1.xlsx 确认写盘正确

clear; clc;

%% ① 冠军双分辨率复核
champ = [3.0, 72.0, 0.0, 2.5];
[Ta, ia] = obscure(champ(1), champ(2), champ(3), champ(4), 0.01);
[Tb, ib] = obscure(champ(1), champ(2), champ(3), champ(4), 0.001);
fprintf('① 冠军复核 dt=0.01 ：%.4f s，窗口 [%.4f, %.4f]\n', ...
        Ta, ia.intervals(1,1), ia.intervals(end,2));
fprintf('   dt=0.001：%.4f s，窗口 [%.4f, %.4f]\n', ...
        Tb, ib.intervals(1,1), ib.intervals(end,2));
fprintf('   两分辨率时长差 = %.5f s（<0.001 即精度合格）\n', abs(Ta-Tb));

%% ② 邻域网格复扫（确认局部最优、无更优点）
th_g  = 2.8:0.05:3.2;
v_g   = 71:0.25:73;
t0_g  = 0:0.05:0.2;       % t0 ≥ 0 约束边界，只向正方向扫
tau_g = 2.4:0.025:2.6;
[TH, VV, T0, TT] = ndgrid(th_g, v_g, t0_g, tau_g);
Fg = reshape(arrayfun(@obscure, TH(:), VV(:), T0(:), TT(:)), size(TH));
[fm, ix] = max(Fg(:));
[i1,i2,i3,i4] = ind2sub(size(Fg), ix);
fprintf('\n② 邻域网格（%d 点）最优：(%.2f°, %.2f, %.2f, %.3f) → %.4f s\n', ...
        numel(Fg), th_g(i1), v_g(i2), t0_g(i3), tau_g(i4), fm);
fprintf('   与冠军差 = %+.5f s（≤0 即冠军确为局部最优）\n', fm - Ta);
n_near = nnz(Fg > Ta - 0.01);
fprintf('   邻域内与冠军相差 0.01 s 以内的点：%d / %d（反映山脊宽度）\n', ...
        n_near, numel(Fg));

%% ③ 读回 result1.xlsx
T = readtable(fullfile(fileparts(mfilename('fullpath')), 'result1.xlsx'));
fprintf('\n③ result1.xlsx 内容：\n');
disp(T);
