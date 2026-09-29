"""Figure 2: forest plot of the phase odds ratio (primary model and key sensitivity analyses).

Session 6 (2026-09-29, peer review): the former panel (a), bad-window counts per household,
was dropped (counts fell in most households anyway; the bad-window share per household is
reported in the text and Figure 3 shows the time pattern). Neutral ink replaces the green/orange
that mean great/bad windows in Figure 1; filled markers = profile likelihood (primary), open =
Wald; the household-bootstrap interval is a thin whisker on the primary row.

Inputs: the verified aggregate CSVs in outputs/results/2026-09-24. All values are read, never typed.
Colours and font come from analysis/figure_style.json (shared by all figures); PDF text
is typeset by LaTeX with acmart's libertine package, as in figure_system.py.
Run from the project root: python3 analysis/figure_results.py
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib import font_manager

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "outputs/results/2026-09-24"
EVENTS = ROOT / "data/derived/2026-09-24_analysis/primary_events.csv"
STYLE = json.loads((ROOT / "analysis/figure_style.json").read_text())
for path in STYLE["font_files"].values():
    font_manager.fontManager.addfont(path)
plt.rcParams.update({"font.family": "sans-serif", "font.sans-serif": [STYLE["font_family"]],
                     "font.size": STYLE["base_size_pt"], "text.color": STYLE["neutral"]["ink"],
                     "axes.edgecolor": STYLE["neutral"]["frame"], "axes.linewidth": 0.6,
                     "xtick.color": STYLE["neutral"]["ink"], "ytick.color": STYLE["neutral"]["ink"],
                     "pgf.texsystem": "pdflatex", "pgf.rcfonts": False,
                     "pgf.preamble": "\\usepackage[T1]{fontenc}\\usepackage{libertine}\\renewcommand{\\familydefault}{\\sfdefault}"})
INK = STYLE["neutral"]["ink"]
GRID = STYLE["neutral"]["grid"]
FRAME = STYLE["neutral"]["frame"]


def forest_rows() -> pd.DataFrame:
    sm = pd.read_csv(RES / "sensitivity_matrix.csv").set_index("analysis")
    ph = pd.read_csv(RES / "posthoc_phase_checks.csv")

    def s(label):
        r = sm.loc[label]
        return float(r.OR), float(r.lower), float(r.upper)

    def p(fragment):
        r = ph[ph.check.str.contains(fragment, regex=False)]
        assert len(r) == 1
        r = r.iloc[0]
        return float(r.OR), float(r.lower), float(r.upper)

    rows = [
        ("Primary model", s("Primary"), "primary"),
        ("Calendar-adjusted", s("Weekday and linear calendar-day adjustment"), "calendar"),
        ("Overlap dates only", s("Calendar-overlap dates only, adjusted"), "calendar"),
        ("Great vs. rest", s("Great versus ok/bad"), "other"),
        ("Ok/great vs. bad", s("Great/ok versus bad"), "other"),
        ("Immediate only", s("Immediate registrations only"), "other"),
        ("Excl. phone charging", s("High-load appliances only"), "other"),
        ("Waits as bad uses", p("waits"), "other"),
        ("Incl. overwritten", p("Including households with rewritten records"), "other"),
    ]
    assert sm.loc["Primary"].interval == "Profile likelihood 95%"
    assert all(sm.loc[l].interval == "Wald 95%" for l in ["Weekday and linear calendar-day adjustment", "Calendar-overlap dates only, adjusted",
                                                          "Great versus ok/bad", "Great/ok versus bad", "Immediate registrations only", "High-load appliances only"])
    assert (ph[ph.check.str.contains("waits") | ph.check.str.contains("rewritten records")].interval == "Wald 95%").all()
    return pd.DataFrame([(lbl, *v, g) for lbl, v, g in rows], columns=["label", "OR", "lower", "upper", "group"])


def main() -> None:
    forest = forest_rows()
    boot = pd.read_csv(RES / "sensitivity_matrix.csv").set_index("analysis").loc["Household-bootstrap interval"]
    forest.to_csv(RES / "figure_results_forest.csv", index=False)

    fig = plt.figure(figsize=(3.33, 1.55))
    ax = fig.add_axes([0.3, 0.2, 0.66, 0.77])
    n = len(forest)
    # A small gap separates the primary row and the calendar rows from the other checks.
    y, pos = [], n + 0.8
    for g in forest.group:
        pos -= 1 + (0.4 if g != "primary" and (not y or g != prev) else 0)
        y.append(pos); prev = g
    for yi, (_, r) in zip(y, forest.iterrows()):
        primary = r.group == "primary"
        ax.plot([r.lower, r.upper], [yi, yi], color=INK, lw=1.0, solid_capstyle="butt", zorder=2)
        ax.plot(r.OR, yi, marker="o", ms=3.0, mfc=INK if primary else "white", mec=INK, mew=0.8, zorder=3)
        if primary:
            ax.plot([float(boot.lower), float(boot.upper)], [yi - 0.28, yi - 0.28], color=INK, lw=0.5, zorder=2)
    ax.axvline(1, color=FRAME, lw=0.6, ls=(0, (3, 2)), zorder=1)
    ax.set_xscale("log")
    lo, hi = min(forest.lower.min(), float(boot.lower)), max(forest.upper.max(), float(boot.upper))
    assert lo > 0.45 and hi < 4.6, (lo, hi)  # keep every interval inside the axis
    ax.set_xlim(0.45, 4.6)
    ax.set_xticks([0.5, 1, 2, 4])
    ax.set_xticklabels(["0.5", "1", "2", "4"])
    ax.minorticks_off()
    ax.set_yticks(y)
    ax.set_yticklabels(forest.label, fontsize=6)
    ax.set_ylim(min(y) - 0.7, max(y) + 0.6)
    ax.tick_params(axis="x", labelsize=6, length=2, pad=1.5)
    ax.tick_params(axis="y", length=0, pad=2)
    ax.grid(axis="x", color=GRID, lw=0.4)
    ax.set_axisbelow(True)
    for sp in ("top", "right", "left"):
        ax.spines[sp].set_visible(False)
    ax.set_xlabel("Phase odds ratio (log scale)", fontsize=6.5, labelpad=1.5)

    fig.savefig(RES / "figure_results.pdf", backend="pgf")
    fig.savefig(RES / "figure_results.png", dpi=300)
    print("Wrote", RES / "figure_results.pdf")


if __name__ == "__main__":
    main()
