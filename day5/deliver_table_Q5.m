%% deliver_table_Q5.m —— 第 5 题交付：只写 result3.xlsx（不画图，防批处理挂起）
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];

hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)','干扰的导弹编号'};
rows = cell(0, 12);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    th_p = routes(p,1)*pi/180;  u_p = [-cos(th_p), sin(th_p), 0];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    ivp = ivs5t(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    for j = 1:3
        if j <= size(bombs{p},1)
            drop = S_all(p,:) + routes(p,2)*bombs{p}(j,1)*u_p;
            det  = drop + routes(p,2)*bombs{p}(j,2)*u_p + [0, 0, -4.9*bombs{p}(j,2)^2];
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, routes(p,2), j, ...
                drop(1), drop(2), drop(3), det(1), det(2), det(3), ...
                union_length(ivp{j}), sprintf('M%d', m)}; %#ok<AGROW>
        else
            rows(end+1, :) = {sprintf('FY%d', p), dir_official, routes(p,2), j, ...
                '', '', '', '', '', '', '', sprintf('M%d', m)}; %#ok<AGROW>
        end
    end
end
writecell([hdr; rows], fullfile(here, 'result3.xlsx'), 'Sheet', 1);
writecell({'注：以x轴为正向，逆时针方向为正，取值0~360（度）。'}, ...
          fullfile(here, 'result3.xlsx'), 'Sheet', 1, 'Range', 'A17');
sum_hdr = {'导弹','分配飞机','并集遮蔽时长(s)'};
sum_rows = cell(3, 3);
for m = 1:3
    sum_rows(m, :) = {sprintf('M%d', m), sprintf('FY%s', mat2str(assign{m})), G_each(m)};
end
sum_rows(end+1, :) = {'合计', '', total};
writecell([sum_hdr; sum_rows], fullfile(here, 'result3.xlsx'), 'Sheet', 2);
fprintf('table saved: result3.xlsx\n');
fprintf('obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f, Total=%.3f\n', G_each, total);

function ivs = ivs5t(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end
