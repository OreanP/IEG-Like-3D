class_name IEGTrainingSession
extends RefCounted
## Autorité locale de l'entraînement S0. Ni Input, ni Node, ni animation.
## step() est appelé exactement une fois par tick physique, à 60 Hz.
## Ce n'est pas encore le moteur d'un match à onze contre onze.

const Rules = preload("res://core/training_rules.gd")
const Command = preload("res://core/game_command.gd")
const PlayerState = preload("res://core/player_state.gd")
const BallState = preload("res://core/ball_state.gd")
const Profile = preload("res://core/player_profile.gd")

enum EventKind { PASS, SHOT, RECEPTION, GOAL, OUT, RESET, SELECTION }

var players: Array[IEGPlayerState] = []
var events: Array[Dictionary] = []
var ball: IEGBallState = BallState.new()
var controlled_id: int = 7
var goals: int = 0
var tick_number: int = 0
var _reset_timer: float = 0.0
var _since_kick: float = 10.0
var _last_kicker: int = -1

func _init(profiles: Array[IEGPlayerProfile] = []) -> void:
    var roster: Array[IEGPlayerProfile] = profiles.duplicate()
    if not _valid_roster(roster):
        if not roster.is_empty():
            push_warning("Effectif S0 invalide : utilisation des trois profils par défaut.")
        roster = default_profiles()
    var spawns: Array[Vector2] = [Vector2(0.0, 8.0), Vector2(-5.0, 2.0), Vector2(5.0, -1.0)]
    for index: int in range(roster.size()):
        players.append(PlayerState.new(roster[index], spawns[index]))
    _reset_positions()
    events.clear()

static func default_profiles() -> Array[IEGPlayerProfile]:
    var result: Array[IEGPlayerProfile] = []
    var ids: Array[int] = [7, 8, 10]
    var skins: Array[String] = ["a9663f", "e6ad82", "6e3f2b"]
    for index: int in range(3):
        var profile: IEGPlayerProfile = Profile.new()
        profile.player_id = ids[index]
        profile.shirt_number = ids[index]
        profile.display_name = "Joueur %02d" % ids[index]
        profile.skin_color = Color(skins[index])
        result.append(profile)
    return result

static func _valid_roster(roster: Array[IEGPlayerProfile]) -> bool:
    if roster.size() != 3:
        return false
    var ids: Array[int] = []
    for profile: IEGPlayerProfile in roster:
        if profile == null or not profile.is_valid() or profile.player_id in ids:
            return false
        ids.append(profile.player_id)
    return true

func get_player(player_id: int) -> IEGPlayerState:
    for player: IEGPlayerState in players:
        if player.get_id() == player_id:
            return player
    return null

func controlled() -> IEGPlayerState:
    return get_player(controlled_id)

func is_resetting() -> bool:
    return _reset_timer > 0.0

func suggested_pass_target(aim: Vector2) -> IEGPlayerState:
    var actor: IEGPlayerState = controlled()
    var direction: Vector2 = Rules.direction(aim, actor.facing)
    var best: IEGPlayerState = null
    var best_score: float = -INF
    for other: IEGPlayerState in players:
        if other.get_id() == actor.get_id():
            continue
        var offset: Vector2 = other.position - actor.position
        var distance: float = offset.length()
        var alignment: float = direction.dot(offset / distance) if distance > 0.01 else -1.0
        var score: float = alignment * 3.0 - distance * 0.035
        if score > best_score:
            best_score = score
            best = other
    return best

func step(command: IEGGameCommand) -> void:
    if command == null:
        command = Command.new()
    tick_number += 1
    events.clear()
    if command.reset_drill:
        _reset_positions()
        return
    if _reset_timer > 0.0:
        _reset_timer -= Rules.TICK
        if _reset_timer <= 0.0:
            _reset_positions()
        return
    if command.switch_player:
        var index: int = players.find(controlled())
        controlled_id = players[(index + 1) % players.size()].get_id()
        _emit(EventKind.SELECTION, controlled_id)
    _advance_players(command)
    _since_kick += Rules.TICK
    if ball.owner_id >= 0:
        _follow_owner()
        if ball.owner_id == controlled_id and not command.switch_player:
            if command.pass_ball:
                _pass(command.aim)
            elif command.shoot:
                _shoot(command.aim, command.shot_charge)
    if ball.owner_id < 0:
        _advance_ball()

func _advance_players(command: IEGGameCommand) -> void:
    var move: Vector2 = Rules.limit_input(command.move)
    for player: IEGPlayerState in players:
        var active: bool = player.get_id() == controlled_id
        var moving: bool = active and move.length_squared() > 0.001
        if player.energy <= 1.0:
            player.sprint_exhausted = true
        elif player.energy >= 20.0:
            player.sprint_exhausted = false
        var sprinting: bool = moving and command.sprint and not player.sprint_exhausted
        var speed: float = player.profile.sprint_speed if sprinting else player.profile.run_speed
        var target: Vector2 = move * speed if active else Vector2.ZERO
        player.velocity = player.velocity.lerp(target, 1.0 - exp(-13.0 * Rules.TICK))
        player.position += player.velocity * Rules.TICK
        player.position = _clamp_player(player.position)
        if moving:
            player.facing = move.normalized()
        var energy_rate: float = -19.0 if sprinting else 11.0
        player.energy = clampf(player.energy + energy_rate * Rules.TICK, 0.0, 100.0)
    _separate_players()

func _clamp_player(value: Vector2) -> Vector2:
    return value.clamp(Vector2(-Rules.HALF_WIDTH + 0.6, -Rules.HALF_LENGTH + 0.6),
        Vector2(Rules.HALF_WIDTH - 0.6, Rules.HALF_LENGTH - 0.6))

func _separate_players() -> void:
    for i: int in range(players.size()):
        for j: int in range(i + 1, players.size()):
            var offset: Vector2 = players[j].position - players[i].position
            var distance: float = offset.length()
            var minimum: float = Rules.PLAYER_RADIUS * 2.0
            if distance >= minimum:
                continue
            var direction: Vector2 = offset / distance if distance > 0.001 else Vector2.RIGHT
            var correction: Vector2 = direction * ((minimum - distance) * 0.5)
            players[i].position -= correction
            players[j].position += correction
    for player: IEGPlayerState in players:
        player.position = _clamp_player(player.position)

func _follow_owner() -> void:
    var owner: IEGPlayerState = get_player(ball.owner_id)
    if owner == null:
        ball.owner_id = -1
        ball.mode = BallState.Mode.FREE
        return
    var bounce: float = 0.045 * sin(float(tick_number) * 0.32)
    bounce *= clampf(owner.velocity.length() / 5.0, 0.0, 1.0)
    ball.position = Rules.on_ground(owner.position + owner.facing * (0.61 + bounce))
    ball.velocity = Rules.on_ground(owner.velocity, 0.0)

func _pass(aim: Vector2) -> void:
    var actor: IEGPlayerState = controlled()
    var receiver: IEGPlayerState = suggested_pass_target(aim)
    if receiver == null:
        return
    # Point choisi au départ : aucune poursuite magique de la cible ensuite.
    var target: Vector2 = receiver.position + receiver.velocity * 0.22
    var direction: Vector2 = Rules.direction(target - actor.position, actor.facing)
    actor.facing = direction
    _follow_owner()
    var speed: float = clampf(actor.position.distance_to(target) * 1.2, 11.0, 21.0)
    _release(actor.get_id(), BallState.Mode.PASS, Rules.on_ground(direction * speed, 0.0))
    controlled_id = receiver.get_id()
    _emit(EventKind.PASS, actor.get_id(), receiver.get_id())

func _shoot(aim: Vector2, charge: float) -> void:
    var actor: IEGPlayerState = controlled()
    charge = clampf(charge, 0.0, 1.0) if is_finite(charge) else 0.0
    var direction: Vector2 = Rules.direction(aim, actor.facing)
    actor.facing = direction
    _follow_owner()
    var speed: float = 13.0 + charge * 16.0
    _release(actor.get_id(), BallState.Mode.SHOT,
        Rules.on_ground(direction * speed, 0.8 + charge * 2.0))
    _emit(EventKind.SHOT, actor.get_id())

func _release(actor_id: int, mode: IEGBallState.Mode, velocity: Vector3) -> void:
    ball.owner_id = -1
    ball.mode = mode
    ball.velocity = velocity
    _last_kicker = actor_id
    _since_kick = 0.0

func _advance_ball() -> void:
    var before: Vector3 = ball.position
    var velocity: Vector3 = ball.velocity
    if before.y > Rules.BALL_RADIUS + 0.001 or velocity.y > 0.0:
        velocity.y -= Rules.GRAVITY * Rules.TICK
    else:
        velocity.y = 0.0
    var next_position: Vector3 = before + velocity * Rules.TICK
    if next_position.y < Rules.BALL_RADIUS:
        next_position.y = Rules.BALL_RADIUS
        velocity.y = -velocity.y * 0.28
        if velocity.y < 0.45:
            velocity.y = 0.0
    var drag: float = 0.32 if next_position.y <= Rules.BALL_RADIUS + 0.01 else 0.03
    velocity.x *= exp(-drag * Rules.TICK)
    velocity.z *= exp(-drag * Rules.TICK)
    ball.position = next_position
    ball.velocity = velocity
    # Ordre temporel : une réception antérieure au passage de la ligne prime.
    var goal_t: float = Rules.goal_crossing_time(before, next_position)
    var first: IEGPlayerState = null
    var first_t: float = INF
    for player: IEGPlayerState in players:
        if player.get_id() == _last_kicker and _since_kick < 0.35:
            continue
        var t: float = Rules.closest_segment_time(Rules.planar(before),
            Rules.planar(next_position), player.position)
        var point: Vector3 = before.lerp(next_position, t)
        if point.y > 0.95 or Rules.planar(point).distance_to(player.position) > 0.64:
            continue
        if t < first_t:
            first = player
            first_t = t
    if first != null and first_t < goal_t:
        ball.owner_id = first.get_id()
        ball.mode = BallState.Mode.HELD
        ball.velocity = Vector3.ZERO
        _follow_owner()
        _emit(EventKind.RECEPTION, first.get_id())
        return
    if is_finite(goal_t):
        goals += 1
        _reset_timer = 1.4
        ball.velocity = Vector3.ZERO
        _emit(EventKind.GOAL, _last_kicker)
        return
    if (absf(next_position.x) > Rules.HALF_WIDTH + 0.3
            or absf(next_position.z) > Rules.HALF_LENGTH + 0.3):
        _reset_timer = 0.9
        ball.velocity = Vector3.ZERO
        _emit(EventKind.OUT, _last_kicker)
        return
    if ball.velocity.length_squared() < 0.12:
        ball.mode = BallState.Mode.FREE

func _reset_positions() -> void:
    for player: IEGPlayerState in players:
        player.reset()
    controlled_id = players[0].get_id()
    ball.owner_id = controlled_id
    ball.mode = BallState.Mode.HELD
    _last_kicker = -1
    _since_kick = 10.0
    _reset_timer = 0.0
    _follow_owner()
    _emit(EventKind.RESET, controlled_id)

func _emit(kind: EventKind, actor_id: int = -1, target_id: int = -1) -> void:
    events.append({"kind": kind, "actor_id": actor_id, "target_id": target_id})

func make_snapshot() -> Dictionary:
    # Sérialisable en JSON ; pas de références de nœuds. Ce n'est pas du réseau actif.
    var states: Array[Dictionary] = []
    for player: IEGPlayerState in players:
        states.append({"id": player.get_id(),
            "position": [player.position.x, player.position.y],
            "velocity": [player.velocity.x, player.velocity.y],
            "facing": [player.facing.x, player.facing.y], "energy": player.energy})
    return {"version": 1, "tick": tick_number, "controlled_id": controlled_id,
        "goals": goals, "players": states,
        "ball": {"owner_id": ball.owner_id, "mode": ball.mode,
            "position": [ball.position.x, ball.position.y, ball.position.z],
            "velocity": [ball.velocity.x, ball.velocity.y, ball.velocity.z]}}
