%% deliver_Q5.m —— 第 5 题交付：从 Q5_plan.mat 出图 + result3.xlsx
% 与计算拆开，避免批处理模式退出时堆崩溃丢失交付物。
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));        % assign, routes, bombs, G_each, total
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];

fprintf('loaded plan: obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f, Total=%.3f\n', ...
        G_each, total);

%% ---------- 图：三导弹遮蔽接力图 ----------
figure('Color','w','Position',[120 120 1000 780]);
for m = 1:3
    subplot(3,1,m); hold on;
    group = assign{m};
    U = zeros(0,2);
    ci = 0;
    cols = {'b', [0 0.6 0], [0.8 0.4 0], [0.6 0 0.6]};
    for pi = 1:numel(group)
        p = group(pi);
        ci = ci + 1;
        ivp = bomb_ivs5d(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for j = 1:numel(ivp)
            if ~isempty(ivp{j})
                for k = 1:size(ivp{j},1)
                    plot(ivp{j}(k,1)*[1 1], [0, 1], '-', 'Color', cols{ci}, 'LineWidth', 4);
                end
                U = [U; ivp{j}];
            end
        end
    end
    U = sortrows(U, 1);
    if ~isempty(U)
        cs = U(1,1); ce = U(1,2); segs = zeros(0,2);
        for i = 2:size(U,1)
            if U(i,1) <= ce, ce = max(ce, U(i,2));
            else, segs(end+1,:) = [cs ce]; cs = U(i,1); ce = U(i,2); end
        end
        segs(end+1,:) = [cs ce];
        for i = 1:size(segs,1)
            patch([segs(i,1) segs(i,2) segs(i,2) segs(i,1)], [0 0 1.2 1.2], ...
                  [0.85 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.6);
        end
    end
    xline(t_hit5(m), 'r:', 'LineWidth', 1.2);
    ylabel(sprintf('M%d', m)); ylim([-0.1, 1.3]); yticks([]);
    xlim([0, 70]); grid on;
    title(sprintf('M%d relay (union=%.3f s, planes FY%s)', m, G_each(m), mat2str(group)));
    xlabel('t (s)');
end
saveas(gcf, fullfile(here, 'Q5_三导弹遮蔽接力图.png'));
fprintf('figure saved: Q5_三导弹遮蔽接力图.png\n');

%% ---------- result3.xlsx（官方模板：无人机 × 弹号，共 15 行）----------
hdr = {'无人机编号','无人机运动方向','无人机运动速度(m/s)','烟幕干扰弹编号', ...
       '投放点x(m)','投放点y(m)','投放点z(m)', ...
       '起爆点x(m)','起爆点y(m)','起爆点z(m)','有效干扰时长(s)','干扰的导弹编号'};
rows = cell(0, 12);
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    th_p = routes(p,1)*pi/180;  u_p = [-cos(th_p), sin(th_p), 0];
    dir_official = mod(atan2d(u_p(2), u_p(1)), 360);
    ivp = bomb_ivs5d(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
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
fprintf('table saved: result3.xlsx (Sheet1 official, Sheet2 summary)\n');

%% ---------- 控制台汇总 ----------
fprintf('\n========== Q5 DELIVERY ==========\n');
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = bomb_ivs5d(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    fprintf('FY%d (M%d): th=%.3f deg, v=%.2f m/s, %d bombs:\n', ...
            p, m, routes(p,1), routes(p,2), size(bombs{p},1));
    for j = 1:numel(ivp)
        fprintf('   bomb %d: t0=%.3f, tau=%.3f | ', j, bombs{p}(j,1), bombs{p}(j,2));
        if isempty(ivp{j})
            fprintf('EMPTY');
        else
            for k = 1:size(ivp{j},1)
                fprintf('[%.3f, %.3f] ', ivp{j}(k,1), ivp{j}(k,2));
            end
        end
        fprintf('\n');
    end
end
fprintf('obscure_1=%.3f, obscure_2=%.3f, obscure_3=%.3f\n', G_each);
fprintf('TOTAL = %.3f s\n', total);

%% ---------- 局部函数 ----------
function ivs = bomb_ivs5d(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end
