
#!/usr/bin/env bash
set -Eeuo pipefail

# Se placer à la racine du projet
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"

RAW="data/raw"
OUT="results"
LOGS="logs"
TMP=$(mktemp -d)

if [[ -x ".venv/bin/python" ]]; then
    PYTHON=".venv/bin/python"
else
    PYTHON="${PYTHON_BIN:-python3}"
fi

usage() {
    echo "Usage: $0 [-d dossier_csv] [-o dossier_resultats] [-h]"
}

log() {
    mkdir -p "$LOGS"
    echo "$(date '+%F %T') $*" | tee -a "$LOGS/run.log"
}

die() {
    log "ERREUR : $*"
    exit 1
}

cleanup() {
    rm -rf "$TMP"
}

on_interrupt() {
    log "Interruption du pipeline"
    exit 130
}

trap cleanup EXIT
trap on_interrupt INT TERM
trap 'die "Echec ligne $LINENO : $BASH_COMMAND"' ERR

while getopts ":d:o:h" opt; do
    case "$opt" in
        d) RAW="$OPTARG" ;;
        o) OUT="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

# Normalize paths so equivalent spellings such as ./data/raw and an absolute
# data/raw path behave identically.
RAW="$(realpath -m "$RAW")"
OUT="$(realpath -m "$OUT")"
LOGS="$(realpath -m "$LOGS")"
DEFAULT_RAW="$PROJECT_DIR/data/raw"

mkdir -p "$OUT" "$LOGS" figures

log "===== DEBUT DU PIPELINE ====="

# 1. Téléchargement et vérification SHA256
if [[ "$RAW" == "$DEFAULT_RAW" ]]; then
    log "Téléchargement et vérification des données"
    bash scripts/telecharger_donnees.sh \
        -o "$RAW" \
        -c "$PROJECT_DIR/data/checksums/SHA256SUMS"
else
    log "Dossier personnalisé : téléchargement ignoré"
fi

# 2. Recherche des fichiers CSV
shopt -s nullglob
files=("$RAW"/S*_whole_df.csv)

[[ ${#files[@]} -gt 0 ]] ||
    die "Aucun fichier CSV trouvé dans $RAW"

# 3. Filtrage Shell
log "Début du filtrage Shell"
mkdir -p "$OUT/filtered"

for csv in "${files[@]}"; do
    id=$(basename "$csv" _whole_df.csv)
    log "Filtrage de $id"

    bash scripts/filtrer_phases_sommeil.sh \
        -f "$csv" \
        -o "$TMP/$id.csv"

    mv "$TMP/$id.csv" "$OUT/filtered/$id.csv"
done

log "Filtrage terminé"

# 4. Analyse Python des fichiers filtrés
log "Début de l'analyse Python"

subjects=()
for csv in "${files[@]}"; do
    id=$(basename "$csv" _whole_df.csv)
    subjects+=("$id")
done

"$PYTHON" src/analyse.py \
    --input-dir "$OUT/filtered" \
    --subjects "${subjects[@]}" \
    --file-suffix ".csv" \
    --output-dir "$OUT"

log "Analyse Python terminée"

# 5. Génération de la figure
log "Génération du graphique"

if [[ "$OUT" == "$PROJECT_DIR/results" ]]; then
    FIGURE="$PROJECT_DIR/figures/figure.png"
else
    FIGURE="$OUT/figure.png"
fi
"$PYTHON" src/figure.py "$OUT/all_subjects_results.csv" "$FIGURE"

log "Graphique généré"

# 6. Archivage
if [[ "$OUT" == "$PROJECT_DIR/results" ]]; then
    log "Archivage des résultats"
    bash scripts/archiver_resultats.sh
    log "Archivage terminé"
else
    log "Archivage ignoré : dossier de sortie personnalisé"
fi

log "===== PIPELINE TERMINE AVEC SUCCES ====="

