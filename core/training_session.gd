class_name IEGTrainingSession
extends RefCounted
## Autorité locale S1. Ni Input, ni Node, ni animation.
## Le joueur et l'IA fournissent des commandes ; seule la session décide.
## step() est appelé exactement une fois par tick physique, à 60 Hz.
## Ce n'est pas encore le moteur d'un match à onze contre onze.

const Rules = preload("res://core/training_rules.gd")
const DuelRules = preload("res://core/duel_rules.gd")
const Command = preload("res://core/game_command.gd")
const PlayerState = preload("res://core/player_state.gd")
const BallState = preload("res://core/ball_state.gd")
const Profile = preload("res://core/player_profile.gd")

enum EventKind { PASS, SHOT, RECEPTION, GOAL, OUT, RESET, SELECTION,
    TACKLE_ATTEMPT, TACKLE_WON, TACKLE_MISSED, INTERCEPTION,
    KEEPER_CAPTURE, KEEPER_DEFLECTION, KEEPER_RELEASE }

const LOCAL_TEAM: int = 0

var players: Array[IEGPlayerState] = []
var events: Array[Dictionary] = []
var ball: IEGBallState = BallState.new()
var controlled_id: int = 7
var goals: int = 0
var team_goals: Array[int] = [0, 0]
var tick_number: int = 0
var _reset_timer: float = 0.0
var _since_kick: float = 10.0
var _last_kicker: int = -1

func _init(profiles: Array[IEGPlayerProfile] = [],
        start_positions: Array[Vector2] = [], team_ids: Array[int] = [], goalkeeper_roles: Array[bool] = []) -> void:
    var roster: Array[IEGPlayerProfile] = profiles.duplicate()
    var spawns: Array[Vector2] = start_positions.duplicate()
    var teams: Array[int] = team_ids.duplicate()
    if roster.is_empty():
        roster = default_profiles()
    if spawns.is_empty():
        var defaults: Array[Vector2] = [Vector2(0.0, 8.0), Vector2(-5.0, 2.0), Vector2(5.0, -1.0)]
        for index: int in range(roster.size()):
            spawns.append(defaults[index] if index < defaults.size() else Vector2(float(index - 3) * 2.0, -6.0))
    if teams.is_empty():
        for _index: int in range(roster.size()):
            teams.append(LOCAL_TEAM)
    if not valid_setup(roster, spawns, teams):
        push_warning("Effectif S1 invalide : retour aux trois joueurs S0.")
        roster = default_profiles()
        spawns = [Vector2(0.0, 8.0), Vector2(-5.0, 2.0), Vector2(5.0, -1.0)]
        teams = [0, 0, 0]
    for index: int in range(roster.size()):
        var keeper: bool = index < goalkeeper_roles.size() and goalkeeper_roles[index]
        players.append(PlayerState.new(roster[index], spawns[index], teams[index], keeper))
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

static func valid_setup(roster: Array[IEGPlayerProfile],
        spawns: Array[Vector2], teams: Array[int]) -> bool:
    if roster.is_empty() or roster.size() != spawns.size() or roster.size() != teams.size():
        return false
    var ids: Array[int] = []
    var has_local_player: bool = false
    for index: int in range(roster.size()):
        var profile: IEGPlayerProfile = roster[index]
        if profile == null or not profile.is_valid() or profile.player_id in ids:
            return false
        if teams[index] != 0 and teams[index] != 1:
            return false
        if not spawns[index].is_finite():
            return false
        if absf(spawns[index].x) > Rules.HALF_WIDTH - 0.6 or absf(spawns[index].y) > Rules.HALF_LENGTH - 0.6:
            return false
        ids.append(profile.player_id)
        has_local_player = has_local_player or teams[index] == LOCAL_TEAM
    return has_local_player

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
    return _pass_target_for(controlled(), aim)

func _pass_target_for(actor: IEGPlayerState, aim: Vector2) -> IEGPlayerState:
    var direction: Vector2 = Rules.direction(aim, actor.facing)
    var best: IEGPlayerState = null
    var best_score: float = -INF
    for other: IEGPlayerState in players:
        if other.get_id() == actor.get_id() or other.team_id != actor.team_id:
            continue
        var offset: Vector2 = other.position - actor.position
        var distance: float = offset.length()
        var alignment: float = direction.dot(offset / distance) if distance > 0.01 else -1.0
        var score: float = alignment * 3.0 - distance * 0.035
        if score > best_score:
            best_score = score
            best = other
    return best

func step(command: IEGGameCommand, ai_commands: Dictionary = {}) -> void:
    if command == null:
        command = Command.new()
    command = Command.from_dict(command.to_dict())
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
        _select_next_teammate()
    var commands: Dictionary = _commands_for_tick(command, ai_commands)
    _advance_players(commands)
    _since_kick += Rules.TICK
    if ball.owner_id >= 0:
        _follow_owner()
        var owner: IEGPlayerState = get_player(ball.owner_id)
        if owner != null:
            var owner_command: IEGGameCommand = commands[owner.get_id()]
            var selection_changed: bool = owner.team_id == LOCAL_TEAM and command.switch_player
            if not selection_changed and owner.recovery_time <= 0.0:
                if owner_command.pass_ball:
                    _pass(owner, owner_command)
                elif owner_command.shoot:
                    _shoot(owner, owner_command.aim, owner_command.shot_charge)
    # Choix S1 : une passe/un tir déclenché ce tick précède les prises de balle.
    # La protection du nouveau porteur empêche plusieurs vols au même tick.
    for player: IEGPlayerState in players:
        var player_command: IEGGameCommand = commands[player.get_id()]
        if player_command.tackle:
            _try_tackle(player, player_command.aim)
    if ball.owner_id < 0:
        _advance_ball()
    else:
        _follow_owner()

func _select_next_teammate() -> void:
    var teammates: Array[IEGPlayerState] = []
    for player: IEGPlayerState in players:
        if player.team_id == LOCAL_TEAM:
            teammates.append(player)
    var index: int = teammates.find(controlled())
    controlled_id = teammates[(index + 1) % teammates.size()].get_id()
    _emit(EventKind.SELECTION, controlled_id)

func _commands_for_tick(local_command: IEGGameCommand, ai_commands: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for player: IEGPlayerState in players:
        var intent: IEGGameCommand = Command.new()
        if player.get_id() == controlled_id:
            intent = local_command
        else:
            var proposed: Variant = ai_commands.get(player.get_id())
            if proposed is IEGGameCommand:
                intent = Command.from_dict(proposed.to_dict())
            # Même une commande injectée ne permet pas à un allié IA de jouer
            # une passe/un tir. Un gain de possession le sélectionnera ensuite.
            if player.team_id == LOCAL_TEAM:
                intent.pass_ball = false
                intent.shoot = false
        result[player.get_id()] = intent
    return result

func _advance_players(commands: Dictionary) -> void:
    for player: IEGPlayerState in players:
        var command: IEGGameCommand = commands[player.get_id()]
        var move: Vector2 = Rules.limit_input(command.move)
        var moving: bool = move.length_squared() > 0.001
        if player.is_goalkeeper:
            player.keeper_hold_time = player.keeper_hold_time + Rules.TICK if ball.owner_id == player.get_id() else 0.0
        player.tackle_cooldown = maxf(0.0, player.tackle_cooldown - Rules.TICK)
        player.recovery_time = maxf(0.0, player.recovery_time - Rules.TICK)
        player.possession_grace = maxf(0.0, player.possession_grace - Rules.TICK)
        if player.energy <= 1.0:
            player.sprint_exhausted = true
        elif player.energy >= 20.0:
            player.sprint_exhausted = false
        var sprinting: bool = moving and command.sprint and not player.sprint_exhausted and player.recovery_time <= 0.0
        var speed: float = player.profile.sprint_speed if sprinting else player.profile.run_speed
        if player.recovery_time > 0.0:
            speed *= DuelRules.RECOVERY_SPEED_FACTOR
        var target: Vector2 = move * speed
        player.velocity = player.velocity.lerp(target, 1.0 - exp(-13.0 * Rules.TICK))
        player.position = _clamp_player(player.position + player.velocity * Rules.TICK)
        if player.is_goalkeeper:
            var side: float = 1.0 if player.team_id == 0 else -1.0
            player.position.x = clampf(player.position.x, -4.0, 4.0)
            player.position.y = clampf(player.position.y * side, 12.0, 17.4) * side
        if moving:
            player.facing = move.normalized()
        var energy_rate: float = -19.0 if sprinting else 11.0
        player.energy = clampf(player.energy + energy_rate * Rules.TICK, 0.0, 100.0)
    _separate_players()

func _try_tackle(actor: IEGPlayerState, aim: Vector2) -> void:
    var owner: IEGPlayerState = get_player(ball.owner_id)
    if owner == null or owner.team_id == actor.team_id:
        return
    if actor.tackle_cooldown > 0.0 or actor.recovery_time > 0.0:
        return
    if owner.is_goalkeeper and ball.mode == BallState.Mode.HELD:
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
    _gain_possession(actor)
    _follow_owner()
    _emit(EventKind.TACKLE_WON, actor.get_id(), owner.get_id())

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
    ball.position = Rules.on_ground(owner.position + owner.facing * (0.61 + bounce),
        1.1 if owner.is_goalkeeper else Rules.BALL_RADIUS)
    ball.velocity = Rules.on_ground(owner.velocity, 0.0)

func _pass(actor: IEGPlayerState, command: IEGGameCommand) -> void:
    var receiver: IEGPlayerState = null
    if command.pass_target_id >= 0:
        receiver = get_player(command.pass_target_id)
        if receiver == null or receiver == actor or receiver.team_id != actor.team_id:
            return
    else:
        receiver = _pass_target_for(actor, command.aim)
    if receiver == null:
        return
    # Point choisi au départ : aucune poursuite magique de la cible ensuite.
    var target: Vector2 = receiver.position + receiver.velocity * 0.22
    var direction: Vector2 = Rules.direction(target - actor.position, actor.facing)
    actor.facing = direction
    _follow_owner()
    var speed: float = clampf(actor.position.distance_to(target) * 1.2, 11.0, 21.0)
    var velocity: Vector3 = Rules.on_ground(direction * speed, 0.0)
    if command.lob_pass:
        var distance: float = Rules.planar(ball.position).distance_to(target)
        var flight: float = clampf(distance / 11.0, 1.05, 1.7)
        velocity = Rules.on_ground(direction * (distance / flight),
            (Rules.BALL_RADIUS - ball.position.y + 0.5 * Rules.GRAVITY * flight * flight) / flight)
    elif actor.is_goalkeeper:
        ball.position.y = Rules.BALL_RADIUS
    _release(actor.get_id(), BallState.Mode.PASS, velocity)
    if actor.team_id == LOCAL_TEAM:
        controlled_id = receiver.get_id()
    _emit(EventKind.KEEPER_RELEASE if actor.is_goalkeeper else EventKind.PASS, actor.get_id(), receiver.get_id())
    events.back()["lob"] = command.lob_pass

func _shoot(actor: IEGPlayerState, aim: Vector2, charge: float) -> void:
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
        if player.recovery_time > 0.0:
            continue
        var keeper_active: bool = player.is_goalkeeper and _in_keeper_area(player, Rules.planar(before))
        var t: float = Rules.contact_time(before, next_position, player.position,
            1.15 if keeper_active else 0.64, 2.5 if keeper_active else 0.95)
        if t < first_t:
            first = player
            first_t = t
    if first != null and first_t < goal_t:
        var contact: Vector3 = before.lerp(next_position, first_t)
        if first.is_goalkeeper and _in_keeper_area(first, Rules.planar(contact)):
            if velocity.length() <= 18.0 and contact.y <= 1.6:
                _gain_possession(first)
                _follow_owner()
                _emit(EventKind.KEEPER_CAPTURE, first.get_id(), _last_kicker)
            else:
                # Déviation = ballon libre. Aucun changement de sélection.
                var outward: Vector2 = Vector2(0.45 if contact.x >= first.position.x else -0.45,
                    -1.0 if first.team_id == 0 else 1.0).normalized()
                ball.position = Rules.on_ground(first.position + outward * 1.22, maxf(contact.y, Rules.BALL_RADIUS))
                _release(first.get_id(), BallState.Mode.FREE,
                    Rules.on_ground(outward * clampf(velocity.length() * 0.45, 5.0, 14.0), 2.2))
                _emit(EventKind.KEEPER_DEFLECTION, first.get_id())
        else:
            _gain_possession(first)
            _follow_owner()
            var kicker: IEGPlayerState = get_player(_last_kicker)
            var interception: bool = kicker != null and kicker.team_id != first.team_id
            _emit(EventKind.INTERCEPTION if interception else EventKind.RECEPTION, first.get_id(), _last_kicker)
        return
    if is_finite(goal_t):
        goals += 1
        # Le but franchi détermine le score, y compris un but contre son camp.
        var scoring_team: int = 0 if next_position.z < 0.0 else 1
        team_goals[scoring_team] += 1
        _reset_timer = 1.4
        ball.velocity = Vector3.ZERO
        _emit(EventKind.GOAL, _last_kicker)
        events[events.size() - 1]["team_id"] = scoring_team
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
    for player: IEGPlayerState in players:
        if player.team_id == LOCAL_TEAM:
            controlled_id = player.get_id()
            break
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
        states.append({"id": player.get_id(), "team_id": player.team_id,
            "tackle_cooldown": player.tackle_cooldown, "recovery_time": player.recovery_time,
            "possession_grace": player.possession_grace,
            "is_goalkeeper": player.is_goalkeeper, "keeper_hold_time": player.keeper_hold_time,
            "position": [player.position.x, player.position.y],
            "velocity": [player.velocity.x, player.velocity.y],
            "facing": [player.facing.x, player.facing.y], "energy": player.energy})
    return {"version": 2, "tick": tick_number, "controlled_id": controlled_id,
        "goals": goals, "team_goals": team_goals.duplicate(), "players": states,
        "ball": {"owner_id": ball.owner_id, "mode": ball.mode,
            "position": [ball.position.x, ball.position.y, ball.position.z],
            "velocity": [ball.velocity.x, ball.velocity.y, ball.velocity.z]}}

func _in_keeper_area(keeper: IEGPlayerState, point: Vector2) -> bool:
    var side: float = 1.0 if keeper.team_id == 0 else -1.0
    return absf(point.x) <= 4.5 and point.y * side >= 12.0 and point.y * side <= Rules.HALF_LENGTH + Rules.BALL_RADIUS

func _gain_possession(player: IEGPlayerState) -> void:
    ball.owner_id = player.get_id()
    ball.mode = BallState.Mode.HELD
    ball.velocity = Vector3.ZERO
    player.possession_grace = DuelRules.POSSESSION_GRACE
    player.keeper_hold_time = 0.0
    if player.team_id == LOCAL_TEAM:
        controlled_id = player.get_id()
