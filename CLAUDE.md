# CLAUDE.md — plan-culture

Plan de culture maraîchère de Chants de la Terre. Remplace le fichier FileMaker.
Ce fichier porte les **règles de travail** sur ce dépôt.

## Contexte

- Base : le projet Supabase **partagé** (`oldkmapumqnibdcniecd`) avec le Suivi des
  temps (`public`), le planning (`planning`) et la cantine (`cantine`). Le plan de
  culture vit dans le schéma **`production`**, et le module stock en fait partie.
- Front : pages statiques servies par GitHub Pages depuis ce dépôt. Pas d'étape de
  compilation. `auth.js` porte la session et l'accès à la base, sans bibliothèque
  extérieure.
- Lire ne demande pas de compte ; écrire demande d'être connecté.
- Le « Max rows » du projet est 1000 → paginer, ou passer par une vue agrégée.

## ⚠️ Dépôt PUBLIC

Les journaux de GitHub Actions sont lisibles par tout le monde. **Jamais de donnée
de la base en clair dans un journal.** Le script n'affiche que des noms de fichiers,
des compteurs et des messages d'erreur expurgés.

## Les migrations

Un envoi sur `main` applique les migrations nouvelles de `migrations/`, dans
l'ordre alphabétique de leur nom, qui est leur horodatage.

Chaque migration commence par une ligne d'en-tête :

```sql
-- portee: production     -- appliquée automatiquement
-- portee: validation     -- attend l'approbation de Coco (environnement « validation-coco »)
-- sauvegarde: production.affectation, production.culture   -- facultatif, copie avant application
```

- **`production`** : exécutée sous le rôle `production_proprietaire`, qui ne possède
  que le schéma `production`. Une erreur ne peut atteindre ni le Suivi des temps,
  ni la cantine, ni les comptes. Ce n'est pas une promesse, c'est un droit Postgres —
  le banc d'essai le vérifie en tentant une migration qui vise la paie.
- Passe **automatiquement en validation**, quel que soit l'en-tête : `drop`,
  `truncate`, `delete from`, changement de rôle, méta-commande psql, en-tête absent.
- **`validation`** : exécutée en `postgres`, après copie des tables listées dans
  `production_sauvegardes` (schéma non publié par l'API).
- Chaque migration passe en **une seule transaction** : elle aboutit entièrement ou
  ne laisse rien. C'est la différence avec l'éditeur SQL de Supabase, qui valide
  instruction par instruction et qui nous a coûté quatre allers-retours en octobre.
- Suivi dans `production._migrations`. **Une migration appliquée ne se modifie
  jamais** : on en ajoute une nouvelle.
- `archives/` contient du SQL hors de la suite : jamais appliqué.

## Méthode

- **Tester avant d'envoyer** : `outils/tester.sh` reconstruit la base depuis vide et
  vérifie les garde-fous. Onze contrôles, dont le fait qu'une migration du plan de
  culture ne peut pas écrire dans le Suivi des temps.
- Toute migration finit par un bloc de contrôle qui compte ce qu'elle vient d'écrire
  et lève une exception si le compte est faux.
- Les contrôles doivent rester vrais si la migration est rejouée **en cours de
  campagne** : vérifier que le report est complet, pas que la cible est intacte.
- Chaque table de `production` active la RLS, même quand une politique ouvre tout :
  défense en profondeur.
- Toute page publiée est regardée avant d'être poussée (capture via Playwright),
  en clair, en sombre et à largeur de téléphone.

## Les conventions du métier

- **Numérotation des planches** : vers l'est et vers le nord, comme des coordonnées.
  Planche 1 à l'ouest si les planches sont nord-sud, au sud si elles sont est-ouest.
  Jamais au nord, jamais à l'est.
- **Trois niveaux de vérité** (`production.niveau_verite`) : `declare` (PAC, ±2 m),
  `releve` (orthophoto, ±0,50 m), `cale` (RTK, ±2 cm). On superpose, on n'écrase pas.
- **Emprise** = nb planches × 1,70 m + 0,30 m. C'est une inégalité : le nombre écrit
  sur la feuille fait foi.
- **L'unité du besoin est le mètre linéaire de planche**, pas la planche (90 à 265 m)
  ni le m² (qui cache le passage de roue).
- **Dans le prévisionnel, la localisation n'a pas d'intérêt ; les quantités, si.**
- **Délai de retour : quatre ans pour toutes les familles.** La luzerne est la
  coupure, pas un retour.
- Interface et messages de commit en français.
