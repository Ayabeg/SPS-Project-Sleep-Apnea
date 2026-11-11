# SPS Project — Sleep Apnea Analysis

## 1. Présentation

Ce projet étudie les événements d'apnée du sommeil selon les phases REM et NREM. Il repose sur un pipeline automatisé utilisant Bash et Python.

Question de recherche : La fréquence des événements respiratoires (apnées et hypopnées) varie-t-elle selon les
phases du sommeil, notamment entre le sommeil paradoxal (REM) et le sommeil non
paradoxal (NREM) ?

## 2. Jeu de données

Nom : DREAMT (PhysioNet)

Lien : https://huggingface.co/datasets/bsaenz/dreamt/tree/main/data_64Hz

Taille : Sujets S002, S003, S004, S005, S006, S007, S008,taille totale mesurée : 986MO

Date du téléchargement : 23 Octobre 2026

## 3. Organisation du projet

data/ : données brutes

scripts/ : scripts de traitement

results/ : résultats numériques

figures/ : graphiques

logs/ : journaux d'exécution

archives/ : archives datées

tests/ : tests automatiques

run.sh : script principal

requirements.txt : dépendances Python

SOURCES.md : provenance des données

## 4. Installation

### Prérequis

Le projet nécessite un environnement Linux (Ubuntu recommandé) avec :

- Bash
- Python 3
- pip et venv
- curl
- awk
- sha256sum
- tar et gzip
- cron pour la planification

### Installation du projet

```bash
git clone https://github.com/Ayabeg/SPS-Project-Sleep-Apnea.git
cd SPS-Project-Sleep-Apnea
```

Créer et activer un environnement virtuel :

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Installer les dépendances Python :

```bash
python -m pip install -r requirements.txt
```

Les bibliothèques principales sont `pandas`, `matplotlib` et `pytest`.

## 5. Exécution

### Télécharger les données

```bash
bash scripts/telecharger_donnees.sh
```

Le script télécharge les sujets S002 à S008, vérifie leurs empreintes SHA256 et évite de télécharger à nouveau les fichiers déjà présents et intacts.

### Afficher l'aide du pipeline

```bash
./run.sh -h
```

Le script principal propose les options :

- `-d` : dossier contenant les CSV d'entrée
- `-o` : dossier des résultats
- `-h` : affichage de l'aide

### Lancer le traitement Shell

```bash
./run.sh -d data/raw -o results
```

## 6. Résultats produits

Le projet prévoit les répertoires suivants :

- `results/` : résultats des traitements et analyses
- `figures/` : visualisations
- `logs/` : journaux d'exécution
- `archives/` : archives compressées datées

## 7. Vérification et archivage

### Vérification SHA256

```bash
cd data/raw
sha256sum -c ../checksums/SHA256SUMS
cd ../..
```

### Permissions

Les fichiers bruts sont placés en lecture seule après leur acquisition et leur vérification.

Pour rendre les scripts exécutables :

```bash
chmod +x run.sh scripts/*.sh
```

### Archivage

Le script `scripts/archiver_resultats.sh` permet de créer une archive compressée datée contenant les résultats et, si le dossier existe, les figures.

```bash
bash scripts/archiver_resultats.sh
```

Pour afficher les archives :

```bash
ls -lh archives/
```

Pour consulter le contenu d'une archive :

```bash
tar -tzf archives/NOM_ARCHIVE.tar.gz
```

### Journalisation

Le script principal écrit ses messages horodatés dans :

`logs/run.log`

Pour consulter les dernières lignes :

```bash
tail -n 30 logs/run.log
```

### Planification avec cron

Un exemple de configuration se trouve dans :

`cron/pipeline.cron.example`

Il prévoit une exécution chaque lundi à 08h00.

### Tests Python

Les tests automatiques peuvent être lancés avec :

```bash
python -m pytest -v
```
