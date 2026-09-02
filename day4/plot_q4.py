# -*- coding: utf-8 -*-
"""plot_q4.py —— 读取 Q4_segments.txt，绘制 Q4 三机遮蔽接力图。
MATLAB 批处理图形渲染挂起，改用 Python 出图（数据由 recheck_Q4.m 导出）。
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager

HERE = os.path.dirname(os.path.abspath(__file__))
for name in ['Microsoft YaHei', 'SimHei', 'DengXian']:
    if any(name.lower() in f.name.lower() for f in font_manager.fontManager.ttflist):
        plt.rcParams['font.sans-serif'] = [name]
        break
plt.rcParams['axes.unicode_minus'] = False

hit, total = None, None
bombs = {}    # p -> [(t0, t1), ...]
unions = []

with open(os.path.join(HERE, 'Q4_segments.txt'), encoding='utf-8') as f:
    for line in f:
        parts = line.split()
        if not parts:
            continue
        tag = parts[0]
        if tag == 'HIT':
            hit = float(parts[1])
        elif tag == 'TOTAL':
            total = float(parts[1])
        elif tag == 'BOMB':
            p, t0, t1 = int(parts[1]), float(parts[2]), float(parts[3])
            bombs.setdefault(p, []).append((t0, t1))
        elif tag == 'UNION':
            unions.append((float(parts[1]), float(parts[2])))

plane_colors = {1: 'tab:blue', 2: 'tab:green', 3: 'tab:orange'}
fig, ax = plt.subplots(figsize=(11, 3.6))
for t0, t1 in unions:
    ax.axvspan(t0, t1, ymin=0, ymax=1, color='0.85', zorder=1)
for p, segs in sorted(bombs.items()):
    for i, (t0, t1) in enumerate(segs):
        ax.plot([t0, t1], [1.05 + 0.09 * (p - 1)] * 2, '-',
                color=plane_colors.get(p, 'gray'), linewidth=6)
ax.axvline(hit, color='r', linestyle=':', linewidth=1.2)
ax.text(hit + 0.5, 1.32, f'M1 命中假目标 t={hit:.1f}s', color='r', fontsize=9, va='bottom')
ax.set_yticks([1.05, 1.14, 1.23])
ax.set_yticklabels(['FY1', 'FY2', 'FY3'])
ax.set_ylim(0.95, 1.42)
ax.set_xlim(0, hit + 2)
ax.grid(True, alpha=0.3)
ax.set_xlabel('t (s)')
ax.set_title(f'Q4（云中心 z≥0 不许钻地）：FY1/FY2/FY3 各 1 弹遮 M1，并集总时长 {total:.3f} s（灰底）',
             fontsize=11)
fig.tight_layout()
out = os.path.join(HERE, 'Q4_三机遮蔽接力图.png')
fig.savefig(out, dpi=150)
print('figure saved:', out)
