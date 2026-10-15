class_name IEGMatchSession
extends IEGTrainingSession
## Autorité de match : horloge, phases, duels et contenu sont indépendants du rendu.
const Catalog = preload("res://core/content/technique_catalog.gd")

enum Phase { LIVE, DUEL_CHOICE, CINEMATIC, HALFTIME, FINISHED }
const MODIFIER_LIMIT_PER_TEAM: int = 3
const MODIFIER_CATEGORIES: Array[String] = ["KARMA", "RESONANCE"]
const CHOICES: Array[String] = ["left", "right", "special"]
var phase: Phase = Phase.LIVE
var period: int = 1
var elapsed_half: float = 0.0
var half_duration: float = 300.0
var team_names: Array[String] = ["Azur", "Carmin"]
var winner_team: int = -1
var duel: Dictionary = {}
var cinematic_elapsed: float = 0.0
var formations: Dictionary = {0: "balanced", 1: "balanced"}
var tactics: Dictionary = {0: "", 1: ""}
var tactic_time: Dictionary = {0: 0.0, 1: 0.0}
var modifier_error: String = ""
var catalog: IEGTechniqueCatalog = Catalog.new()
var _base_spawns: Dictionary = {}
var _duel_cooldown: float = 0.0
var _duel_count: int = 0
var _next_kickoff_team: int = 0
var _initialized: bool = false
var _shot_technique: String = ""
var _shot_charge: float = 0.0
var _sprinting: Dictionary = {}

func _init(profiles: Array[IEGPlayerProfile] = [], starts: Array[Vector2] = [],
        teams: Array[int] = [], keeper_roles: Array[bool] = [], half_seconds: float = 300.0) -> void:
    super(profiles, starts, teams, keeper_roles, Vector2(30.0, 45.0))
    half_duration = clampf(half_seconds, 0.1, 2700.0) if is_finite(half_seconds) else 300.0
    goal_half_width = 3.66
    goal_height = 2.44
    for player: IEGPlayerState in players:
        _base_spawns[player.get_id()] = player.spawn
    _initialized = true
    _reset_positions()
    events.clear()

func attack_direction(team: int) -> float:
    var initial: float = -1.0 if team == 0 else 1.0
    return initial if period == 1 else -initial

func step(command: IEGGameCommand, ai_commands: Dictionary = {}) -> void:
    events.clear()
    if phase in [Phase.HALFTIME, Phase.FINISHED, Phase.DUEL_CHOICE]:
        return
    if phase == Phase.CINEMATIC:
        cinematic_elapsed += Rules.TICK
        if cinematic_elapsed + 0.00001 >= float(duel.get("duration", 3.2)):
            _finish_duel()
        return
    if command == null:
        command = Command.new()
    command = Command.from_dict(command.to_dict())
    command.reset_drill = false # Seul un nouveau match réinitialise son état.
    _shot_technique = command.technique_id
    _shot_charge = command.shot_charge
    _duel_cooldown = maxf(0.0, _duel_cooldown - Rules.TICK)
    var in_restart: bool = is_resetting()
    super.step(command, ai_commands)
    if phase != Phase.LIVE:
        return
    if not in_restart:
        elapsed_half = minf(half_duration, elapsed_half + Rules.TICK)
        _advance_modifiers()
    for event: Dictionary in events:
        if event["kind"] == EventKind.GOAL:
            _next_kickoff_team = 1 - int(event["team_id"])
    if elapsed_half + 0.00001 >= half_duration:
        _end_period()
        return
    _detect_field_duel()

func _end_period() -> void:
    ball.velocity = Vector3.ZERO
    for player: IEGPlayerState in players:
        player.velocity = Vector2.ZERO
    _duel_cooldown = 0.0
    if period == 1:
        phase = Phase.HALFTIME
    else:
        phase = Phase.FINISHED
        winner_team = -1 if team_goals[0] == team_goals[1] else (0 if team_goals[0] > team_goals[1] else 1)

func set_formation(team: int, id: String) -> bool:
    if phase != Phase.HALFTIME or team not in [0, 1] or id not in ["balanced", "wide", "press"]:
        return false
    formations[team] = id
    return true

func start_second_half(new_formations: Dictionary = {}) -> bool:
    if phase != Phase.HALFTIME:
        return false
    for key: Variant in new_formations:
        if not key is int or key not in [0, 1] or String(new_formations[key]) not in ["balanced", "wide", "press"]:
            return false
    for key: Variant in new_formations:
        formations[key] = String(new_formations[key])
    period = 2
    elapsed_half = 0.0
    _next_kickoff_team = 1
    for player: IEGPlayerState in players:
        var source: Vector2 = _base_spawns[player.get_id()]
        source.y = -source.y
        if not player.is_goalkeeper:
            if formations[player.team_id] == "wide":
                source.x *= 1.3
            elif formations[player.team_id] == "press":
                source.y += attack_direction(player.team_id) * 5.0
        player.spawn = _clamp_player(source)
        player.dazed_time = 0.0
        player.keeper_stamina = minf(100.0, player.keeper_stamina + 20.0)
        player.energy = minf(100.0, player.energy + 20.0)
        player.resonance_used_period = 0
        player.karma_reserves.clear()
        var karma: Dictionary = player.modifiers.get("KARMA", {})
        if karma.has("pg"):
            var properties: Dictionary = catalog.get_definition(String(karma["id"])).get("properties", {})
            karma["pg_max"] = float(properties.get("pg_max", karma["pg_max"]))
            karma["pe_max"] = float(properties.get("pe_max", karma["pe_max"]))
            karma["pg"] = float(karma["pg_max"])
            karma["pe"] = float(karma["pe_max"])
            karma["energy"] = float(karma["pe"])
            karma["energy_max"] = float(karma["pe_max"])
            _store_karma_reserves(player, karma)
    phase = Phase.LIVE
    duel.clear()
    _reset_positions()
    return true

func request_duel(actor_id: int, target_id: int, kind: String = "field") -> bool:
    if phase != Phase.LIVE or is_resetting() or _duel_cooldown > 0.0 or kind not in ["field", "block", "keeper"]:
        return false
    var actor: IEGPlayerState = get_player(actor_id)
    var target: IEGPlayerState = get_player(target_id)
    if actor == null or target == null or actor.team_id == target.team_id or ball.owner_id != actor_id:
        return false
    if actor.dazed_time > 0.0 or target.dazed_time > 0.0 or actor.is_goalkeeper:
        return false
    if kind == "field" and (target.is_goalkeeper or actor.position.distance_to(target.position) > 2.2):
        return false
    if kind == "block" and (target.is_goalkeeper or _shot_blocker(actor) != target or actor.position.distance_to(attacking_goal(actor.team_id)) > shot_range(actor, _shot_technique)):
        return false
    if kind == "keeper" and (not target.is_goalkeeper or actor.position.distance_to(attacking_goal(actor.team_id)) > shot_range(actor, _shot_technique)):
        return false
    _duel_count += 1
    duel = {"kind": kind, "actor_id": actor_id, "target_id": target_id,
        "defender_id": target_id, "local_role": "attack" if actor.team_id == LOCAL_TEAM else "defend",
        "attack_choice": "", "defend_choice": "", "attack_technique": "", "defend_technique": "",
        "attack_score": 0.0, "defend_score": 0.0, "winner_id": -1, "attacker_won": false,
        "duration": 3.2, "reveal_time": 1.4, "applied": false, "outcome": "", "result": "",
        "ai_choice": "left" if (_duel_count + target_id) % 2 == 0 else "right",
        "ai_special": (_duel_count + target_id) % 3 == 0, "shot_charge": _shot_charge,
        "techniques": catalog.all_definitions(), "prepaid_technique": ""}
    if kind == "keeper" and not _shot_technique.is_empty() and actor.team_id != LOCAL_TEAM:
        duel["attack_technique"] = _shot_technique
    phase = Phase.DUEL_CHOICE
    cinematic_elapsed = 0.0
    return true

func choose_duel(choice: String, technique_id: String = "") -> bool:
    if phase != Phase.DUEL_CHOICE or choice not in CHOICES:
        return false
    var attacker: IEGPlayerState = get_player(int(duel["actor_id"]))
    var defender: IEGPlayerState = get_player(int(duel["target_id"]))
    var is_attack: bool = duel["local_role"] == "attack"
    var local_actor: IEGPlayerState = attacker if is_attack else defender
    var category: String = ("TIR" if is_attack else "GAR") if duel["kind"] == "keeper" else (("TIR" if is_attack else "DEF") if duel["kind"] == "block" else ("ATT" if is_attack else "DEF"))
    var prepaid_id: String = String(duel.get("prepaid_technique", ""))
    var prepaid_shot: bool = bool(duel.get("shot_chain", false))
    var prepaid: bool = is_attack and not technique_id.is_empty() and technique_id == prepaid_id
    if is_attack and prepaid_shot and choice == "special" and (prepaid_id.is_empty() or technique_id != prepaid_id):
        return false
    if choice == "special" and not prepaid and not _technique_available(local_actor, technique_id, category):
        return false
    if choice != "special" and not technique_id.is_empty():
        return false
    var attack_choice: String = choice if is_attack else String(duel["ai_choice"])
    var defense_choice: String = String(duel["ai_choice"]) if is_attack else choice
    var attack_tech: String = technique_id if is_attack and choice == "special" else ""
    var defense_tech: String = technique_id if not is_attack and choice == "special" else ""
    if not prepaid_id.is_empty():
        attack_tech = prepaid_id
    var chosen_attack_technique: String = attack_tech if is_attack else String(duel.get("prepaid_technique", ""))
    if duel["kind"] in ["keeper", "block"] and attacker.position.distance_to(attacking_goal(attacker.team_id)) > shot_range(attacker, chosen_attack_technique):
        return false
    var ai_actor: IEGPlayerState = defender if is_attack else attacker
    var ai_category: String = ("GAR" if is_attack else "TIR") if duel["kind"] == "keeper" else (("DEF" if is_attack else "TIR") if duel["kind"] == "block" else ("DEF" if is_attack else "ATT"))
    var ai_tech: String = _affordable_ai_technique(ai_actor, ai_category)
    if bool(duel["ai_special"]) and not ai_tech.is_empty():
        if is_attack:
            defense_choice = "special"
            defense_tech = ai_tech
        else:
            if not prepaid_shot:
                attack_choice = "special"
                attack_tech = ai_tech
    # Les bonus de l'invocation participent au duel même si son paiement l'épuise.
    var attack_stat: String = "shot" if duel["kind"] in ["keeper", "block"] else "dribble"
    var defense_stat: String = "keeper" if defender.is_goalkeeper else "defense"
    var attack_bonus: float = _modifier_bonus(attacker, attack_stat)
    var defense_bonus: float = _modifier_bonus(defender, defense_stat)
    if bool(duel.get("shot_chain", false)):
        attack_bonus = float(duel.get("prepaid_attack_bonus", attack_bonus))
    var attack_karma_id: String = String(attacker.modifiers.get("KARMA", {}).get("id", ""))
    if not attacker.modifiers.get("KARMA", {}).has("pg"):
        attack_karma_id = ""
    if prepaid_shot:
        attack_karma_id = String(duel.get("prepaid_karma_id", attack_karma_id))
    # Dépenser seulement après validation de l'ensemble de la décision locale.
    if not attack_tech.is_empty() and attack_tech != String(duel.get("prepaid_technique", "")):
        _pay_technique(attacker, attack_tech)
    _pay_technique(defender, defense_tech)
    var attack_score: float = 42.0 + attacker.energy * 0.24 + attack_bonus
    var defense_score: float = 43.0 + (defender.keeper_stamina if defender.is_goalkeeper else defender.energy) * 0.24 + defense_bonus
    if duel["kind"] in ["keeper", "block"]:
        attack_score += float(duel["shot_charge"]) * 13.0
        attack_score -= maxf(0.0, attacker.position.distance_to(attacking_goal(attacker.team_id)) - 24.0) * 0.5
    if attack_choice == defense_choice and attack_choice != "special":
        defense_score += 18.0
    elif attack_choice != "special" and defense_choice != "special":
        attack_score += 16.0
    if not attack_tech.is_empty():
        var attack_definition: Dictionary = catalog.get_definition(attack_tech)
        attack_score += float(attack_definition.get("power", 0.0))
        if duel["kind"] in ["keeper", "block"]:
            var shot_properties: Dictionary = attack_definition.get("properties", {})
            var distance: float = attacker.position.distance_to(attacking_goal(attacker.team_id))
            var optimal_min: float = float(shot_properties.get("optimal_min", 0.0))
            var optimal_max: float = float(shot_properties.get("optimal_max", INF))
            var outside_optimal: float = maxf(0.0, optimal_min - distance) + maxf(0.0, distance - optimal_max)
            attack_score -= outside_optimal * float(shot_properties.get("distance_falloff", 0.0))
    if not defense_tech.is_empty():
        defense_score += float(catalog.get_definition(defense_tech).get("power", 0.0))
    if defender.is_goalkeeper:
        defender.keeper_stamina = maxf(0.0, defender.keeper_stamina - 9.0)
    else:
        defender.energy = maxf(0.0, defender.energy - 4.0)
    attacker.energy = maxf(0.0, attacker.energy - 4.0)
    var won: bool = attack_score > defense_score
    _pay_karma_duel(attacker, attack_tech, won, prepaid_shot, attack_karma_id)
    _pay_karma_duel(defender, defense_tech, not won)
    var outcome: String = "dribble" if won else "tackle"
    if duel["kind"] == "block":
        outcome = "shot_continues" if won else "block"
    if duel["kind"] == "keeper":
        outcome = "goal" if won else ("capture" if defense_score - attack_score >= 8.0 else "deflection")
    duel.merge({"attack_choice": attack_choice, "defend_choice": defense_choice,
        "attack_technique": attack_tech, "defend_technique": defense_tech,
        "attack_score": snappedf(attack_score, 0.1), "defend_score": snappedf(defense_score, 0.1),
        "winner_id": attacker.get_id() if won else defender.get_id(), "attacker_won": won,
        "attack_bonus": attack_bonus, "attack_karma_id": attack_karma_id,
        "outcome": outcome, "result": "parry" if outcome == "deflection" else outcome}, true)
    var cinematic_duration: float = 0.0
    for id: String in [attack_tech, defense_tech]:
        if not id.is_empty():
            cinematic_duration = maxf(cinematic_duration, float(catalog.get_definition(id).get("duration", 3.2)))
    duel["duration"] = clampf(cinematic_duration if cinematic_duration > 0.0 else 3.2, 1.8, 10.0)
    if not defense_tech.is_empty() and duel["kind"] == "keeper":
        var branch: float = float(catalog.get_definition(defense_tech).get("properties", {}).get("branch_at", 0.58))
        duel["reveal_time"] = clampf(float(duel["duration"]) * branch, 0.7, float(duel["duration"]) - 0.4)
    phase = Phase.CINEMATIC
    cinematic_elapsed = 0.0
    return true

func _finish_duel() -> void:
    if bool(duel.get("applied", false)):
        return
    var attacker: IEGPlayerState = get_player(int(duel["actor_id"]))
    var defender: IEGPlayerState = get_player(int(duel["target_id"]))
    phase = Phase.LIVE
    match String(duel["outcome"]):
        "dribble":
            defender.dazed_time = 1.0
            defender.velocity = Vector2.ZERO
            var side: float = -1.0 if duel["attack_choice"] == "left" else 1.0
            attacker.position = _clamp_player(attacker.position + Vector2(side * 1.8, attack_direction(attacker.team_id) * 1.8))
            _gain_possession(attacker)
            _emit(EventKind.RECEPTION, attacker.get_id(), defender.get_id())
        "tackle", "block":
            attacker.recovery_time = 0.45
            attacker.velocity = Vector2.ZERO
            _gain_possession(defender)
            _emit(EventKind.TACKLE_WON, defender.get_id(), attacker.get_id())
        "shot_continues":
            defender.recovery_time = 0.35
        "goal":
            goals += 1
            team_goals[attacker.team_id] += 1
            _next_kickoff_team = defender.team_id
            ball.owner_id = -1
            ball.mode = BallState.Mode.FREE
            ball.position = Rules.on_ground(attacking_goal(attacker.team_id), 0.8)
            ball.velocity = Vector3.ZERO
            _reset_timer = 1.4
            _emit(EventKind.GOAL, attacker.get_id())
            events.back()["team_id"] = attacker.team_id
        "capture":
            _gain_possession(defender)
            _emit(EventKind.KEEPER_CAPTURE, defender.get_id(), attacker.get_id())
        "deflection":
            var direction: Vector2 = Vector2(0.5, attack_direction(defender.team_id)).normalized()
            ball.position = Rules.on_ground(defender.position + direction * 1.4, 1.1)
            _release(defender.get_id(), BallState.Mode.FREE, Rules.on_ground(direction * 12.0, 2.0))
            _emit(EventKind.KEEPER_DEFLECTION, defender.get_id(), attacker.get_id())
    _follow_owner_if_held()
    _duel_cooldown = 1.1
    duel["applied"] = true
    if duel["outcome"] == "shot_continues":
        var paid_technique: String = String(duel["attack_technique"])
        var paid_bonus: float = float(duel.get("attack_bonus", 0.0))
        var paid_karma: String = String(duel.get("attack_karma_id", ""))
        _shot_technique = paid_technique
        _shot_charge = float(duel["shot_charge"]) * 0.8
        _duel_cooldown = 0.0
        var keeper: IEGPlayerState = keeper_for_team(defender.team_id)
        if keeper != null and request_duel(attacker.get_id(), keeper.get_id(), "keeper"):
            duel["prepaid_technique"] = paid_technique
            duel["shot_chain"] = true
            duel["prepaid_attack_bonus"] = paid_bonus
            duel["prepaid_karma_id"] = paid_karma

func _follow_owner_if_held() -> void:
    if ball.owner_id >= 0:
        _follow_owner()

func _detect_field_duel() -> void:
    if _duel_cooldown > 0.0 or is_resetting() or ball.owner_id < 0:
        return
    var owner: IEGPlayerState = get_player(ball.owner_id)
    if owner == null or owner.is_goalkeeper or owner.possession_grace > 0.0 or owner.dazed_time > 0.0:
        return
    for opponent: IEGPlayerState in players:
        if opponent.team_id != owner.team_id and not opponent.is_goalkeeper and opponent.dazed_time <= 0.0:
            if opponent.position.distance_to(owner.position) <= 1.65:
                if request_duel(owner.get_id(), opponent.get_id()):
                    return

func _try_tackle(actor: IEGPlayerState, _aim: Vector2) -> void:
    if phase != Phase.LIVE or actor.dazed_time > 0.0:
        return
    var owner: IEGPlayerState = get_player(ball.owner_id)
    if owner != null and owner.team_id != actor.team_id and not owner.is_goalkeeper and owner.possession_grace <= 0.0:
        request_duel(owner.get_id(), actor.get_id())

func _commands_for_tick(local_command: IEGGameCommand, ai_commands: Dictionary) -> Dictionary:
    var commands: Dictionary = super._commands_for_tick(local_command, ai_commands)
    for player: IEGPlayerState in players:
        if player.dazed_time > 0.0:
            commands[player.get_id()] = Command.new()
    return commands

func _advance_players(commands: Dictionary) -> void:
    var frozen: Dictionary = {}
    _sprinting.clear()
    for player: IEGPlayerState in players:
        var movement: IEGGameCommand = commands.get(player.get_id(), Command.new())
        _sprinting[player.get_id()] = movement.sprint and movement.move.length_squared() > 0.01 and not player.sprint_exhausted and player.recovery_time <= 0.0 and player.dazed_time <= 0.0
        player.speed_multiplier = 1.0
        # Les pondérations de profil et le bonus de Karma se composent.
        for modifier: Dictionary in get_active_modifiers(player.get_id()):
            var definition: Dictionary = catalog.get_definition(String(modifier["id"]))
            if modifier["category"] == "RESONANCE" and not definition.get("properties", {}).has("donor_key"):
                var partner: IEGPlayerState = get_player(int(modifier.get("partner_id", -1)))
                if partner != null:
                    var blend: float = float(definition.get("properties", {}).get("blend", 0.5))
                    player.speed_multiplier *= lerpf(player.profile.run_speed, partner.profile.run_speed, blend) / player.profile.run_speed
            elif modifier["category"] == "KARMA" and not definition.get("properties", {}).has("pg_max"):
                player.speed_multiplier *= 1.08
        if player.dazed_time > 0.0:
            frozen[player.get_id()] = player.position
            player.velocity = Vector2.ZERO
    super._advance_players(commands)
    for player: IEGPlayerState in players:
        if frozen.has(player.get_id()):
            player.position = frozen[player.get_id()]
            player.velocity = Vector2.ZERO
            player.dazed_time = 0.0 if player.dazed_time <= Rules.TICK + 0.0000001 else player.dazed_time - Rules.TICK
        player.keeper_stamina = minf(100.0, player.keeper_stamina + Rules.TICK * 0.4)

func _separate_players() -> void:
    for i: int in range(players.size()):
        for j: int in range(i + 1, players.size()):
            var a: IEGPlayerState = players[i]
            var b: IEGPlayerState = players[j]
            var offset: Vector2 = b.position - a.position
            var distance: float = offset.length()
            if distance >= Rules.PLAYER_RADIUS * 2.0 or (a.dazed_time > 0.0 and b.dazed_time > 0.0):
                continue
            var direction: Vector2 = offset.normalized() if distance > 0.001 else Vector2.RIGHT
            var correction: Vector2 = direction * (Rules.PLAYER_RADIUS * 2.0 - distance)
            if a.dazed_time > 0.0:
                b.position += correction
            elif b.dazed_time > 0.0:
                a.position -= correction
            else:
                a.position -= correction * 0.5
                b.position += correction * 0.5
    for player: IEGPlayerState in players:
        if player.dazed_time <= 0.0:
            player.position = _clamp_player(player.position)
            if player.is_goalkeeper:
                _clamp_keeper(player)

func _clamp_keeper(player: IEGPlayerState) -> void:
    var side: float = -attack_direction(player.team_id)
    player.position.x = clampf(player.position.x, -6.0, 6.0)
    player.position.y = clampf(player.position.y * side, half_length - 12.0, half_length - 0.8) * side

func _in_keeper_area(keeper: IEGPlayerState, point: Vector2) -> bool:
    var side: float = -attack_direction(keeper.team_id)
    return absf(point.x) <= 8.0 and point.y * side >= half_length - 14.0 and point.y * side <= half_length + Rules.BALL_RADIUS

func _shoot(actor: IEGPlayerState, aim: Vector2, charge: float) -> void:
    if phase != Phase.LIVE or actor.dazed_time > 0.0:
        return
    var keeper: IEGPlayerState = keeper_for_team(1 - actor.team_id)
    if keeper != null:
        _shot_charge = charge
        if actor.team_id != LOCAL_TEAM:
            _shot_technique = ""
        var distance: float = actor.position.distance_to(attacking_goal(actor.team_id))
        if distance > 24.0 and not _technique_available(actor, _shot_technique, "TIR"):
            return
        var blocker: IEGPlayerState = _shot_blocker(actor)
        if blocker != null:
            request_duel(actor.get_id(), blocker.get_id(), "block")
        else:
            request_duel(actor.get_id(), keeper.get_id(), "keeper")
    else:
        super._shoot(actor, aim, charge)

func keeper_for_team(team: int) -> IEGPlayerState:
    for player: IEGPlayerState in players:
        if player.team_id == team and player.is_goalkeeper:
            return player
    return null

func shot_range(_actor: IEGPlayerState, technique_id: String = "") -> float:
    var definition: Dictionary = catalog.get_definition(technique_id)
    return 24.0 + (float(definition.get("range_bonus", 0.0)) if definition.get("category", "") == "TIR" else 0.0)

func _reset_positions() -> void:
    var saved: Dictionary = {}
    if _initialized:
        for player: IEGPlayerState in players:
            saved[player.get_id()] = [player.energy, player.keeper_stamina, player.modifiers.duplicate(true), player.karma_reserves.duplicate(true), player.resonance_used_period]
    super._reset_positions()
    for player: IEGPlayerState in players:
        player.facing = Vector2(0.0, attack_direction(player.team_id))
        if saved.has(player.get_id()):
            var state: Array = saved[player.get_id()]
            player.energy = float(state[0])
            player.keeper_stamina = float(state[1])
            player.modifiers = state[2].duplicate(true)
            player.karma_reserves = state[3].duplicate(true)
            player.resonance_used_period = int(state[4])
    var kicker: IEGPlayerState = null
    for player: IEGPlayerState in players:
        if player.team_id == _next_kickoff_team and not player.is_goalkeeper:
            if kicker == null or player.position.length_squared() < kicker.position.length_squared():
                kicker = player
    if kicker != null:
        kicker.position = Vector2(0.0, -attack_direction(kicker.team_id) * 0.8)
        _gain_possession(kicker)
        # Cercle d'engagement : laisser au porteur le temps de jouer.
        for opponent: IEGPlayerState in players:
            if opponent.team_id != kicker.team_id and not opponent.is_goalkeeper and opponent.position.length() < 9.15:
                var direction: Vector2 = opponent.position.normalized() if opponent.position.length_squared() > 0.001 else Vector2(0.0, -attack_direction(opponent.team_id))
                opponent.position = direction * 9.15
        _duel_cooldown = 1.2
    _follow_owner_if_held()

func get_available_techniques(player_id: int, category: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var player: IEGPlayerState = get_player(player_id)
    if player == null:
        return result
    var inherited: Array = []
    var resonance: Dictionary = player.modifiers.get("RESONANCE", {})
    if _modifier_is_active(resonance):
        inherited = resonance.get("techniques", [])
    for definition: Dictionary in catalog.all_definitions():
        var family: String = String(definition.get("category", ""))
        if family not in ["TIR", "ATT", "DEF", "GAR"] or (not category.is_empty() and family != category):
            continue
        if family == "GAR" and not player.is_goalkeeper:
            continue
        var id: String = String(definition["id"])
        var karma_id: String = String(definition.get("properties", {}).get("karma_id", ""))
        if not karma_id.is_empty():
            var karma: Dictionary = player.modifiers.get("KARMA", {})
            if not _modifier_is_active(karma) or String(karma.get("id", "")) != karma_id:
                continue
        elif not player.profile.technique_ids.is_empty() and id not in player.profile.technique_ids and id not in inherited:
            continue
        result.append(definition)
    return result

func can_use_technique(player_id: int, id: String, category: String = "") -> bool:
    var player: IEGPlayerState = get_player(player_id)
    if player == null or player.dazed_time > 0.0:
        return false
    var definition: Dictionary = catalog.get_definition(id)
    if definition.is_empty() or (not category.is_empty() and String(definition.get("category", "")) != category):
        return false
    var known: bool = false
    for available: Dictionary in get_available_techniques(player_id, category):
        if available["id"] == definition["id"]:
            known = true
            break
    if not known:
        return false
    var properties: Dictionary = definition.get("properties", {})
    if properties.has("karma_id"):
        var karma: Dictionary = player.modifiers.get("KARMA", {})
        return float(karma.get("pg", 0.0)) >= float(properties.get("pg_cost", 0.0)) and float(karma.get("pe", 0.0)) >= float(properties.get("pe_cost", 0.0))
    var reserve: float = player.keeper_stamina if player.is_goalkeeper else player.energy
    return reserve >= float(definition.get("cost", 0.0))

func _technique_available(actor: IEGPlayerState, id: String, category: String) -> bool:
    return actor != null and can_use_technique(actor.get_id(), id, category)

func _pay_technique(actor: IEGPlayerState, id: String) -> void:
    if id.is_empty():
        return
    var technique: Dictionary = catalog.get_definition(id)
    # La signature possède son coût PG/PE, débité avec le résultat du duel.
    if technique.get("properties", {}).has("karma_id"):
        return
    var cost: float = float(technique.get("cost", 0.0))
    if actor.is_goalkeeper:
        actor.keeper_stamina = maxf(0.0, actor.keeper_stamina - cost)
    else:
        actor.energy = maxf(0.0, actor.energy - cost)
    # Compatibilité des anciennes fiches à réserve unique.
    for category: String in MODIFIER_CATEGORIES:
        var state: Dictionary = actor.modifiers.get(category, {})
        if not _modifier_is_active(state) or state.has("pg"):
            continue
        var definition: Dictionary = catalog.get_definition(String(state["id"]))
        var extra: float = float(definition.get("properties", {}).get("technique_energy_cost", 0.0))
        state["energy"] = maxf(0.0, float(state["energy"]) - extra)
        if float(state["energy"]) <= 0.0:
            deactivate_modifier(actor.get_id(), category)

func _pay_karma_duel(actor: IEGPlayerState, technique_id: String, won: bool, prepaid: bool = false, prepaid_karma_id: String = "") -> void:
    if prepaid and not prepaid_karma_id.is_empty():
        # Le tir poursuit sa route même si son invocation a épuisé ses PE au blocage.
        if not won and actor.karma_reserves.has(prepaid_karma_id):
            var reserve: Dictionary = actor.karma_reserves[prepaid_karma_id]
            var properties: Dictionary = catalog.get_definition(prepaid_karma_id).get("properties", {})
            reserve["pg"] = maxf(0.0, float(reserve["pg"]) - float(properties.get("defeat_pg_cost", 20.0)))
            var active: Dictionary = actor.modifiers.get("KARMA", {})
            if String(active.get("id", "")) == prepaid_karma_id:
                active["pg"] = float(reserve["pg"])
                if not _modifier_is_active(active):
                    actor.modifiers.erase("KARMA")
        return
    var karma: Dictionary = actor.modifiers.get("KARMA", {})
    if not _modifier_is_active(karma) or not karma.has("pg"):
        return
    var properties: Dictionary = catalog.get_definition(String(karma["id"])).get("properties", {})
    var technique: Dictionary = catalog.get_definition(technique_id).get("properties", {})
    var signature: bool = String(technique.get("karma_id", "")) == String(karma["id"])
    var pg_cost: float = float(technique.get("pg_cost", 0.0)) if signature else float(properties.get("duel_pg_cost", 10.0))
    var pe_cost: float = float(technique.get("pe_cost", 0.0)) if signature else float(properties.get("duel_pe_cost", 4.0))
    if prepaid:
        pg_cost = 0.0
        pe_cost = 0.0
    if not won:
        pg_cost += float(properties.get("defeat_pg_cost", 20.0))
    karma["pg"] = maxf(0.0, float(karma["pg"]) - pg_cost)
    karma["pe"] = maxf(0.0, float(karma["pe"]) - pe_cost)
    karma["energy"] = float(karma["pe"])
    _store_karma_reserves(actor, karma)
    if not _modifier_is_active(karma):
        actor.modifiers.erase("KARMA")

func _store_karma_reserves(player: IEGPlayerState, karma: Dictionary) -> void:
    if karma.has("pg"):
        player.karma_reserves[String(karma["id"])] = {"pg": float(karma["pg"]), "pe": float(karma["pe"])}

func _affordable_ai_technique(actor: IEGPlayerState, category: String) -> String:
    var definitions: Array[Dictionary] = get_available_techniques(actor.get_id(), category)
    if definitions.is_empty():
        return ""
    var offset: int = _duel_count % definitions.size()
    for index: int in range(definitions.size()):
        var id: String = String(definitions[(offset + index) % definitions.size()]["id"])
        if _technique_available(actor, id, category):
            return id
    return ""

func set_tactic(team: int, id: String) -> bool:
    if phase not in [Phase.LIVE, Phase.HALFTIME] or team not in [0, 1]:
        return false
    var definition: Dictionary = catalog.get_definition(id)
    if definition.get("category", "") != "TAC":
        return false
    tactics[team] = id
    tactic_time[team] = float(definition.get("duration", 30.0))
    return true

func get_available_modifiers(player_id: int, category: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var player: IEGPlayerState = get_player(player_id)
    if player == null or player.team_id != LOCAL_TEAM or category not in MODIFIER_CATEGORIES:
        return result
    for definition: Dictionary in catalog.definitions_for(category):
        var properties: Dictionary = definition.get("properties", {})
        if category == "KARMA" and properties.has("pg_max") and not _owns_karma(player, String(definition["id"])):
            continue
        if category == "RESONANCE" and properties.has("donor_key"):
            var donor: IEGPlayerState = _find_donor(player, String(properties["donor_key"]))
            if donor == null:
                continue
            definition["partner_id"] = donor.get_id()
        result.append(definition)
    return result

func _find_donor(player: IEGPlayerState, donor_key: String) -> IEGPlayerState:
    for candidate: IEGPlayerState in players:
        if candidate != player and candidate.team_id == player.team_id and candidate.profile.content_key == donor_key:
            return candidate
    return null

func _owns_karma(player: IEGPlayerState, karma_id: String) -> bool:
    if _profile_owns_karma(player, karma_id):
        return true
    var resonance: Dictionary = player.modifiers.get("RESONANCE", {})
    if not _modifier_is_active(resonance):
        return false
    var donor: IEGPlayerState = get_player(int(resonance.get("partner_id", -1)))
    return String(resonance.get("inherited_karma_id", "")) == karma_id and donor != null and donor.team_id == player.team_id and _profile_owns_karma(donor, karma_id)

func _profile_owns_karma(player: IEGPlayerState, karma_id: String) -> bool:
    var properties: Dictionary = catalog.get_definition(karma_id).get("properties", {})
    return karma_id in player.profile.karma_ids or (not player.profile.content_key.is_empty() and player.profile.content_key in properties.get("owner_keys", []))

func activate_modifier(player_id: int, content_id: String, partner_id: int = -1) -> bool:
    modifier_error = ""
    var player: IEGPlayerState = get_player(player_id)
    if phase != Phase.LIVE or is_resetting():
        return _reject_modifier("Les augmentations s'activent pendant le jeu live.")
    if player == null or player.team_id != LOCAL_TEAM:
        return _reject_modifier("Choisissez un joueur de votre équipe.")
    if player.dazed_time > 0.0:
        return _reject_modifier("Ce joueur est encore inactif.")
    var definition: Dictionary = catalog.get_definition(content_id)
    var category: String = String(definition.get("category", ""))
    if category not in MODIFIER_CATEGORIES:
        return _reject_modifier("Cette fiche n'est ni un Karma ni une Resonance.")
    if _modifier_is_active(player.modifiers.get(category, {})):
        return _reject_modifier("Ce joueur possède déjà un %s actif." % ("Karma" if category == "KARMA" else "état de Resonance"))
    if count_active_modifiers(player.team_id, category) >= MODIFIER_LIMIT_PER_TEAM:
        return _reject_modifier("Limite atteinte : 3 %s actifs dans cette équipe." % ("Karmas" if category == "KARMA" else "Resonance"))
    var cost: float = float(definition.get("cost", 0.0))
    if player.energy < cost:
        return _reject_modifier("Endurance insuffisante pour cette activation.")
    var properties: Dictionary = definition.get("properties", {})
    var partner: IEGPlayerState = null
    if category == "KARMA" and properties.has("pg_max") and not _owns_karma(player, String(definition["id"])):
        return _reject_modifier("Ce joueur ne possède pas ce Karma, personnellement ou par Resonance.")
    if category == "RESONANCE":
        if properties.has("donor_key"):
            if player.resonance_used_period == period:
                return _reject_modifier("Une seule activation de Resonance par joueur et par mi-temps.")
            if partner_id < 0:
                partner = _find_donor(player, String(properties["donor_key"]))
                partner_id = partner.get_id() if partner != null else -1
        partner = get_player(partner_id)
        if partner == null or partner == player or partner.team_id != player.team_id or partner.dazed_time > 0.0:
            return _reject_modifier("Choisissez un partenaire allié valide pour la Resonance.")
        if properties.has("donor_key"):
            if partner.profile.content_key != String(properties["donor_key"]):
                return _reject_modifier("Cette Resonance exige le donneur indiqué sur sa fiche.")
            for other: IEGPlayerState in players:
                var active: Dictionary = other.modifiers.get("RESONANCE", {})
                if _modifier_is_active(active) and int(active.get("partner_id", -1)) == partner_id:
                    return _reject_modifier("Ce donneur alimente déjà une Resonance active.")
    var reserve: float = float(properties.get("energy_max", 100.0))
    var state: Dictionary = {"id": String(definition["id"]),
        "time": float(definition.get("duration", 20.0)), "energy": reserve,
        "energy_max": reserve, "partner_id": partner_id if category == "RESONANCE" else -1}
    if category == "KARMA" and properties.has("pg_max"):
        var saved: Dictionary = player.karma_reserves.get(String(definition["id"]), {})
        state["pg_max"] = float(properties["pg_max"])
        state["pe_max"] = float(properties["pe_max"])
        state["pg"] = minf(float(saved.get("pg", state["pg_max"])), float(state["pg_max"]))
        state["pe"] = minf(float(saved.get("pe", state["pe_max"])), float(state["pe_max"]))
        if float(state["pg"]) <= 0.0 or float(state["pe"]) <= 0.0:
            return _reject_modifier("Ce Karma est épuisé jusqu'à la mi-temps.")
        state["energy"] = float(state["pe"])
        state["energy_max"] = float(state["pe_max"])
        state["time"] = float(state["pe"]) / maxf(0.001, float(properties.get("pe_drain", 1.0)))
        state["inherited_from"] = not _profile_owns_karma(player, String(definition["id"]))
        state["inherited_from_id"] = int(player.modifiers.get("RESONANCE", {}).get("partner_id", -1)) if bool(state["inherited_from"]) else -1
        _store_karma_reserves(player, state)
    elif category == "RESONANCE" and properties.has("donor_key"):
        state["energy_max"] = float(state["time"])
        state["energy"] = float(state["time"])
        state["techniques"] = properties.get("inherited_techniques", []).duplicate()
        var inherited_karma: String = String(properties.get("inherited_karma_id", ""))
        state["inherited_karma_id"] = inherited_karma if _profile_owns_karma(partner, inherited_karma) else ""
        player.resonance_used_period = period
    # Toutes les validations précèdent la dépense et la création d'état.
    player.energy -= cost
    player.modifiers[category] = state
    return true

func deactivate_modifier(player_id: int, category: String) -> bool:
    var player: IEGPlayerState = get_player(player_id)
    if player == null or not player.modifiers.has(category):
        return false
    var state: Dictionary = player.modifiers[category]
    if category == "KARMA":
        _store_karma_reserves(player, state)
    player.modifiers.erase(category)
    if category == "RESONANCE":
        var karma: Dictionary = player.modifiers.get("KARMA", {})
        if bool(karma.get("inherited_from", false)):
            deactivate_modifier(player_id, "KARMA")
    return true

func _reject_modifier(reason: String) -> bool:
    modifier_error = reason
    return false

func _modifier_is_active(state: Dictionary) -> bool:
    if state.has("pg"):
        return float(state.get("pg", 0.0)) > 0.0000001 and float(state.get("pe", 0.0)) > 0.0000001
    return not state.is_empty() and float(state.get("time", 0.0)) > 0.0000001 and float(state.get("energy", 0.0)) > 0.0000001

func get_active_modifiers(player_id: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var player: IEGPlayerState = get_player(player_id)
    if player == null:
        return result
    for category: String in MODIFIER_CATEGORIES:
        var state: Dictionary = player.modifiers.get(category, {})
        if _modifier_is_active(state):
            var entry: Dictionary = state.duplicate(true)
            entry["category"] = category
            result.append(entry)
    return result

func count_active_modifiers(team: int, category: String) -> int:
    # Ancien nom accepté en lecture, sans réintroduire une troisième famille.
    category = "KARMA" if category == "ECHO" else category
    if team not in [0, 1] or category not in MODIFIER_CATEGORIES:
        return 0
    var count: int = 0
    for player: IEGPlayerState in players:
        if player.team_id == team and _modifier_is_active(player.modifiers.get(category, {})):
            count += 1
    return count

func get_stat_bonuses(player_id: int) -> Dictionary:
    var result: Dictionary = {"shot": 0.0, "dribble": 0.0, "technique": 0.0, "defense": 0.0, "keeper": 0.0}
    var player: IEGPlayerState = get_player(player_id)
    if player == null:
        return result
    for modifier: Dictionary in get_active_modifiers(player_id):
        var properties: Dictionary = catalog.get_definition(String(modifier["id"])).get("properties", {})
        if modifier["category"] == "KARMA":
            var bonuses: Dictionary = properties.get("stat_bonuses", {})
            for key: String in result:
                result[key] = float(result[key]) + float(bonuses.get(key, 0.0))
        elif properties.has("donor_key"):
            var donor: IEGPlayerState = get_player(int(modifier.get("partner_id", -1)))
            if donor != null:
                for key: String in properties.get("stat_keys", []):
                    if result.has(key):
                        # Uniquement les statistiques de base, jamais ses bonus temporaires.
                        result[key] = float(result[key]) + float(donor.profile.base_stats.get(key, 0.0)) * float(properties.get("blend", 0.2))
    return result

func _modifier_bonus(player: IEGPlayerState, stat: String = "") -> float:
    var bonus: float = 0.0
    var stats: Dictionary = get_stat_bonuses(player.get_id())
    if not stat.is_empty():
        bonus += float(stats.get(stat, 0.0))
        bonus += float(stats.get("technique", 0.0)) * 0.25
    for modifier: Dictionary in get_active_modifiers(player.get_id()):
        var definition: Dictionary = catalog.get_definition(String(modifier["id"]))
        var properties: Dictionary = definition.get("properties", {})
        if properties.has("pg_max") or properties.has("donor_key"):
            continue
        bonus += float(definition.get("power", 0.0))
        if modifier["category"] == "RESONANCE":
            var partner: IEGPlayerState = get_player(int(modifier.get("partner_id", -1)))
            if partner != null:
                bonus += partner.energy * float(properties.get("blend", 0.5)) * 0.1
    return bonus

func _advance_modifiers() -> void:
    for team: int in [0, 1]:
        tactic_time[team] = maxf(0.0, float(tactic_time[team]) - Rules.TICK)
        if float(tactic_time[team]) <= 0.0:
            tactics[team] = ""
    for player: IEGPlayerState in players:
        for category: String in MODIFIER_CATEGORIES:
            var state: Dictionary = player.modifiers.get(category, {})
            if state.is_empty():
                continue
            var definition: Dictionary = catalog.get_definition(String(state["id"]))
            var properties: Dictionary = definition.get("properties", {})
            if state.has("pg"):
                var drain: float = float(properties.get("pe_drain", 1.0))
                if bool(_sprinting.get(player.get_id(), false)):
                    drain += float(properties.get("sprint_pe_drain", 1.0))
                state["pe"] = maxf(0.0, float(state["pe"]) - drain * Rules.TICK)
                state["energy"] = float(state["pe"])
                state["time"] = float(state["pe"]) / maxf(0.001, float(properties.get("pe_drain", 1.0)))
                _store_karma_reserves(player, state)
            else:
                state["time"] = maxf(0.0, float(state["time"]) - Rules.TICK)
                if properties.has("donor_key"):
                    state["energy"] = float(state["time"])
                else:
                    state["energy"] = maxf(0.0, float(state["energy"]) - float(properties.get("energy_drain", 1.0)) * Rules.TICK)
            if not _modifier_is_active(state):
                deactivate_modifier(player.get_id(), category)

func build_ai_commands() -> Dictionary:
    var commands: Dictionary = {}
    var point: Vector2 = Rules.planar(ball.position)
    var owner: IEGPlayerState = get_player(ball.owner_id)
    var chasers: Dictionary = {}
    for team: int in [0, 1]:
        var best: IEGPlayerState = null
        for player: IEGPlayerState in players:
            if player.team_id != team or player.is_goalkeeper or player.dazed_time > 0.0:
                continue
            if best == null or player.position.distance_squared_to(point) < best.position.distance_squared_to(point):
                best = player
        chasers[team] = best
    for player: IEGPlayerState in players:
        if player.get_id() == controlled_id:
            continue
        var command: IEGGameCommand = Command.new()
        var target: Vector2 = player.spawn
        var forward: float = attack_direction(player.team_id)
        var properties: Dictionary = catalog.get_definition(String(tactics[player.team_id])).get("properties", {})
        if player.is_goalkeeper:
            target = Vector2(clampf(point.x * 0.35, -4.8, 4.8), -forward * (half_length - 2.0))
            if ball.owner_id == player.get_id():
                if player.team_id != LOCAL_TEAM and player.keeper_hold_time >= 0.8:
                    command.pass_ball = true
                    command.lob_pass = true
            elif ball.owner_id < 0 and point.y * -forward > half_length - 12.0:
                target = point
        elif ball.owner_id == player.get_id():
            if player.team_id != LOCAL_TEAM:
                target = attacking_goal(player.team_id)
                command.shoot = player.position.distance_to(target) < 21.0
                command.shot_charge = 0.65
        elif (owner == null or owner.team_id != player.team_id) and chasers[player.team_id] == player:
            target = point
            command.tackle = owner != null and player.position.distance_to(owner.position) < 1.5
            command.sprint = player.position.distance_to(point) > 8.0
        else:
            target.x *= float(properties.get("width_factor", 1.0))
            target.y = clampf(target.y + point.y * 0.3 + forward * float(properties.get("pressure", 0.2)) * 5.0, -half_length + 8.0, half_length - 8.0)
            if owner != null and owner.team_id == player.team_id and target.distance_to(owner.position) < 4.0:
                target.x += -4.5 if player.spawn.x <= 0.0 else 4.5
        target = _clamp_player(target)
        var offset: Vector2 = target - player.position
        command.move = offset.limit_length(1.0) if offset.length() > 0.35 else Vector2.ZERO
        command.aim = Rules.direction(point - player.position, Vector2(0.0, forward)) if command.tackle else Rules.direction(offset, Vector2(0.0, forward))
        commands[player.get_id()] = command
    return commands

func make_snapshot() -> Dictionary:
    var snapshot: Dictionary = super.make_snapshot()
    snapshot["match"] = {"phase": phase, "period": period, "elapsed_half": elapsed_half,
        "half_duration": half_duration, "winner_team": winner_team, "formations": formations.duplicate(),
        "tactics": tactics.duplicate(), "duel": duel.duplicate(true)}
    for index: int in range(players.size()):
        var player: IEGPlayerState = players[index]
        snapshot["players"][index].merge({"dazed_time": player.dazed_time,
            "keeper_stamina": player.keeper_stamina, "modifiers": player.modifiers.duplicate(true),
            "karma_reserves": player.karma_reserves.duplicate(true),
            "resonance_used_period": player.resonance_used_period,
            "stat_bonuses": get_stat_bonuses(player.get_id())}, true)
    return snapshot

func _shot_blocker(shooter: IEGPlayerState) -> IEGPlayerState:
    var goal: Vector2 = attacking_goal(shooter.team_id)
    var best: IEGPlayerState = null
    var first_t: float = INF
    for opponent: IEGPlayerState in players:
        if opponent.team_id == shooter.team_id or opponent.is_goalkeeper or opponent.dazed_time > 0.0:
            continue
        var t: float = Rules.closest_segment_time(shooter.position, goal, opponent.position)
        var point: Vector2 = shooter.position.lerp(goal, t)
        if t > 0.05 and t < 0.95 and opponent.position.distance_to(point) <= 2.2 and t < first_t:
            best = opponent
            first_t = t
    return best

func _advance_ball() -> void:
    # Un joueur inactif n'intercepte pas involontairement un ballon qui le traverse.
    var saved_recovery: Dictionary = {}
    for player: IEGPlayerState in players:
        if player.dazed_time > 0.0:
            saved_recovery[player.get_id()] = player.recovery_time
            player.recovery_time = maxf(player.recovery_time, player.dazed_time)
    super._advance_ball()
    for player: IEGPlayerState in players:
        if saved_recovery.has(player.get_id()):
            player.recovery_time = float(saved_recovery[player.get_id()])
