#!/usr/bin/env bash
set -euo pipefail

# Détecter automatiquement le chemin du projet
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Vérifier que l'environnement Python existe
if [[ ! -x "$PROJECT_DIR/.venv/bin/python" ]]; then
    echo "ERREUR : environnement .venv introuvable."
    exit 1
fi

# Créer le dossier des journaux
mkdir -p "$PROJECT_DIR/logs"

# Générer la tâche cron avec le chemin détecté
CRON_JOB="0 8 * * 1 cd \"$PROJECT_DIR\" && . .venv/bin/activate && /bin/bash run.sh >> logs/cron.log 2>&1"

# Installer la tâche cron sans supprimer les autres tâches
{
    crontab -l 2>/dev/null | grep -vF '# SPS-SLEEP-APNEA' | grep -vF 'run.sh >> logs/cron.log' || true
    echo "# SPS-SLEEP-APNEA"
    echo "$CRON_JOB"
} | crontab -

echo "Tâche cron installée pour : $PROJECT_DIR"
