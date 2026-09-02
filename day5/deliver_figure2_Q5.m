%% deliver_figure2_Q5.m —— 第 5 题接力图（软件 OpenGL 渲染，防批处理挂起）
% 与 deliver_figure_Q5 相同，但用 print -painters 渲染并提前关闭硬件加速。
clear; clc;
try, opengl software; catch, end        % 强制软件渲染（若可用）
set(0, 'DefaultFigureVisible', 'off');
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];

fig = figure('Visible','off', 'Renderer','painters', 'Position',[120 120 1000 780]);
for m = 1:3
    subplot(3,1,m); hold on;
    group = assign{m};
    U = zeros(0,2);
    ci = 0;
    cols = {'b', [0 0.6 0], [0.8 0.4 0], [0.6 0 0.6]};
    for pi = 1:numel(group)
        p = group(pi);
        ci = ci + 1;
        ivp = ivs5g(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
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
print(fig, fullfile(here, 'Q5_三导弹遮蔽接力图.png'), '-dpng', '-r150');
close(fig);
fprintf('figure saved: Q5_三导弹遮蔽接力图.png\n');

function ivs = ivs5g(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end
