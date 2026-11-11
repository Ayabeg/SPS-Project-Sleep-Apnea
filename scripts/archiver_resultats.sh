
#!/usr/bin/env bash
set -euo pipefail

# Se placer à la racine du projet
cd "$(dirname "$0")/.."

# Vérifier la présence de résultats
if [[ ! -d results ]] ||
   [[ -z "$(find results -type f -print -quit)" ]]; then
    echo "ERREUR : aucun résultat à archiver" >&2
    exit 1
fi

# Créer le dossier d'archives
mkdir -p archives

# Nom daté
DATE=$(date '+%Y%m%d_%H%M%S')
ARCHIVE="archives/resultats_${DATE}.tar.gz"

# Archiver les résultats
DOSSIERS=(results)

if [[ -d figures ]]; then
    DOSSIERS+=(figures)
fi

tar -czf "$ARCHIVE" "${DOSSIERS[@]}"

# Vérifier que l'archive est lisible
tar -tzf "$ARCHIVE" > /dev/null

echo "Archive créée : $ARCHIVE"
