#!/usr/bin/env bash
set -Eeuo pipefail

fichier=""
sortie=""
remplacer=0
temp=""

aide() {
    echo "Utilisez bash filtrer_phases_sommeil.sh -f fichier.csv -o sortie.csv [-r] [-h]"
    echo ""
    echo "Garde les colonnes TIMESTAMP, Sleep_Stage, Obstructive_Apnea, Central_Apnea, Hypopnea"
    echo "(et Multiple_Events si elle existe) et les phases W, N1, N2, N3, R."
    echo "Les annotations sont converties en 0/1."
    echo ""
    echo "Options :"
    echo "  -f FICHIER   CSV d'entrée (obligatoire)"
    echo "  -o FICHIER   CSV de sortie (obligatoire)"
    echo "  -r           autorise le remplacement d'un fichier de sortie existant"
    echo "  -h           affiche cette aide"
}

erreur() {
    echo "Erreur : $1" >&2
    exit "${2:-1}"
}

nettoyer() {
    if [ -n "$temp" ] && [ -f "$temp" ]; then
        rm -f "$temp"
    fi
}

# Supprime le fichier temporaire en cas derreur ou d'interruption
trap nettoyer EXIT
trap 'nettoyer; exit 130' INT TERM

while getopts ":f:o:rh" option; do
    case "$option" in
        f) fichier="$OPTARG" ;;
        o) sortie="$OPTARG" ;;
        r) remplacer=1 ;;
        h) aide; exit 0 ;;
        :) erreur "l'option -$OPTARG demande une valeur (voir -h)" ;;
        \?) erreur "option invalide -$OPTARG (voir -h)" ;;
    esac
done

[ -n "$fichier" ] && [ -n "$sortie" ] || erreur "il faut -f et -o (voir -h)"
[ -f "$fichier" ] || erreur "fichier $fichier introuvable"
[ -d "$(dirname "$sortie")" ] || erreur "le dossier de destination $(dirname "$sortie") n'existe pas"
if [ -e "$sortie" ] && [ "$remplacer" -eq 0 ]; then
    erreur "$sortie existe déjà (utilisez -r pour le remplacer)"
fi
if [ "$(realpath -m "$fichier")" = "$(realpath -m "$sortie")" ]; then
    erreur "les fichiers d'entrée et de sortie doivent être différents"
fi


CSV_VERS_TSV='
    NR == 1 { sub("^\357\273\277", "") }
    index($0, "\"") == 0 { gsub(/,/, "\t"); print; next }
    {
        ligne = ""; dedans = 0; n = length($0)
        for (i = 1; i <= n; i++) {
            c = substr($0, i, 1)
            if (c == "\"") {
                if (dedans && substr($0, i + 1, 1) == "\"") { ligne = ligne "\""; i++ }
                else dedans = !dedans
            } else if (c == "," && !dedans) ligne = ligne "\t"
            else ligne = ligne c
        }
        print ligne
    }'


colonnes=$(head -n 1 "$fichier" | tr -d '\r' | awk "$CSV_VERS_TSV" | awk -F'\t' '
    {
        for (i = 1; i <= NF; i++) col[$i] = i
        n = split("TIMESTAMP Sleep_Stage Obstructive_Apnea Central_Apnea Hypopnea", besoin, " ")
        liste = ""
        for (k = 1; k <= n; k++) {
            if (!(besoin[k] in col)) {
                print "Erreur : colonne " besoin[k] " absente de l en-tete" > "/dev/stderr"
                exit 2
            }
            liste = liste (k > 1 ? "," : "") col[besoin[k]]
        }
        if ("Multiple_Events" in col) liste = liste "," col["Multiple_Events"]
        print liste
    }')

#  tr nettoie les \r awk passe en tabulation cut garde les colonnes
# awk garde les bonnes phases et convertit en 0/1
temp="$(dirname "$sortie")/.$(basename "$sortie").$$.part"

tr -d '\r' < "$fichier" | awk "$CSV_VERS_TSV" | cut -f "$colonnes" | awk -F'\t' -v OFS=',' '

    function binaire(v) {
        gsub(/ /, "", v)
        v = tolower(v)
        if (v == "" || v == "0" || v == "0.0" || v == "nan" || v == "null" || v == "none" || v == "false") return 0
        return 1
    }

    NR == 1 {
        for (i = 1; i <= NF; i++) col[$i] = i
        multiples = ("Multiple_Events" in col)
        if (multiples)
            print "TIMESTAMP", "Sleep_Stage", "Obstructive_Apnea", "Central_Apnea", "Hypopnea", "Multiple_Events"
        else
            print "TIMESTAMP", "Sleep_Stage", "Obstructive_Apnea", "Central_Apnea", "Hypopnea"
        next
    }

    {
        stade = $col["Sleep_Stage"]
        gsub(/ /, "", stade)
        if (stade != "W" && stade != "N1" && stade != "N2" && stade != "N3" && stade != "R") next
        if (multiples)
            print $col["TIMESTAMP"], stade, binaire($col["Obstructive_Apnea"]),
                  binaire($col["Central_Apnea"]), binaire($col["Hypopnea"]), binaire($col["Multiple_Events"])
        else
            print $col["TIMESTAMP"], stade, binaire($col["Obstructive_Apnea"]),
                  binaire($col["Central_Apnea"]), binaire($col["Hypopnea"])
    }
' > "$temp"

mv -f "$temp" "$sortie"
temp=""

echo "Fichier filtré : $sortie ($(($(wc -l < "$sortie") - 1)) lignes)"
