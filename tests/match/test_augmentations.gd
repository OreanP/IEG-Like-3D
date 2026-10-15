extends RefCounted
## Les transformations sont des décisions de simulation, indépendantes du rendu.
const Match = preload("res://core/match/match_session.gd")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")
const Roster = preload("res://scripts/match/match_roster.gd")

func run_all() -> Dictionary:
    var cases: Array[Callable] = [_named_donors, _personal_karma_only, _signature_requires_invocation,
        _initial_pg_pe, _idle_and_sprint_drain, _frozen_choice_and_cinematic,
        _reactivation_keeps_reserves, _exhaustion_until_halftime, _ordinary_duel_cost,
        _defeat_additional_cost, _signature_replaces_duel_cost, _signature_unaffordable_no_cost,
        _last_signature_keeps_bonus, _prepaid_signature_once,
        _resonance_two_techniques, _resonance_exact_base_stats, _donor_stays_on_field,
        _donor_identity_and_team, _donor_exclusivity, _one_use_per_half,
        _inherited_karma_requires_donor_ownership, _inherited_karma_expiry,
        _personal_karma_survives_resonance_end, _borrowed_reserves_survive_new_resonance,
        _keeper_role_still_required, _three_karma_and_resonance_limits,
        _snapshots_are_independent, _signature_range_falloff, _keeper_signature_branches,
        _edited_technique_stat_changes_contextual_score, _edited_resonance_duration,
        _restart_keeps_pg_pe_and_usage, _halftime_refills_active_karma,
        _custom_karma_owner_keys, _prepaid_exhausted_signature_loss,
        _enemy_prepaid_signature_is_preserved, _normal_shot_karma_cost_once]
    var passed: int = 0
    var lines: Array[String] = []
    for test: Callable in cases:
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "AUGMENTATIONS : " + String(test.get_method()))
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func fixture() -> IEGMatchSession:
    var roster: Dictionary = Roster.build()
    var s: IEGMatchSession = Match.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    s._duel_cooldown = 0.0
    s.ball.owner_id = 7
    s.controlled_id = 7
    s._follow_owner()
    return s

func has_id(definitions: Array[Dictionary], id: String) -> bool:
    for definition: Dictionary in definitions:
        if definition["id"] == id:
            return true
    return false

func begin_field(s: IEGMatchSession) -> bool:
    s.get_player(7).position = Vector2.ZERO
    s.get_player(22).position = Vector2(0, -1.8)
    s.get_player(7).possession_grace = 0.0
    s.ball.owner_id = 7
    return s.request_duel(7, 22, "field")

func finish_cinematic(s: IEGMatchSession) -> void:
    for _tick: int in range(700):
        if s.phase != Match.Phase.CINEMATIC:
            break
        s.step(Command.new())

func _named_donors() -> bool:
    var s: IEGMatchSession = fixture()
    return s.get_player(7).profile.content_key == "soren_vale" and s.get_player(1).profile.display_name == "Maëlle Néris" and s.get_player(1).profile.content_key == "maelle_neris"

func _personal_karma_only() -> bool:
    var s: IEGMatchSession = fixture()
    return not s.activate_modifier(8, "astreion") and not s.activate_modifier(7, "thalassa") and s.activate_modifier(7, "astreion") and s.activate_modifier(1, "thalassa") and has_id(s.get_available_modifiers(7, "KARMA"), "astreion")

func _signature_requires_invocation() -> bool:
    var s: IEGMatchSession = fixture()
    if s.can_use_technique(7, "perihelion_hammer", "TIR") or has_id(s.get_available_techniques(7), "perihelion_hammer"):
        return false
    return s.activate_modifier(7, "astreion") and s.can_use_technique(7, "perihelion_hammer", "TIR") and not s.can_use_technique(7, "abyssal_cathedral", "GAR")

func _initial_pg_pe() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.activate_modifier(1, "thalassa")
    var a: Dictionary = s.get_player(7).modifiers["KARMA"]
    var t: Dictionary = s.get_player(1).modifiers["KARMA"]
    return a["pg"] == 240.0 and a["pe"] == 80.0 and a["energy"] == a["pe"] and a["energy_max"] == a["pe_max"] and t["pg"] == 300.0 and t["pe"] == 100.0

func _idle_and_sprint_drain() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.step(Command.new())
    var state: Dictionary = s.get_player(7).modifiers["KARMA"]
    if not is_equal_approx(state["pe"], 80.0 - Rules.TICK) or state["pg"] != 240.0:
        return false
    var c: IEGGameCommand = Command.new()
    c.move = Vector2.RIGHT
    c.sprint = true
    s.step(c)
    return is_equal_approx(state["pe"], 80.0 - 3.0 * Rules.TICK) and state["pg"] == 240.0

func _frozen_choice_and_cinematic() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    if not begin_field(s):
        return false
    var before: String = JSON.stringify(s.get_player(7).modifiers)
    for _tick: int in range(30):
        s.step(Command.new())
    if JSON.stringify(s.get_player(7).modifiers) != before:
        return false
    s.choose_duel("right")
    before = JSON.stringify(s.get_player(7).modifiers)
    for _tick: int in range(30):
        s.step(Command.new())
    return JSON.stringify(s.get_player(7).modifiers) == before

func _reactivation_keeps_reserves() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    var state: Dictionary = s.get_player(7).modifiers["KARMA"]
    state["pg"] = 54.0
    state["pe"] = 23.0
    return s.deactivate_modifier(7, "KARMA") and s.activate_modifier(7, "astreion") and s.get_player(7).modifiers["KARMA"]["pg"] == 54.0 and s.get_player(7).modifiers["KARMA"]["pe"] == 23.0

func _exhaustion_until_halftime() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.get_player(7).modifiers["KARMA"]["pe"] = Rules.TICK * 0.5
    s.step(Command.new())
    if s.activate_modifier(7, "astreion") or s.get_player(7).dazed_time > 0.0:
        return false
    s.phase = Match.Phase.HALFTIME
    return s.start_second_half() and s.activate_modifier(7, "astreion") and s.get_player(7).modifiers["KARMA"]["pg"] == 240.0 and s.get_player(7).modifiers["KARMA"]["pe"] == 80.0

func _ordinary_duel_cost() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    begin_field(s)
    s.duel["ai_special"] = false
    var opposite: String = "right" if s.duel["ai_choice"] == "left" else "left"
    if not s.choose_duel(opposite) or not s.duel["attacker_won"]:
        return false
    var state: Dictionary = s.get_player(7).modifiers["KARMA"]
    return state["pg"] == 230.0 and state["pe"] == 76.0

func _defeat_additional_cost() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.get_player(7).energy = 1.0
    begin_field(s)
    s.duel["ai_special"] = false
    if not s.choose_duel(String(s.duel["ai_choice"])) or s.duel["attacker_won"]:
        return false
    return s.get_player(7).modifiers["KARMA"]["pg"] == 210.0 and s.get_player(7).modifiers["KARMA"]["pe"] == 76.0

func shot_fixture() -> IEGMatchSession:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.get_player(7).position = Vector2(0, -31)
    s.get_player(22).position = Vector2(15, -30)
    return s

func _signature_replaces_duel_cost() -> bool:
    var s: IEGMatchSession = shot_fixture()
    if not s.request_duel(7, 21, "keeper") or not s.choose_duel("special", "perihelion_hammer"):
        return false
    return s.duel["attacker_won"] and s.get_player(7).modifiers["KARMA"]["pg"] == 170.0 and s.get_player(7).modifiers["KARMA"]["pe"] == 68.0 and s.get_player(7).energy == 96.0

func _signature_unaffordable_no_cost() -> bool:
    var s: IEGMatchSession = shot_fixture()
    s.get_player(7).modifiers["KARMA"]["pg"] = 69.0
    s.request_duel(7, 21, "keeper")
    var before: String = JSON.stringify(s.get_player(7).modifiers)
    return has_id(s.get_available_techniques(7, "TIR"), "perihelion_hammer") and not s.can_use_technique(7, "perihelion_hammer", "TIR") and not s.choose_duel("special", "perihelion_hammer") and JSON.stringify(s.get_player(7).modifiers) == before and s.get_player(7).energy == 100.0

func _last_signature_keeps_bonus() -> bool:
    var s: IEGMatchSession = shot_fixture()
    s.get_player(7).modifiers["KARMA"]["pg"] = 70.0
    s.get_player(7).modifiers["KARMA"]["pe"] = 12.0
    s.request_duel(7, 21, "keeper")
    s.duel["ai_special"] = false
    return s.choose_duel("special", "perihelion_hammer") and is_equal_approx(s.duel["attack_score"], 129.0) and not s.get_player(7).modifiers.has("KARMA") and s.get_player(7).karma_reserves["astreion"]["pg"] == 0.0

func _prepaid_signature_once() -> bool:
    var s: IEGMatchSession = shot_fixture()
    s.get_player(22).position = Vector2(0, -37)
    s.request_duel(7, 22, "block")
    if not s.choose_duel("special", "perihelion_hammer"):
        return false
    finish_cinematic(s)
    var pg: float = s.get_player(7).modifiers["KARMA"]["pg"]
    var pe: float = s.get_player(7).modifiers["KARMA"]["pe"]
    if s.phase != Match.Phase.DUEL_CHOICE or not s.choose_duel("special", "perihelion_hammer"):
        return false
    return s.get_player(7).modifiers["KARMA"]["pg"] == pg and s.get_player(7).modifiers["KARMA"]["pe"] == pe

func _resonance_two_techniques() -> bool:
    var s: IEGMatchSession = fixture()
    var before: int = s.get_available_techniques(8).size()
    if s.can_use_technique(8, "drift") or not s.activate_modifier(8, "sovereign_orbit"):
        return false
    return s.get_available_techniques(8).size() == before + 2 and s.can_use_technique(8, "drift") and s.can_use_technique(8, "magnus_shot") and s.get_player(8).profile.technique_ids.size() == 2

func _resonance_exact_base_stats() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.activate_modifier(8, "sovereign_orbit")
    var bonus: Dictionary = s.get_stat_bonuses(8)
    return bonus["shot"] == 18.0 and bonus["dribble"] == 16.0 and bonus["technique"] == 17.0 and bonus["defense"] == 0.0 and s.activate_modifier(8, "astreion") and s.get_stat_bonuses(8)["shot"] == 36.0

func _donor_stays_on_field() -> bool:
    var s: IEGMatchSession = fixture()
    var before: Vector2 = s.get_player(7).position
    return s.activate_modifier(8, "sovereign_orbit", 7) and s.players.size() == 22 and s.get_player(7).position == before and s.get_player(7).dazed_time == 0.0

func _donor_identity_and_team() -> bool:
    var s: IEGMatchSession = fixture()
    return not s.activate_modifier(7, "sovereign_orbit", 7) and not s.activate_modifier(8, "sovereign_orbit", 27) and not s.activate_modifier(8, "sovereign_orbit", 9) and s.activate_modifier(8, "sovereign_orbit", 7)

func _donor_exclusivity() -> bool:
    var s: IEGMatchSession = fixture()
    return s.activate_modifier(8, "sovereign_orbit", 7) and not s.activate_modifier(9, "sovereign_orbit", 7) and s.deactivate_modifier(8, "RESONANCE") and s.activate_modifier(9, "sovereign_orbit", 7)

func _one_use_per_half() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "sovereign_orbit")
    s.deactivate_modifier(8, "RESONANCE")
    if s.activate_modifier(8, "deep_watch"):
        return false
    s.phase = Match.Phase.HALFTIME
    return s.start_second_half() and s.activate_modifier(8, "deep_watch")

func _inherited_karma_requires_donor_ownership() -> bool:
    var s: IEGMatchSession = fixture()
    s.get_player(7).profile.karma_ids.clear()
    var definition: Dictionary = s.catalog.get_definition("astreion")
    definition["properties"]["owner_keys"] = []
    s.catalog._overrides["astreion"] = definition
    return s.activate_modifier(8, "sovereign_orbit") and s.can_use_technique(8, "drift") and not s.activate_modifier(8, "astreion")

func _inherited_karma_expiry() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "sovereign_orbit")
    s.activate_modifier(8, "astreion")
    s.get_player(8).modifiers["RESONANCE"]["time"] = Rules.TICK * 0.5
    s.step(Command.new())
    return s.get_player(8).modifiers.is_empty() and not s.can_use_technique(8, "drift") and s.get_player(8).karma_reserves.has("astreion")

func _personal_karma_survives_resonance_end() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "deep_watch")
    s.activate_modifier(7, "astreion")
    return s.deactivate_modifier(7, "RESONANCE") and s.get_player(7).modifiers.has("KARMA") and s.get_player(7).modifiers["KARMA"]["id"] == "astreion"

func _borrowed_reserves_survive_new_resonance() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "sovereign_orbit")
    s.activate_modifier(8, "astreion")
    s.get_player(8).modifiers["KARMA"]["pg"] = 130.0
    s.deactivate_modifier(8, "KARMA")
    return s.activate_modifier(8, "astreion") and s.get_player(8).modifiers["KARMA"]["pg"] == 130.0

func _keeper_role_still_required() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "deep_watch")
    if not s.can_use_technique(8, "aquablast") or s.can_use_technique(8, "gyroscopic_stop"):
        return false
    return s.activate_modifier(8, "thalassa") and not s.can_use_technique(8, "abyssal_cathedral")

func _three_karma_and_resonance_limits() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.activate_modifier(1, "thalassa")
    s.activate_modifier(8, "sovereign_orbit")
    s.activate_modifier(8, "astreion")
    s.activate_modifier(9, "deep_watch")
    var energy: float = s.get_player(9).energy
    return not s.activate_modifier(9, "thalassa") and s.count_active_modifiers(0, "KARMA") == 3 and s.count_active_modifiers(0, "RESONANCE") == 2 and s.get_player(9).energy == energy

func _snapshots_are_independent() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "sovereign_orbit")
    s.activate_modifier(8, "astreion")
    var active: Array[Dictionary] = s.get_active_modifiers(8)
    active[0]["pg"] = 0.0
    active[1]["techniques"].clear()
    return s.get_player(8).modifiers["KARMA"]["pg"] == 240.0 and s.get_player(8).modifiers["KARMA"]["inherited_from"] and s.get_player(8).modifiers["KARMA"]["inherited_from_id"] == 7 and s.get_player(8).modifiers["RESONANCE"]["techniques"].size() == 2

func _signature_range_falloff() -> bool:
    var scores: Array[float] = []
    for distance: float in [14.0, 34.0, 4.0]:
        var s: IEGMatchSession = shot_fixture()
        var definition: Dictionary = s.catalog.get_definition("perihelion_hammer")
        definition["range_bonus"] = 18.0
        s.catalog._overrides["perihelion_hammer"] = definition
        s.get_player(7).position = Vector2(0, -45.0 + distance)
        s._shot_technique = "perihelion_hammer"
        if not s.request_duel(7, 21, "keeper"):
            return false
        s.duel["ai_special"] = false
        if not s.choose_duel("special", "perihelion_hammer"):
            return false
        scores.append(float(s.duel["attack_score"]))
    # 5 points de distance ordinaire + 7,2 de perte propre à la technique.
    return is_equal_approx(scores[0] - scores[1], 12.2) and is_equal_approx(scores[0] - scores[2], 7.2)

func _keeper_signature_branches() -> bool:
    # Ajuster seulement la puissance de tir permet d'exercer les trois décisions du moteur.
    for power: float in [10.0, 65.0, 90.0]:
        var s: IEGMatchSession = fixture()
        s.activate_modifier(1, "thalassa")
        s.get_player(27).profile.technique_ids = ["orbital_shot"]
        s.get_player(27).position = Vector2(0, 31)
        s.ball.owner_id = 27
        s.request_duel(27, 1, "keeper")
        s.duel["ai_special"] = true
        var shot: Dictionary = s.catalog.get_definition("orbital_shot")
        shot["power"] = power
        s.catalog._overrides["orbital_shot"] = shot
        if not s.choose_duel("special", "abyssal_cathedral"):
            return false
        var expected: String = "capture" if power == 10.0 else ("deflection" if power == 65.0 else "goal")
        if s.duel["outcome"] != expected:
            return false
        var owner: int = s.ball.owner_id
        finish_cinematic(s)
        if expected == "deflection" and (s.ball.owner_id != -1 or owner != 27 or s.controlled().team_id != 0):
            return false
    return true

func _edited_technique_stat_changes_contextual_score() -> bool:
    var scores: Array[float] = []
    for powered: bool in [false, true]:
        var s: IEGMatchSession = fixture()
        if powered:
            var definition: Dictionary = s.catalog.get_definition("astreion")
            definition["properties"]["stat_bonuses"] = {"shot": 80.0, "technique": 20.0}
            s.catalog._overrides["astreion"] = definition
            s.activate_modifier(7, "astreion")
        begin_field(s)
        s.duel["ai_special"] = false
        s.choose_duel("right" if s.duel["ai_choice"] == "left" else "left")
        scores.append(float(s.duel["attack_score"]))
    # La technique intervient à 25 % ; le bonus de tir ne s'applique pas au dribble.
    return is_equal_approx(scores[1] - scores[0], 5.0)

func _edited_resonance_duration() -> bool:
    var s: IEGMatchSession = fixture()
    var definition: Dictionary = s.catalog.get_definition("sovereign_orbit")
    definition["duration"] = 120.0
    s.catalog._overrides["sovereign_orbit"] = definition
    if not s.activate_modifier(8, "sovereign_orbit"):
        return false
    var state: Dictionary = s.get_player(8).modifiers["RESONANCE"]
    if state["energy_max"] != 120.0:
        return false
    state["time"] = 46.0
    state["energy"] = 0.00001 # Le timer reste l'unique budget de cette fiche structurée.
    s.step(Command.new())
    return s.get_player(8).modifiers.has("RESONANCE") and is_equal_approx(state["energy"], 46.0 - Rules.TICK)

func _restart_keeps_pg_pe_and_usage() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(8, "sovereign_orbit")
    s.activate_modifier(8, "astreion")
    s.get_player(8).modifiers["KARMA"]["pg"] = 121.0
    s.get_player(8).modifiers["KARMA"]["pe"] = 35.0
    s.deactivate_modifier(8, "KARMA")
    s._reset_positions()
    return s.get_player(8).resonance_used_period == 1 and s.activate_modifier(8, "astreion") and s.get_player(8).modifiers["KARMA"]["pg"] == 121.0 and s.get_player(8).modifiers["KARMA"]["pe"] == 35.0

func _halftime_refills_active_karma() -> bool:
    var s: IEGMatchSession = fixture()
    s.activate_modifier(7, "astreion")
    s.get_player(7).modifiers["KARMA"]["pg"] = 30.0
    s.get_player(7).modifiers["KARMA"]["pe"] = 4.0
    var edited: Dictionary = s.catalog.get_definition("astreion")
    edited["properties"]["pg_max"] = 300.0
    edited["properties"]["pe_max"] = 120.0
    s.catalog._overrides["astreion"] = edited
    s.phase = Match.Phase.HALFTIME
    if not s.start_second_half():
        return false
    var karma: Dictionary = s.get_player(7).modifiers["KARMA"]
    return karma["pg"] == 300.0 and karma["pe"] == 120.0 and karma["energy_max"] == 120.0 and s.get_player(7).karma_reserves["astreion"]["pg"] == 300.0

func _custom_karma_owner_keys() -> bool:
    var s: IEGMatchSession = fixture()
    var definition: Dictionary = s.catalog.get_definition("astreion")
    definition["id"] = "custom_forge"
    definition["properties"]["owner_keys"] = [s.get_player(8).profile.content_key]
    s.catalog._overrides["custom_forge"] = definition
    return not s.activate_modifier(9, "custom_forge") and has_id(s.get_available_modifiers(8, "KARMA"), "custom_forge") and s.activate_modifier(8, "custom_forge") and not s.get_player(8).modifiers["KARMA"]["inherited_from"]

func _prepaid_exhausted_signature_loss() -> bool:
    var s: IEGMatchSession = shot_fixture()
    s.get_player(7).modifiers["KARMA"]["pe"] = 12.0
    s.get_player(22).position = Vector2(0, -37)
    s.request_duel(7, 22, "block")
    s.duel["ai_special"] = false
    if not s.choose_duel("special", "perihelion_hammer") or s.get_player(7).modifiers.has("KARMA"):
        return false
    finish_cinematic(s)
    if s.phase != Match.Phase.DUEL_CHOICE:
        return false
    var stop: Dictionary = s.catalog.get_definition("photo_stop")
    stop["power"] = 200.0
    s.catalog._overrides["photo_stop"] = stop
    s.get_player(21).profile.technique_ids = ["photo_stop"]
    s.duel["ai_special"] = true
    if not s.choose_duel("left") or s.duel["attacker_won"]:
        return false
    return s.duel["attack_technique"] == "perihelion_hammer" and s.duel["attack_bonus"] == 18.0 and s.get_player(7).karma_reserves["astreion"]["pg"] == 150.0

func _enemy_prepaid_signature_is_preserved() -> bool:
    var s: IEGMatchSession = fixture()
    var actor: IEGPlayerState = s.get_player(27)
    actor.team_id = 0 # Installation d'un état de test ; l'interface interdit l'activation adverse.
    actor.profile.karma_ids = ["astreion"]
    s.activate_modifier(27, "astreion")
    actor.team_id = 1
    actor.position = Vector2(0, 31)
    actor.profile.technique_ids = ["perihelion_hammer"]
    s.get_player(8).position = Vector2(0, 37)
    s.ball.owner_id = 27
    s._shot_technique = "perihelion_hammer"
    if not s.request_duel(27, 8, "block"):
        return false
    s.duel["ai_special"] = true
    if not s.choose_duel("left") or s.duel["attack_technique"] != "perihelion_hammer":
        return false
    finish_cinematic(s)
    var pg: float = actor.modifiers["KARMA"]["pg"]
    if s.phase != Match.Phase.DUEL_CHOICE:
        return false
    actor.profile.technique_ids = ["orbital_shot"] # Une nouvelle sélection IA donnerait un autre tir.
    s.duel["ai_special"] = true
    return s.choose_duel("left") and s.duel["attack_technique"] == "perihelion_hammer" and actor.modifiers["KARMA"]["pg"] == pg

func _normal_shot_karma_cost_once() -> bool:
    var s: IEGMatchSession = shot_fixture()
    s.get_player(22).position = Vector2(0, -37)
    s.request_duel(7, 22, "block")
    s.duel["ai_special"] = false
    var direction: String = "right" if s.duel["ai_choice"] == "left" else "left"
    if not s.choose_duel(direction) or not s.duel["attacker_won"]:
        return false
    finish_cinematic(s)
    if s.phase != Match.Phase.DUEL_CHOICE or s.duel["prepaid_technique"] != "":
        return false
    var before: Dictionary = s.get_player(7).modifiers["KARMA"].duplicate(true)
    if s.choose_duel("special", "perihelion_hammer"):
        return false
    s.duel["ai_special"] = false
    direction = "right" if s.duel["ai_choice"] == "left" else "left"
    if not s.choose_duel(direction) or not s.duel["attacker_won"]:
        return false
    return before["pg"] == 230.0 and before["pe"] == 76.0 and s.get_player(7).modifiers["KARMA"]["pg"] == 230.0 and s.get_player(7).modifiers["KARMA"]["pe"] == 76.0 and s.duel["attack_technique"] == ""
