extends RefCounted
## Le nouveau lot emprunte le moteur de match réel ; aucune issue n'est injectée.
## Les éditions et sauvegardes de test restent dans un fichier user:// isolé.
const Catalog = preload("res://core/content/technique_catalog.gd")
const Match = preload("res://core/match/match_session.gd")
const Command = preload("res://core/game_command.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const RouteCatalog = preload("res://core/routes/route_catalog.gd")
const ORDINARY: Dictionary = {
    "seismic_strike": "TIR", "prism_ricochet": "TIR",
    "paper_escape": "ATT", "syncope": "ATT",
    "bronze_rampart": "DEF", "mechanical_brambles": "DEF",
    "titan_grip": "GAR", "midnight_dial": "GAR"}
var _path: String = "user://test_new_content_%d.json" % OS.get_process_id()
var _total: int = 0
var _passed: int = 0
var _lines: Array[String] = []

func run_all() -> Dictionary:
    _total = 0
    _passed = 0
    _lines.clear()
    _cleanup()
    _catalog_contracts()
    _cinematic_timing()
    _roster_contracts()
    _route_loadouts()
    _personal_signatures()
    _signature_budgets()
    _signature_defeats()
    _signature_refusal_is_atomic()
    _freeze_and_reactivation()
    _field_dribbles()
    _field_defenses()
    _shot_blocks()
    _shots_and_range()
    _keeper_outcomes()
    _persisted_new_entries()
    _cleanup()
    return {"total": _total, "passed": _passed, "failed": _total - _passed, "lines": _lines.duplicate()}

func _fixture() -> IEGMatchSession:
    var roster: Dictionary = Roster.build()
    var session: IEGMatchSession = Match.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    session.catalog = Catalog.new(_path)
    session._duel_cooldown = 0.0
    return session

func _check(condition: bool, message: String) -> void:
    _total += 1
    _passed += 1 if condition else 0
    _lines.append(("OK   " if condition else "ÉCHEC   ") + "NOUVEAU LOT : " + message)

func _cleanup() -> void:
    for path: String in [_path, _path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _known(entries: Array[Dictionary], id: String) -> bool:
    for entry: Dictionary in entries:
        if str(entry.get("id", "")) == id:
            return true
    return false

func _finish(session: IEGMatchSession) -> void:
    for _tick: int in range(700):
        if session.phase != Match.Phase.CINEMATIC:
            break
        session.step(Command.new())

func _field(session: IEGMatchSession, attacker: int, defender: int) -> bool:
    session.get_player(attacker).position = Vector2.ZERO
    session.get_player(defender).position = Vector2(0, -1.5)
    session.ball.owner_id = attacker
    session._follow_owner()
    return session.request_duel(attacker, defender, "field")

func _block(session: IEGMatchSession) -> bool:
    session.get_player(27).position = Vector2(0, 31)
    session.get_player(4).position = Vector2(0, 37)
    session.ball.owner_id = 27
    session._follow_owner()
    return session.request_duel(27, 4, "block")

func _catalog_contracts() -> void:
    var catalog: IEGTechniqueCatalog = Catalog.new(_path)
    _check(catalog.all_definitions().size() == 30 and catalog.validate_entries(catalog.all_definitions()).is_empty(),
        "30 définitions valides, références croisées comprises")
    for id: String in ORDINARY:
        var data: Dictionary = catalog.get_definition(id)
        _check(data.get("category", "") == ORDINARY[id] and not data.get("properties", {}).has("karma_id")
            and float(data.get("cost", 0)) > 0.0 and float(data.get("duration", 0)) >= 3.0,
            id + " : technique ordinaire de la bonne famille, coût et durée explicites")
    for pair: Array in [["vaelis", "ninefold_hunt", "ATT", 210.0, 95.0, 55.0, 10.0],
            ["orvann", "antler_citadel", "DEF", 260.0, 80.0, 65.0, 11.0]]:
        var karma: Dictionary = catalog.get_definition(str(pair[0]))
        var signature: Dictionary = catalog.get_definition(str(pair[1]))
        _check(karma.get("category") == "KARMA" and karma.properties.signature_id == pair[1]
            and karma.properties.pg_max == pair[3] and karma.properties.pe_max == pair[4]
            and karma.properties.max_active_per_team == 3 and signature.category == pair[2]
            and signature.properties.karma_id == pair[0] and signature.properties.pg_cost == pair[5]
            and signature.properties.pe_cost == pair[6], str(pair[0]) + " : réserves et signature liées réciproquement")
    _check(catalog.get_definition("bronze_rampart").properties.block
        and catalog.get_definition("antler_citadel").properties.block
        and not catalog.get_definition("mechanical_brambles").properties.block,
        "blocages de tir et intervention au sol distingués dans les données")
    for id: String in ["titan_grip", "midnight_dial"]:
        var properties: Dictionary = catalog.get_definition(id).properties
        _check(properties.success_animation != properties.failure_animation
            and properties.parry_animation != properties.success_animation
            and properties.parry_animation != properties.failure_animation
            and is_equal_approx(float(properties.branch_at), 0.58),
            id + " : capture, déviation et échec nommés avec révélation commune")

func _roster_contracts() -> void:
    var session: IEGMatchSession = _fixture()
    var owners: Dictionary = {"seismic_strike": 7, "prism_ricochet": 7, "paper_escape": 8,
        "syncope": 8, "bronze_rampart": 4, "mechanical_brambles": 4, "titan_grip": 1, "midnight_dial": 1}
    for id: String in owners:
        var owner: int = int(owners[id])
        _check(session.can_use_technique(owner, id, str(ORDINARY[id]))
            and not session.can_use_technique(10, id), id + " : disponible sur son porteur, pas sur un autre joueur")
    _check(not session.can_use_technique(8, "titan_grip") and not session.can_use_technique(4, "midnight_dial"),
        "les techniques GAR restent réservées aux gardiens")

func _route_loadouts() -> void:
    var routes: IEGRouteCatalog = RouteCatalog.new()
    var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RouteCatalog.DATA_PATH))
    var seen: Dictionary = {}
    var valid: bool = routes.last_errors.is_empty()
    for team: Dictionary in document.get("teams", []):
        var roster: Dictionary = routes.build_roster(str(team.id))
        valid = valid and roster.get("profiles", []).size() == 22
        for index: int in range(11, roster.get("profiles", []).size()):
            var profile: IEGPlayerProfile = roster.profiles[index]
            for id: String in profile.technique_ids:
                if ORDINARY.has(id):
                    seen[id] = true
                if ORDINARY.get(id, "") == "GAR" and index != 11:
                    valid = false
    _check(valid and seen.size() == ORDINARY.size(), "les six adversaires réutilisent les profils du moteur et proposent les huit techniques")

func _personal_signatures() -> void:
    var session: IEGMatchSession = _fixture()
    _check(not session.can_use_technique(8, "ninefold_hunt") and not session.can_use_technique(4, "antler_citadel"),
        "les signatures sont absentes tant que leur Karma n'est pas invoqué")
    _check(not session.activate_modifier(7, "vaelis") and not session.activate_modifier(8, "orvann")
        and not session.activate_modifier(28, "vaelis"), "propriété personnelle et équipe locale respectées")
    _check(session.activate_modifier(8, "vaelis") and session.activate_modifier(4, "orvann")
        and session.can_use_technique(8, "ninefold_hunt", "ATT")
        and session.can_use_technique(4, "antler_citadel", "DEF")
        and not session.can_use_technique(8, "antler_citadel")
        and not session.can_use_technique(4, "ninefold_hunt"), "les deux invocations déverrouillent uniquement leur propre signature")
    _check(not session.can_use_technique(4, "antler_citadel", "ATT")
        and not session.can_use_technique(8, "ninefold_hunt", "TIR"), "une signature défensive ne devient pas un dribble ou un tir")

func _signature_budgets() -> void:
    for data: Array in [[8, "vaelis", "ninefold_hunt", 55.0, 10.0], [4, "orvann", "antler_citadel", 65.0, 11.0]]:
        var session: IEGMatchSession = _fixture()
        var owner: int = int(data[0])
        session.activate_modifier(owner, str(data[1]))
        var before: Dictionary = session.get_player(owner).modifiers.KARMA.duplicate(true)
        var began: bool = _field(session, 8, 22) if owner == 8 else _block(session)
        session.duel.ai_special = false
        var chosen: bool = began and session.choose_duel("special", str(data[2]))
        var karma: Dictionary = session.get_player(owner).modifiers.KARMA
        _check(chosen and int(session.duel.winner_id) == owner
            and is_equal_approx(float(karma.pg), float(before.pg) - float(data[3]))
            and is_equal_approx(float(karma.pe), float(before.pe) - float(data[4])),
            str(data[2]) + " : succès réel, coût PG/PE de signature débité une seule fois")
        _finish(session)
        _check(session.ball.owner_id == owner and session.controlled_id == owner
            and session.get_player(owner).team_id == 0, str(data[2]) + " : récupération réelle sélectionnant immédiatement le porteur allié")

func _signature_defeats() -> void:
    for owner: int in [8, 4]:
        var session: IEGMatchSession = _fixture()
        var karma_id: String = "vaelis" if owner == 8 else "orvann"
        var signature_id: String = "ninefold_hunt" if owner == 8 else "antler_citadel"
        var opponent_id: String = "hurricane_barrier" if owner == 8 else "orbital_shot"
        session.activate_modifier(owner, karma_id)
        var opponent: Dictionary = session.catalog.get_definition(opponent_id)
        opponent.power = 200.0
        session.catalog._overrides[opponent_id] = opponent
        session.get_player(22 if owner == 8 else 27).profile.technique_ids = [opponent_id]
        var began: bool = _field(session, 8, 22) if owner == 8 else _block(session)
        session.duel.ai_special = true
        var before: Dictionary = session.get_player(owner).modifiers.KARMA.duplicate(true)
        var chosen: bool = session.choose_duel("special", signature_id)
        var expected_pg: float = float(before.pg) - float(session.catalog.get_definition(signature_id).properties.pg_cost) - float(session.catalog.get_definition(karma_id).properties.defeat_pg_cost)
        var expected_pe: float = float(before.pe) - float(session.catalog.get_definition(signature_id).properties.pe_cost)
        var karma: Dictionary = session.get_player(owner).modifiers.KARMA
        _check(began and chosen and int(session.duel.winner_id) != owner
            and is_equal_approx(float(karma.pg), expected_pg) and is_equal_approx(float(karma.pe), expected_pe),
            signature_id + " : défaite calculée et surcoût PG appliqué sans double coût ordinaire")
        _finish(session)
        _check(session.ball.owner_id == (22 if owner == 8 else 27) and session.controlled().team_id == 0
            and (session.phase == Match.Phase.LIVE if owner == 8 else session.phase == Match.Phase.DUEL_CHOICE),
            signature_id + " : récupération adverse ou tir poursuivi sans sélection adverse")

func _signature_refusal_is_atomic() -> void:
    for budget: String in ["pg", "pe"]:
        for owner: int in [8, 4]:
            var session: IEGMatchSession = _fixture()
            var karma_id: String = "vaelis" if owner == 8 else "orvann"
            var signature: String = "ninefold_hunt" if owner == 8 else "antler_citadel"
            session.activate_modifier(owner, karma_id)
            session.get_player(owner).modifiers.KARMA[budget] = 0.5
            var began: bool = _field(session, 8, 22) if owner == 8 else _block(session)
            var before: String = JSON.stringify(session.get_player(owner).modifiers)
            var energy: float = session.get_player(owner).energy
            _check(began and not session.choose_duel("special", signature)
                and session.phase == Match.Phase.DUEL_CHOICE and session.get_player(owner).energy == energy
                and JSON.stringify(session.get_player(owner).modifiers) == before,
                signature + " : réserve " + budget + " insuffisante, décision refusée sans paiement partiel")

func _freeze_and_reactivation() -> void:
    for owner: int in [8, 4]:
        var session: IEGMatchSession = _fixture()
        var karma_id: String = "vaelis" if owner == 8 else "orvann"
        var signature: String = "ninefold_hunt" if owner == 8 else "antler_citadel"
        session.activate_modifier(owner, karma_id)
        var began: bool = _field(session, 8, 22) if owner == 8 else _block(session)
        var before: String = JSON.stringify(session.get_player(owner).modifiers)
        var clock: float = session.elapsed_half
        for _tick: int in range(20):
            session.step(Command.new())
        var frozen_choice: bool = before == JSON.stringify(session.get_player(owner).modifiers)
        session.duel.ai_special = false
        var chosen: bool = session.choose_duel("special", signature)
        before = JSON.stringify(session.get_player(owner).modifiers)
        for _tick: int in range(20):
            session.step(Command.new())
        _check(began and chosen and frozen_choice and session.elapsed_half == clock
            and before == JSON.stringify(session.get_player(owner).modifiers),
            karma_id + " : chrono et réserves gelés pendant choix et cinématique")
        _finish(session)
        var pg: float = session.get_player(owner).modifiers.KARMA.pg
        var pe: float = session.get_player(owner).modifiers.KARMA.pe
        _check(session.deactivate_modifier(owner, "KARMA") and session.activate_modifier(owner, karma_id)
            and session.get_player(owner).modifiers.KARMA.pg == pg and session.get_player(owner).modifiers.KARMA.pe == pe,
            karma_id + " : désactivation et réinvocation ne restaurent pas les réserves dépensées")

func _field_dribbles() -> void:
    for id: String in ["paper_escape", "syncope"]:
        var session: IEGMatchSession = _fixture()
        var began: bool = _field(session, 8, 22)
        session.duel.ai_special = false
        var position: Vector2 = session.get_player(8).position
        var chosen: bool = session.choose_duel("special", id)
        var scored_win: bool = float(session.duel.attack_score) > float(session.duel.defend_score)
        _finish(session)
        _check(began and chosen and scored_win and session.duel.outcome == "dribble"
            and session.ball.owner_id == 8 and session.controlled_id == 8
            and session.get_player(8).position != position and session.get_player(22).dazed_time == 1.0,
            id + " : dribble calculé, dépassement, sélection alliée et une seconde d'inactivité adverse")

func _field_defenses() -> void:
    for id: String in ["bronze_rampart", "mechanical_brambles"]:
        var session: IEGMatchSession = _fixture()
        var began: bool = _field(session, 27, 4)
        session.duel.ai_special = false
        var chosen: bool = session.choose_duel("special", id)
        var scored_win: bool = float(session.duel.defend_score) > float(session.duel.attack_score)
        _finish(session)
        _check(began and chosen and scored_win and session.duel.outcome == "tackle"
            and session.ball.owner_id == 4 and session.controlled_id == 4,
            id + " : intervention réelle, résultat calculé et récupération du défenseur allié")

func _shot_blocks() -> void:
    for id: String in ["bronze_rampart", "antler_citadel"]:
        var session: IEGMatchSession = _fixture()
        if id == "antler_citadel":
            session.activate_modifier(4, "orvann")
        var began: bool = _block(session)
        session.duel.ai_special = false
        var chosen: bool = session.choose_duel("special", id)
        var attacker_position: Vector2 = session.get_player(27).position
        _finish(session)
        _check(began and chosen and session.duel.kind == "block" and session.duel.outcome == "block"
            and session.ball.owner_id == 4 and session.controlled_id == 4
            and session.get_player(27).position == attacker_position,
            id + " : blocage de tir réel sans déplacement de dribble du tireur")

func _shots_and_range() -> void:
    for id: String in ["seismic_strike", "prism_ricochet"]:
        var session: IEGMatchSession = _fixture()
        session.get_player(7).position = Vector2(0, -31)
        session.ball.owner_id = 7
        session._follow_owner()
        var began: bool = session.request_duel(7, 21, "keeper")
        session.duel.ai_special = false
        var chosen: bool = session.choose_duel("special", id)
        _finish(session)
        _check(began and chosen and session.duel.attack_score > session.duel.defend_score
            and session.duel.outcome == "goal" and session.team_goals[0] == 1
            and session.team_goals[1] == 0 and session.ball.owner_id == -1,
            id + " : tir résolu par le même moteur, score réel après la cinématique")
    var range_session: IEGMatchSession = _fixture()
    var shooter: IEGPlayerState = range_session.get_player(7)
    _check(range_session.shot_range(shooter, "prism_ricochet") > range_session.shot_range(shooter, "seismic_strike")
        and range_session.shot_range(shooter, "seismic_strike") > range_session.shot_range(shooter, ""),
        "Ricochet prismatique possède réellement une portée supérieure")

func _keeper_outcomes() -> void:
    # Seule la puissance du tir de la fixture varie : le moteur décide de l'issue.
    for id: String in ["titan_grip", "midnight_dial"]:
        for power: float in [10.0, 33.0 if id == "titan_grip" else 30.0, 100.0]:
            var session: IEGMatchSession = _fixture()
            session.get_player(27).profile.technique_ids = ["orbital_shot"]
            session.get_player(27).position = Vector2(0, 31)
            session.ball.owner_id = 27
            session._follow_owner()
            var shot: Dictionary = session.catalog.get_definition("orbital_shot")
            shot.power = power
            session.catalog._overrides["orbital_shot"] = shot
            var began: bool = session.request_duel(27, 1, "keeper")
            session.duel.ai_special = true
            var chosen: bool = session.choose_duel("special", id)
            var expected: String = "capture" if power == 10.0 else ("goal" if power == 100.0 else "deflection")
            var selection: int = session.controlled_id
            var reserve: float = 100.0 - float(session.catalog.get_definition(id).cost) - 9.0
            var result_was_delayed: bool = session.ball.owner_id == 27 and session.team_goals[1] == 0
            _finish(session)
            var possession_valid: bool = session.ball.owner_id == 1 and session.controlled_id == 1 if expected == "capture" else session.ball.owner_id == -1
            if expected == "deflection":
                possession_valid = possession_valid and session.controlled_id == selection and session.team_goals[1] == 0
            elif expected == "goal":
                possession_valid = possession_valid and session.team_goals[1] == 1
            _check(began and chosen and session.duel.outcome == expected and possession_valid and result_was_delayed
                and is_equal_approx(session.get_player(1).keeper_stamina, reserve) and session.controlled().team_id == 0,
                id + " : " + expected + " décidé par les scores, endurance payée et possession appliquée après cinéma")

func _persisted_new_entries() -> void:
    var catalog: IEGTechniqueCatalog = Catalog.new(_path)
    var entries: Array[Dictionary] = []
    for id: String in ORDINARY:
        var data: Dictionary = catalog.get_definition(id)
        data.power = float(data.power) + 1.0
        entries.append(data)
    for id: String in ["vaelis", "orvann"]:
        var data: Dictionary = catalog.get_definition(id)
        data.properties.appearance.primary = "#193857"
        data.properties.appearance.accent = "#f0ac63"
        entries.append(data)
    _check(catalog.save_overrides(entries) == OK and FileAccess.file_exists(_path),
        "nouvelles techniques et palettes Karma sauvegardées dans le fichier de test isolé")
    var restored: IEGTechniqueCatalog = Catalog.new(_path)
    var same: bool = restored.last_errors.is_empty()
    for expected: Dictionary in entries:
        same = same and _same_json(restored.get_definition(str(expected.id)), expected)
    _check(same and restored.all_definitions().size() == 30
        and restored.validate_entries(restored.all_definitions()).is_empty(),
        "rechargement préservant toutes les éditions et les liens vers les signatures")

func _same_json(left: Variant, right: Variant) -> bool:
    # JSON représente tous les nombres par des flottants ; les données de jeu
    # définissent aussi des entiers (la limite de trois invocations par équipe).
    if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
        return is_equal_approx(float(left), float(right))
    if left is Dictionary and right is Dictionary:
        if left.size() != right.size():
            return false
        for key: Variant in left:
            if not right.has(key) or not _same_json(left[key], right[key]):
                return false
        return true
    if left is Array and right is Array:
        if left.size() != right.size():
            return false
        for index: int in range(left.size()):
            if not _same_json(left[index], right[index]):
                return false
        return true
    return typeof(left) == typeof(right) and left == right

func _cinematic_timing() -> void:
    for owner: int in [8, 4]:
        var session: IEGMatchSession = _fixture()
        var karma: String = "vaelis" if owner == 8 else "orvann"
        var signature: String = "ninefold_hunt" if owner == 8 else "antler_citadel"
        session.activate_modifier(owner, karma)
        var began: bool = _field(session, 8, 22) if owner == 8 else _block(session)
        session.duel.ai_special = false
        var chosen: bool = session.choose_duel("special", signature)
        _check(began and chosen and is_equal_approx(float(session.duel.duration), 5.0)
            and is_equal_approx(float(session.duel.reveal_time), 2.9),
            signature + " : le moteur respecte la préparation de 58 % avant de révéler le résultat")
    var catalog: IEGTechniqueCatalog = Catalog.new(_path)
    var attacker: Dictionary = catalog.get_definition("ninefold_hunt")
    attacker.properties.branch_at = 0.7
    var defender: Dictionary = catalog.get_definition("titan_grip")
    defender.properties.branch_at = 0.5
    var timing: Dictionary = Catalog.cinematic_timing(attacker, defender)
    _check(is_equal_approx(float(timing.duration), 5.0) and is_equal_approx(float(timing.reveal_time), 2.5),
        "timing partagé : la défense impose son instant de bifurcation sur la durée la plus longue")
    var edited: IEGMatchSession = _fixture()
    var technique: Dictionary = edited.catalog.get_definition("paper_escape")
    technique.duration = 4.8
    technique.properties.branch_at = 0.65
    edited.catalog._overrides["paper_escape"] = technique
    var began: bool = _field(edited, 8, 22)
    edited.duel.ai_special = false
    var chosen: bool = edited.choose_duel("special", "paper_escape")
    _check(began and chosen and is_equal_approx(float(edited.duel.duration), 4.8)
        and is_equal_approx(float(edited.duel.reveal_time), 3.12),
        "édition de durée et branch_at appliquée au vrai duel, sans modifier son résultat")
