%% dump_plan_Q5.m —— 转储 Q5_plan.mat 全部策略内容（纯文本，不画图）
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];

fprintf('assign: M1<-FY%s, M2<-FY%s, M3<-FY%s\n', ...
        mat2str(assign{1}), mat2str(assign{2}), mat2str(assign{3}));
fprintf('G_each = [%.4f, %.4f, %.4f], total = %.4f\n', G_each, total);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    th = routes(p,1);  v = routes(p,2);
    u = [-cos(th*pi/180), sin(th*pi/180), 0];
    dir_off = mod(atan2d(u(2), u(1)), 360);
    fprintf('\nFY%d -> M%d: th_internal=%.4f deg, dir_official=%.4f deg, v=%.4f\n', ...
            p, m, th, dir_off, v);
    for j = 1:size(bombs{p},1)
        t0 = bombs{p}(j,1);  tau = bombs{p}(j,2);
        iv = single_bomb5(S_all(p,:), th, v, t0, tau, m);
        dur = union_length(iv);
        drop = S_all(p,:) + v*t0*u;
        det  = drop + v*tau*u + [0, 0, -4.9*tau^2];
        fprintf('  bomb%d: t0=%.4f, tau=%.4f | drop=(%.1f,%.1f,%.1f) det=(%.1f,%.1f,%.1f) | dur=%.4f | iv: ', ...
                j, t0, tau, drop, det, dur);
        if isempty(iv)
            fprintf('EMPTY');
        else
            for k = 1:size(iv,1)
                fprintf('[%.4f,%.4f] ', iv(k,1), iv(k,2));
            end
        end
        fprintf('\n');
    end
end
