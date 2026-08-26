%% final_check2_Q2.m —— 问题 2 冠军点最终核验（山脊顶确认）
% 爬山在末级步长仍沿浅山脊微升，需确认是否已到脊顶：
%   ① 固定 τ、t0=0，对 (θ, v) 做 2D 细网格扫描，找真实脊顶
%   ② 冠军高分辨率复核（dt=0.001）
%   ③ xlsx 写盘确认
clear; clc;
here = fileparts(mfilename('fullpath'));

champ = [3.0654, 72.185, 0.0, 2.5050];   % 当前冠军

%% ① 2D 细网格扫描 (θ × v)，τ、t0 固定在冠军值
fprintf('① (θ × v) 2D 细网格扫描（τ=%.4f, t0=%.4f 固定）：\n', champ(3), champ(4));
th_g = 2.8:0.002:3.3;          % 比爬山末级步长更细
v_g  = 71.8:0.005:72.6;
[TH, VV] = ndgrid(th_g, v_g);
F2 = arrayfun(@(a,b) obscure(a, b, champ(3), champ(4)), TH, VV);
[fm, ix] = max(F2(:));
[i1,i2] = ind2sub(size(F2), ix);
fprintf('   %d 点最优：θ=%.4f°, v=%.4f → %.5f s\n', numel(F2), th_g(i1), v_g(i2), fm);
fprintf('   与冠军差 = %+.5f s\n', fm - obscure(champ(1), champ(2), champ(3), champ(4)));
% 脊线宽度：与最大值相差 0.001 s 以内的点数（反映平台宽度）
n_plateau = nnz(F2 > fm - 0.001);
fprintf('   脊顶平台（与峰值差 <0.001 s）点数：%d / %d\n', n_plateau, numel(F2));

%% ② 冠军高分辨率复核
fprintf('\n② 冠军高分辨率复核 (dt=0.001)：\n');
[Tc, ic] = obscure(champ(1), champ(2), champ(3), champ(4), 0.001);
fprintf('   %.5f s，窗口 ', Tc);
for k = 1:size(ic.intervals,1)
    fprintf('[%.4f, %.4f] ', ic.intervals(k,1), ic.intervals(k,2));
end
fprintf('\n');

%% ③ xlsx 写盘确认
T = readtable(fullfile(here, 'result1.xlsx'));
fprintf('\n③ result1.xlsx 内容：\n');
disp(T);
