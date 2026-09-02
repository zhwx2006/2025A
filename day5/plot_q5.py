# -*- coding: utf-8 -*-
"""plot_q5.py —— 读取 Q5_segments.txt，绘制三导弹遮蔽接力图。
MATLAB 批处理模式图形渲染挂起，改用 Python 出图（数据由 dump_segments_Q5.m 导出）。
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager

HERE = os.path.dirname(os.path.abspath(__file__))

# 中文字体（Windows 常见候选）
for name in ['Microsoft YaHei', 'SimHei', 'DengXian']:
    if any(name.lower() in f.name.lower() for f in font_manager.fontManager.ttflist):
        plt.rcParams['font.sans-serif'] = [name]
        break
plt.rcParams['axes.unicode_minus'] = False

hits, geach, total = {}, None, None
planes = {}
bombs = {}     # m -> [(p, t0, t1), ...]
unions = {}    # m -> [(t0, t1), ...]

with open(os.path.join(HERE, 'Q5_segments.txt'), encoding='utf-8') as f:
    for line in f:
        parts = line.split()
        if not parts:
            continue
        tag = parts[0]
        if tag == 'HIT':
            hits[int(parts[1])] = float(parts[2])
        elif tag == 'GEACH':
            geach = [float(x) for x in parts[1:4]]
        elif tag == 'TOTAL':
            total = float(parts[1])
        elif tag == 'PLANES':
            m = int(parts[1])
            s = parts[2].strip('[]')
            planes[m] = [int(x) for x in s.split()]
        elif tag == 'BOMB':
            m, p, t0, t1 = int(parts[1]), int(parts[2]), float(parts[3]), float(parts[4])
            bombs.setdefault(m, []).append((p, t0, t1))
        elif tag == 'UNION':
            m, t0, t1 = int(parts[1]), float(parts[2]), float(parts[3])
            unions.setdefault(m, []).append((t0, t1))

# 每架飞机的颜色
plane_colors = {1: 'tab:blue', 2: 'tab:green', 3: 'tab:orange', 4: 'purple', 5: 'teal'}

fig, axes = plt.subplots(3, 1, figsize=(10, 7.8), sharex=True)
for i, m in enumerate([1, 2, 3]):
    ax = axes[i]
    # 并集灰底
    for t0, t1 in unions.get(m, []):
        ax.axvspan(t0, t1, ymin=0, ymax=1, color='0.85', zorder=1)
    # 各机弹区间（按飞机着色，纵向错开便于分辨）
    seen_planes = planes.get(m, [])
    for p, t0, t1 in bombs.get(m, []):
        lvl = seen_planes.index(p) if p in seen_planes else 0
        ax.plot([t0, t1], [1.02 + 0.08 * lvl] * 2, '-',
                color=plane_colors.get(p, 'gray'), linewidth=5,
                label=f'FY{p}' if (m, p) not in getattr(ax, '_labeled', set()) else None)
        getattr(ax, '_labeled', None)
    # 手动管理图例去重
    handles, labels = ax.get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    ax.legend(by_label.values(), by_label.keys(), loc='upper right', fontsize=8, ncol=4)
    ax.axvline(hits[m], color='r', linestyle=':', linewidth=1.2, label=None)
    ax.text(hits[m] + 0.4, 1.18, f'M{m} 命中假目标 t={hits[m]:.1f}s',
            color='r', fontsize=8, va='bottom')
    ax.set_ylabel(f'M{m}')
    ax.set_ylim(0.95, 1.35)
    ax.set_yticks([])
    ax.set_xlim(0, 70)
    ax.grid(True, alpha=0.3)
    ax.set_title(f'M{m} 遮蔽接力：并集 {geach[m-1]:.3f} s，参与机 FY{planes.get(m, [])}'.replace('[', '').replace(']', '').replace(', ', '/'),
                 fontsize=10)

axes[-1].set_xlabel('t (s)')
fig.suptitle(f'第 5 题：五机多弹干扰三枚导弹，总遮蔽时长 {total:.3f} s', fontsize=12)
fig.tight_layout(rect=[0, 0, 1, 0.96])
out = os.path.join(HERE, 'Q5_三导弹遮蔽接力图.png')
fig.savefig(out, dpi=150)
print('figure saved:', out)
