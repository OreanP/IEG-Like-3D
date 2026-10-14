# IEG-Like-3D

Première base d'entraînement football en **Godot standard 4.7 stable**, GDScript uniquement. La scène existante conserve le terrain et les modèles GLB ; elle assemble trois joueurs de champ bleus, deux rouges et un gardien par camp. Ce n'est pas le jeu complet ni un match à onze.

Ouvrir `project.godot`, attendre l'importation, puis F5. La scène `scenes/diagnostic.tscn` (F6) reproduit sept situations ; F2, pavé directionnel gauche ou le bouton affiché change de scénario.

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

`cloud_setup.sh` installe Godot 4.7 depuis la distribution officielle en vérifiant SHA-512, puis importe le projet. `validate.sh` exécute les 87 tests natifs, les 12 vérifications scène/entrées, un démarrage et les sept diagnostics. Pour utiliser une autre installation **4.7 stable** : `GODOT_BIN=/chemin/vers/godot bash tools/validate.sh`.

Résultats, contrats, fichiers concernés et limites : [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Les documents S0/S1 décrivent les livraisons historiques ; il n'est plus nécessaire d'appliquer leur diff d'intégration manuelle sur cette branche.
