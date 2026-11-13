import os
import tempfile
import argparse
from pathlib import Path

# Keep Matplotlib's cache out of the user's home directory.  This also makes
# the pipeline work in read-only or sandboxed environments.
if not os.environ.get("MPLCONFIGDIR"):
    matplotlib_cache = Path(tempfile.gettempdir()) / "sps-project-sleep-apnea-matplotlib"
    matplotlib_cache.mkdir(parents=True, exist_ok=True)
    os.environ["MPLCONFIGDIR"] = str(matplotlib_cache)

import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

COLONNES = {"subject", "rem_events_per_hour", "nrem_events_per_hour"}


def charger(chemin_csv):
    df = pd.read_csv(chemin_csv)
    manque = COLONNES - set(df.columns)
    if manque:
        raise ValueError(f"Colonnes manquantes : {sorted(manque)}")
    return df


def tracer(df, sortie="figures/figure.png"):
    Path(sortie).parent.mkdir(parents=True, exist_ok=True)
    x = list(range(len(df)))
    largeur = 0.4
    plt.figure(figsize=(8, 5))
    plt.bar([i - largeur / 2 for i in x], df["nrem_events_per_hour"],
            largeur, label="NREM", color="steelblue")
    plt.bar([i + largeur / 2 for i in x], df["rem_events_per_hour"],
            largeur, label="REM", color="tomato")
    plt.xticks(x, df["subject"])
    plt.xlabel("Sujet")
    plt.ylabel("Événements respiratoires par heure")
    plt.title("Événements respiratoires : REM vs NREM")
    plt.legend()
    plt.savefig(sortie, dpi=150, bbox_inches="tight")
    plt.close()
    return sortie


def main(chemin_csv, sortie="figures/figure.png"):
    df = charger(chemin_csv)
    print("Figure enregistrée :", tracer(df, sortie))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate the REM/NREM comparison chart.")
    parser.add_argument("input_csv", help="Combined analysis CSV")
    parser.add_argument(
        "output_png",
        nargs="?",
        default="figures/figure.png",
        help="Output PNG path (default: figures/figure.png)",
    )
    args = parser.parse_args()
    main(args.input_csv, args.output_png)
