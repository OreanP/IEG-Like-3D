extends RefCounted
## Tests S1. Les commandes IA sont injectées explicitement, comme dans la scène.

const Session = preload("res://core/training_session.gd")
const Command = preload("res://core/game_command.gd")
const Brain = preload("res://core/ai/defender_brain.gd")
const DuelRules = preload("res://core/duel_rules.gd")
const Rules = preload("res://core/training_rules.gd")
const Defender = preload("res://assets/players/defender_21.tres")

func run_all() -> Dictionary:
    var cases: Array[Dictionary] = [
        {"name": "S1 : effectif à quatre et deux équipes", "run": _four_players},
        {"name": "S1 : positions initiales fournies respectées", "run": _custom_spawns},
        {"name": "S1 : ID dupliqués et équipe absente refusés", "run": _invalid_setup},
        {"name": "S1 : sélection limitée aux alliés", "run": _allied_selection},
        {"name": "S1 : aucune passe vers un adversaire", "run": _allied_pass},
        {"name": "S1 : commande IA fait déplacer le défenseur", "run": _ai_moves},
        {"name": "S1 : l'IA ne modifie pas directement la session", "run": _ai_read_only},
        {"name": "S1 : commande IA ne pilote pas le joueur local", "run": _ai_cannot_control_local},
        {"name": "S1 : IA contre-attaque vers le bon but", "run": _ai_counterattack},
        {"name": "S1 : IA tire via la même commande", "run": _ai_shoots},
        {"name": "S1 : récupération proche et orientée réussie", "run": _tackle_success},
        {"name": "S1 : récupération trop éloignée ratée", "run": _tackle_range},
        {"name": "S1 : récupération mal orientée ratée", "run": _tackle_angle},
        {"name": "S1 : impossible de voler le ballon à un allié", "run": _no_friendly_tackle},
        {"name": "S1 : énergie insuffisante empêche l'action", "run": _tackle_energy},
        {"name": "S1 : délai entre deux récupérations respecté", "run": _tackle_cooldown},
        {"name": "S1 : brève protection du nouveau porteur", "run": _possession_grace},
        {"name": "S1 : récupération de l'IA suit les mêmes règles", "run": _ai_tackles},
        {"name": "S1 : interception sans sélectionner l'adversaire", "run": _interception},
        {"name": "S1 : chaque but incrémente la bonne équipe", "run": _team_scores},
        {"name": "S1 : reset des délais et des positions", "run": _reset},
        {"name": "S1 : commande de récupération sérialisable", "run": _command_roundtrip},
        {"name": "S1 : instantané comporte équipe et délais", "run": _snapshot},
        {"name": "S1 : action récupérer clavier et manette", "run": _tackle_input},
    ]
    var passed: int = 0
    var lines: Array[String] = []
    for entry: Dictionary in cases:
        var callback: Callable = entry["run"]
        var ok: bool = callback.call()
        if ok:
            passed += 1
        lines.append(("OK   " if ok else "ÉCHEC   ") + String(entry["name"]))
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func _session() -> IEGTrainingSession:
    var profiles: Array[IEGPlayerProfile] = Session.default_profiles()
    profiles.append(Defender)
    var starts: Array[Vector2] = [Vector2(0, 8), Vector2(-5, 2), Vector2(5, -1), Vector2(0, -5)]
    var teams: Array[int] = [0, 0, 0, 1]
    return Session.new(profiles, starts, teams)

func _duel() -> IEGTrainingSession:
    var session: IEGTrainingSession = _session()
    session.get_player(7).position = Vector2.ZERO
    session.get_player(8).position = Vector2(-9, 9)
    session.get_player(10).position = Vector2(9, 9)
    session.get_player(21).position = Vector2(0, -1)
    session.ball.owner_id = 21
    return session

func _tackle(aim: Vector2 = Vector2.UP) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    command.tackle = true
    command.aim = aim
    return command

func _has_event(session: IEGTrainingSession, kind: int) -> bool:
    for event: Dictionary in session.events:
        if event["kind"] == kind:
            return true
    return false

func _four_players() -> bool:
    var session: IEGTrainingSession = _session()
    return session.players.size() == 4 and session.get_player(21).team_id == 1 and session.controlled().team_id == 0

func _custom_spawns() -> bool:
    var session: IEGTrainingSession = _session()
    return session.get_player(21).position == Vector2(0, -5) and session.get_player(21).spawn == Vector2(0, -5)

func _invalid_setup() -> bool:
    var profiles: Array[IEGPlayerProfile] = Session.default_profiles()
    var starts: Array[Vector2] = [Vector2.ZERO, Vector2(2, 0), Vector2(4, 0)]
    var teams: Array[int] = [1, 1, 1]
    if Session.valid_setup(profiles, starts, teams):
        return false
    teams = [0, 0, 0]
    profiles[1] = profiles[0]
    return not Session.valid_setup(profiles, starts, teams)

func _allied_selection() -> bool:
    var session: IEGTrainingSession = _session()
    var command: IEGGameCommand = Command.new()
    command.switch_player = true
    for _index: int in range(12):
        session.step(command)
        if session.controlled().team_id != 0:
            return false
    return session.controlled_id == 7

func _allied_pass() -> bool:
    var session: IEGTrainingSession = _session()
    for aim: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
        var target: IEGPlayerState = session.suggested_pass_target(aim)
        if target == null or target.team_id != 0:
            return false
    return true

func _ai_moves() -> bool:
    var session: IEGTrainingSession = _session()
    var brain: IEGDefenderBrain = Brain.new()
    var defender: IEGPlayerState = session.get_player(21)
    var before: Vector2 = defender.position
    for _tick: int in range(30):
        session.step(Command.new(), {21: brain.decide(session, defender)})
    return defender.position.distance_to(before) > 1.0 and defender.energy < 100.0

func _ai_read_only() -> bool:
    var session: IEGTrainingSession = _session()
    var before: String = JSON.stringify(session.make_snapshot())
    var brain: IEGDefenderBrain = Brain.new()
    brain.decide(session, session.get_player(21))
    return JSON.stringify(session.make_snapshot()) == before

func _ai_cannot_control_local() -> bool:
    var session: IEGTrainingSession = _session()
    var command: IEGGameCommand = Command.new()
    command.move = Vector2.RIGHT
    var before: Vector2 = session.controlled().position
    session.step(Command.new(), {7: command})
    return session.controlled().position == before

func _ai_counterattack() -> bool:
    var session: IEGTrainingSession = _session()
    session.ball.owner_id = 21
    var brain: IEGDefenderBrain = Brain.new()
    var command: IEGGameCommand = brain.decide(session, session.get_player(21))
    return command.move.y > 0.0 and not command.sprint

func _ai_shoots() -> bool:
    var session: IEGTrainingSession = _session()
    var defender: IEGPlayerState = session.get_player(21)
    defender.position = Vector2(0, 13)
    session.ball.owner_id = 21
    var brain: IEGDefenderBrain = Brain.new()
    session.step(Command.new(), {21: brain.decide(session, defender)})
    return session.ball.owner_id == -1 and _has_event(session, Session.EventKind.SHOT) and session.controlled_id == 7

func _tackle_success() -> bool:
    var session: IEGTrainingSession = _duel()
    session.step(_tackle())
    return session.ball.owner_id == 7 and _has_event(session, Session.EventKind.TACKLE_WON) and session.controlled().energy < 100.0

func _tackle_range() -> bool:
    var session: IEGTrainingSession = _duel()
    session.get_player(21).position = Vector2(0, -3)
    session.step(_tackle())
    return session.ball.owner_id == 21 and _has_event(session, Session.EventKind.TACKLE_MISSED)

func _tackle_angle() -> bool:
    var session: IEGTrainingSession = _duel()
    session.step(_tackle(Vector2.DOWN))
    return session.ball.owner_id == 21 and _has_event(session, Session.EventKind.TACKLE_MISSED)

func _no_friendly_tackle() -> bool:
    var session: IEGTrainingSession = _duel()
    session.ball.owner_id = 8
    session.step(_tackle())
    return session.ball.owner_id == 8 and session.controlled().tackle_cooldown == 0.0

func _tackle_energy() -> bool:
    var session: IEGTrainingSession = _duel()
    session.controlled().energy = 0.0
    session.step(_tackle())
    return session.ball.owner_id == 21 and not _has_event(session, Session.EventKind.TACKLE_ATTEMPT)

func _tackle_cooldown() -> bool:
    var session: IEGTrainingSession = _duel()
    session.controlled().tackle_cooldown = 0.7
    session.step(_tackle())
    return session.ball.owner_id == 21 and not _has_event(session, Session.EventKind.TACKLE_ATTEMPT)

func _possession_grace() -> bool:
    var session: IEGTrainingSession = _duel()
    session.get_player(21).possession_grace = DuelRules.POSSESSION_GRACE
    session.step(_tackle())
    return session.ball.owner_id == 21 and _has_event(session, Session.EventKind.TACKLE_MISSED)

func _ai_tackles() -> bool:
    var session: IEGTrainingSession = _duel()
    session.ball.owner_id = 7
    var brain: IEGDefenderBrain = Brain.new()
    session.step(Command.new(), {21: brain.decide(session, session.get_player(21))})
    return session.ball.owner_id == 21 and session.controlled_id == 7 and _has_event(session, Session.EventKind.TACKLE_WON)

func _interception() -> bool:
    var session: IEGTrainingSession = _duel()
    session.get_player(7).position = Vector2(0, 6)
    session.ball.owner_id = -1
    session.ball.position = Vector3(0, Rules.BALL_RADIUS, 0)
    session.ball.velocity = Vector3(0, 0, -120)
    session._last_kicker = 7
    session.step(Command.new())
    return session.ball.owner_id == 21 and session.controlled_id == 7 and _has_event(session, Session.EventKind.INTERCEPTION)

func _team_scores() -> bool:
    var session: IEGTrainingSession = _session()
    session.ball.owner_id = -1
    session.ball.position = Vector3(0, Rules.BALL_RADIUS, -17.9)
    session.ball.velocity = Vector3(0, 0, -90)
    session._last_kicker = 21 # But contre son camp : compte pour les bleus.
    session.step(Command.new())
    if session.team_goals != [1, 0]:
        return false
    var reset: IEGGameCommand = Command.new()
    reset.reset_drill = true
    session.step(reset)
    session.ball.owner_id = -1
    session.ball.position = Vector3(0, Rules.BALL_RADIUS, 17.9)
    session.ball.velocity = Vector3(0, 0, 90)
    session.step(Command.new())
    return session.team_goals == [1, 1] and session.goals == 2

func _reset() -> bool:
    var session: IEGTrainingSession = _duel()
    session.step(_tackle())
    var reset: IEGGameCommand = Command.new()
    reset.reset_drill = true
    session.step(reset)
    return session.get_player(21).position == Vector2(0, -5) and session.controlled().tackle_cooldown == 0.0 and session.controlled().possession_grace == 0.0 and session.ball.owner_id == 7

func _command_roundtrip() -> bool:
    var command: IEGGameCommand = _tackle()
    var restored: IEGGameCommand = Command.from_dict(command.to_dict())
    return restored.tackle and not Command.from_dict({}).tackle

func _snapshot() -> bool:
    var data: Dictionary = _session().make_snapshot()
    var last: Dictionary = data["players"][3]
    return data["version"] == 2 and data["team_goals"] == [0, 0] and last["team_id"] == 1 and last.has("tackle_cooldown")

func _tackle_input() -> bool:
    if not InputMap.has_action("tackle"):
        return false
    var keyboard: bool = false
    var gamepad: bool = false
    for event: InputEvent in InputMap.action_get_events("tackle"):
        if event is InputEventKey:
            keyboard = keyboard or event.physical_keycode == KEY_E or event.keycode == KEY_E
        if event is InputEventJoypadButton:
            gamepad = gamepad or event.button_index == JOY_BUTTON_B
    return keyboard and gamepad
