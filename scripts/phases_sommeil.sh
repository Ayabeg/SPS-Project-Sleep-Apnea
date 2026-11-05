#!/bin/bash

fichier=""

aide() {
    echo "aide pour l'analyse des phases de sommeil"
    echo "Utilisez bash phases_sommeil.sh -f fichier.csv"
    echo ""
    echo "Compte les échantillons de chaque phase du sommeil (64 par seconde)"
    echo "et affiche la durée en heures, puis le total REM (R) et NREM (N1+N2+N3)."
    echo ""
    echo "Options :"
    echo "  -f FICHIER   CSV à analyser (brut ou filtré)"
    echo "  -h           affiche cette aide"
}

while getopts ":hf:" option; do
    case "$option" in
        h) aide; exit 0 ;;
        f) fichier="$OPTARG" ;;
        :) echo "Erreur : l'option -$OPTARG demande un fichier" >&2; exit 1 ;;
        \?) echo "Erreur : option invalide -$OPTARG (voir -h)" >&2; exit 1 ;;
    esac
done

if [ -z "$fichier" ]; then
    echo "Erreur : aucun fichier CSV fourni " >&2
    exit 1
fi

if [ ! -f "$fichier" ]; then
    echo "Erreur : le fichier $(basename "$fichier") n'existe pas" >&2
    exit 1
fi

col=$(head -n 1 "$fichier" | tr -d '\r' | awk -F',' '{for (i = 1; i <= NF; i++) if ($i == "Sleep_Stage") print i}')

if [ -z "$col" ]; then
    echo "Erreur : colonne Sleep_Stage absente de $(basename "$fichier")" >&2
    exit 1
fi

echo "Phases du sommeil — $(basename "$fichier")"

tr -d '\r' < "$fichier" | awk -F',' -v c="$col" 'NR > 1 {print $c}' | sort | uniq -c |
awk '
    {
        heures = $1 / (64 * 3600)
        printf "  %-8s %10d échantillons  %6.2f h\n", $2, $1, heures
        if ($2 == "R") rem += heures
        if ($2 == "N1" || $2 == "N2" || $2 == "N3") nrem += heures
    }
    END {
        printf "  REM  : %.2f h\n", rem
        printf "  NREM : %.2f h\n", nrem
    }
'
