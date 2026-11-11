# SPS Project — Sleep Apnea Analysis

## 1. Présentation

Ce projet, réalisé dans le cadre du module **Systèmes, Programmation et Scripts (SPS)**, vise à analyser la fréquence des événements respiratoires (apnées et hypopnées) selon les phases du sommeil, notamment REM (sommeil paradoxal) et NREM (sommeil non paradoxal).

L'objectif est de répondre à la question suivante :

**La fréquence des événements respiratoires varie-t-elle entre les phases REM et NREM ?**

Le projet repose sur des scripts Bash pour le traitement et l'automatisation des tâches, ainsi que sur Python pour l'analyse des données et la visualisation des résultats.

## 2. Jeu de données

- **Nom :** DREAMT (PhysioNet)
- **Source :** [DREAMT — Hugging Face](https://huggingface.co/datasets/bsaenz/dreamt/tree/main/data_64Hz)
- **Sujets sélectionnés :** S002 à S008 (7 sujets)
- **Volume total :** 986 Mo
- **Format :** CSV
- **Date de téléchargement :** 23 octobre 2026

La provenance des données et les mécanismes de vérification de leur intégrité sont détaillés dans [SOURCES.md](SOURCES.md).

## 3. Organisation du projet

```text
SPS-Project-Sleep-Apnea/
├── data/
│   ├── raw/                # Données brutes
│   └── checksums/          # Empreintes SHA256
├── scripts/                # Scripts Bash
├── src/                    # Scripts Python
├── tests/                  # Tests automatisés
├── results/                # Résultats numériques
├── figures/                # Graphiques
├── logs/                   # Journaux d'exécution
├── archives/               # Archives datées
├── cron/                   # Configuration de la planification
├── run.sh                  # Script principal
├── requirements.txt        # Dépendances Python
├── SOURCES.md              # Provenance des données
└── README.md               # Documentation du projet
```

Certains répertoires de sortie sont créés lors de l'exécution et peuvent être absents d'un dépôt fraîchement cloné.

## 4. Installation

### Prérequis

- Linux (Ubuntu recommandé)
- Bash et outils système (`curl`, `awk`, `sha256sum`, `tar`, `gzip`)
- Python 3, pip et venv
- cron (pour la planification automatique)

### Configuration

Cloner le dépôt :

```bash
git clone https://github.com/Ayabeg/SPS-Project-Sleep-Apnea.git
cd SPS-Project-Sleep-Apnea
```

Créer l'environnement virtuel et installer les dépendances :

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

## 5. Exécution

### Téléchargement des données

```bash
bash scripts/telecharger_donnees.sh
```

Ce script télécharge les fichiers des sept sujets dans `data/raw/`, vérifie leur intégrité à l'aide de SHA256 et réutilise les fichiers déjà présents lorsqu'ils sont valides.

### Lancement du traitement

```bash
./run.sh -d data/raw -o results
```

Options disponibles :

| Option | Description |
|---|---|
| `-d` | Répertoire des données d'entrée |
| `-o` | Répertoire de sortie |
| `-h` | Affichage de l'aide |

## 6. Résultats

Les sorties du projet sont organisées dans les répertoires suivants :

| Répertoire | Contenu |
|---|---|
| `results/` | Résultats des traitements et analyses |
| `figures/` | Graphiques de comparaison |
| `logs/` | Journaux d'exécution horodatés |
| `archives/` | Archives compressées des résultats |

## 7. Administration et reproductibilité

### Vérification de l'intégrité

Les empreintes SHA256 de référence sont enregistrées dans `data/checksums/SHA256SUMS`.

Pour vérifier les fichiers téléchargés :

```bash
(cd data/raw && sha256sum -c ../checksums/SHA256SUMS)
```

### Permissions

Les fichiers bruts sont placés en lecture seule après leur téléchargement et leur vérification afin de limiter les modifications accidentelles.

### Journalisation

Les messages d'exécution sont enregistrés dans `logs/run.log`.

### Archivage

Le script suivant crée une archive compressée et datée des résultats et des figures disponibles :

```bash
bash scripts/archiver_resultats.sh
```

Les archives sont enregistrées dans `archives/` au format `.tar.gz`.

### Planification

Le fichier `cron/pipeline.cron.example` contient un exemple de planification hebdomadaire, chaque lundi à 08h00.

### Tests

Les tests automatisés sont exécutés avec pytest :

```bash
python -m pytest -v
```

## 8. Limites

Cette analyse est exploratoire et ne constitue pas un outil de diagnostic médical.
