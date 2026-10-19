# IEG-Like-3D

Prototype de football en **Godot standard 4.7 stable**, GDScript uniquement : match **11 contre 11, deux mi-temps de cinq minutes**, duels et techniques spéciales. Le terrain d’entraînement et les modèles GLB existants sont conservés.

La [refonte visuelle](docs/VISUAL_UPDATE.md) ajoute un stade habité, de nouveaux joueurs riggés, des modèles détaillés pour Astreion/Thalassa, un HUD compact avec radar et portraits de duel, ainsi qu'un atelier repensé. Les captures de cette page proviennent du moteur.

Ouvrir `project.godot`, attendre l'importation, puis **F5 pour les Parcours**. Sélectionner Brise des Prés puis **Jouer le match** : la rencontre utilise le moteur normal, avec 11 joueurs par équipe et deux mi-temps de cinq minutes. La victoire attribue un rang B/A/S, sauvegarde le meilleur et ouvre les branches suivantes. Les six adversaires sont rejouables ; un second tableau est disponible. Voir [le guide des parcours](docs/ROUTES.md).

**Match libre** lance la rencontre de test sans progression de parcours. Elle conserve le terrain de 60×90 m, les duels, les techniques et l'atelier ; voir [docs/FULL_MATCH.md](docs/FULL_MATCH.md). Le terrain d'entraînement reste accessible par le bouton dédié ou en ouvrant `scenes/training_ground.tscn` puis F6. `scenes/full_match.tscn` reste lançable directement avec F6.

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

`cloud_setup.sh` installe Godot 4.7 depuis la distribution officielle en vérifiant SHA-512, puis importe le projet. `validate.sh` exécute les suites natives, la boucle complète des parcours, les contrôles de scène match et de menus Karma/Résonance, les contrôles d'entraînement, les prévisualisations, les démarrages et les sept diagnostics. Les résultats de la livraison Parcours sont dans [docs/ROUTES.md](docs/ROUTES.md). Pour utiliser une autre installation **4.7 stable** : `GODOT_BIN=/chemin/vers/godot bash tools/validate.sh`.

Résultats, contrats, fichiers concernés et limites : [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Les documents S0/S1 décrivent les livraisons historiques ; il n'est plus nécessaire d'appliquer leur diff d'intégration manuelle sur cette branche.
