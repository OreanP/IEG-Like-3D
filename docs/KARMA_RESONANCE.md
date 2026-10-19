# Karma et Résonances jouables

Godot standard **4.7 stable**, GDScript uniquement. Les concepts ont des géométries 3D et des animations procédurales originales ; les GLB de joueurs et les scènes d'entraînement sont conservés. Les valeurs sont des règles originales du prototype, pas des formules vérifiées des jeux Inazuma Eleven.

## Contenu

| Contenu | Propriétaire / donneur | Ressources et bonus | Technique propre / héritages |
| --- | --- | --- | --- |
| Astreion, le Forgeron orbital | Soren Vale, Azur n° 7 | 240 PG, 80 PE ; tir +18, dribble +8 | Marteau du Périhélie — TIR |
| Thalassa, la Sentinelle des marées | Maëlle Néris, Azur n° 1 | 300 PG, 100 PE ; gardien +18, défense +10 | Cathédrale abyssale — GAR |
| Orbite souveraine | Résonance avec Soren | 75 s ; tir +18, dribble +16, technique +17 | Drift, Tir Magnus ; accès à Astreion si le donneur le possède |
| Vigie des profondeurs | Résonance avec Maëlle | 90 s ; gardien +19, défense +17, technique +16 | Aquablast, Arrêt Gyroscopique ; accès à Thalassa si le donneur le possède |

Les anciennes fiches Vigie des vents et Double horizon restent disponibles. Elles conservent leur fonctionnement historique à réserve générique, pour préserver les sauvegardes et les anciens tests.

## Essayer dans le match

1. F5 ouvre les Parcours ; choisir **Match libre**, ou lancer `scenes/full_match.tscn` avec F6. Soren reçoit l'engagement.
2. **V / L3**, puis **Karma** : invoquer Astreion. Ses PG et PE apparaissent dans deux jauges distinctes ; la signature devient accessible dans les tirs.
3. Ouvrir **Résonance**, choisir un autre receveur avec les boutons **Joueur ← / →**, puis Orbite souveraine. Le receveur apprend temporairement Drift et Tir Magnus. Le choix d'un receveur ne change ni la sélection live ni la possession.
4. Sur ce même receveur, ouvrir Karma : Astreion peut être invoqué grâce à Soren. Cela utilise une place de Karma supplémentaire.
5. Dans Karma, choisir Maëlle et invoquer Thalassa. Quand elle affronte un tireur, Cathédrale abyssale est proposée si ses réserves suffisent.
6. **Dissiper** termine une transformation sans remplir ses réserves. Dissiper une Résonance retire aussi un Karma obtenu uniquement grâce à elle.

Les techniques grisées sont accessibles au joueur mais inabordables avec ses réserves actuelles. Les autres techniques personnelles ne sont pas proposées. Les boutons indiquent les coûts PG/PE des signatures. Un tir déjà engagé après un blocage porte la mention **déjà payée**.

## Ressources et affrontements

Les **PG** alimentent le combat du Karma. Les **PE** limitent son maintien. L'endurance ordinaire du joueur et celle du gardien restent distinctes et ne sont pas rechargées par une transformation.

- Maintien : 1 PE/s de jeu effectif ; supplément de 1 PE/s pendant le sprint effectif.
- Affrontement ordinaire avec Karma : 10 PG et 4 PE.
- Défaite : perte supplémentaire de 20 PG.
- Marteau du Périhélie : 70 PG et 12 PE, à la place du coût Karma ordinaire. Plage optimale 10–28 m ; diminution de 1,2 point par mètre hors de cette plage, en plus de l'atténuation ordinaire des tirs lointains.
- Cathédrale abyssale : 80 PG et 14 PE, à la place du coût Karma ordinaire.
- Une même frappe traversant un blocage puis affrontant le gardien paie son coût de technique et de Karma une seule fois. Sa technique et son bonus initial sont conservés, même si le paiement a épuisé le Karma. Une défaite finale peut encore réduire les PG persistants du Karma payeur.

Les bonus de tir/dribble/défense/gardien ne s'appliquent qu'au contexte correspondant. Le bonus de technique contribue à 25 % dans les affrontements. Les bonus sont calculés avant les débits qui pourraient épuiser une transformation.

À zéro PG ou PE, le Karma disparaît sans rendre son joueur inactif. Le joueur dribblé reste soumis à l'inactivité habituelle d'une seconde. Les réserves sont conservées par couple joueur–Karma à la dissipation, à une nouvelle invocation et après les buts. Elles se rechargent à la mi-temps. Les pauses, choix de duel, cinématiques, reprises et l'atelier ne consomment ni maintien ni durée de Résonance.

La simulation choisit le résultat. Cathédrale abyssale partage sa préparation entre les trois issues ; après les scores, une victoire nette capture, une victoire serrée dévie et une défaite laisse passer le ballon. Une déviation ne donne aucune possession. Les règles de sélection alliée et l'interdiction des passes/tirs des alliés IA restent actives.

## Résonance et cumul

La Résonance transmet exactement deux techniques ordinaires distinctes, ajoutées sans supprimer les techniques personnelles. Un doublon avec une technique déjà connue n'apparaît qu'une fois. Les techniques GAR restent réservées aux gardiens. Les héritages cessent à la fin de la transformation.

Les bonus valent `statistique de base du donneur × ratio` pour les caractéristiques sélectionnées. Le ratio initial est 0,2. Les bonus temporaires du donneur ne sont jamais transmis. Le donneur reste sur le terrain et ne peut alimenter qu'une Résonance à la fois. Une nouvelle Résonance structurée est utilisable une fois par receveur et par mi-temps.

Un receveur peut maintenir **un Karma et une Résonance**. Il choisit entre son Karma personnel et celui du donneur. Le Karma hérité doit réellement appartenir au donneur ; sa possession n'entraîne pas d'invocation automatique. Chaque équipe reste limitée à **3 Karma et 3 Résonances**, héritages compris. Les refus ne consomment aucune ressource.

## Atelier

Ouvrir **Atelier** dans le match ou `scenes/content_editor.tscn` avec F6. Les champs dédiés permettent d'éditer :

- Karma : maxima PG/PE, consommations, coûts des affrontements et des défaites, signature, bonus et propriétaires.
- Signature : Karma propriétaire et coûts PG/PE.
- Résonance : donneur, deux techniques, Karma héritable, ratio, statistiques transmises et durée.
- Apparence : style, couleurs principale/secondaire, motif et description. Les couleurs d'apparence ont priorité sur la couleur générique de la fiche. Les motifs/descriptions sont des métadonnées ; les styles choisissent des géométries prédéfinies, avec une aura de repli pour un style inconnu.

Les styles sont `astreion`, `thalassa`, `sovereign_orbit`, `deep_watch`. La hauteur du Karma peut être ajustée dans le JSON `appearance.height`. Le JSON avancé conserve les propriétés personnalisées. Les seules statistiques proposées et validées sont tir, dribble, technique, défense et gardien.

Les propriétaires utilisent les clés `soren_vale`, `maelle_neris`, puis `azur_02` à `azur_11` pour les autres joueurs locaux, hors n° 7. **Dupliquer un Karma copie aussi sa signature et relie les deux nouvelles fiches.** Les propriétaires copiés peuvent immédiatement employer ce nouveau Karma ; modifier leur liste permet de l'attribuer à un autre joueur.

La sauvegarde atomique écrit uniquement dans `user://match_content.json`, schéma 3. Les versions 1 et 2 sont migrées en mémoire sans réécriture ni perte de paramètres ; une sauvegarde explicite actualise le format. Les références invalides, les types incorrects et les héritages incomplets sont refusés avant écriture. Recharger/restaurer des modifications non sauvegardées demande une confirmation.

Les règles et apparences sauvegardées sont rechargées au retour dans le match. Une transformation déjà active garde les réserves et maxima établis à son invocation ; les valeurs modifiées s'appliquent à une nouvelle invocation, sans régénérer les réserves déjà dépensées.

## Vérification

```bash
bash tools/validate.sh
```

Cette commande vérifie l'import natif, les suites GDScript, les scènes de match et d'entraînement, le parcours réel des menus Karma/Résonance, les démarrages d'atelier et les diagnostics. Elle parcourt aussi dix animations de techniques dans `scenes/duel_preview.tscn`, dont les deux signatures et les variantes gardien.

Les résultats finaux de cette livraison sont consignés dans [FULL_MATCH.md](FULL_MATCH.md). Les animations utilisent les modèles existants et des accessoires procéduraux : les silhouettes et effets sont jouables, avec un travail artistique et d'équilibrage restant. Pas de test de manette physique dans le cloud.
