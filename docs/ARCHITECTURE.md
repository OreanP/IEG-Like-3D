# Architecture GDScript

## Flux d'une commande

Manette / clavier / souris → IEGLocalPlayerInput → IEGGameCommand →
IEGTrainingSession.step() → état + événements → modèles, caméra et interface.

Le cœur utilise RefCounted, Resource pour les définitions, Vector2/Vector3 et les
fonctions mathématiques de Godot, mais aucun Node, Input, AnimationPlayer ou
SceneTree. Il est testable sans scène 3D et sans matériel connecté. On n'essaie
pas de reproduire artificiellement une bibliothèque .NET indépendante du moteur.

## Types

IEGPlayerProfile (Resource) : identité, vitesses et palette, partagés et éditables.
IEGPlayerState (RefCounted) : position, vitesse, orientation, énergie et seuils.
IEGBallState (RefCounted) : position 3D, vitesse, mode et propriétaire.
IEGGameCommand (RefCounted) : intention locale ; une action n'est pas un résultat.
IEGTrainingSession (RefCounted) : autorité locale qui valide la possession.
IEGPlayerView (Node3D) : rend l'état et joue les animations.

## Temps

La simulation est fixée à 60 Hz. Les actions ponctuelles sont consommées au tick
physique ; la caméra est mise à jour au rendu. Le déplacement de souris n'est pas
multiplié par delta, contrairement à la vitesse angulaire du stick droit.
L'interpolation physique lisse les positions des joueurs et du ballon.
La pause fige la session et les animations ; l'UI reste active. Toute charge est
annulée lors d'une pause, d'un changement de joueur, d'une passe ou d'un reset.

## Ballon

HELD : le ballon suit le porteur.
PASS : trajectoire de passe choisie au départ, sans poursuite de la cible.
SHOT : vitesse et hauteur initiales issues de la charge.
FREE : ballon libre récupérable.

Les réceptions et buts utilisent un segment entre les positions successives pour
ne pas manquer un franchissement rapide. Le but exige le passage complet du
ballon. Un événement GOAL déclenche une courte temporisation puis un reset ; la
commande RESET remet en place mais conserve le compteur.

## Choix de présentation

Les GLB inclus sont repris du premier lot. Le footballer contient quatre clips.
Les animations sont dupliquées par vue avant de modifier leur mode de boucle.
Chaque joueur duplique ses matériaux colorables. Changer un profil ne recolore
pas les autres joueurs.

La scène d'environnement est enregistrée, pas recréée par un gros script de
bootstrap. Deux petits ensembles de segments @tool groupent filets et clôtures
sans multiplier les nœuds pour chaque fil. Les objets visibles du terrain ne
sont pas tous des corps de collision : l'exercice utilise ses propres règles.

## Limites explicites et réseau futur

Les trois partenaires restent statiques s'ils ne sont pas contrôlés.
Pas de logique de gardien, de duel, de match complet ou de technique spéciale.
Pas de campagne ni de sauvegarde de progression.
Les instantanés JSON sont des représentations d'état, pas des sauvegardes
complètes permettant déjà de restaurer un match, ni des paquets envoyés.
Avant le réseau : validation des acteurs et ticks, protocole, autorité de session,
interpolation des états distants, connexion, tests de latence et sécurité.
