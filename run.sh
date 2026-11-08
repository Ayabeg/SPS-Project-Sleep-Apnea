#!/usr/bin/env bash
# PARTIE SCRIPT : enveloppe du pipeline (options, erreurs, signaux, codes de retour).
# Le traitement des données se fait dans scripts/ : ici on ne fait que les appeler.
set -Eeuo pipefail                     # arrêt à la première erreur

RAW="data" #le dossier où se trouvent les cvs
OUT="results"
LOGS="logs"
TMP=$(mktemp -d)

# --- Fonctions réutilisées ---------------------------------------------------
usage() { echo "Usage: $0 [-d dossier_csv] [-o dossier_resultats] [-h]"; }

log() {
  mkdir -p "$LOGS"
  echo "$(date '+%F %T') $*" | tee -a "$LOGS/run.log"
}

die() {
  log "ERREUR: $*"
  exit 1
}

check_file() { [[ -f "$1" ]] || die "fichier manquant : $1"; }

cleanup() { rm -rf "$TMP"; }

on_interrupt() {
  log "interruption : nettoyage"
  cleanup
  exit 130
}

# --- Erreurs et signaux ------------------------------------------------------
trap 'die "échec ligne $LINENO : $BASH_COMMAND"' ERR   # message clair
trap cleanup EXIT                                      # temporaires supprimés à la fin
trap on_interrupt INT TERM                             # ... et à l'interruption

# --- Options (getopts) -------------------------------------------------------
while getopts "d:o:h" opt; do
  case "$opt" in
    d) RAW=$OPTARG ;;
    o) OUT=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

# --- Préparation -------------------------------------------------------------
check_file "scripts/filtrer_phases_sommeil.sh"
mkdir -p "$OUT"                        # relance possible : rien à nettoyer avant

shopt -s nullglob
files=("$RAW"/S*_whole_df.csv)
[[ ${#files[@]} -gt 0 ]] || die "aucun CSV trouvé dans $RAW"

# --- Appel de la partie Shell, patient par patient ---------------------------
for csv in "${files[@]}"; do
  id=$(basename "$csv" _whole_df.csv)
  log "traitement de $id"
  bash scripts/filtrer_phases_sommeil.sh -f "$csv" -o "$TMP/$id.csv"
  mv "$TMP/$id.csv" "$OUT/$id.csv"     # le résultat n'apparaît que s'il est complet
done

# --- Appel de la partie Python (si elle existe déjà) -------------------------
if [[ -f scripts/analyse.py ]]; then
  log "analyse Python"
  python3 scripts/analyse.py --results "$OUT"
else
  log "analyse.py absent : étape ignorée"
fi

log "terminé"
