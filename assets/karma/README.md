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
