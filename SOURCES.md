# Sources des données

## Dataset principal

- **Nom :** DREAMT (Hugging Face)
- **Identifiant du jeu sur Hugging Face :** `bsaenz/dreamt` (dossier `data_64Hz`)
- **Version :** 2.1.0
- **Source originale :** PhysioNet
- **Miroir utilisé pour le téléchargement :** https://huggingface.co/datasets/bsaenz/dreamt/tree/main/data_64Hz
- **Révision du miroir utilisée par le pipeline :** `ab79e53dd135c69da9e70de33503150c3d4cdc57`
- **Date de téléchargement :** 23 octobre 2026
- **Sujets sélectionnés :** S002 à S008 (7 sujets)
- **Taille totale :** 986 Mo
- **Format :** CSV

Le dépôt utilise le miroir Hugging Face pour automatiser le téléchargement,
tandis que DREAMT est documenté comme le jeu de données d'origine PhysioNet.
Le dataset est distribué sous la licence PhysioNet Restricted Health Data
License 1.5.0. Les utilisateurs doivent disposer des autorisations nécessaires
et ne doivent pas redistribuer les fichiers bruts.

## Description

Le jeu de données DREAMT contient des enregistrements liés au sommeil.

Dans ce projet, sept sujets sont sélectionnés afin d'étudier les événements respiratoires, notamment les apnées obstructives, les apnées centrales et les hypopnées, selon les phases REM et NREM.

## Acquisition des données

Le téléchargement est assuré par `scripts/telecharger_donnees.sh`.

Pour récupérer ou vérifier les sept sujets :

```bash
bash scripts/telecharger_donnees.sh
```

Pour sélectionner un sujet ( par exemple le sujet n°2 ) :

```bash
bash scripts/telecharger_donnees.sh -s S002
```

Les fichiers bruts sont enregistrés dans `data/raw/`.

## Intégrité des fichiers

L'algorithme SHA-256 permet de contrôler l'intégrité des fichiers.

Les empreintes des sept fichiers sont enregistrées dans :

`data/checksums/SHA256SUMS`

Vérification manuelle :

```bash
cd data/raw
sha256sum -c ../checksums/SHA256SUMS
cd ../..
```

Une ligne `OK` signifie que le fichier correspond à l'empreinte enregistrée.

## Protection des données

Après téléchargement et vérification, le script applique des permissions de lecture seule aux fichiers bruts avec `chmod 444`.

Cette mesure réduit les risques de modification accidentelle des données originales.

## Reproductibilité

Les fichiers CSV bruts ne sont pas inclus dans le dépôt GitHub. Ils peuvent être récupérés à partir de leur source grâce au script de téléchargement.
