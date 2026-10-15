extends RefCounted
## Contrats du match, exécutés dans le moteur Godot, sans rendu ni Python.
const Match = preload("res://core/match/match_session.gd")
const Training = preload("res://core/training_session.gd")
const Command = preload("res://core/game_command.gd")
const Profile = preload("res://core/player_profile.gd")
const Rules = preload("res://core/training_rules.gd")

func run_all() -> Dictionary:
    var cases: Array[Callable] = [_clock_live, _halftime_boundary, _halftime_freeze,
        _formation_only_halftime, _formation_unknown, _formation_valid,
        _second_half_preserves_score, _second_half_swaps_sides,
        _finish_local_winner, _finish_enemy_winner, _finish_draw, _finished_freeze,
        _duel_reject_same_team, _duel_reject_missing, _duel_reject_nonowner,
        _duel_reject_far, _duel_freezes_world, _duel_blocks_second_request,
        _invalid_choice_keeps_prompt, _invalid_technique_no_cost,
        _wrong_technique_type_no_cost, _unaffordable_technique_no_cost,
        _field_special_cost, _cinematic_defers_result, _cinematic_freezes_clock,
        _duel_deterministic, _field_result_possession, _dribbled_inactive,
        _allied_gain_selects, _enemy_gain_not_selected,
        _keeper_choice_role, _keeper_wrong_type_no_cost, _keeper_unaffordable,
        _keeper_special_stamina_cost, _keeper_result, _keeper_attack_goal,
        _keeper_deflection_is_not_possession, _keeper_enemy_capture_not_selected,
        _second_half_shot_credits_attacker,
        _tactic_validation, _modifier_exclusive, _modifier_partner_validation,
        _complete_match_from_kickoff, _kickoff_protection, _kickoff_circle_clear,
        _block_attack_category, _block_defense_capture, _block_before_keeper,
        _block_success_chains_keeper, _block_prepaid_once, _block_reject_offline,
        _dazed_cannot_receive, _long_range_invalid_choice_rollback,
        _long_range_requires_affordable_technique, _out_of_range_shot_does_not_prompt,
        _second_half_blue_physical_deflection, _second_half_red_physical_deflection]
    var lines: Array[String] = []
    var passed: int = 0
    for test: Callable in cases:
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "MATCH : " + String(test.get_method()))
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func fixture() -> RefCounted:
    var profiles: Array[IEGPlayerProfile] = Training.default_profiles()
    for id: int in [21, 1, 31]:
        var p: IEGPlayerProfile = Profile.new()
        p.player_id = id
        p.display_name = "Test %d" % id
        p.shirt_number = id
        profiles.append(p)
    var s: RefCounted = Match.new(profiles, [Vector2(0, 8), Vector2(-5, 2), Vector2(5, -1),
        Vector2(6, -8), Vector2(0, 43), Vector2(0, -43)],
        [0, 0, 0, 1, 0, 1], [false, false, false, false, true, true], 180.0)
    s.ball.owner_id = 7
    s.controlled_id = 7
    s._duel_cooldown = 0.0
    s._follow_owner()
    return s

func field_fixture(local_attacks: bool = true) -> RefCounted:
    var s: RefCounted = fixture()
    s.get_player(7).position = Vector2.ZERO
    s.get_player(21).position = Vector2(0, -1.8)
    s.ball.owner_id = 7 if local_attacks else 21
    s.get_player(7).possession_grace = 0.0
    s.get_player(21).possession_grace = 0.0
    return s

func keeper_fixture(local_attacks: bool = false) -> RefCounted:
    var s: RefCounted = fixture()
    var shooter: IEGPlayerState = s.get_player(7 if local_attacks else 21)
    var keeper: IEGPlayerState = s.get_player(31 if local_attacks else 1)
    shooter.position = keeper.position + Vector2(0, 10 if local_attacks else -10)
    s.ball.owner_id = shooter.get_id()
    return s

func block_fixture(local_attacks: bool = true) -> RefCounted:
    var s: RefCounted = fixture()
    s.get_player(7).position = Vector2(0, -31) if local_attacks else Vector2(0, 37)
    s.get_player(21).position = Vector2(0, -37) if local_attacks else Vector2(0, 31)
    s.get_player(1).position = Vector2(0, 43)
    s.get_player(31).position = Vector2(0, -43)
    s.ball.owner_id = 7 if local_attacks else 21
    s._follow_owner()
    return s

func begin_field(s: RefCounted, local_attacks: bool = true) -> bool:
    return s.request_duel(7 if local_attacks else 21, 21 if local_attacks else 7, "field")

func begin_keeper(s: RefCounted, local_attacks: bool = false) -> bool:
    return s.request_duel(7 if local_attacks else 21, 31 if local_attacks else 1, "keeper")

func finish_cinematic(s: RefCounted) -> bool:
    for _tick: int in range(600):
        if s.phase != Match.Phase.CINEMATIC:
            return s.phase == Match.Phase.LIVE
        s.step(Command.new())
    return false

func halftime(s: RefCounted) -> void:
    s.elapsed_half = s.half_duration - Rules.TICK * 0.5
    s.step(Command.new())

func finish_match(s: RefCounted) -> void:
    halftime(s)
    s.start_second_half()
    halftime(s)

func _clock_live() -> bool:
    var s: RefCounted = fixture()
    s.step(Command.new())
    return s.phase == Match.Phase.LIVE and is_equal_approx(s.elapsed_half, Rules.TICK)

func _halftime_boundary() -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    return s.phase == Match.Phase.HALFTIME and is_equal_approx(s.elapsed_half, s.half_duration) and s.period == 1

func _halftime_freeze() -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    var before: Vector2 = s.controlled().position
    var c: IEGGameCommand = Command.new()
    c.move = Vector2.RIGHT
    for _tick: int in range(120):
        s.step(c)
    return s.phase == Match.Phase.HALFTIME and s.controlled().position == before and is_equal_approx(s.elapsed_half, s.half_duration)

func _formation_only_halftime() -> bool:
    var s: RefCounted = fixture()
    return not s.set_formation(0, "wide")

func _formation_unknown() -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    return not s.set_formation(0, "missing") and not s.set_formation(42, "balanced")

func _formation_valid() -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    return s.set_formation(0, "wide") and s.set_formation(1, "press")

func _second_half_preserves_score() -> bool:
    var s: RefCounted = fixture()
    s.team_goals[0] = 2
    s.team_goals[1] = 1
    halftime(s)
    s.start_second_half({0: "wide", 1: "press"})
    return s.period == 2 and s.phase == Match.Phase.LIVE and s.elapsed_half == 0.0 and s.team_goals == [2, 1]

func _second_half_swaps_sides() -> bool:
    var s: RefCounted = fixture()
    var blue_side: float = signf(s.get_player(1).position.y)
    var red_side: float = signf(s.get_player(31).position.y)
    halftime(s)
    s.start_second_half()
    return signf(s.get_player(1).position.y) == -blue_side and signf(s.get_player(31).position.y) == -red_side

func _finish_local_winner() -> bool:
    var s: RefCounted = fixture()
    s.team_goals[0] = 3
    s.team_goals[1] = 1
    finish_match(s)
    return s.phase == Match.Phase.FINISHED and s.winner_team == 0

func _finish_enemy_winner() -> bool:
    var s: RefCounted = fixture()
    s.team_goals[1] = 2
    finish_match(s)
    return s.phase == Match.Phase.FINISHED and s.winner_team == 1

func _finish_draw() -> bool:
    var s: RefCounted = fixture()
    s.team_goals[0] = 1
    s.team_goals[1] = 1
    finish_match(s)
    return s.phase == Match.Phase.FINISHED and s.winner_team == -1

func _finished_freeze() -> bool:
    var s: RefCounted = fixture()
    finish_match(s)
    var before: Vector2 = s.controlled().position
    var c: IEGGameCommand = Command.new()
    c.move = Vector2.RIGHT
    c.shoot = true
    for _tick: int in range(120):
        s.step(c)
    return s.phase == Match.Phase.FINISHED and s.controlled().position == before and s.team_goals == [0, 0]

func _duel_reject_same_team() -> bool:
    var s: RefCounted = field_fixture()
    return not s.request_duel(7, 8) and s.phase == Match.Phase.LIVE

func _duel_reject_missing() -> bool:
    var s: RefCounted = field_fixture()
    return not s.request_duel(7, 999) and not s.request_duel(999, 21)

func _duel_reject_nonowner() -> bool:
    var s: RefCounted = field_fixture()
    return not s.request_duel(21, 7) and s.ball.owner_id == 7

func _duel_reject_far() -> bool:
    var s: RefCounted = field_fixture()
    s.get_player(21).position = Vector2(0, -10)
    return not s.request_duel(7, 21)

func _duel_freezes_world() -> bool:
    var s: RefCounted = field_fixture()
    if not begin_field(s):
        return false
    var before: Vector2 = s.get_player(7).position
    var clock: float = s.elapsed_half
    var c: IEGGameCommand = Command.new()
    c.move = Vector2.RIGHT
    c.shoot = true
    for _tick: int in range(120):
        s.step(c)
    return s.phase == Match.Phase.DUEL_CHOICE and s.get_player(7).position == before and s.elapsed_half == clock and s.ball.owner_id == 7

func _duel_blocks_second_request() -> bool:
    var s: RefCounted = field_fixture()
    return begin_field(s) and not begin_field(s)

func _invalid_choice_keeps_prompt() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    return not s.choose_duel("teleport") and s.phase == Match.Phase.DUEL_CHOICE

func _invalid_technique_no_cost() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    return not s.choose_duel("special", "unknown") and s.get_player(7).energy == 100.0 and s.phase == Match.Phase.DUEL_CHOICE

func _wrong_technique_type_no_cost() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    return not s.choose_duel("special", "orbital_shot") and s.get_player(7).energy == 100.0

func _unaffordable_technique_no_cost() -> bool:
    var s: RefCounted = field_fixture()
    s.get_player(7).energy = 1.0
    begin_field(s)
    return not s.choose_duel("special", "drift") and s.get_player(7).energy == 1.0 and s.phase == Match.Phase.DUEL_CHOICE

func _field_special_cost() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    var expected: float = 100.0 - float(s.catalog.get_definition("drift")["cost"]) - 4.0
    return s.choose_duel("special", "drift") and is_equal_approx(s.get_player(7).energy, expected) and s.phase == Match.Phase.CINEMATIC

func _cinematic_defers_result() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    var attacker: Vector2 = s.get_player(7).position
    var defender: Vector2 = s.get_player(21).position
    s.choose_duel("special", "combat_blade")
    for _tick: int in range(30):
        s.step(Command.new())
    return s.phase == Match.Phase.CINEMATIC and s.ball.owner_id == 7 and s.get_player(7).position == attacker and s.get_player(21).position == defender and s.get_player(21).dazed_time == 0.0

func _cinematic_freezes_clock() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    var clock: float = s.elapsed_half
    s.choose_duel("left")
    return finish_cinematic(s) and s.elapsed_half == clock

func _duel_deterministic() -> bool:
    var a: RefCounted = field_fixture()
    var b: RefCounted = field_fixture()
    begin_field(a)
    begin_field(b)
    a.choose_duel("right")
    b.choose_duel("right")
    return JSON.stringify(a.duel) == JSON.stringify(b.duel)

func _field_result_possession() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    s.choose_duel("left")
    var outcome: String = String(s.duel.get("outcome", ""))
    if not finish_cinematic(s):
        return false
    return (outcome == "dribble" and s.ball.owner_id == 7) or (outcome == "tackle" and s.ball.owner_id == 21)

func _dribbled_inactive() -> bool:
    var s: RefCounted = field_fixture()
    begin_field(s)
    s.choose_duel("special", "combat_blade")
    if String(s.duel.get("outcome", "")) != "dribble" or not finish_cinematic(s):
        return false
    var loser: IEGPlayerState = s.get_player(21)
    if not is_equal_approx(loser.dazed_time, 1.0):
        return false
    var before: Vector2 = loser.position
    var c: IEGGameCommand = Command.new()
    c.move = Vector2.RIGHT
    for _tick: int in range(59):
        s.step(Command.new(), {21: c})
        if loser.position != before or loser.velocity != Vector2.ZERO or loser.dazed_time <= 0.0:
            return false
    s.step(Command.new(), {21: c})
    if loser.dazed_time != 0.0 or loser.position != before or loser.velocity != Vector2.ZERO:
        return false
    s.step(Command.new(), {21: c})
    return loser.dazed_time <= 0.0 and loser.position.x > before.x

func _allied_gain_selects() -> bool:
    var s: RefCounted = field_fixture(false)
    s.controlled_id = 8
    # Gain réel de possession : aucune dépendance à une formule de duel.
    s._gain_possession(s.get_player(7))
    return s.ball.owner_id == 7 and s.controlled_id == 7

func _enemy_gain_not_selected() -> bool:
    var s: RefCounted = field_fixture()
    s._gain_possession(s.get_player(21))
    return s.ball.owner_id == 21 and s.controlled_id == 7 and s.controlled().team_id == 0

func _keeper_choice_role() -> bool:
    var s: RefCounted = keeper_fixture()
    return begin_keeper(s) and s.duel.get("local_role", "") == "defend"

func _keeper_wrong_type_no_cost() -> bool:
    var s: RefCounted = keeper_fixture()
    begin_keeper(s)
    return not s.choose_duel("special", "combat_blade") and s.get_player(1).keeper_stamina == 100.0

func _keeper_unaffordable() -> bool:
    var s: RefCounted = keeper_fixture()
    s.get_player(1).keeper_stamina = 1.0
    begin_keeper(s)
    return not s.choose_duel("special", "photo_stop") and s.get_player(1).keeper_stamina == 1.0

func _keeper_special_stamina_cost() -> bool:
    var s: RefCounted = keeper_fixture()
    begin_keeper(s)
    var expected: float = 100.0 - float(s.catalog.get_definition("photo_stop")["cost"]) - 9.0
    return s.choose_duel("special", "photo_stop") and is_equal_approx(s.get_player(1).keeper_stamina, expected) and s.get_player(1).energy == 100.0

func _keeper_result() -> bool:
    var s: RefCounted = keeper_fixture()
    begin_keeper(s)
    s.choose_duel("special", "photo_stop")
    var outcome: String = String(s.duel.get("outcome", ""))
    if not finish_cinematic(s):
        return false
    if outcome == "capture":
        return s.ball.owner_id == 1 and s.controlled_id == 1 and s.team_goals == [0, 0]
    if outcome == "deflection":
        return s.ball.owner_id == -1 and s.controlled_id == 7 and s.team_goals == [0, 0]
    return false

func _keeper_attack_goal() -> bool:
    var s: RefCounted = keeper_fixture(true)
    s.get_player(31).keeper_stamina = 0.0
    begin_keeper(s, true)
    s.choose_duel("special", "orbital_shot")
    if String(s.duel.get("outcome", "")) != "goal":
        return false
    return finish_cinematic(s) and s.team_goals == [1, 0] and s.controlled().team_id == 0

func _keeper_deflection_is_not_possession() -> bool:
    var s: RefCounted = keeper_fixture()
    # Bonne anticipation mais faible réserve : arrêt avec marge courte.
    s.get_player(1).keeper_stamina = 33.0
    if not begin_keeper(s):
        return false
    s.choose_duel(String(s.duel["ai_choice"]))
    if String(s.duel.get("outcome", "")) != "deflection":
        return false
    return finish_cinematic(s) and s.ball.owner_id == -1 and s.controlled_id == 7 and s.team_goals == [0, 0] and s.ball.velocity.length() > 0.0

func _keeper_enemy_capture_not_selected() -> bool:
    var s: RefCounted = keeper_fixture(true)
    if not begin_keeper(s, true):
        return false
    s.choose_duel(String(s.duel["ai_choice"]))
    if String(s.duel.get("outcome", "")) != "capture":
        return false
    return finish_cinematic(s) and s.ball.owner_id == 31 and s.controlled_id == 7 and s.team_goals == [0, 0]

func _second_half_shot_credits_attacker() -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    s.start_second_half()
    s.get_player(7).position = Vector2(0, 33)
    s.get_player(31).position = Vector2(0, 43)
    s.get_player(31).keeper_stamina = 0.0
    s.ball.owner_id = 7
    s._duel_cooldown = 0.0
    if not begin_keeper(s, true):
        return false
    s.choose_duel("special", "orbital_shot")
    if String(s.duel.get("outcome", "")) != "goal":
        return false
    return finish_cinematic(s) and s.team_goals == [1, 0] and s.ball.position.z > 40.0

func _tactic_validation() -> bool:
    var s: RefCounted = fixture()
    return not s.set_tactic(0, "drift") and not s.set_tactic(99, "wide_wings") and s.set_tactic(0, "wide_wings")

func _modifier_exclusive() -> bool:
    var s: RefCounted = fixture()
    if not s.activate_modifier(7, "tempest_echo"):
        return false
    return not s.activate_modifier(7, "twin_resonance", 10)

func _modifier_partner_validation() -> bool:
    var s: RefCounted = fixture()
    return not s.activate_modifier(7, "twin_resonance", 7) and not s.activate_modifier(7, "twin_resonance", 21) and s.activate_modifier(7, "twin_resonance", 10)

func _complete_match_from_kickoff() -> bool:
    var s: RefCounted = fixture()
    # Deux périodes entières, sans avancer artificiellement l'horloge.
    var ticks_per_half: int = ceili(s.half_duration / Rules.TICK) + 2
    for _tick: int in range(ticks_per_half):
        s.step(Command.new())
        if s.phase != Match.Phase.LIVE:
            break
    if s.phase != Match.Phase.HALFTIME or not s.start_second_half({0: "wide", 1: "balanced"}):
        return false
    for _tick: int in range(ticks_per_half):
        s.step(Command.new())
        if s.phase != Match.Phase.LIVE:
            break
    return s.phase == Match.Phase.FINISHED and s.winner_team == -1 and s.team_goals == [0, 0] and s.controlled().team_id == 0

func _kickoff_protection() -> bool:
    var s: RefCounted = fixture()
    s._reset_positions()
    var owner: IEGPlayerState = s.get_player(s.ball.owner_id)
    s.get_player(21).position = owner.position + Vector2(0, -1)
    return is_equal_approx(s._duel_cooldown, 1.2) and not s.request_duel(owner.get_id(), 21) and s.phase == Match.Phase.LIVE

func _kickoff_circle_clear() -> bool:
    var s: RefCounted = fixture()
    s.get_player(21).spawn = Vector2(0, -1)
    s._reset_positions()
    return s.get_player(21).position.length() >= 9.15 - 0.00001

func _block_attack_category() -> bool:
    var s: RefCounted = block_fixture()
    if not s.request_duel(7, 21, "block"):
        return false
    if s.choose_duel("special", "combat_blade") or s.get_player(7).energy != 100.0:
        return false
    return s.choose_duel("special", "orbital_shot") and s.duel["attack_technique"] == "orbital_shot"

func _block_defense_capture() -> bool:
    var s: RefCounted = block_fixture(false)
    if not s.request_duel(21, 7, "block"):
        return false
    if s.choose_duel("special", "photo_stop") or s.get_player(7).energy != 100.0:
        return false
    if not s.choose_duel("special", "hurricane_barrier"):
        return false
    if s.duel["outcome"] != "block" or s.ball.owner_id != 21:
        return false
    return finish_cinematic(s) and s.ball.owner_id == 7 and s.controlled_id == 7 and s.team_goals == [0, 0]

func _block_before_keeper() -> bool:
    var s: RefCounted = block_fixture()
    var c: IEGGameCommand = Command.new()
    c.shoot = true
    c.technique_id = "orbital_shot"
    s.step(c)
    return s.phase == Match.Phase.DUEL_CHOICE and s.duel["kind"] == "block" and s.duel["target_id"] == 21 and s.ball.owner_id == 7

func _advance_block_cinematic(s: RefCounted) -> void:
    for _tick: int in range(600):
        if s.phase != Match.Phase.CINEMATIC:
            return
        s.step(Command.new())

func _block_success_chains_keeper() -> bool:
    var s: RefCounted = block_fixture()
    if not s.request_duel(7, 21, "block") or not s.choose_duel("special", "orbital_shot"):
        return false
    if s.duel["outcome"] != "shot_continues":
        return false
    var clock: float = s.elapsed_half
    _advance_block_cinematic(s)
    return s.phase == Match.Phase.DUEL_CHOICE and s.duel["kind"] == "keeper" and s.duel["target_id"] == 31 and s.duel["prepaid_technique"] == "orbital_shot" and s.ball.owner_id == 7 and s.elapsed_half == clock and s.team_goals == [0, 0]

func _block_prepaid_once() -> bool:
    var s: RefCounted = block_fixture()
    s.request_duel(7, 21, "block")
    s.choose_duel("special", "orbital_shot")
    _advance_block_cinematic(s)
    var energy: float = s.get_player(7).energy
    if s.phase != Match.Phase.DUEL_CHOICE or not s.choose_duel("special", "orbital_shot"):
        return false
    return is_equal_approx(s.get_player(7).energy, energy - 4.0) and s.duel["attack_technique"] == "orbital_shot"

func _block_reject_offline() -> bool:
    var s: RefCounted = block_fixture()
    s.get_player(21).position.x = 3.0
    return not s.request_duel(7, 21, "block") and s.phase == Match.Phase.LIVE

func _dazed_cannot_receive() -> bool:
    var s: RefCounted = fixture()
    var inactive: IEGPlayerState = s.get_player(8)
    inactive.dazed_time = 1.0
    var before: Vector2 = inactive.position
    s.ball.owner_id = -1
    s.ball.position = Vector3(-6, 0.19, 2)
    s.ball.velocity = Vector3(120, 0, 0)
    s._last_kicker = 21
    s.step(Command.new())
    return s.ball.owner_id == -1 and s.controlled_id == 7 and inactive.position == before and inactive.dazed_time > 0.0

func _long_range_invalid_choice_rollback() -> bool:
    var s: RefCounted = fixture()
    s.get_player(7).position = Vector2(0, -8)
    s.get_player(21).position = Vector2(10, -20)
    var c: IEGGameCommand = Command.new()
    c.shoot = true
    c.technique_id = "magnus_shot"
    s.step(c)
    if s.phase != Match.Phase.DUEL_CHOICE or s.duel["kind"] != "keeper":
        return false
    s.duel["ai_special"] = true
    var before: String = JSON.stringify(s.duel)
    if s.choose_duel("left") or s.choose_duel("special", "orbital_shot"):
        return false
    if s.get_player(7).energy != 100.0 or s.get_player(31).keeper_stamina != 100.0 or JSON.stringify(s.duel) != before or s.phase != Match.Phase.DUEL_CHOICE:
        return false
    return s.choose_duel("special", "magnus_shot") and s.duel["attack_technique"] == "magnus_shot"

func _long_range_requires_affordable_technique() -> bool:
    var s: RefCounted = fixture()
    s.get_player(7).position = Vector2(0, -8)
    s.get_player(21).position = Vector2(10, -20)
    s.get_player(7).energy = 1.0
    var c: IEGGameCommand = Command.new()
    c.shoot = true
    c.technique_id = "magnus_shot"
    s.step(c)
    return s.phase == Match.Phase.LIVE and s.ball.owner_id == 7 and s.duel.is_empty()

func _out_of_range_shot_does_not_prompt() -> bool:
    var s: RefCounted = block_fixture()
    s.get_player(7).position = Vector2.ZERO # 45 m : au-delà des 42 m du Tir Magnus.
    s.get_player(21).position = Vector2(0, -20)
    var c: IEGGameCommand = Command.new()
    c.shoot = true
    c.technique_id = "magnus_shot"
    s.step(c)
    return s.phase == Match.Phase.LIVE and s.ball.owner_id == 7 and s.duel.is_empty() and s.get_player(7).energy == 100.0

func second_half_physical_deflection(team: int) -> bool:
    var s: RefCounted = fixture()
    halftime(s)
    s.start_second_half()
    var side: float = -1.0 if team == 0 else 1.0
    s.ball.owner_id = -1
    s.ball.position = Vector3(0, 0.8, side * 41.8)
    s.ball.velocity = Vector3(0, 0, side * 30.0)
    s._last_kicker = 21 if team == 0 else 7
    s.step(Command.new())
    var deflected: bool = false
    for event: Dictionary in s.events:
        if event["kind"] == Training.EventKind.KEEPER_DEFLECTION:
            deflected = true
    return deflected and s.ball.owner_id == -1 and s.ball.velocity.z * side < 0.0 and s.controlled().team_id == 0

func _second_half_blue_physical_deflection() -> bool:
    return second_half_physical_deflection(0)

func _second_half_red_physical_deflection() -> bool:
    return second_half_physical_deflection(1)
