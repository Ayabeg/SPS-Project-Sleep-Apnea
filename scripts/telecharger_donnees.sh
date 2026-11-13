#!/usr/bin/env bash
# telecharger_donnees.sh
# Télécharge les fichiers DREAMT (64 Hz) et vérifie leur intégrité (SHA-256).
# Un fichier déjà présent et intact n'est pas retéléchargé : on peut relancer sans nettoyer.
# Exemple : bash scripts/telecharger_donnees.sh -s S002 -s S003

set -Eeuo pipefail

# Pin the upstream dataset revision so a mutable branch cannot silently change
# the source behind the recorded checksums.
DATASET_REVISION="ab79e53dd135c69da9e70de33503150c3d4cdc57"
URL_BASE="https://huggingface.co/datasets/bsaenz/dreamt/resolve/$DATASET_REVISION/data_64Hz"
DOSSIER="data/raw"
SOMMES="data/checksums/SHA256SUMS"
SUJETS=()
TEMP=""

aide() {
    echo "Utilisez bash telecharger_donnees.sh [-o dossier] [-c fichier_sommes] [-s sujet]... [-u url] [-h]"
    echo ""
    echo "Télécharge les fichiers DREAMT 64 Hz et vérifie leur intégrité (SHA-256)."
    echo "Les fichiers déjà présents et intacts ne sont pas retéléchargés."
    echo ""
    echo "Options :"
    echo "  -o DOSSIER   dossier des fichiers bruts            (défaut : $DOSSIER)"
    echo "  -c FICHIER   fichier des sommes de contrôle        (défaut : $SOMMES)"
    echo "  -s SUJET     sujet à télécharger, ex. S002 (répétable ; défaut : S002 à S008)"
    echo "  -u URL       adresse du dossier en ligne           (défaut : Hugging Face)"
    echo "  -h           affiche cette aide"
}

erreur() {
    echo "Erreur : $1" >&2
    exit "${2:-1}"
}

# Supprime le fichier en cours de téléchargement
nettoyer() {
    if [ -n "$TEMP" ] && [ -f "$TEMP" ]; then
        rm -f "$TEMP"
    fi
}

# Renvoie 0 si le fichier correspond à sa somme de référence
verifier() {
    local nom="$1"
    local ligne
    ligne="$(awk -v fichier="$nom" '$2 == fichier { print; exit }' "$SOMMES_ABS")" || return 1
    [ -n "$ligne" ] || return 1
    printf '%s\n' "$ligne" |
        ( cd "$DOSSIER" && sha256sum -c --quiet - ) >/dev/null 2>&1
}

telecharger_sujet() {
    local sujet="$1"
    local nom="${sujet}_whole_df.csv"
    local cible="$DOSSIER/$nom"

    if ! awk -v fichier="$nom" '$2 == fichier { found = 1; exit } END { exit !found }' "$SOMMES"; then
        erreur "pas de somme de contrôle pour $nom dans $SOMMES"
    fi

    if [ -f "$cible" ] && verifier "$nom"; then
        chmod 444 "$cible"
        echo "-> $sujet : déjà présent et intact"
        return 0
    fi

    if [ -f "$cible" ]; then
        echo "-> $sujet : fichier abîmé, nouveau téléchargement"
        rm -f "$cible"
    fi

    # Téléchargement dans un fichier .part, renommé seulement s'il est complet
    echo "-> $sujet : téléchargement de $URL_BASE/$nom"
    TEMP="$cible.part"
    if ! curl -fL --proto '=https' --proto-redir '=https' \
        --retry 3 --progress-bar -o "$TEMP" "$URL_BASE/$nom"; then
        nettoyer
        erreur "échec du téléchargement de $nom (connexion ou adresse ?)" 3
    fi
    mv "$TEMP" "$cible"
    TEMP=""

    if ! verifier "$nom"; then
        rm -f "$cible"
        erreur "somme de contrôle incorrecte pour $nom : fichier supprimé" 4
    fi

    chmod 444 "$cible"   # données brutes en lecture seule
    echo "   $nom téléchargé et vérifié"
}

# Pas de fichier à moitié téléchargé en cas d'interruption
trap nettoyer EXIT
trap 'echo "Interruption : téléchargement annulé" >&2; nettoyer; exit 130' INT TERM

while getopts ":o:c:s:u:h" option; do
    case "$option" in
        o) DOSSIER="$OPTARG" ;;
        c) SOMMES="$OPTARG" ;;
        s) SUJETS+=("$OPTARG") ;;
        u) URL_BASE="$OPTARG" ;;
        h) aide; exit 0 ;;
        :) erreur "l'option -$OPTARG demande une valeur (voir -h)" ;;
        \?) erreur "option invalide -$OPTARG (voir -h)" ;;
    esac
done

if [ "${#SUJETS[@]}" -eq 0 ]; then
    SUJETS=(S002 S003 S004 S005 S006 S007 S008)
fi

case "$URL_BASE" in
    https://*) ;;
    *) erreur "l'URL doit utiliser HTTPS" ;;
esac

for s in "${SUJETS[@]}"; do
    [[ "$s" =~ ^S[0-9]{3}$ ]] || erreur "sujet invalide : $s (format attendu : S###)"
done

command -v curl >/dev/null      || erreur "la commande curl n'est pas installée"
command -v sha256sum >/dev/null || erreur "la commande sha256sum n'est pas installée"
[ -f "$SOMMES" ] || erreur "fichier de sommes de contrôle introuvable : $SOMMES"

mkdir -p "$DOSSIER" || erreur "impossible de créer le dossier $DOSSIER"
SOMMES_ABS="$(cd "$(dirname "$SOMMES")" && pwd)/$(basename "$SOMMES")"

for s in "${SUJETS[@]}"; do
    telecharger_sujet "$s"
done

echo "Terminé : ${#SUJETS[@]} fichier(s) présent(s) et vérifié(s) dans $DOSSIER"
