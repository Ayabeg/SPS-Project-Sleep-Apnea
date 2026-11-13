# SPS Project — Sleep Apnea Analysis

## 1. Présentation

Ce projet étudie la fréquence des événements respiratoires (apnées et hypopnées) selon les phases du sommeil REM (sommeil paradoxal) et NREM (sommeil non paradoxal).

**Question de recherche :** La fréquence des événements respiratoires varie-t-elle entre les phases REM et NREM ?

Le projet repose sur un pipeline automatisé utilisant Bash pour l'acquisition, le prétraitement et la gestion des fichiers, ainsi que Python pour l'analyse des données et la visualisation des résultats.

## 2. Jeu de données

- **Nom :** DREAMT, jeu de données d'origine PhysioNet
- **Fichiers utilisés :** [miroir DREAMT sur Hugging Face](https://huggingface.co/datasets/bsaenz/dreamt/tree/main/data_64Hz)
- **Sujets sélectionnés :** S002 à S008 (7 sujets)
- **Volume total :** environ 986 Mo
- **Format :** CSV
- **Date de téléchargement :** 23 octobre 2026

Les données brutes ne sont pas incluses dans GitHub. Une connexion Internet et
environ 1 Go d'espace disque libre sont nécessaires pour les télécharger.

La provenance des données et les contrôles d'intégrité sont détaillés dans [SOURCES.md](SOURCES.md).

## 3. Organisation du projet

```text
SPS-Project-Sleep-Apnea/
├── data/
│   ├── raw/                  # Données CSV brutes
│   └── checksums/            # Empreintes SHA256
├── scripts/                  # Scripts Bash
├── src/                      # Scripts Python
├── tests/                    # Tests automatisés
├── results/                  # Résultats numériques
├── figures/                  # Graphiques
├── logs/                     # Journaux d'exécution
├── archives/                 # Archives compressées datées
├── cron/                     # Exemple de planification
├── .github/workflows/        # Tests automatiques GitHub Actions
├── run.sh                    # Script principal
├── requirements.txt          # Dépendances Python
├── SOURCES.md                # Provenance des données
└── README.md                 # Documentation du projet
```

Les répertoires de sortie peuvent être créés lors de l'exécution et ne sont pas nécessairement présents après le clonage.

## 4. Installation

### Prérequis

- Linux (Ubuntu recommandé)
- Bash et outils système : `curl`, `awk`, `sha256sum`, `tar`, `gzip`
- Python 3.11 à 3.13, pip et venv
- cron (pour la planification automatique)

Le pipeline n'est pas prévu pour une exécution native sous Windows. Windows
peut être utilisé avec WSL ou une machine virtuelle Linux. macOS peut nécessiter
l'installation d'outils GNU, notamment `sha256sum`.

### Configuration

Cloner le dépôt :

```bash
git clone https://github.com/Ayabeg/SPS-Project-Sleep-Apnea.git
cd SPS-Project-Sleep-Apnea
```

Créer et activer l'environnement virtuel, puis installer les dépendances :

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

`run.sh` utilise automatiquement `.venv/bin/python` lorsqu'il existe. Il est
donc recommandé d'activer l'environnement virtuel avant l'exécution.

## 5. Exécution du pipeline

Lancer le pipeline complet :

```bash
./run.sh
```

Le script réalise successivement :

1. Le téléchargement et la vérification SHA256 des fichiers CSV.
2. Le filtrage des données avec les scripts Bash.
3. L'analyse des événements respiratoires avec Python.
4. La génération du graphique comparatif REM/NREM.
5. L'archivage des résultats et des figures.
6. L'enregistrement des opérations dans un journal horodaté.

Le téléchargement peut également être exécuté séparément :

```bash
bash scripts/telecharger_donnees.sh
```

Les options disponibles pour le script principal sont :

| Option | Description |
|---|---|
| `-d` | Répertoire contenant les CSV d'entrée |
| `-o` | Répertoire des résultats |
| `-h` | Affichage de l'aide |

Exemple avec des chemins explicites :

```bash
./run.sh -d data/raw -o results
```

## 6. Résultats

Après exécution, les fichiers produits comprennent :

| Fichier ou répertoire | Contenu |
|---|---|
| `results/S002_results.csv` à `S008_results.csv` | Résultats individuels par sujet |
| `results/S002_summary.json` à `S008_summary.json` | Résumés individuels |
| `results/all_subjects_results.csv` | Tableau récapitulatif des sept sujets |
| `results/filtered/S002.csv` à `results/filtered/S008.csv` | Données filtrées par sujet |
| `figures/figure.png` | Graphique comparatif REM/NREM |
| `logs/run.log` | Journal horodaté des opérations |
| `archives/` | Archives compressées datées au format `.tar.gz` |

## 7. Administration et reproductibilité

### Vérification de l'intégrité

Les empreintes SHA256 de référence sont conservées dans `data/checksums/SHA256SUMS`.

Vérification manuelle :

```bash
(cd data/raw && sha256sum -c ../checksums/SHA256SUMS)
```

### Permissions

Après téléchargement et vérification, les fichiers CSV bruts sont placés en lecture seule afin de limiter les modifications accidentelles.

### Journalisation

Les opérations du pipeline, notamment les étapes exécutées et les erreurs éventuelles, sont enregistrées dans `logs/run.log`.

### Archivage

Le script suivant permet de créer manuellement une archive compressée et datée des résultats et des figures disponibles :

```bash
bash scripts/archiver_resultats.sh
```

L'archivage est également intégré à l'exécution standard du pipeline.

### Planification

Le fichier `cron/pipeline.cron.example` fournit un exemple de tâche cron
exécutant le pipeline chaque lundi à 08h00. Avant de l'installer, remplacez
`/chemin/vers/SPS-Project-Sleep-Apnea` par le chemin absolu réel du dépôt.

Pour installer la planification après modification du chemin :

```bash
crontab cron/pipeline.cron.example
```

Pour vérifier la tâche installée :

```bash
crontab -l
```

**Remarque :** la tâche planifiée s'exécute uniquement lorsque le système Ubuntu est en fonctionnement.

## 8. Tests et validation

Les tests automatisés sont exécutés avec pytest :

```bash
python -m pytest -v
```

Les tests de syntaxe Bash, les tests Python et un test de l'analyse d'un fichier
d'exemple sont exécutés automatiquement par GitHub Actions sur Ubuntu avec
Python 3.11, 3.12 et 3.13. Le pipeline complet nécessite le téléchargement des
sept fichiers DREAMT et doit être validé séparément sur une machine disposant
de suffisamment d'espace disque.

Une validation manuelle a également été effectuée dans un environnement Linux
avec Python 3.14 : les 7 fichiers ont été téléchargés et vérifiés, les 9 tests
ont réussi, le pipeline complet a terminé sans erreur et la figure ainsi que
l'archive des résultats ont été générées.

## 9. Limites

Les résultats sont descriptifs et dépendent des annotations disponibles dans le dataset. Ils ne permettent pas, à eux seuls, de conclure à une différence statistiquement significative ni d'établir un diagnostic médical. Ce projet est destiné à l'enseignement et à la recherche, pas à un usage clinique.
