# Première livraison de développement — 14 octobre 2026

Base inspectée : `origin/main`, commit `5da9c8935a2f84c28c2a3f6015249183105a783e`. Branche : `codex/ieg-development`. Aucun `AGENTS.md` ni paquet des lots 01/02 présent dans les répertoires projet, bibliothèque et fichiers partagés. Les corrections ont été implémentées sur cette base réelle, sans réappliquer aveuglément les diffs S1.

## Problème corrigé et comportement livré

La session S1 appelait un constructeur `IEGPlayerState` à trois arguments alors que le fichier en acceptait deux. L'état et les commandes n'avaient pas les champs d'équipe/tacle attendus ; la scène et les entrées étaient encore S0. Les contrats sont maintenant compatibles. Les 54 tests S0/S1 préexistants passent.

La scène existante contient sept personnages, dont deux gardiens. Le placement collectif conserve des couloirs de soutien et désigne un seul joueur de champ par équipe comme poursuivant/presseur. Les alliés IA ne passent ni ne tirent, même si une commande injectée le demande. Les adversaires porteurs utilisent les commandes de mouvement/tir existantes.

`IEGGameCommand` expose `tackle`, `pass_target_id` et `lob_pass`, avec sérialisation JSON et validation des valeurs numériques. Le ciblage explicite refuse les adversaires, soi-même et les identifiants inexistants. Le mode directionnel reste disponible. Le point de passe est fixé au départ, avec une anticipation courte ; le ballon ne poursuit pas magiquement sa cible. Les lobs utilisent un temps de vol minimum donnant assez de hauteur même sur une passe courte.

`_gain_possession()` centralise réception, interception, tacle et capture. Un porteur bleu nouvellement établi est immédiatement sélectionné. La passe conserve la sélection anticipée du destinataire pour les déplacements ; la possession reste libre pendant le trajet. Les rouges ne sont jamais sélectionnés. Les charges de tir sont annulées aux changements de contrôle, réceptions, captures, pauses et remises en place.

Les gardiens restent dans leur zone (x ±4 m, profondeur 12–17,4 m de leur moitié). Un contact sous 1,6 m et à vitesse ≤18 m/s capture le ballon ; un contact accessible plus rapide ou plus haut (jusqu'à 2,5 m) le dévie vers le terrain. Le rayon d'arrêt est de 1,15 m, celui des réceptions de champ de 0,64 m. La collision balayée utilise le premier contact, comparé au franchissement de la ligne. Les déviations laissent le ballon libre et ne changent pas la sélection. Le ballon capturé est protégé des tacles, puis relancé par passe/lob ; le gardien rouge propose sa relance après 0,6 s. La simulation ne dépend pas des clips d'animation.

## Fichiers concernés

| Groupe | Fichiers modifiés ou ajoutés (hors compagnons `.uid`) |
| --- | --- |
| Simulation | `core/game_command.gd`, `core/player_state.gd`, `core/training_session.gd`, `core/training_rules.gd` |
| IA | `core/ai/collective_brain.gd`, `core/ai/goalkeeper_brain.gd` |
| Entrées et assemblage | `project.godot`, `scripts/input/local_player_input.gd`, `scripts/match/training_ground.gd` |
| Présentation | `scripts/presentation/player_view.gd`, `scripts/presentation/training_hud.gd` |
| Scènes | `scenes/training_ground.tscn`, `scenes/diagnostic.tscn`, `scripts/match/diagnostic.gd` |
| Profils | `assets/players/keeper_blue.tres`, `assets/players/keeper_red.tres`, `assets/players/opponent_22.tres` |
| Tests | `tests/development/test_suite.gd`, `tests/development/test_cli.gd`, `tests/development/scene_smoke.gd` |
| Installation et validation | `tools/cloud_setup.sh`, `tools/validate.sh` |
| Documentation | `README.md`, `DEMARRER.txt`, `docs/DEVELOPMENT.md`, `docs/VALIDATION.md` |

Les GLB, le terrain et la scène partagée des personnages sont conservés. Les `.uid` créés par Godot sont versionnés pour stabiliser les références des nouveaux scripts et des scripts S1 qui en étaient dépourvus. Les tests S0/S1 n'ont pas été désactivés ni modifiés.

## Commandes réellement exécutées et résultats

Godot déclaré dans `project.godot` : **4.7**. Le moteur 4.6.3 préinstallé n'a pas été substitué silencieusement à cette exigence. Téléchargement de Godot standard 4.7 stable depuis `godotengine/godot-builds`, vérification de l'archive avec le `SHA512-SUMS.txt` officiel. Version exécutée : `4.7.stable.official.5b4e0cb0f`.

Dans `/workspace/IEG-Like-3D`, avec `XDG_CONFIG_HOME=/workspace/.config`, `XDG_CACHE_HOME=/workspace/.cache` et `XDG_DATA_HOME=/workspace/.local/share` :

```bash
# Installation et import reproductibles, exécutés avec succès.
bash tools/cloud_setup.sh
# Validation complète, exécutée avec succès.
bash tools/validate.sh
```

Les commandes moteur exécutées par la validation (binaire `$GODOT_BIN` = `/workspace/tools/godot-4.7/Godot_v4.7-stable_linux.x86_64`) :

```bash
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . --script res://tests/development/test_cli.gd
"$GODOT_BIN" --headless --path . --script res://tests/development/scene_smoke.gd
"$GODOT_BIN" --headless --path . --quit-after 180
"$GODOT_BIN" --headless --path . res://scenes/diagnostic.tscn -- --verify
```

| Vérification | Résultat |
| --- | --- |
| Import natif, GLB et compilation GDScript | Réussi, aucune erreur moteur/script |
| Tests S0 + S1 + développement | **87/87** (30 + 24 + 33) |
| Vraie scène et adaptateur d'entrées | **12/12** : analogique, tacle, cible, lob, charge/release, annulation, pause, capture/sélection/synchronisation visuelle |
| Scène principale, 180 itérations | Chargée et exécutée, aucune erreur moteur/script |
| Scène diagnostic automatisée | **7/7** : captures et déviations bleues/rouges, lob, tacle allié, placement collectif |
| `git diff --check` | Réussi |

Les journaux de la validation sont écrits dans un dossier `/tmp/ieg-validation.*`. Les codes de sortie sont conservés ; la validation échoue aussi en présence d'erreurs moteur/script, même si Godot termine à zéro. Aucun test Python n'est utilisé comme remplacement des tests natifs : Python sert uniquement à vérifier SHA-512 et à préserver les métadonnées pendant l'installation.

## Limites restantes

Validation headless : aucun essai visuel OpenGL sur écran ni manette physique. Les actions manette/clavier sont vérifiées et les entrées logiques sont exercées, mais cela ne certifie pas les sensations, la compatibilité de chaque périphérique ou les performances graphiques. Les animations gardien utilisent le modèle existant et des réactions simples ; pas d'animation dédiée de plongeon/capture. La déviation est une réponse déterministe simplifiée, pas une simulation biomécanique.

Le placement est une première base par couloirs et poursuivant unique, sans stratégie complète à onze. Les gardiens sont confinés à leur zone. Pas de hors-jeu, fautes/arbitre, gardien sortant, match complet, réseau, progression RPG ou techniques spéciales. Les contrôles et la lisibilité du HUD doivent encore être essayés sur un poste graphique.

Cette branche est une première livraison fonctionnelle et testée, pas le jeu complet. Aucun changement de `main`, force-push ou fusion de PR n'est nécessaire à sa livraison.
