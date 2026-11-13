#!/usr/bin/env bash
# filtrer_phases_sommeil.sh
# Réduit un CSV DREAMT aux colonnes utiles, garde les phases W, N1, N2, N3, R
# (supprime P et Missing) et convertit les annotations en 0/1.
# Les lignes W sont gardées pour ne pas coller deux apnées séparées par un réveil.
# Exemple : bash scripts/filtrer_phases_sommeil.sh -f data/raw/S002_whole_df.csv -o results/filtered/S002.csv

set -Eeuo pipefail

fichier=""
sortie=""
remplacer=0

aide() {
    echo "Utilisez bash filtrer_phases_sommeil.sh -f fichier.csv -o sortie.csv [-r] [-h]"
    echo ""
    echo "Garde les colonnes TIMESTAMP, Sleep_Stage, Obstructive_Apnea, Central_Apnea, Hypopnea"
    echo "et les phases W, N1, N2, N3, R (supprime P, Missing et les lignes sans stade)."
    echo "Conserve Multiple_Events lorsqu'elle existe dans le fichier source."
    echo "Les annotations sont converties en 0/1."
    echo ""
    echo "Options :"
    echo "  -f FICHIER   CSV d'entrée (obligatoire)"
    echo "  -o FICHIER   CSV de sortie (obligatoire)"
    echo "  -r           autorise le remplacement d'un fichier de sortie existant"
    echo "  -h           affiche cette aide"
}

# Lecture des options
while getopts ":f:o:rh" option; do
    case "$option" in
        f) fichier="$OPTARG" ;;
        o) sortie="$OPTARG" ;;
        r) remplacer=1 ;;
        h) aide; exit 0 ;;
        :) echo "Erreur : l'option -$OPTARG demande une valeur (voir -h)" >&2; exit 1 ;;
        \?) echo "Erreur : option invalide -$OPTARG (voir -h)" >&2; exit 1 ;;
    esac
done

# Vérifications
if [ -z "$fichier" ] || [ -z "$sortie" ]; then
    echo "Erreur : il faut -f et -o (voir -h)" >&2
    exit 1
fi

if [ ! -f "$fichier" ]; then
    echo "Erreur : fichier $fichier introuvable" >&2
    exit 1
fi

if [ -e "$sortie" ] && [ "$remplacer" -eq 0 ]; then
    echo "Erreur : $sortie existe déjà (utilisez -r pour le remplacer)" >&2
    exit 1
fi

if [ ! -d "$(dirname "$sortie")" ]; then
    echo "Erreur : le dossier de destination $(dirname "$sortie") n'existe pas" >&2
    exit 1
fi

# Use Python's standard-library CSV parser instead of cut/awk.  DREAMT is a
# CSV dataset, so quoted fields must be handled correctly.  The output is
# written atomically and preserves Multiple_Events when it exists in the raw
# file, allowing the filtered file to be the canonical analysis input.
PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "$PYTHON_BIN" >/dev/null || {
    echo "Erreur : interpréteur Python introuvable : $PYTHON_BIN" >&2
    exit 1
}

fichier_abs="$fichier"
sortie_abs="$sortie"

if "$PYTHON_BIN" - "$fichier_abs" "$sortie_abs" "$remplacer" <<'PY'
import csv
import os
import sys
import tempfile
from pathlib import Path

source = Path(sys.argv[1]).resolve()
destination = Path(sys.argv[2]).resolve()
if source == destination:
    raise SystemExit("Erreur : les fichiers d'entrée et de sortie doivent être différents")

required = (
    "TIMESTAMP",
    "Sleep_Stage",
    "Obstructive_Apnea",
    "Central_Apnea",
    "Hypopnea",
)
optional = "Multiple_Events"
allowed_stages = {"W", "N1", "N2", "N3", "R"}
false_values = {"", "0", "0.0", "nan", "null", "none", "false"}

def binary(value: object) -> str:
    normalized = "" if value is None else str(value).strip().lower()
    return "0" if normalized in false_values else "1"

destination.parent.mkdir(parents=False, exist_ok=True)
with source.open("r", newline="", encoding="utf-8-sig") as source_handle:
    reader = csv.DictReader(source_handle, strict=True)
    fieldnames = reader.fieldnames or []
    missing = [name for name in required if name not in fieldnames]
    if missing:
        raise SystemExit(f"Erreur : colonne(s) absente(s) de l'en-tête : {', '.join(missing)}")

    output_fields = list(required)
    if optional in fieldnames:
        output_fields.append(optional)

    temp_name = None
    rows_written = 0
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            newline="",
            encoding="utf-8",
            dir=destination.parent,
            prefix=f".{destination.name}.",
            suffix=".part",
            delete=False,
        ) as temporary:
            temp_name = temporary.name
            writer = csv.DictWriter(temporary, fieldnames=output_fields, lineterminator="\n")
            writer.writeheader()
            for row in reader:
                stage = (row.get("Sleep_Stage") or "").strip()
                if stage not in allowed_stages:
                    continue
                output = {
                    "TIMESTAMP": row.get("TIMESTAMP", ""),
                    "Sleep_Stage": stage,
                    "Obstructive_Apnea": binary(row.get("Obstructive_Apnea")),
                    "Central_Apnea": binary(row.get("Central_Apnea")),
                    "Hypopnea": binary(row.get("Hypopnea")),
                }
                if optional in output_fields:
                    output[optional] = binary(row.get(optional))
                writer.writerow(output)
                rows_written += 1
        os.replace(temp_name, destination)
    except Exception:
        if temp_name:
            Path(temp_name).unlink(missing_ok=True)
        raise

print(f"Fichier filtré : {destination} ({rows_written} lignes)")
PY
then
    exit 0
fi

exit 1
