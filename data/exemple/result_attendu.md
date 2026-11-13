# Fichiers d'exemple

Ces trois petits fichiers servent à vérifier que le programme Python compte juste
avant de le lancer sur les vrais sujets (plus d'un million de lignes chacun).

On connaît déjà la bonne réponse pour chaque fichier.
Si le programme trouve la même réponse, il marche. Sinon, il y a une erreur.

Les trois fichiers ont le même format que les fichiers filtrés (`results/filtered/SXXX.csv`) :

```
TIMESTAMP,Sleep_Stage,Obstructive_Apnea,Central_Apnea,Hypopnea
```

## Règles à respecter dans le calcul

- On compte les **événements**, pas les lignes : un événement commence quand on passe de 0 à 1.
- Un événement est compté dans la **phase où il commence**.
- **REM** = R. **NREM** = N1 + N2 + N3.
- La phase **W** (éveil) ne compte ni en REM ni en NREM.

---

## 1. `exemple_filtre.csv` : le cas normal

**Ce qu'il teste :** que le comptage est juste, avec quelques pièges.

**Résultat attendu :**

| | REM | NREM |
|---|---|---|
| Échantillons | 7 | 16 |
| Événements | 2 | 5 |

Détail des événements : 3 obstructives en N2, 1 centrale en N3, 1 hypopnée en N1,
1 obstructive et 1 hypopnée en R. Il y a aussi 1 obstructive en W, qui n'est pas comptée.

**Les pièges :**

- deux apnées séparées par une seule ligne à 0 : ça fait **2** événements ;
- deux apnées séparées par un réveil (W) : ça fait **2** événements ;
- une apnée qui commence en N2 et continue en R : comptée en **N2** ;
- une apnée qui commence en W et continue en N2 : comptée en **W**, donc exclue.

**Erreur fréquente :** compter les lignes à 1 au lieu des débuts donne 8 en N2 au lieu de 3.

---

## 2. `exemple_sans_evenement.csv` : aucune apnée

**Ce qu'il teste :** que le programme marche quand il n'y a aucun événement.

**Résultat attendu :**

| | REM | NREM |
|---|---|---|
| Échantillons | 2 | 4 |
| Événements | 0 | 0 |
| Fréquence | 0 | 0 |

Le programme doit donner 0, sans erreur.

---

## 3. `exemple_sans_rem.csv` : aucune phase REM

**Ce qu'il teste :** que le programme ne plante pas quand le temps REM vaut 0
(sinon, il diviserait par 0).

**Résultat attendu :**

| | REM | NREM |
|---|---|---|
| Échantillons | 0 | 4 |
| Événements | 0 | 2 |
| Fréquence | non calculable | calculable |

Détail : 1 obstructive en N2 et 1 hypopnée en N3.

Le programme doit afficher « non calculable » (ou une valeur vide), mais **ne doit pas planter**.

---

## Remarque

Les fréquences par heure n'ont pas vraiment de sens sur ces fichiers : quelques lignes
représentent moins d'une seconde (64 lignes = 1 seconde).
Ces fichiers servent à tester le **comptage** des événements et des échantillons.
