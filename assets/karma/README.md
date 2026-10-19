# Modèles originaux des Karma

`astreion.glb` et `thalassa.glb` sont des modèles originaux créés pour ce
projet. Ils ne contiennent aucun modèle, texture ou personnage extrait d'un
autre jeu. Les matériaux sont remplacés par la palette éditable du catalogue
au chargement ; il n'y a pas de dépendance à une texture externe.

- **Astreion** : cuirasse à fournaise ouverte, étoile facettée,
  casque éclipse, épaulières en lames superposées, gantelets et doigts,
  marteau météore, trois orbites gravées et panaches effilés.
- **Thalassa** : plastron en verre marin, masque à ailettes, manteau manta
  courbe avec épaisseur et nervures, mains articulées, deux turbines à onze
  pales et nageoires inférieures.

Chaque modèle possède neuf maillages. Les régions fixes sont fusionnées par
matériau pour limiter les appels de dessin ; bras, cœur, orbites, ailes,
turbines et marteau conservent des pivots indépendants. Les poses sont pilotées
par `scripts/presentation/modifier_visual.gd`, sans animation autonome pendant
les pauses et sans influence sur les résultats de la simulation.

Pour reconstruire les GLB avec Blender 4.3 ou ultérieur :

```sh
blender --background --python tools/art/build_spirits.py
```

Blender sert uniquement à produire les assets hors jeu. Le jeu utilise Godot
standard et GDScript ; le rendu est compatible avec le moteur Compatibility.

## Vaélis et Orvann

Deux modèles originaux supplémentaires, sans texture ni extraction externe :

- **Vaélis** : masque blanc de renard avec museau et oreilles sculptés, armure
  indigo gravée d'or, doigts à griffes, bottes et neuf queues épaisses courbes,
  translucides et terminées par des pointes dorées. 16 maillages, 27 660 triangles.
- **Orvann** : cerf de pierre claire, nasal allongé, bois géométriques ramifiés,
  épaulières en tours crénelées, gantelets-bastions, cuivre et gravures de jade.
  9 maillages, 23 672 triangles.

Ces budgets comptent la géométrie GLB détaillée ; Godot génère également ses
niveaux de détail à l'importation. Chaque modèle conserve les pivots `Head`,
`ArmLeft`, `ArmRight`, `LegLeft`, `LegRight`, et `Core`. Vaélis ajoute `Tail0` à
`Tail8` ; Orvann ajoute `AntlerLeft` et `AntlerRight`.

Leurs poses d'invocation, respiration et signature sont déterministes dans
`modifier_visual.gd`. L'issue ne modifie la pose qu'après la révélation des
scores. Les palettes `Primary`, `Trim`, `Light`, `Dark`, `Glass` sont appliquées
au chargement ; le masque blanc de Vaélis conserve sa couleur de matériau.

```sh
blender --background --python tools/art/build_new_spirits.py
```

Cet outil réutilise les primitives de `build_spirits.py` comme bibliothèque,
sans exécuter ses exports ni écraser Astreion ou Thalassa.
