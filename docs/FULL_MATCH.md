# Prototype de match complet — 15 octobre 2026

Cette scène permet de jouer un match du coup d'envoi au résultat final. Elle reste un prototype : la demande est implémentée avec des règles originales et des animations procédurales sur les modèles existants, pas avec les ressources ni les formules commerciales d'Inazuma Eleven.

## Lancer et jouer

Godot **standard 4.7 stable**, GDScript uniquement. Ouvrir `project.godot` et F5 lance désormais `scenes/full_match.tscn`. Le terrain d'entraînement reste disponible par le menu ou en lançant `scenes/training_ground.tscn` avec F6.

La scène construit un terrain de **60 × 90 m**, deux équipes de **11 joueurs**, deux buts de 7,32 × 2,44 m, les tribunes et les marquages. Les profils du match sont indépendants de ceux de l'entraînement ; les GLB existants sont conservés. Les camps sont inversés en seconde période, y compris les buts, le placement des gardiens, les déviations et l'attribution des scores.

Deux mi-temps de **300 secondes de jeu** par défaut. Modifier `half_seconds` sur la racine de la scène pour une autre durée. Le chrono s'arrête pendant les choix, les cinématiques, les menus, les remises en place et la mi-temps. Il repart avec le jeu live. À la fin, l'écran affiche le score et l'équipe gagnante, ou le match nul ; il propose de rejouer.

| Action | Manette | Clavier / souris |
| --- | --- | --- |
| Bouger / sprint | Stick gauche / RT | WASD physiques (ZQSD AZERTY), flèches / Maj |
| Passe / lob | A / Y | Espace / G physique |
| Tir chargé puis relâché | X | F physique ou clic gauche |
| Intervention | B | E physique |
| Cible / joueur | RB / LB | Q physique / Tab |
| Caméra | Stick droit | Clic droit maintenu et souris |
| Menu techniques / tactiques / augmentations | L3 | V physique, boutons du HUD |
| Pause | Start | Échap |
| Choix de duel | Croix directionnelle, A pour valider | Flèches / Tab, Entrée, ou clic |

Le tir normal porte à 24 m ; Tir Magnus ajoute 18 m. Préparer la technique depuis le menu TIR permet d'afficher la zone de longue portée ; choisir ensuite la technique spéciale dans le duel pour l'utiliser. Un choix normal hors de sa portée est refusé sans dépense ni perte du choix. Le triangle cyan relie le porteur et les deux coins du but lorsqu'il est en portée. Le HUD affiche séparément l'endurance des deux gardiens.

## Duels

Un contact proche du porteur adverse déclenche un face-à-face. Toutes les positions, la physique du ballon, l'endurance et le chrono restent figés pendant le choix : gauche, droite ou une technique de la catégorie appropriée. Les techniques et les choix sont calculés par la session, avant leur présentation ; l'animation ne décide jamais d'une possession ou d'un but.

| Duel | Catégories | Résultat |
| --- | --- | --- |
| Dribble / intervention | ATT contre DEF | Passage du porteur ou récupération du défenseur |
| Tir / blocage dans le couloir | TIR contre DEF | Tir stoppé ou passage vers le duel gardien |
| Tireur / gardien | TIR contre GAR | But, capture ou déviation |

Le choix adverse est fixé au début du duel, avant la décision du joueur. Les scores combinent une base, l'endurance restante, le contre directionnel, la puissance de technique et l'augmentation éventuelle. Un contre directionnel correct avantage la défense ; un côté opposé avantage l'attaque. En cas d'égalité de puissance, la défense gagne. Les coûts sont validés avant toute dépense. L'endurance de gardien est distincte de celle du joueur de champ et se régénère lentement en jeu live.

La cinématique cache d'abord les scores puis les révèle avec le vainqueur. La simulation applique l'issue seulement à la fin de la présentation. Un défenseur dribblé reste **immobile et semi-transparent pendant exactement 60 ticks**, soit une seconde de jeu ; il ne peut pas tacler ni réceptionner pendant cet état, et une séparation de corps ne le déplace pas. Une déviation laisse le ballon libre et ne change pas la sélection. Toute vraie possession alliée sélectionne immédiatement le porteur ; aucun adversaire n'est sélectionné. Les alliés IA ne passent ni ne tirent.

Un tir qui traverse un blocage continue vers le gardien. La même technique déjà engagée n'est pas payée une seconde fois lors de cet enchaînement. Le cercle d'engagement et une courte protection empêchent un duel dès le premier instant du coup d'envoi.

## Mi-temps

La mi-temps propose, pour chaque équipe, une disposition équilibrée, large ou avec bloc de pressing plus haut. La reprise conserve les scores, inverse les camps et donne l'engagement à l'autre équipe. Une récupération partielle de l'endurance est appliquée. L'atelier est accessible sans perdre le match en cours.

## Techniques et atelier

`scenes/content_editor.tscn` est une scène autonome modulaire (F6), accessible aussi par le bouton Atelier du match. Elle permet de consulter, modifier et dupliquer une fiche ; éditer nom, catégorie, puissance, coût, durée, portée, couleur, effet, description et propriétés JSON ; prévisualiser ; sauvegarder/recharger/rétablir. Les valeurs invalides et les doublons sont rejetés sans écraser les données valides.

| Type | Technique | Signature visuelle |
| --- | --- | --- |
| TIR | Tir orbital | Anneaux orbitaux, sphères satellites et frappe ascendante |
| TIR | Tir Magnus | Frappe rotative et rubans courbes |
| ATT | Lame de combat | Lames lumineuses et percée |
| ATT | Drift | Copies translucides et glissement latéral |
| DEF | Barrage ouragan | Mur de spirales, blocage du tir |
| DEF | Aquablast | Vague et projections d'eau stylisées |
| GAR | Arrêt photo | Cadre lumineux, flash et capture ou rupture |
| GAR | Arrêt Gyroscopique | Anneaux gyroscopiques, protection ou dispersion |

Les deux techniques GAR partagent strictement leur préparation entre réussite et échec, puis divergent lorsque les scores apparaissent. Une capture, une déviation réussie et un but reçu ont des fins visuelles distinctes. Les modèles, os, caméras, décorations et visibilité du ballon sont restaurés après chaque cinématique. Les effets lisent la couleur, la famille visuelle et la puissance du catalogue ; la durée de présentation est bornée entre 1,8 et 10 secondes.

Les contenus sauvegardés sont des overrides dans `user://match_content.json`, hors des fichiers source. En cloud Linux, le dossier utilisateur est sous `/workspace/.local/share/godot/app_userdata/`. Ils sont rechargés au retour de l'atelier. Les sauvegardes de l’ancien système Écho sont migrées vers Karma à la lecture, sans perdre les paramètres personnalisés ; le format courant est réécrit à la prochaine sauvegarde explicite. La prévisualisation simplifiée de l'atelier sert à éditer les paramètres ; `scenes/duel_preview.tscn` montre les gestes complets sur les personnages, avec bascule réussite/échec et parcours automatique.

Deux tactiques sont incluses : **Ailes ouvertes** (largeur et soutien) et **Étau collectif** (bloc compact et pression). Leurs propriétés agissent sur le placement IA.

Les deux systèmes se nomment **Karma** et **Resonance** :

- **Karma : Vigie des vents** : renforcement temporaire, réserve propre qui se vide en jeu et lors des techniques ; puissance supplémentaire et légère accélération.
- **Resonance : Double impulsion** : association temporaire avec un partenaire allié, pondération des profils et bonus d'affrontement. La vitesse tient compte du profil partenaire. L'association est refusée sans partenaire valide.

Un joueur peut **cumuler Karma et Resonance**, avec une réserve et une durée indépendantes pour chacun. Chaque équipe peut maintenir **3 Karmas et 3 Resonance au maximum**, soit jusqu’à six états actifs répartis sur trois à six joueurs. Une seconde activation de la même famille sur un joueur déjà actif et une quatrième activation dans l’équipe sont refusées sans dépense ni remise à zéro. L’expiration ou l’épuisement d’un état libère uniquement sa place, sans supprimer l’autre famille. Les compteurs sont affichés pour les deux équipes. Ces états sont éditables comme les tactiques et les techniques. Il s'agit de variantes propres au prototype, pas d'une reproduction complète des systèmes des jeux de référence.

## Architecture et validation exécutée

La scène d'entraînement conserve ses dimensions et ses règles par défaut. Ses dimensions et directions de jeu ont été rendues configurables pour que `core/match/match_session.gd` puisse ajouter les phases et les duels sans casser l'entraînement. Les fonctions de score, de collision et de possession restent dans la simulation.

Principaux fichiers : `core/match/match_session.gd`, `core/content/technique_catalog.gd`, `scripts/match/full_match.gd`, `match_roster.gd`, `match_arena.gd`, `scripts/presentation/match_hud.gd`, `duel_cinematic.gd`, `duel_preview.gd`, `scripts/editor/content_editor.gd`, `technique_preview.gd`, les trois scènes `full_match.tscn`, `content_editor.tscn`, `duel_preview.tscn` et `tests/match/*`.

Commandes exécutées depuis `/workspace/IEG-Like-3D` :

```bash
bash tools/validate.sh
# ou directement avec le binaire Godot 4.7 et les variables XDG documentées :
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . --script res://tests/match/test_cli.gd
"$GODOT_BIN" --headless --path . --script res://tests/match/scene_smoke.gd
"$GODOT_BIN" --headless --path . res://scenes/full_match.tscn --quit-after 180 -- --smoke
"$GODOT_BIN" --headless --path . res://scenes/content_editor.tscn --quit-after 120
```

Résultats Godot `4.7.stable.official.5b4e0cb0f` : **265/265 tests natifs** (87 historiques, 76 match, 33 catalogue, 69 cinématiques), **32/32 contrôles de la vraie scène de match**, **12/12 contrôles scène/entrées de l'entraînement**, **7/7 diagnostics de l'entraînement**. Import, démarrages et `git diff --check` réussis, sans erreur moteur/script. Les tests parcourent notamment deux périodes complètes sans saut du chrono, le gel des duels, les coûts, les changements de camp et les deux déviations physiques de seconde période.

Le rendu réel OpenGL 4.5/Mesa llvmpipe a été exécuté sous Xvfb : terrain, atelier, choix de duel, révélation et huit familles d'effets inspectés. Le pilote signale seulement que VSync n'est pas pris en charge. Ces vérifications graphiques ne mesurent pas les performances sur le GPU d'un joueur.

## Limites et références

Aucun essai de manette physique dans ce cloud. Les animations sont des poses squelettiques et effets procéduraux réels, mais demandent encore un affinage artistique et un playtest des rythmes. Les formules de puissance et le placement IA sont une première base à équilibrer. Pas encore de fautes/arbitre, hors-jeu, prolongation/tirs au but, remplacements, règles de touche/corner réglementaires, multijoueur réseau ou progression de campagne. Les sorties reprennent encore par remise en place simplifiée.

Les descriptions externes de Chrono Stones et Galaxy tentées ont été bloquées par HTTP 403. Les URL essayées et la distinction entre la demande utilisateur et les choix originaux du prototype sont consignées dans [MATCH_GAMEPLAY_SOURCES.md](MATCH_GAMEPLAY_SOURCES.md).
