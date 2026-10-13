# IEG Like — S1 : premier défenseur et récupération

## Objectif

Conserver le projet Godot GDScript S0. Ajouter un adversaire rouge au terrain existant : il presse, intercepte, récupère et contre-attaque. Le joueur peut récupérer avec B / Cercle / E. Il n'y a pas encore de gardien, de règles complètes de match ni de duel cinématique.

## Ce que le ZIP fait et ne fait pas

Le ZIP contient les nouveaux modules, le profil de l'adversaire, les tests et UNE version modifiée d'un fichier existant : `core/training_session.gd`. Il ne contient pas `project.godot`, les scènes de terrain existantes ou de nouveaux modèles 3D. Il ne crée pas un autre jeu. Le modèle et les animations actuels sont réutilisés.

Les six autres scripts indiqués ci-dessous se modifient à la main. `integration_manuelle.diff` montre leur différence exacte avec S0. `session_changes.diff` permet de lire les changements du grand script de simulation.

Les chemins sont relatifs au dossier contenant votre `project.godot`. `res://` désigne ce même dossier dans Godot.

## 0. Sauvegarder le point de départ dans Git

Dans PowerShell ouvert dans le dossier du projet :

```powershell
git init
git add .
git commit -m "chore: checkpoint GDScript S0"
git branch -M main
git tag s0-gdscript
```

Le `.gitignore` existant ignore déjà `.godot/`. Ne mettez pas les clés et fichiers `.env` dans Git. Conservez les `.uid` et les fichiers source/imports utiles au projet. Si Git demande votre identité, renseignez votre nom et votre adresse Git dans la configuration locale.

Créez sur GitHub un dépôt privé vide nommé par exemple `ieg-like`, sans ajout automatique de README, .gitignore ou licence. Utilisez ensuite l'URL HTTPS réellement affichée par GitHub :

```powershell
git remote add origin https://github.com/TON_COMPTE/ieg-like.git
git push -u origin main
git push origin s0-gdscript
git switch -c feature/s1-opposition
```

`TON_COMPTE` est à remplacer. Aucun accès GitHub n'est nécessaire à l'assistant pour cette étape.

## 1. Copier le contenu du ZIP

Arrêter le jeu, enregistrer et fermer Godot. Dézipper les dossiers `core`, `assets`, `tests` et `docs` à la racine du projet existant. Accepter UNIQUEMENT le remplacement de `core/training_session.gd`. Aucun autre fichier déjà présent dans le S0 original n'est inclus.

Le remplacement suppose que ce fichier est encore celui du S0. En présence de modifications personnelles, comparez le diff et fusionnez plutôt que de les écraser.

Effectuez ensuite toutes les étapes avant F5/F6. Des erreurs temporaires sont possibles tant que les nouvelles propriétés n'ont pas été ajoutées.

## 2. Enrichir la commande

Dans `core/game_command.gd`, ajouter parmi les variables :

```gdscript
var tackle: bool = false
```

Dans le dictionnaire retourné par `to_dict()`, ajouter une entrée :

```gdscript
"tackle": tackle,
```

Dans `from_dict()`, juste après la lecture de `shoot`, ajouter :

```gdscript
command.tackle = data.get("tackle", false) == true
```

Une commande dit « je tente de récupérer », jamais « j'ai gagné le ballon ».

## 3. État du joueur

Remplacer le contenu de `core/player_state.gd` par :

```gdscript
class_name IEGPlayerState
extends RefCounted
## État mutable. L'équipe appartient au match, pas au profil du personnage.

var profile: IEGPlayerProfile
var team_id: int = 0
var position: Vector2 = Vector2.ZERO
var spawn: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, -1.0)
var energy: float = 100.0
var sprint_exhausted: bool = false
var tackle_cooldown: float = 0.0
var recovery_time: float = 0.0
var possession_grace: float = 0.0

func _init(source: IEGPlayerProfile, start: Vector2, team: int = 0) -> void:
    profile = source
    position = start
    spawn = start
    team_id = team

func get_id() -> int:
    return profile.player_id

func reset() -> void:
    position = spawn
    velocity = Vector2.ZERO
    facing = Vector2(0.0, -1.0) if team_id == 0 else Vector2(0.0, 1.0)
    energy = 100.0
    sprint_exhausted = false
    tackle_cooldown = 0.0
    recovery_time = 0.0
    possession_grace = 0.0
```

`team_id` désigne l'équipe pendant cet entraînement. Il n'est pas dans `PlayerProfile` : le personnage pourra changer d'équipe dans le futur RPG. Les trois délais servent au coût d'une tentative, au ralentissement et à la protection temporaire du nouveau porteur.

## 4. Brancher les entrées et les équipes visuelles

Dans `scripts/input/local_player_input.gd`, dans `read_command()`, juste après l'affectation de `command.pass_ball` :

```gdscript
command.tackle = Input.is_action_just_pressed("tackle")
```

Au début de `scripts/presentation/player_view.gd`, après `@export var profile: IEGPlayerProfile` :

```gdscript
@export_enum("Alliés:0", "Adversaires:1") var team_id: int = 0
```

Ne modifiez pas le reste de ce script d'affichage.

## 5. Raccorder la scène à la simulation et à l'IA

Fichier : `scripts/match/training_ground.gd`.

### 5.1. Ajouts en tête de fichier

Avec les autres `preload` :

```gdscript
const DefenderBrain = preload("res://core/ai/defender_brain.gd")
```

AVANT le groupe `Contrôles` :

```gdscript
@export_group("Opposition S1")
@export var opposition_enabled: bool = true
```

Après `var _views: Dictionary = {}` :

```gdscript
var _brains: Dictionary = {}
```

### 5.2. Dans `_ready()`

Supprimer le bloc qui commence à :

```gdscript
var roster: Array[IEGPlayerProfile] = []
```

et se termine à :

```gdscript
        index += 1
```

C'est tout le bloc qui récolte trois profils et associe les vues par index. Remplacer ce bloc par :

```gdscript
    if not _create_session():
        return
```

Conserver immédiatement après la ligne existante `ball_view.position = session.ball.position` et toute la suite de `_ready()`.

Le `print` de fin peut devenir :

```gdscript
print("IEG Like S1 — opposition chargée (%d joueurs)." % session.players.size())
```

### 5.3. Ajouter ces deux fonctions à la fin du fichier

```gdscript
func _create_session() -> bool:
    var roster: Array[IEGPlayerProfile] = []
    var spawns: Array[Vector2] = []
    var teams: Array[int] = []
    var views: Array[IEGPlayerView] = []
    for child: Node in players_root.get_children():
        if child is IEGPlayerView:
            views.append(child)
            roster.append(child.profile)
            spawns.append(Vector2(child.position.x, child.position.z))
            teams.append(child.team_id)
    if not Session.valid_setup(roster, spawns, teams):
        push_error("Effectif invalide : profils/ID uniques, équipes 0 ou 1, au moins un allié, positions sur le terrain.")
        return false
    session = Session.new(roster, spawns, teams)
    _views.clear()
    _brains.clear()
    for view: IEGPlayerView in views:
        var state: IEGPlayerState = session.get_player(view.profile.player_id)
        _views[state.get_id()] = view
        if state.team_id != Session.LOCAL_TEAM:
            _brains[state.get_id()] = DefenderBrain.new()
        view.sync_state(state, state.get_id() == session.controlled_id, false, 1.0)
        view.reset_physics_interpolation()
    return true

func _create_ai_commands() -> Dictionary:
    var commands: Dictionary = {}
    if not opposition_enabled:
        return commands
    for actor_id: int in _brains:
        var brain: IEGDefenderBrain = _brains[actor_id]
        var actor: IEGPlayerState = session.get_player(actor_id)
        commands[actor_id] = brain.decide(session, actor)
    return commands
```

Les coordonnées de départ viennent maintenant des instances placées dans l'éditeur. Les vues sont associées par ID, pas par un ordre fixe de trois joueurs.

### 5.4. Modifier UNE invocation de `step()`

Dans `_physics_process()`, juste après `controls.read_command(...)`, remplacer :

```gdscript
session.step(command)
```

par :

```gdscript
session.step(command, _create_ai_commands())
```

Conserver l'autre `session.step(command)` dans `_reset_from_menu()` : le reset n'a pas besoin de commande IA.

### 5.5. Présenter les nouveaux événements

Dans `_present()`, ajouter les branches suivantes SOUS `match kind:`, au même niveau que `Session.EventKind.PASS`, avant la branche `RESET` :

```gdscript
        Session.EventKind.TACKLE_ATTEMPT:
            var tackler: IEGPlayerView = _views[actor_id]
            tackler.kick() # Animation de contact provisoire, pas une glissade.
        Session.EventKind.TACKLE_WON:
            controls.cancel_charge()
            hud.show_message("Récupération du n°%02d !" % actor_id)
        Session.EventKind.TACKLE_MISSED:
            if actor_id == session.controlled_id:
                hud.show_message("Trop loin, mal orienté ou porteur encore protégé.")
        Session.EventKind.INTERCEPTION:
            controls.cancel_charge()
            hud.show_message("Interception du n°%02d !" % actor_id)
```

Dans la branche `GOAL`, garder `controls.cancel_charge()` puis remplacer le message générique par :

```gdscript
var scoring_team: int = int(event.get("team_id", 0))
hud.show_message("BUT DES BLEUS !" if scoring_team == 0 else "BUT DES ROUGES !")
```

Respecter l'indentation du bloc `match`.

## 6. Mettre à jour l'interface

Fichier : `scripts/presentation/training_hud.gd`.

Dans `_ready()`, remplacer `FINITION LIBRE` par `BLEUS / ROUGES`, et `00  BUT` par `00 — 00`.

Dans `refresh()`, remplacer la ligne `_score.text = ...` par :

```gdscript
_score.text = "%02d — %02d" % [session.team_goals[0], session.team_goals[1]]
if player.tackle_cooldown > 0.0:
    _status.text = "Récupération : %.1f s" % player.tackle_cooldown
```

Juste AVANT la ligne `_message_life = maxf(0.0, _message_life - delta)`, ajouter (en dehors du `if/else` de choix de périphérique) :

```gdscript
_controls.text += "\nB / Cercle / E : récupérer"
```

Le texte de commandes étant réassigné chaque image juste avant, cette ligne ne s'accumule pas à l'infini.

Pour agrandir le panneau de commandes, remplacer :

```gdscript
Rect2(-486, -195, 462, 171)
```

par :

```gdscript
Rect2(-486, -215, 462, 191)
```

Dans `_build_pause()`, remplacer la phrase qui annonce qu'il n'y a pas d'adversaire par :

```gdscript
"Trois alliés contre un défenseur\nPasse, interception et récupération debout."
```

## 7. Configuration dans Godot

Réouvrir le projet existant. Aucune importation d'un autre projet.

### Action `tackle`

Dans les paramètres du projet, onglet des actions d'entrée (Input Map), ajouter `tackle` avec :

- clavier : touche physique E ;
- manette : bouton B / Cercle, c'est le bouton à DROITE du losange (`JOY_BUTTON_B`, indice 1), toutes les manettes.

La touche E n'est pas utilisée par les contrôles S0. Les autres actions restent inchangées.

### Ajouter le défenseur à `scenes/training_ground.tscn`

Sélectionner le nœud `Players`. Faire glisser `scenes/characters/player_view.tscn` sur `Players` pour ajouter une instance, et renommer sa racine `Defender21`.

Sur cette nouvelle instance UNIQUEMENT :

| Champ | Valeur |
|---|---|
| `profile` | res://assets/players/defender_21.tres |
| `team_id` | Adversaires (1) |
| Position X / Y / Z | 0 / 0 / -5 |
| Échelle | 1 / 1 / 1 |

Les trois autres joueurs gardent `team_id = Alliés (0)` et leurs profils 7, 8 et 10. Ne modifiez pas la scène partagée `player_view.tscn` pour affecter le profil du défenseur, car cela changerait sa valeur par défaut pour les autres instances. Ne dupliquez pas un joueur en gardant le même ID.

Arbre attendu :

```text
TrainingGround
  Players
    Player07
    Player08
    Player10
    Defender21
```

Sauvegarder la scène. Le maillot rouge est appliqué par `configure()` au lancement ; la couleur d'aperçu dans l'éditeur peut rester celle du modèle.

Les nœuds restent des `Node3D` visuels. Ne pas les convertir en `CharacterBody3D`, ni ajouter des `Area3D` pour décider des récupérations : cette étape utilise la simulation existante, avec ses distances et sa séparation des joueurs.

## 8. Comprendre et régler la fonctionnalité

### Cerveau du défenseur

Fichier fourni : `core/ai/defender_brain.gd`. Il fournit des commandes, sans lire le clavier ou modifier le ballon. Voici son code :

```gdscript
class_name IEGDefenderBrain
extends RefCounted
## IA de démonstration : observer l'état, proposer une commande, ne rien imposer.
## Pas de lecture de l'Input ni d'écriture dans la session.

const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

func decide(session: IEGTrainingSession, actor: IEGPlayerState) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    if session.is_resetting():
        return command
    var owner: IEGPlayerState = session.get_player(session.ball.owner_id)
    if owner == null:
        var future_ball: Vector2 = Rules.planar(session.ball.position)
        future_ball += Rules.planar(session.ball.velocity) * 0.12
        _move_towards(command, actor, future_ball)
        command.sprint = actor.position.distance_to(future_ball) > 5.0
        return command
    if owner.get_id() == actor.get_id():
        # L'adversaire rouge attaque vers +Z. Il ne sprinte pas ballon au pied,
        # afin que le joueur puisse le rattraper pour essayer la récupération.
        var goal: Vector2 = Vector2(0.0, Rules.HALF_LENGTH if actor.team_id == 1 else -Rules.HALF_LENGTH)
        _move_towards(command, actor, goal)
        if actor.position.distance_to(goal) < 7.0:
            command.shoot = true
            command.shot_charge = 0.55
        return command
    if owner.team_id == actor.team_id:
        _move_towards(command, actor, actor.spawn)
        return command
    # D'abord fermer l'axe du but, puis presser directement le porteur.
    var own_goal: Vector2 = Vector2(0.0, -Rules.HALF_LENGTH if actor.team_id == 1 else Rules.HALF_LENGTH)
    var distance: float = actor.position.distance_to(owner.position)
    var predicted: Vector2 = owner.position + owner.velocity * 0.16
    var target: Vector2 = predicted
    if distance > 3.0:
        target += (own_goal - predicted).normalized() * 0.9
    _move_towards(command, actor, target)
    command.sprint = distance > 5.0
    command.aim = Rules.direction(owner.position - actor.position, actor.facing)
    command.tackle = distance <= 1.20 and actor.tackle_cooldown <= 0.0 and owner.possession_grace <= 0.0
    return command

func _move_towards(command: IEGGameCommand, actor: IEGPlayerState, target: Vector2) -> void:
    var offset: Vector2 = target - actor.position
    command.move = offset.limit_length(1.0) if offset.length() > 0.12 else Vector2.ZERO
    command.aim = Rules.direction(offset, actor.facing)
```

Le défenseur avance après une récupération vers +Z, tandis que les alliés attaquent vers -Z. Les deux buts restent sans gardien. Les partenaires non contrôlés restent immobiles. Cette IA individuelle n'est pas encore une IA collective de match.

### Récupération

La méthode suivante est DÉJÀ dans `core/training_session.gd` copié à l'étape 1 ; ne pas l'ajouter une deuxième fois :

```gdscript
func _try_tackle(actor: IEGPlayerState, aim: Vector2) -> void:
    var owner: IEGPlayerState = get_player(ball.owner_id)
    if owner == null or owner.team_id == actor.team_id:
        return
    if actor.tackle_cooldown > 0.0 or actor.recovery_time > 0.0:
        return
    if actor.energy < DuelRules.TACKLE_ENERGY:
        return
    actor.energy -= DuelRules.TACKLE_ENERGY
    actor.tackle_cooldown = DuelRules.TACKLE_COOLDOWN
    actor.recovery_time = DuelRules.TACKLE_RECOVERY
    actor.facing = Rules.direction(aim, actor.facing)
    _emit(EventKind.TACKLE_ATTEMPT, actor.get_id(), owner.get_id())
    var offset: Vector2 = owner.position - actor.position
    var in_range: bool = offset.length() <= DuelRules.TACKLE_RANGE
    var in_front: bool = offset.length_squared() < 0.0001 or actor.facing.dot(offset.normalized()) >= cos(DuelRules.TACKLE_HALF_ANGLE)
    if not in_range or not in_front or owner.possession_grace > 0.0:
        _emit(EventKind.TACKLE_MISSED, actor.get_id(), owner.get_id())
        return
    owner.recovery_time = maxf(owner.recovery_time, DuelRules.STAGGER_DURATION)
    owner.velocity *= DuelRules.RECOVERY_SPEED_FACTOR
    actor.possession_grace = DuelRules.POSSESSION_GRACE
    ball.owner_id = actor.get_id()
    ball.mode = BallState.Mode.HELD
    ball.velocity = Vector3.ZERO
    _follow_owner()
    _emit(EventKind.TACKLE_WON, actor.get_id(), owner.get_id())

```

Les paramètres éditables dans `core/duel_rules.gd` : portée 1,35 unité, demi-angle 60° (cône total 120°), délai 0,90 s, coût 10 d'énergie, récupération du geste 0,22 s, protection après gain 0,50 s.

En S1, passer ou tirer au même tick a priorité sur une tentative de récupération. Ce choix est explicite ; il changera lorsque les futurs duels structurés remplaceront les prises directes.

L'animation `Kick` est réutilisée pour donner un retour de contact. Ce n'est pas un tacle glissé ni une nouvelle animation originale. Le rendu sera retravaillé au jalon animation/duels.

Le paramètre `opposition_enabled` sur `TrainingGround` permet de couper les décisions IA pour comparer avec S0. Le défenseur reste présent et peut encore recevoir/intercepter une balle qui le touche : ce réglage ne le supprime pas.

## 9. Vérifier

Ouvrir `tests/s1/test_runner.tscn`, puis F6. Résultat attendu : 54 / 54 (30 tests S0 + 24 tests S1). Ces tests sont fournis mais n'ont pas pu être exécutés dans Godot dans l'environnement de préparation. Ils ne prouvent pas la qualité visuelle ni le bon fonctionnement d'une manette physique.

Puis F5 :

1. Trois joueurs bleus, un rouge et score 00 — 00.
2. Tab/L1 ne sélectionne jamais le rouge ; il n'est jamais une cible turquoise de passe.
3. Le rouge se rapproche du porteur et peut récupérer/intercepter.
4. À courte distance du rouge porteur, viser vers lui et presser E/B/Cercle : prise de balle, message, court délai.
5. Une tentative de loin échoue ; marteler le bouton ne supprime pas le délai.
6. Le rouge contre-attaque vers l'autre but après une récupération. Le compteur distingue les deux équipes.
7. R replace les quatre joueurs et le ballon ; pause fige la simulation.

Conserver la première erreur exacte en cas de problème, avec le fichier et sa ligne.

## 10. Enregistrer le jalon

Après validation locale :

```powershell
git status --short
git diff --stat
git diff -- core/training_session.gd
git add .
git commit -m "feat: S1 opponent AI and ball recovery"
git push -u origin feature/s1-opposition
```

Il n'y a pas encore de réseau, de serveur ni de synchronisation distante. La frontière commandes/simulation est conservée pour ces évolutions.

## Références officielles

- Godot, actions manette/clavier : https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html
- Godot, Input Map : https://docs.godotengine.org/en/stable/classes/class_inputmap.html
- Godot, propriétés exportées : https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html
- Godot, gestion de versions : https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html
- GitHub, ajout d'un projet local : https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github
