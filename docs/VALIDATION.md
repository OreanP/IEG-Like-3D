# État de validation — livraison GDScript S0

## Effectué dans l'environnement de préparation

Les 15 scripts GDScript ont été analysés avec Lark et une grammaire GDScript
issue de gdtoolkit. Cette vérification de syntaxe n'est **pas** le parseur/typeur
de Godot. Résultats détaillés dans `SYNTAX_CHECKS.txt`.

Les références res://, les identifiants des ressources de scènes, les compteurs
load_steps, les noms des classes, la configuration Input Map, la scène principale
et l'absence de dépendances C#/.NET ont été contrôlés automatiquement.
Résultats détaillés dans `STRUCTURE_CHECKS.txt`.

Les deux modèles GLB ont été vérifiés : en-têtes, longueur, buffers intégrés et
quatre animations Idle/Walk/Run/Kick dans le modèle de joueur. Les scènes, données,
textures procédurales et modèles ne nécessitent aucun téléchargement à l'exécution.

## Non effectué ici

Le moteur Godot n'était pas disponible dans cet environnement et son téléchargement
n'a pas abouti. Aucun import natif, lancement de la scène, rendu 3D, profilage ou
test de manette physique n'a donc été effectué. Aucun résultat « 30 tests passés »
n'est revendiqué : les 30 tests GDScript sont **fournis**, à exécuter dans Godot.

## Vérifier sur la machine de développement

Importer le projet, attendre l'importation des GLB, puis ouvrir
`tests/test_runner.tscn` et appuyer sur F6. Les résultats apparaîtront à l'écran et
dans la sortie Godot. Une erreur rouge de compilation/type doit être résolue avant
d'interpréter les résultats des tests. F5 lance l'entraînement.

Le protocole d'essai des commandes et du ballon est dans `TEST_MANUEL.md`.
La cible de compatibilité est Godot standard 4.5+ de la branche 4.x ; la compatibilité
exacte avec chaque version et chaque manette reste à confirmer par ce passage.

Référence de la grammaire utilisée uniquement pour la vérification externe :
https://github.com/Scony/godot-gdscript-toolkit/tree/master/gdtoolkit/parser
