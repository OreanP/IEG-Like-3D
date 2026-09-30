extends RefCounted
## Tests de régression. Exécution native dans Godot, sans extension ni .NET.

const Session = preload("res://core/training_session.gd")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")
const BallState = preload("res://core/ball_state.gd")
const Profile = preload("res://core/player_profile.gd")

func run_all() -> Dictionary:
    var cases: Array[Dictionary] = [
        {"name": "Trois joueurs et possession initiale", "run": _initial_state},
        {"name": "Aucun déplacement sans commande", "run": _idle},
        {"name": "La diagonale ne donne pas de vitesse bonus", "run": _diagonal},
        {"name": "Amplitude analogique conservée", "run": _analog},
        {"name": "Sprint plus rapide que la course", "run": _sprint_speed},
        {"name": "Consommation et récupération d'endurance", "run": _energy},
        {"name": "Limites du terrain respectées", "run": _bounds},
        {"name": "Changer de joueur ne téléporte pas le ballon", "run": _switch_owner},
        {"name": "Cycle de sélection 07 → 08 → 10 → 07", "run": _switch_cycle},
        {"name": "Cible de passe liée à la direction", "run": _pass_target},
        {"name": "Passe : ballon libéré et contrôle du receveur", "run": _pass_release},
        {"name": "Réception d'une passe", "run": _pass_reception},
        {"name": "Tir libère le ballon et produit un événement", "run": _shot},
        {"name": "Un tir chargé est plus puissant", "run": _charge_power},
        {"name": "Impossible de tirer sans possession", "run": _cannot_shoot_without_ball},
        {"name": "But détecté malgré une grande vitesse", "run": _swept_goal},
        {"name": "Le ballon doit franchir entièrement la ligne", "run": _full_crossing},
        {"name": "Un tir au-dessus ou à côté n'est pas un but", "run": _missed_goal},
        {"name": "Les deux buts sont reconnus", "run": _both_goals},
        {"name": "Un tir compte une seule fois", "run": _single_goal},
        {"name": "Sortie puis remise en place", "run": _out_reset},
        {"name": "Replacer conserve le compteur de buts", "run": _reset_score},
        {"name": "Réception balayée d'un ballon rapide", "run": _swept_reception},
        {"name": "Pas de réception d'un ballon trop haut", "run": _high_ball},
        {"name": "Commandes infinies ou NaN neutralisées", "run": _nonfinite},
        {"name": "Commande sérialisable et relecture", "run": _command_roundtrip},
        {"name": "Instantané du match sérialisable", "run": _snapshot},
        {"name": "Validation d'un profil invalide", "run": _profile_validation},
        {"name": "Actions manette/clavier présentes", "run": _input_map},
        {"name": "Deux modèles 3D et quatre animations intégrés", "run": _assets},
    ]
    var lines: Array[String] = []
    var passed: int = 0
    for entry: Dictionary in cases:
        var callback: Callable = entry["run"]
        var ok: bool = callback.call()
        if ok:
            passed += 1
        lines.append(("OK   " if ok else "ÉCHEC   ") + String(entry["name"]))
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func _ticks(session: IEGTrainingSession, count: int, command: IEGGameCommand = null) -> void:
    if command == null:
        command = Command.new()
    for _tick: int in range(count):
        session.step(command)

func _has_event(session: IEGTrainingSession, kind: int) -> bool:
    for event: Dictionary in session.events:
        if int(event["kind"]) == kind:
            return true
    return false

func _initial_state() -> bool:
    var session: IEGTrainingSession = Session.new()
    return session.players.size() == 3 and session.controlled_id == 7 and session.ball.owner_id == 7

func _idle() -> bool:
    var session: IEGTrainingSession = Session.new()
    _ticks(session, 120)
    return session.controlled().position.is_equal_approx(Vector2(0.0, 8.0))

func _diagonal() -> bool:
    var a: IEGTrainingSession = Session.new()
    var b: IEGTrainingSession = Session.new()
    var straight: IEGGameCommand = Command.new()
    straight.move = Vector2(1.0, 0.0)
    var diagonal: IEGGameCommand = Command.new()
    diagonal.move = Vector2(1.0, -1.0)
    _ticks(a, 50, straight)
    _ticks(b, 50, diagonal)
    return absf(a.controlled().velocity.length() - b.controlled().velocity.length()) < 0.001

func _analog() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2(0.25, 0.0)
    _ticks(session, 80, command)
    return absf(session.controlled().velocity.length() - session.controlled().profile.run_speed * 0.25) < 0.01

func _sprint_speed() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2(1.0, 0.0)
    command.sprint = true
    _ticks(session, 30, command)
    return session.controlled().velocity.length() > session.controlled().profile.run_speed + 1.0

func _energy() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2(1.0, 0.0)
    command.sprint = true
    _ticks(session, 60, command)
    var spent: float = session.controlled().energy
    _ticks(session, 60)
    return spent < 85.0 and session.controlled().energy > spent

func _bounds() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2(1.0, 1.0)
    _ticks(session, 900, command)
    var point: Vector2 = session.controlled().position
    return absf(point.x) < Rules.HALF_WIDTH and absf(point.y) < Rules.HALF_LENGTH

func _switch_owner() -> bool:
    var session: IEGTrainingSession = Session.new()
    var before: Vector3 = session.ball.position
    var command: IEGGameCommand = Command.new()
    command.switch_player = true
    session.step(command)
    return session.controlled_id == 8 and session.ball.owner_id == 7 and session.ball.position.distance_to(before) < 0.01

func _switch_cycle() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.switch_player = true
    _ticks(session, 3, command)
    return session.controlled_id == 7

func _pass_target() -> bool:
    var session: IEGTrainingSession = Session.new()
    return (session.suggested_pass_target(Vector2(-5.0, -6.0)).get_id() == 8
        and session.suggested_pass_target(Vector2(5.0, -9.0)).get_id() == 10)

func _pass_release() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.pass_ball = true
    command.aim = Vector2(-5.0, -6.0)
    session.step(command)
    return (session.ball.owner_id == -1 and session.ball.mode == BallState.Mode.PASS
        and session.controlled_id == 8 and _has_event(session, Session.EventKind.PASS))

func _pass_reception() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.pass_ball = true
    command.aim = Vector2(-5.0, -6.0)
    session.step(command)
    _ticks(session, 120)
    return session.ball.owner_id == 8

func _shot() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.shoot = true
    command.shot_charge = 0.5
    session.step(command)
    return session.ball.owner_id == -1 and _has_event(session, Session.EventKind.SHOT)

func _charge_power() -> bool:
    var weak: IEGTrainingSession = Session.new()
    var strong: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.shoot = true
    weak.step(command)
    command.shot_charge = 1.0
    strong.step(command)
    return strong.ball.velocity.length() > weak.ball.velocity.length() + 10.0

func _cannot_shoot_without_ball() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.switch_player = true
    session.step(command)
    command.switch_player = false
    command.shoot = true
    session.step(command)
    return session.ball.owner_id == 7 and not _has_event(session, Session.EventKind.SHOT)

func _swept_goal() -> bool:
    return Rules.crosses_goal(Vector3(0.0, 1.0, -17.0), Vector3(0.0, 1.0, -22.0))

func _full_crossing() -> bool:
    return not Rules.crosses_goal(Vector3(0.0, 1.0, -17.0), Vector3(0.0, 1.0, -18.1))

func _missed_goal() -> bool:
    return (not Rules.crosses_goal(Vector3(0.0, 3.0, -17.0), Vector3(0.0, 3.0, -22.0))
        and not Rules.crosses_goal(Vector3(4.0, 1.0, -17.0), Vector3(4.0, 1.0, -22.0)))

func _both_goals() -> bool:
    return (_swept_goal() and Rules.crosses_goal(Vector3(0.0, 1.0, 17.0), Vector3(0.0, 1.0, 22.0))
        and not Rules.crosses_goal(Vector3(0.0, 1.0, -22.0), Vector3(0.0, 1.0, -17.0)))

func _single_goal() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.shoot = true
    command.shot_charge = 1.0
    session.step(command)
    _ticks(session, 240)
    return session.goals == 1 and session.ball.owner_id == 7

func _out_reset() -> bool:
    var session: IEGTrainingSession = Session.new()
    session.ball.owner_id = -1
    session.ball.position = Vector3(13.0, 0.19, 0.0)
    session.step(Command.new())
    var out_seen: bool = _has_event(session, Session.EventKind.OUT)
    _ticks(session, 70)
    return out_seen and session.ball.owner_id == 7 and session.goals == 0

func _reset_score() -> bool:
    var session: IEGTrainingSession = Session.new()
    session.ball.owner_id = -1
    session.ball.position = Vector3(0.0, 0.19, -17.9)
    session.ball.velocity = Vector3(0.0, 0.0, -90.0)
    session.step(Command.new())
    var command: IEGGameCommand = Command.new()
    command.reset_drill = true
    session.step(command)
    return session.goals == 1 and session.controlled_id == 7 and not session.is_resetting()

func _swept_reception() -> bool:
    var session: IEGTrainingSession = Session.new()
    session.ball.owner_id = -1
    session.ball.position = Vector3(3.0, 0.19, -1.0)
    session.ball.velocity = Vector3(240.0, 0.0, 0.0)
    session.step(Command.new())
    return session.ball.owner_id == 10

func _high_ball() -> bool:
    var session: IEGTrainingSession = Session.new()
    session.ball.owner_id = -1
    session.ball.position = Vector3(0.0, 2.0, 8.0)
    session.step(Command.new())
    return session.ball.owner_id == -1

func _nonfinite() -> bool:
    var session: IEGTrainingSession = Session.new()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2(INF, NAN)
    command.aim = Vector2(INF, INF)
    command.shoot = true
    command.shot_charge = INF
    session.step(command)
    return session.controlled().position.is_finite() and session.ball.velocity.is_finite()

func _command_roundtrip() -> bool:
    var original: IEGGameCommand = Command.new()
    original.move = Vector2(0.3, -0.4)
    original.shoot = true
    original.shot_charge = 0.7
    var restored: IEGGameCommand = Command.from_dict(original.to_dict())
    var invalid: IEGGameCommand = Command.from_dict({"move": ["bad", 0.0], "shot_charge": INF})
    return (restored.move.is_equal_approx(original.move) and restored.shoot
        and is_equal_approx(restored.shot_charge, 0.7)
        and invalid.move == Vector2.ZERO and invalid.shot_charge == 0.0)

func _snapshot() -> bool:
    var session: IEGTrainingSession = Session.new()
    var restored: Variant = JSON.parse_string(JSON.stringify(session.make_snapshot()))
    return restored is Dictionary and restored.has("players") and restored["players"].size() == 3

func _profile_validation() -> bool:
    var profile: IEGPlayerProfile = Profile.new()
    profile.run_speed = -2.0
    return not profile.is_valid()

func _input_map() -> bool:
    for action: String in ["move_left", "move_right", "move_forward", "move_back",
            "look_left", "look_right", "look_up", "look_down", "sprint", "pass_ball",
            "shoot", "switch_player", "recenter", "reset_drill", "pause", "zoom_in", "zoom_out"]:
        if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
            return false
    var keyboard: bool = false
    var gamepad: bool = false
    for event: InputEvent in InputMap.action_get_events("pass_ball"):
        keyboard = keyboard or event is InputEventKey
        gamepad = gamepad or event is InputEventJoypadButton
    return keyboard and gamepad

func _assets() -> bool:
    var player_scene: PackedScene = load("res://assets/characters/footballer.glb")
    var ball_scene: PackedScene = load("res://assets/ball/football.glb")
    if player_scene == null or ball_scene == null:
        return false
    var model: Node = player_scene.instantiate()
    var animations: Array[String] = []
    _find_clips(model, animations)
    model.free()
    for expected: String in ["idle", "walk", "run", "kick"]:
        if not animations.has(expected):
            return false
    return true

func _find_clips(node: Node, result: Array[String]) -> void:
    if node is AnimationPlayer:
        for clip: StringName in node.get_animation_list():
            result.append(String(clip).get_file().to_lower())
    for child: Node in node.get_children():
        _find_clips(child, result)
