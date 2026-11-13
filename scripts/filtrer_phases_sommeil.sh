#!/bin/bash
# filtrer_phases_sommeil.sh
# Réduit un CSV DREAMT aux 5 colonnes utiles, garde les phases W, N1, N2, N3, R
# (supprime P et Missing) et convertit les annotations en 0/1.
# Les lignes W sont gardées pour ne pas coller deux apnées séparées par un réveil.
# Exemple : bash scripts/filtrer_phases_sommeil.sh -f data/raw/S002_whole_df.csv -o results/filtered/S002.csv

set -o pipefail   # une erreur au milieu d'un tube est détectée

fichier=""
sortie=""
remplacer=0

aide() {
    echo "Utilisez bash filtrer_phases_sommeil.sh -f fichier.csv -o sortie.csv [-r] [-h]"
    echo ""
    echo "Garde les colonnes TIMESTAMP, Sleep_Stage, Obstructive_Apnea, Central_Apnea, Hypopnea"
    echo "et les phases W, N1, N2, N3, R (supprime P, Missing et les lignes sans stade)."
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

# Numéros des 5 colonnes utiles, trouvés par leur nom (ex. "1,10,11,12,13")
colonnes=$(head -n 1 "$fichier" | tr -d '\r' | awk -F',' '
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
        print liste
    }')
code=$?
if [ "$code" -ne 0 ]; then
    exit "$code"
fi

# Filtrage : tr nettoie les \r, cut garde les 5 colonnes, awk filtre les phases
tr -d '\r' < "$fichier" | cut -d',' -f"$colonnes" | awk -F',' -v OFS=',' '

    # Annotation en 0/1 : vide, 0 ou NaN = 0, sinon 1
    function binaire(v) {
        gsub(/"| /, "", v)
        v = tolower(v)
        if (v == "" || v == "0" || v == "0.0" || v == "nan") return 0
        return 1
    }

    NR == 1 {
        for (i = 1; i <= NF; i++) col[$i] = i
        print "TIMESTAMP", "Sleep_Stage", "Obstructive_Apnea", "Central_Apnea", "Hypopnea"
        next
    }

    {
        stade = $col["Sleep_Stage"]
        if (stade == "W" || stade == "N1" || stade == "N2" || stade == "N3" || stade == "R")
            print $col["TIMESTAMP"], stade,
                  binaire($col["Obstructive_Apnea"]),
                  binaire($col["Central_Apnea"]),
                  binaire($col["Hypopnea"])
    }
' > "$sortie"

# En cas d'échec, on supprime le fichier incomplet
code=$?
if [ "$code" -ne 0 ]; then
    rm -f "$sortie"
    exit "$code"
fi

echo "Fichier filtré : $sortie ($(($(wc -l < "$sortie") - 1)) lignes)"
