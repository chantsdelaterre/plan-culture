# Plan de culture — Chants de la Terre

Remplace le fichier FileMaker. Base de données **Supabase** (projet
`oldkmapumqnibdcniecd`, schéma `production`), écrans servis par **GitHub Pages**.

## Ce qu'il y a ici

| Dossier | Contenu |
|---|---|
| `index.html` | L'écran des blocs d'assolement, publié sur GitHub Pages |
| `migrations/` | Toutes les migrations SQL, dans l'ordre de leur nom (horodaté) |
| `asso/` | Les relevés d'assolement manuscrits, transcrits, une année par fichier |
| `geo/` | Les contours relevés au GPS et les scripts qui les traitent |

## Les migrations

Elles s'appliquent dans l'ordre alphabétique de leur nom, qui est leur
horodatage. On les colle dans l'éditeur SQL de Supabase.

Deux règles, apprises à nos dépens :

1. **L'éditeur SQL de Supabase valide instruction par instruction.** Un script
   qui échoue au milieu laisse la base à moitié modifiée. Chaque migration doit
   donc pouvoir être relancée sans rien casser : `create ... if not exists`,
   `insert ... on conflict do update`, `drop ... if exists` avant chaque
   `create` de vue ou de politique.
2. **Chaque migration finit par un bloc de contrôle** qui compte ce qu'elle
   vient d'écrire et lève une exception si le compte est faux. C'est ce qui a
   rattrapé une base restée à 502 lignes de relevé au lieu de 521.

## Les trois niveaux de vérité

Le même objet — un îlot, une parcelle — peut avoir plusieurs contours, et on
les superpose au lieu de les écraser :

| Niveau | Source | Précision |
|---|---|---|
| `declare` | Le parcellaire PAC | ± 2 m |
| `releve` | Tracé à la main sur orthophoto IGN | ± 0,50 m |
| `cale` | Relevé RTK au tracteur | ± 0,02 m |

Le jour où le RTK contredira le PAC, on voudra voir les deux.

## La numérotation des planches

Arrêtée le 20 octobre 2026, et elle ne se discute plus : **on numérote vers
l'est et vers le nord, comme des coordonnées.** La planche 1 est donc à
l'ouest si les planches sont orientées nord-sud, au sud si elles sont
orientées est-ouest. Jamais au nord, jamais à l'est.

## L'unité de besoin

Le **mètre linéaire de planche**. Pas la planche — elles font de 90 à 265 m.
Pas le m² — il cache le passage de roue.

Emprise d'une parcelle = nb planches × 1,70 m + 0,30 m. C'est une inégalité :
en cas de désaccord, **le nombre de planches écrit sur la feuille fait foi**.
