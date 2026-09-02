%% dump_segments_Q5.m —— 导出接力图所需区间数据（纯文本，不画图）
% 输出 Q5_segments.txt，供 Python 绘图读取。
% 格式：
%   HIT  <m> <t_hit>          导弹命中时刻（红虚线）
%   GEACH <g1> <g2> <g3>      各导弹并集时长
%   TOTAL <total>
%   PLANES <m> <p1> <p2> ...  该导弹分配的飞机
%   BOMB <m> <p> <t0> <t1>    单弹遮蔽区间
%   UNION <m> <t0> <t1>       该导弹并集段（灰底）
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'day3'));

load(fullfile(here, 'Q5_plan.mat'));
S_all = [17800, 0, 1800;
         12000, 1400, 1400;
         6000, -3000, 700;
         11000, 2000, 1800;
         13000, -2000, 1300];

fid = fopen(fullfile(here, 'Q5_segments.txt'), 'w');
for m = 1:3
    fprintf(fid, 'HIT %d %.6f\n', m, t_hit5(m));
end
fprintf(fid, 'GEACH %.6f %.6f %.6f\n', G_each);
fprintf(fid, 'TOTAL %.6f\n', total);
for m = 1:3
    fprintf(fid, 'PLANES %d %s\n', m, mat2str(assign{m}));
end
for p = 1:5
    m = find(cellfun(@(g) any(g==p), assign), 1);
    ivp = ivs5d2(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
    for j = 1:numel(ivp)
        if ~isempty(ivp{j})
            for k = 1:size(ivp{j},1)
                fprintf(fid, 'BOMB %d %d %.6f %.6f\n', m, p, ivp{j}(k,1), ivp{j}(k,2));
            end
        end
    end
end
for m = 1:3
    group = assign{m};
    U = zeros(0,2);
    for pi = 1:numel(group)
        p = group(pi);
        ivp = ivs5d2(m, S_all(p,:), routes(p,1), routes(p,2), bombs{p});
        for j = 1:numel(ivp)
            if ~isempty(ivp{j}), U = [U; ivp{j}]; end
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
            fprintf(fid, 'UNION %d %.6f %.6f\n', m, segs(i,1), segs(i,2));
        end
    end
end
fclose(fid);
fprintf('segments saved: Q5_segments.txt\n');

function ivs = ivs5d2(m, S, th, v, bombs)
    ivs = cell(size(bombs,1), 1);
    for j = 1:size(bombs,1)
        ivs{j} = single_bomb5(S, th, v, bombs(j,1), bombs(j,2), m);
    end
end
