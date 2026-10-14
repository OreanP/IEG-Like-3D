extends RefCounted
## Régressions de la première livraison. Exécution uniquement par Godot.
const Session = preload("res://core/training_session.gd")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")
const Collective = preload("res://core/ai/collective_brain.gd")
const Keeper = preload("res://core/ai/goalkeeper_brain.gd")
const LocalInput = preload("res://scripts/input/local_player_input.gd")
const BlueKeeper = preload("res://assets/players/keeper_blue.tres")
const RedKeeper = preload("res://assets/players/keeper_red.tres")
const Defender = preload("res://assets/players/defender_21.tres")

func run_all() -> Dictionary:
    var cases: Array[Callable] = [_targeted_pass, _reject_enemy_target, _reject_self_target,
        _reject_missing_target, _lob_clearance, _lob_reception, _command_roundtrip,
        _allied_tackle_selects, _allied_interception_selects, _enemy_tackle_never_selects,
        _capture_blue, _capture_red, _deflect_blue, _deflect_red, _high_keeper_ball,
        _swept_save_before_goal, _already_crossed_goal, _keeper_release, _keeper_protection,
        _enemy_keeper_release, _allied_ai_cannot_kick, _collective_read_only,
        _support_spacing, _single_chaser, _keeper_stays_in_area, _target_cycle,
        _input_bindings, _deterministic_replay, _keeper_snapshot,
        _collision_order, _nonfinite_commands, _scene_roster, _goal_after_deflection]
    var lines: Array[String] = []
    var passed: int = 0
    for test: Callable in cases:
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "DEV : " + String(test.get_method()))
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func fixture() -> IEGTrainingSession:
    var profiles: Array[IEGPlayerProfile] = Session.default_profiles()
    profiles.append(Defender)
    profiles.append(BlueKeeper)
    profiles.append(RedKeeper)
    return Session.new(profiles, [Vector2(0, 8), Vector2(-5, 2), Vector2(5, -1),
        Vector2(6, -8), Vector2(0, 16.2), Vector2(0, -16.2)],
        [0, 0, 0, 1, 0, 1], [false, false, false, false, true, true])

func has_event(session: IEGTrainingSession, kind: int) -> bool:
    for event: Dictionary in session.events:
        if event["kind"] == kind:
            return true
    return false

func _targeted_pass() -> bool:
    var s: IEGTrainingSession = Session.new()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.pass_target_id = 8
    c.aim = Vector2.RIGHT # La cible explicite prime sur la direction.
    s.step(c)
    return has_event(s, Session.EventKind.PASS) and s.events.back()["target_id"] == 8 and s.ball.velocity.x < 0.0

func _reject_enemy_target() -> bool:
    var s: IEGTrainingSession = fixture()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.pass_target_id = 21
    s.step(c)
    return s.ball.owner_id == 7 and s.controlled_id == 7 and not has_event(s, Session.EventKind.PASS)

func _reject_self_target() -> bool:
    var s: IEGTrainingSession = fixture()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.pass_target_id = 7
    s.step(c)
    return s.ball.owner_id == 7

func _reject_missing_target() -> bool:
    var s: IEGTrainingSession = fixture()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.pass_target_id = 999
    s.step(c)
    return s.ball.owner_id == 7

func _lob_clearance() -> bool:
    var s: IEGTrainingSession = Session.new()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.lob_pass = true
    c.pass_target_id = 8
    s.step(c)
    for _tick: int in range(15):
        s.step(Command.new())
    return s.ball.owner_id < 0 and s.ball.position.y > 0.95

func _lob_reception() -> bool:
    var s: IEGTrainingSession = Session.new()
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.lob_pass = true
    c.pass_target_id = 8
    s.step(c)
    for _tick: int in range(120):
        s.step(Command.new())
    return s.ball.owner_id == 8 and s.controlled_id == 8

func _command_roundtrip() -> bool:
    var c: IEGGameCommand = Command.new()
    c.pass_target_id = 8
    c.lob_pass = true
    c.tackle = true
    var restored: IEGGameCommand = Command.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
    return restored.pass_target_id == 8 and restored.lob_pass and restored.tackle and Command.from_dict({"pass_target_id": "enemy"}).pass_target_id == -1

func _allied_tackle_selects() -> bool:
    var s: IEGTrainingSession = fixture()
    s.get_player(8).position = Vector2(6, -7)
    s.ball.owner_id = 21
    var c: IEGGameCommand = Command.new()
    c.tackle = true
    s.step(Command.new(), {8: c})
    return s.ball.owner_id == 8 and s.controlled_id == 8 and has_event(s, Session.EventKind.TACKLE_WON)

func _allied_interception_selects() -> bool:
    var s: IEGTrainingSession = fixture()
    s.ball.owner_id = -1
    s.ball.position = Vector3(-6, 0.19, 2)
    s.ball.velocity = Vector3(120, 0, 0)
    s._last_kicker = 21
    s.step(Command.new())
    return s.ball.owner_id == 8 and s.controlled_id == 8 and has_event(s, Session.EventKind.INTERCEPTION)

func _enemy_tackle_never_selects() -> bool:
    var s: IEGTrainingSession = fixture()
    s.get_player(21).position = Vector2(0, 7)
    var c: IEGGameCommand = Command.new()
    c.tackle = true
    c.aim = Vector2.DOWN
    s.step(Command.new(), {21: c})
    return s.ball.owner_id == 21 and s.controlled_id == 7

func save_fixture(team: int, speed: float = 12.0, height: float = 0.8) -> IEGTrainingSession:
    var s: IEGTrainingSession = fixture()
    var side: float = 1.0 if team == 0 else -1.0
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, height, side * 15.0)
    s.ball.velocity = Vector3(0, 0, side * speed)
    s.step(Command.new())
    return s

func _capture_blue() -> bool:
    var s: IEGTrainingSession = save_fixture(0)
    return s.ball.owner_id == 1 and s.controlled_id == 1 and has_event(s, Session.EventKind.KEEPER_CAPTURE)

func _capture_red() -> bool:
    var s: IEGTrainingSession = save_fixture(1)
    return s.ball.owner_id == 31 and s.controlled_id == 7 and has_event(s, Session.EventKind.KEEPER_CAPTURE)

func _deflect_blue() -> bool:
    var s: IEGTrainingSession = save_fixture(0, 30.0)
    return s.ball.owner_id < 0 and s.controlled_id == 7 and s.ball.velocity.z < 0.0 and has_event(s, Session.EventKind.KEEPER_DEFLECTION)

func _deflect_red() -> bool:
    var s: IEGTrainingSession = save_fixture(1, 30.0)
    return s.ball.owner_id < 0 and s.controlled_id == 7 and s.ball.velocity.z > 0.0 and has_event(s, Session.EventKind.KEEPER_DEFLECTION)

func _high_keeper_ball() -> bool:
    var s: IEGTrainingSession = save_fixture(0, 12.0, 3.0)
    return s.ball.owner_id < 0 and not has_event(s, Session.EventKind.KEEPER_CAPTURE) and not has_event(s, Session.EventKind.KEEPER_DEFLECTION)

func _swept_save_before_goal() -> bool:
    var s: IEGTrainingSession = fixture()
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, 0.8, -15)
    s.ball.velocity = Vector3(0, 0, -300)
    s.step(Command.new())
    return s.goals == 0 and has_event(s, Session.EventKind.KEEPER_DEFLECTION)

func _already_crossed_goal() -> bool:
    var s: IEGTrainingSession = fixture()
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, 0.8, -17.9)
    s.ball.velocity = Vector3(0, 0, -90)
    s.step(Command.new())
    return s.goals == 1 and not has_event(s, Session.EventKind.KEEPER_CAPTURE)

func _keeper_release() -> bool:
    var s: IEGTrainingSession = save_fixture(0)
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.lob_pass = true
    c.pass_target_id = 8
    s.step(c)
    return s.ball.owner_id < 0 and s.ball.velocity.z < 0.0 and has_event(s, Session.EventKind.KEEPER_RELEASE)

func _keeper_protection() -> bool:
    var s: IEGTrainingSession = save_fixture(0)
    s.get_player(21).position = Vector2(0, 15.3)
    var c: IEGGameCommand = Command.new()
    c.tackle = true
    c.aim = Vector2.DOWN
    for _tick: int in range(60):
        s.step(Command.new(), {21: c})
    return s.ball.owner_id == 1 and s.controlled_id == 1

func _enemy_keeper_release() -> bool:
    var s: IEGTrainingSession = save_fixture(1)
    var brain: IEGGoalkeeperBrain = Keeper.new()
    for _tick: int in range(50):
        s.step(Command.new(), {31: brain.decide(s, s.get_player(31))})
        if has_event(s, Session.EventKind.KEEPER_RELEASE):
            return s.ball.owner_id < 0 and s.controlled().team_id == 0
    return false

func _allied_ai_cannot_kick() -> bool:
    var s: IEGTrainingSession = fixture()
    # Possession déjà établie d'un joueur non sélectionné : l'IA ne joue pas la passe.
    s.ball.owner_id = 8
    var c: IEGGameCommand = Command.new()
    c.pass_ball = true
    c.shoot = true
    s.step(Command.new(), {8: c})
    return s.ball.owner_id == 8 and not has_event(s, Session.EventKind.PASS) and not has_event(s, Session.EventKind.SHOT)

func _collective_read_only() -> bool:
    var s: IEGTrainingSession = fixture()
    var before: String = JSON.stringify(s.make_snapshot())
    var brain: IEGCollectiveBrain = Collective.new()
    var keeper: IEGGoalkeeperBrain = Keeper.new()
    for player: IEGPlayerState in s.players:
        var c: IEGGameCommand = keeper.decide(s, player) if player.is_goalkeeper else brain.decide(s, player)
        if player.team_id == 0 and (c.pass_ball or c.shoot):
            return false
    return before == JSON.stringify(s.make_snapshot())

func _support_spacing() -> bool:
    var s: IEGTrainingSession = fixture()
    var brain: IEGCollectiveBrain = Collective.new()
    for _tick: int in range(600):
        s.step(Command.new(), {8: brain.decide(s, s.get_player(8)), 10: brain.decide(s, s.get_player(10))})
    return s.get_player(8).position.distance_to(s.get_player(10).position) > 6.0 and s.get_player(8).position.distance_to(s.get_player(7).position) > 3.0 and s.get_player(10).position.distance_to(s.get_player(7).position) > 3.0

func _single_chaser() -> bool:
    var s: IEGTrainingSession = fixture()
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, 0.19, 8)
    var brain: IEGCollectiveBrain = Collective.new()
    var left: IEGGameCommand = brain.decide(s, s.get_player(8))
    var right: IEGGameCommand = brain.decide(s, s.get_player(10))
    return absf(left.move.x) < 0.01 and absf(right.move.x) < 0.01

func _keeper_stays_in_area() -> bool:
    var s: IEGTrainingSession = save_fixture(0)
    var c: IEGGameCommand = Command.new()
    c.move = Vector2(1, -1)
    for _tick: int in range(600):
        s.step(c)
    return absf(s.get_player(1).position.x) <= 4.0 and s.get_player(1).position.y >= 12.0

func _target_cycle() -> bool:
    var s: IEGTrainingSession = fixture()
    var input: IEGLocalPlayerInput = LocalInput.new()
    var selected: Array[int] = []
    for _i: int in range(4):
        input.cycle_pass_target(s)
        selected.append(input.pass_target_id)
    input.free()
    return selected == [8, 10, 1, -1]

func _input_bindings() -> bool:
    for action: String in ["tackle", "lob_pass", "pass_target_next"]:
        var key: bool = false
        var pad: bool = false
        for event: InputEvent in InputMap.action_get_events(action):
            key = key or event is InputEventKey
            pad = pad or event is InputEventJoypadButton
        if not key or not pad:
            return false
    return true

func _deterministic_replay() -> bool:
    var a: IEGTrainingSession = fixture()
    var b: IEGTrainingSession = fixture()
    var brain: IEGCollectiveBrain = Collective.new()
    for tick: int in range(240):
        var c: IEGGameCommand = Command.new()
        c.move = Vector2(sin(tick * 0.02), -0.4)
        for s: IEGTrainingSession in [a, b]:
            s.step(Command.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))), {8: brain.decide(s, s.get_player(8)), 10: brain.decide(s, s.get_player(10))})
    return JSON.stringify(a.make_snapshot()) == JSON.stringify(b.make_snapshot())

func _keeper_snapshot() -> bool:
    var s: IEGTrainingSession = save_fixture(0)
    var data: Variant = JSON.parse_string(JSON.stringify(s.make_snapshot()))
    return data["players"][4]["is_goalkeeper"] and data["ball"]["owner_id"] == data["controlled_id"]

func _collision_order() -> bool:
    var s: IEGTrainingSession = Session.new()
    s.get_player(8).position = Vector2(3, 0)
    s.get_player(10).position = Vector2(1, 0)
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, 0.19, 0)
    s.ball.velocity = Vector3(240, 0, 0)
    s.step(Command.new())
    return s.ball.owner_id == 10 and s.controlled_id == 10

func _nonfinite_commands() -> bool:
    var s: IEGTrainingSession = fixture()
    var c: IEGGameCommand = Command.new()
    c.move = Vector2(NAN, INF)
    c.aim = Vector2(INF, NAN)
    s.step(c, {21: c})
    return s.controlled().position.is_finite() and s.get_player(21).position.is_finite()

func _scene_roster() -> bool:
    var scene: PackedScene = load("res://scenes/training_ground.tscn")
    var root: Node = scene.instantiate()
    var teams: Array[int] = [0, 0]
    var keepers: Array[int] = [0, 0]
    var ids: Array[int] = []
    var valid: bool = true
    for player: IEGPlayerView in root.get_node("Players").get_children():
        teams[player.team_id] += 1
        keepers[player.team_id] += 1 if player.is_goalkeeper else 0
        valid = valid and not ids.has(player.profile.player_id)
        ids.append(player.profile.player_id)
    root.free()
    return valid and teams == [4, 3] and keepers == [1, 1]

func _goal_after_deflection() -> bool:
    var s: IEGTrainingSession = save_fixture(1, 30.0)
    if not has_event(s, Session.EventKind.KEEPER_DEFLECTION):
        return false
    # Après une déviation, le ballon reste susceptible de rentrer (pas d'arrêt magique).
    s.ball.position = Vector3(2.0, 0.8, -17.9)
    s.ball.velocity = Vector3(0, 0, -90)
    s.step(Command.new())
    return s.goals == 1 and s.team_goals == [1, 0] and s.controlled_id == 7
