"""Figure 1: the EcoTracker app at a glance.

Crops smartphone screenshots of the deployed app (demo account; English UI) and
adds a schematic of the fixed daily window schedule and the two-phase design.
Schedule and phase switch are taken from the app source:
project_info/sus_ai-main/src/lib/schedule.ts and phase.ts.
Crop boxes are in original pixels (945 x 2048 screenshots) and remove the
admin debug bar and the demo account's study-day counter.
Colours and font come from analysis/figure_style.json (shared by all figures).
Run from the project root: python3 analysis/figure_system.py
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Rectangle
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "study_screenshots"
OUT = ROOT / "outputs/results/2026-09-24"
STYLE = json.loads((ROOT / "analysis/figure_style.json").read_text())
for path in STYLE["font_files"].values():
    font_manager.fontManager.addfont(path)
# PDF text is typeset by LaTeX with acmart's own font package (libertine):
# \sffamily = Linux Biolinum, embedded exactly as in the paper. PNG preview uses the OTF.
plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": [STYLE["font_family"]],
                     "font.size": STYLE["base_size_pt"], "text.color": STYLE["neutral"]["ink"],
                     "pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": "\\usepackage[T1]{fontenc}\\usepackage{libertine}\\renewcommand{\\familydefault}{\\sfdefault}"})
WIN = STYLE["window_colors"]

# (file, crop box left, top, right, bottom, panel label)
PANELS = [
    ("study_LogScreen_day1.jpeg", (0, 170, 945, 1400), "(a) Baseline:\nlog a use"),
    ("studyAdmin_greatWindow.jpeg", (0, 300, 945, 1530), "(b) Nudge phase:\ngreat window"),
    ("studyAdmin_okWindow.jpeg", (0, 300, 945, 1530), "(c) Nudge phase:\nok window"),
    ("study_time_window_warning.jpeg", (0, 330, 945, 1560), "(d) Bad window:\nuse anyway or wait"),
    ("study_negative_greenscore.jpeg", (0, 300, 945, 1530), "(e) Score feedback\nafter “use anyway”"),
]

# Fixed daily schedule from schedule.ts: [start, end) in local hours.
SCHEDULE = [(0, 8, "bad"), (8, 10, "ok"), (10, 17, "great"), (17, 19, "ok"), (19, 24, "bad")]


def strip(ax) -> None:
    ax.set_yticks([])
    for s in ax.spines.values():
        s.set_visible(False)


def main() -> None:
    fig = plt.figure(figsize=(7.0, 2.9))
    n = len(PANELS)
    gap = 0.012
    width = (1 - gap * (n + 1)) / n
    for i, (name, box, label) in enumerate(PANELS):
        img = Image.open(SHOTS / name).convert("RGB").crop(box)
        ax = fig.add_axes([gap + i * (width + gap), 0.27, width, 0.60])
        ax.imshow(img)
        ax.set_xticks([]); ax.set_yticks([])
        for s in ax.spines.values():
            s.set_edgecolor(STYLE["neutral"]["frame"]); s.set_linewidth(0.6)
        ax.set_title(label, fontsize=7, pad=2.5, linespacing=1.05)

    # Daily window schedule.
    ax = fig.add_axes([0.04, 0.085, 0.44, 0.075])
    for start, end, w in SCHEDULE:
        ax.add_patch(Rectangle((start, 0), end - start, 1, color=WIN[w], lw=0))
        ax.text((start + end) / 2, 0.5, w, ha="center", va="center", fontsize=6.5,
                color=STYLE["window_text"][w])
    ax.set_xlim(0, 24); ax.set_ylim(0, 1)
    ax.set_xticks([0, 8, 10, 17, 19, 24]); ax.tick_params(labelsize=6, length=2, pad=1)
    ax.set_xlabel("Local hour: fixed daily windows (not live grid data)", fontsize=6.5, labelpad=1)
    strip(ax)

    # Two-phase design per household.
    ax = fig.add_axes([0.54, 0.085, 0.42, 0.075])
    ax.add_patch(Rectangle((0, 0), 7, 1, color=STYLE["phase_colors"]["baseline"], lw=0))
    ax.add_patch(Rectangle((7, 0), 7, 1, color=STYLE["phase_colors"]["nudge"], lw=0))
    ax.text(3.5, 0.5, "Baseline: logging only", ha="center", va="center", fontsize=6.5)
    ax.text(10.5, 0.5, "Nudge: windows, dialog, score", ha="center", va="center", fontsize=6.5)
    ax.set_xlim(0, 14); ax.set_ylim(0, 1)
    ax.set_xticks([0, 7, 14]); ax.set_xticklabels(["day 0", "7", "14"]); ax.tick_params(labelsize=6, length=2, pad=1)
    ax.set_xlabel("Days since each household's first login", fontsize=6.5, labelpad=1)
    strip(ax)

    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / "figure_system.pdf", backend="pgf", dpi=450)
    fig.savefig(OUT / "figure_system.png", dpi=250)
    print("Wrote", OUT / "figure_system.pdf")


if __name__ == "__main__":
    main()
