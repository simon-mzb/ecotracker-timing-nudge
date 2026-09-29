"""Figure 3 (session 6, 2026-09-29): when uses were registered.

(a) Registered uses by local hour, baseline week versus nudge week, immediate and
    retrospective entries stacked; the fixed window schedule is drawn below the axis.
(b) Bad- and great-window shares by study day (top) and registrations per day (bottom);
    two panels with separate y-axes, no dual axis.

Inputs: the identifier-free tables written by analysis/05c_registration_patterns.R
(registrations_by_local_hour.csv, registrations_by_study_day.csv). All values are read,
never typed; totals are asserted against table_registered_windows / registration_patterns.
Colours and font come from analysis/figure_style.json; PDF text is typeset by LaTeX with
acmart's libertine package, as in figure_results.py.
Run from the project root after 05c: python3 analysis/figure_patterns.py
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib import font_manager
from matplotlib.patches import Patch, Rectangle

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "outputs/results/2026-09-24"
STYLE = json.loads((ROOT / "analysis/figure_style.json").read_text())
for path in STYLE["font_files"].values():
    font_manager.fontManager.addfont(path)
plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": [STYLE["font_family"]],
                     "font.size": STYLE["base_size_pt"], "text.color": STYLE["neutral"]["ink"],
                     "axes.edgecolor": STYLE["neutral"]["frame"], "axes.linewidth": 0.6,
                     "xtick.color": STYLE["neutral"]["ink"], "ytick.color": STYLE["neutral"]["ink"],
                     "hatch.linewidth": 0.5,
                     "pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": "\\usepackage[T1]{fontenc}\\usepackage{libertine}\\renewcommand{\\familydefault}{\\sfdefault}"})
WIN = STYLE["window_colors"]
INK = STYLE["neutral"]["ink"]
GRID = STYLE["neutral"]["grid"]
FRAME = STYLE["neutral"]["frame"]
# Phases in neutral ink so that colour keeps meaning "window" as in Figure 1.
PHASE_INK = {"baseline": "#A6A6A6", "nudge": "#3A3A3A"}
NUDGE_SHADE = STYLE["phase_colors"]["nudge"]


def window_of(h: int) -> str:
    return "great" if 10 <= h < 17 else ("ok" if 8 <= h < 10 or 17 <= h < 19 else "bad")


def style_axis(ax):
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    ax.tick_params(labelsize=6, length=2, pad=1.5)
    ax.grid(axis="y", color=GRID, lw=0.4)
    ax.set_axisbelow(True)


def main() -> None:
    hour = pd.read_csv(RES / "registrations_by_local_hour.csv")
    day = pd.read_csv(RES / "registrations_by_study_day.csv")
    rp = pd.read_csv(RES / "registration_patterns.csv").set_index("measure").value
    assert hour.events.sum() == 802 and day.events.sum() == 802
    late = hour[hour.local_hour.between(21, 23)].groupby("phase").events.sum()
    assert late.baseline == int(rp["late_21_23_baseline"]) and late.nudge == int(rp["late_21_23_nudge"])

    fig = plt.figure(figsize=(7.0, 1.75))

    # (a) by local hour: two bars per hour (baseline left, nudge right), retrospective hatched on top.
    ax = fig.add_axes([0.05, 0.25, 0.54, 0.62])
    w = 0.4
    top = 0
    for k, ph in enumerate(("baseline", "nudge")):
        x = np.arange(24) + (k - 0.5) * w
        h = hour[hour.phase == ph].groupby(["local_hour", "source"]).events.sum().unstack(fill_value=0).reindex(range(24), fill_value=0)
        imm, ret = h.get("immediate", 0), h.get("retrospective", 0)
        ax.bar(x, imm, width=w * 0.92, color=PHASE_INK[ph], lw=0)
        ax.bar(x, ret, bottom=imm, width=w * 0.92, color="white", edgecolor=PHASE_INK[ph], hatch="//////", lw=0.4)
        top = max(top, (imm + ret).max())
    ax.set_xlim(-0.6, 23.6)
    ax.set_ylim(0, top * 1.12)
    ax.set_xticks(range(0, 24, 2))
    ax.set_xticklabels([f"{h}" for h in range(0, 24, 2)])
    ax.set_ylabel("Registered uses", fontsize=6.5, labelpad=1.5)
    style_axis(ax)
    ax.tick_params(axis="x", pad=6.5)
    # Window schedule strip directly below the axis (as in Figure 1).
    for h in range(24):
        ax.add_patch(Rectangle((h - 0.5, -0.075 * top * 1.12), 1, 0.05 * top * 1.12, color=WIN[window_of(h)],
                               lw=0, clip_on=False, transform=ax.transData))
    ax.set_xlabel("Local hour of registered use", fontsize=6.5, labelpad=1.5)
    ax.legend(handles=[Patch(color=PHASE_INK["baseline"], label="Baseline week"),
                       Patch(color=PHASE_INK["nudge"], label="Nudge week"),
                       Patch(facecolor="white", edgecolor=INK, hatch="//////", lw=0.4, label="Retrospective entries")],
              loc="upper left", fontsize=5.8, frameon=False, handlelength=1.4, handleheight=0.8, borderaxespad=0.2)
    fig.text(0.005, 0.97, "(a) Registered uses by local hour", fontsize=6.8, ha="left", va="top")

    # (b) by study day: shares (top) and counts (bottom).
    d = day.groupby(["study_day", "window"]).events.sum().unstack(fill_value=0).reindex(range(1, 15), fill_value=0)
    n = d.sum(axis=1)
    assert (n > 0).all()
    x = d.index.values
    axs = fig.add_axes([0.675, 0.53, 0.285, 0.34])
    axc = fig.add_axes([0.675, 0.25, 0.285, 0.2], sharex=axs)
    for a in (axs, axc):
        a.axvspan(7.5, 14.5, color=NUDGE_SHADE, lw=0, zorder=0)
        style_axis(a)
    for win, ls, mk in (("bad", "-", "s"), ("great", "-", "o")):
        axs.plot(x, 100 * d[win] / n, color=WIN[win], lw=1.1, ls=ls, marker=mk, ms=2.4, zorder=3)
        axs.text(14.6, 100 * d[win].iloc[-1] / n.iloc[-1], win, color=INK, fontsize=5.8, va="center", ha="left")
    axs.set_ylim(0, 80)
    axs.set_yticks([0, 30, 60])
    axs.set_ylabel("Share (%)", fontsize=6.5, labelpad=1.5)
    axs.tick_params(labelbottom=False)
    axs.text(4, 79, "Baseline", fontsize=5.8, ha="center", va="top", color=INK)
    axs.text(11, 79, "Nudge", fontsize=5.8, ha="center", va="top", color=INK)
    axc.bar(x, n, width=0.7, color=PHASE_INK["baseline"], lw=0, zorder=3)
    axc.set_ylim(0, n.max() * 1.15)
    axc.set_yticks([0, 50])
    axc.set_ylabel("Uses", fontsize=6.5, labelpad=1.5)
    axc.set_xlim(0.4, 14.6)
    axc.set_xticks([1, 3, 5, 7, 9, 11, 13])
    axc.set_xlabel("Study day", fontsize=6.5, labelpad=1.5)
    fig.text(0.625, 0.97, "(b) Window shares and registrations by study day", fontsize=6.8, ha="left", va="top")

    fig.savefig(RES / "figure_patterns.pdf", backend="pgf")
    fig.savefig(RES / "figure_patterns.png", dpi=300)
    print("Wrote", RES / "figure_patterns.pdf")


if __name__ == "__main__":
    main()
