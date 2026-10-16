# IEG-Like-3D

Prototype de football en **Godot standard 4.7 stable**, GDScript uniquement : match **11 contre 11, deux mi-temps de cinq minutes**, duels et techniques spéciales. Le terrain d’entraînement et les modèles GLB existants sont conservés.

La [refonte visuelle](docs/VISUAL_UPDATE.md) ajoute un stade habité, de nouveaux joueurs riggés, des modèles détaillés pour Astreion/Thalassa, un HUD compact avec radar et portraits de duel, ainsi qu'un atelier repensé. Les captures de cette page proviennent du moteur.

Ouvrir `project.godot`, attendre l'importation, puis **F5 pour le match complet de test** : 11 contre 11, terrain 60×90 m, deux mi-temps réglables, duels à temps arrêté, huit techniques ordinaires, deux signatures de Karma et atelier d'édition. Voir [docs/FULL_MATCH.md](docs/FULL_MATCH.md) pour les règles, les scènes et les résultats de validation. Le terrain d'entraînement reste accessible par le menu ou en ouvrant `scenes/training_ground.tscn` puis F6.

**V / L3** ouvre les actions du match : techniques de tir, tactiques, Karma et Résonances. **Astreion et Thalassa** possèdent leurs PG, PE et techniques exclusives ; **Orbite souveraine et Vigie des profondeurs** transmettent deux techniques, des statistiques et éventuellement le Karma du donneur. Les deux familles sont cumulables, avec au maximum **3 Karma et 3 Résonances par équipe**. Le bouton **Atelier** ouvre l'éditeur sans perdre le match. Voir [le guide Karma/Résonance](docs/KARMA_RESONANCE.md) pour les propriétaires, les ressources et les champs d'édition. À la mi-temps, choisir la disposition de chaque équipe puis reprendre. `scenes/duel_preview.tscn` permet de revoir les dix animations et les variantes gardien.
 La scène `scenes/diagnostic.tscn` (F6) reproduit sept situations ; F2, pavé directionnel gauche ou le bouton affiché change de scénario.

| Action | Manette Xbox / PlayStation | Clavier-souris |
| --- | --- | --- |
| Déplacement | Stick gauche | WASD physiques (ZQSD sur AZERTY), flèches |
| Passe ciblée au sol | A / Croix | Espace |
| Passe lobée | Y / Triangle | G physique |
| Choisir un allié, puis revenir à la visée directionnelle | RB / R1 | Q physique (A sur AZERTY) |
| Tir chargé, au relâchement | X / Carré | F physique ou clic gauche |
| Tacle | B / Rond | E physique |
| Changer d'allié contrôlé | LB / L1 | Tab |
| Sprint | RT / R2 | Maj |
| Caméra | Stick droit | Clic droit maintenu et souris |
| Zoom | Pavé haut/bas | Molette |
| Recentrer | R3 | C physique |
| Replacer | View / Share | R physique |
| Pause | Start / Options | Échap |

La cible de passe est marquée en turquoise. Une cible explicite prime sur la direction. Une passe sélectionne son destinataire pour permettre son déplacement ; cela ne lui donne pas la possession. Tout gain réel de possession bleue, dont tacle, interception ou capture du gardien, sélectionne immédiatement le porteur. Une déviation laisse le ballon libre. Les rouges ne sont jamais sélectionnés. Les alliés IA proposent des déplacements et des tacles ; la simulation leur interdit les passes et tirs.

Le gardien bleu sélectionné après une capture se relance avec passe/lob et les mêmes commandes de ciblage. Le gardien rouge propose automatiquement une relance. Les arrêts dépendent du premier contact balayé, de la hauteur et de la vitesse : la session décide, les vues affichent le résultat.

Dans le cloud Linux :

```bash
cd /workspace/IEG-Like-3D
bash tools/cloud_setup.sh
bash tools/validate.sh
```

`cloud_setup.sh` installe Godot 4.7 depuis la distribution officielle en vérifiant SHA-512, puis importe le projet. `validate.sh` exécute les 385 tests natifs, les 32 vérifications de scène match, les 22 contrôles de menus Karma/Résonance, les 12 contrôles entraînement, les 81 contrôles de prévisualisation, les démarrages et les sept diagnostics. Pour utiliser une autre installation **4.7 stable** : `GODOT_BIN=/chemin/vers/godot bash tools/validate.sh`.

Résultats, contrats, fichiers concernés et limites : [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Les documents S0/S1 décrivent les livraisons historiques ; il n'est plus nécessaire d'appliquer leur diff d'intégration manuelle sur cette branche.
