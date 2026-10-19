extends RefCounted
## Contrats du parcours dans Godot. Les scores injectés ici sont des entrées de
## tests unitaires ; le mode jouable reçoit exclusivement la fin du vrai match.
const Rank = preload("res://core/routes/route_rank.gd")
const Catalog = preload("res://core/routes/route_catalog.gd")
const Progress = preload("res://core/routes/route_progress.gd")
const Techniques = preload("res://core/content/technique_catalog.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const Session = preload("res://core/match/match_session.gd")
const Command = preload("res://core/game_command.gd")

var _paths: Array[String] = []
var _serial: int = 0

func run_all() -> Dictionary:
    var lines: Array[String] = []
    var passed: int = 0
    var cases: Array[Callable] = [_rank_examples, _rank_invalid_scores,
        _rank_order, _rank_configuration, _catalog_six_opponents,
        _catalog_rosters_are_complete, _catalog_references,
        _catalog_configures_formations_and_ai,
        _catalog_roster_isolation, _catalog_rejects_invalid_data,
        _catalog_pending_chests_are_optional, _catalog_pending_contract,
        _fresh_progress, _victory_records_rank,
        _best_rank_never_regresses, _draw_and_loss_no_rank,
        _results_survive_reload, _replay_stays_accessible,
        _locked_match_rejected, _invalid_result_rejected,
        _duplicate_result_is_idempotent, _match_id_collision_rejected,
        _first_and_repeat_rewards, _unlock_requires_both_wins,
        _unlock_accepts_either_branch, _unlock_requires_higher_rank,
        _special_flag_persists, _reward_node_requires_claim,
        _reward_node_unique_after_reload, _pending_chest_preserves_state,
        _pending_chest_can_be_configured_later, _reward_rank_and_chance,
        _experience_counts_each_player_once, _failed_write_rolls_back,
        _corrupted_save_not_overwritten, _bad_reload_keeps_valid_memory,
        _unknown_save_version_rejected, _external_save_change_not_overwritten,
        _configured_defense_affects_real_duel, _ai_long_shot_resolves_once]
    for test: Callable in cases:
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "PARCOURS : " + String(test.get_method()))
    _cleanup()
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func _path(label: String) -> String:
    _serial += 1
    var path: String = "user://test_routes_%s_%d_%d.json" % [label, OS.get_process_id(), _serial]
    _paths.append(path)
    return path

func _cleanup() -> void:
    for path: String in _paths:
        for suffix: String in ["", ".tmp", ".bak"]:
            if FileAccess.file_exists(path + suffix):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
    _paths.clear()

func _fixture(label: String) -> RefCounted:
    return Progress.new(Catalog.new(), _path(label))

func _same_json(a: Dictionary, b: Dictionary) -> bool:
    # JSON Godot recharge les entiers en flottants. Comparer les données après
    # le même passage JSON, sans imposer une représentation numérique interne.
    var normalized_a: Variant = JSON.parse_string(JSON.stringify(a))
    var normalized_b: Variant = JSON.parse_string(JSON.stringify(b))
    return normalized_a == normalized_b

func _entry(catalog: RefCounted) -> Dictionary:
    # Uniquement les véritables nœuds d'entrée définis dans les données.
    for route: Dictionary in catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if String(node.get("type", "")) == "match" and node.get("requires", []).is_empty() and node.get("requires_any", []).is_empty():
                return {"route": String(route.id), "node": String(node.id)}
    return {}

func _win(progress: RefCounted, id: String = "win", gf: int = 1, ga: int = 0) -> Dictionary:
    var entry: Dictionary = _entry(progress.catalog)
    if entry.is_empty():
        return {"error": ERR_DOES_NOT_EXIST}
    var keys: Array[String] = ["soren_vale", "maelle_neris"]
    return progress.record_result(entry.route, entry.node, gf, ga, id, keys)

func _rank_examples() -> bool:
    for row: Array in [[1, 0, "B"], [3, 1, "B"], [4, 1, "A"], [5, 2, "A"],
            [5, 0, "S"], [7, 0, "S"], [2, 3, ""], [2, 2, ""], [0, 0, ""]]:
        if Rank.calculate(row[0], row[1]) != row[2]:
            return false
    return true

func _rank_invalid_scores() -> bool:
    return Rank.calculate(-1, 0).is_empty() and Rank.calculate(5, -1).is_empty()

func _rank_order() -> bool:
    return Rank.value("") < Rank.value("B") and Rank.value("B") < Rank.value("A") and Rank.value("A") < Rank.value("S")

func _rank_configuration() -> bool:
    # Clés définies dans le catalogue : modifier les données modifie la règle.
    var config: Dictionary = Catalog.new().rank_rules.duplicate(true)
    config["a_goal_difference"] = 4
    config["s_goals_for"] = 6
    return Rank.calculate(4, 1, config) == "B" and Rank.calculate(5, 0, config) == "A" and Rank.calculate(6, 0, config) == "S"

func _catalog_six_opponents() -> bool:
    var catalog: RefCounted = Catalog.new()
    if not catalog.last_errors.is_empty() or catalog.routes().is_empty():
        return false
    var opponents: Dictionary = {}
    for route: Dictionary in catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if node.get("type", "") == "match":
                opponents[String(node.get("team_id", ""))] = true
    return opponents.size() == 6 and not opponents.has("")

func _catalog_rosters_are_complete() -> bool:
    var catalog: RefCounted = Catalog.new()
    if catalog.routes().is_empty():
        return false
    for route: Dictionary in catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if node.get("type", "") != "match":
                continue
            var roster: Dictionary = catalog.build_roster(String(node.team_id))
            if roster.is_empty() or roster.profiles.size() != 22 or roster.starts.size() != 22 or roster.teams.size() != 22 or roster.keepers.size() != 22:
                return false
            var ids: Dictionary = {}
            var team_counts: Array[int] = [0, 0]
            var keeper_counts: Array[int] = [0, 0]
            for index: int in range(22):
                var profile: IEGPlayerProfile = roster.profiles[index]
                var team_id: int = int(roster.teams[index])
                if not profile.is_valid() or profile.content_key.is_empty() or ids.has(profile.player_id) or team_id not in [0, 1]:
                    return false
                ids[profile.player_id] = true
                team_counts[team_id] += 1
                keeper_counts[team_id] += 1 if roster.keepers[index] else 0
            if team_counts != [11, 11] or keeper_counts != [1, 1]:
                return false
    return true

func _catalog_references() -> bool:
    var catalog: RefCounted = Catalog.new()
    var techniques: RefCounted = Techniques.new(_path("techniques"))
    var fingerprints: Dictionary = {}
    for route: Dictionary in catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if node.get("type", "") != "match":
                continue
            var team: Dictionary = catalog.team(String(node.team_id))
            if team.is_empty():
                return false
            var roster: Dictionary = catalog.build_roster(String(node.team_id))
            var stats: Array = []
            for index: int in range(roster.profiles.size()):
                var profile: IEGPlayerProfile = roster.profiles[index]
                for technique_id: String in profile.technique_ids:
                    if techniques.get_definition(technique_id).is_empty():
                        return false
                if roster.teams[index] == 1:
                    stats.append(profile.base_stats)
            fingerprints[JSON.stringify(stats)] = true
    return fingerprints.size() == 6

func _catalog_configures_formations_and_ai() -> bool:
    var catalog: RefCounted = Catalog.new()
    var formations: Dictionary = {}
    var pressures: Dictionary = {}
    var neutral_starts: Array = Roster.build().starts
    for route: Dictionary in catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if node.get("type", "") != "match":
                continue
            var team: Dictionary = catalog.team(String(node.team_id))
            var roster: Dictionary = catalog.build_roster(String(node.team_id))
            var formation: String = String(team.get("formation", ""))
            if formation not in ["balanced", "wide", "press"] or roster.get("formation", "") != formation or roster.get("ai", {}) != team.get("ai", {}):
                return false
            # La formation est transmise au moteur existant. Les bases neutres
            # empêchent son application deux fois au premier engagement.
            if roster.keepers[11] != true or roster.starts != neutral_starts:
                return false
            formations[formation] = true
            pressures[str(team.ai.pressure)] = true
    return formations.size() >= 2 and pressures.size() >= 2

func _catalog_roster_isolation() -> bool:
    var catalog: RefCounted = Catalog.new()
    var entry: Dictionary = _entry(catalog)
    if entry.is_empty():
        return false
    var node: Dictionary = catalog.node(entry.route, entry.node)
    var a: Dictionary = catalog.build_roster(String(node.team_id))
    var b: Dictionary = catalog.build_roster(String(node.team_id))
    a.profiles[11].display_name = "Mutation locale"
    a.profiles[11].base_stats["shot"] = -100.0
    a.starts[11] = Vector2(999, 999)
    return b.profiles[11].display_name != "Mutation locale" and float(b.profiles[11].base_stats.shot) >= 0.0 and b.starts[11] != Vector2(999, 999)

func _document() -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Catalog.DATA_PATH))
    return parsed if parsed is Dictionary else {}

func _custom_catalog(pending_ready: bool = false) -> RefCounted:
    var catalog: RefCounted = Catalog.new()
    var document: Dictionary = _document()
    if document.is_empty():
        return catalog
    var team_id: String = String(document.teams[0].id)
    var nodes: Array[Dictionary] = []
    for id: String in ["first", "second", "both", "after_chest"]:
        nodes.append({"id": id, "name": id, "type": "match", "position": [0, nodes.size() * 100],
            "team_id": team_id, "recommended_level": 1})
    nodes[0]["rewards"] = {
        "first_win": [{"id": "first_currency", "type": "currency", "amount": 100},
            {"id": "unique_medal", "type": "item", "amount": 1, "chance": 0.0}],
        "repeat": [{"id": "repeat_currency", "type": "currency", "amount": 10},
            {"id": "training_xp", "type": "xp", "amount": 5},
            {"id": "drift", "type": "technique", "amount": 1, "min_rank": "A"},
            {"id": "perfect_bonus", "type": "currency", "amount": 25, "min_rank": "S"},
            {"id": "never_dropped", "type": "equipment", "amount": 1, "chance": 0.0}]}
    nodes[2]["requires"] = [{"node": "first"}, {"node": "second"}]
    nodes[3]["requires"] = [{"node": "chest"}]
    nodes.append({"id": "either", "name": "Bifurcation", "type": "branch", "position": [100, 100],
        "requires_any": [{"node": "first", "rank": "S"}, {"node": "second"}]})
    nodes.append({"id": "rank_a", "name": "Porte A", "type": "gate", "position": [100, 200],
        "requires": [{"node": "first", "rank": "A"}]})
    nodes.append({"id": "special", "name": "Condition spéciale", "type": "gate", "position": [100, 300],
        "requires": [{"flag": "permit"}]})
    nodes.append({"id": "chest", "name": "Coffre", "type": "reward", "position": [100, 400],
        "requires": [{"node": "first"}],
        "rewards": {"claim": [{"id": "recruit_fragment", "type": "recruitment", "amount": 2},
            {"id": "chest_currency", "type": "currency", "amount": 50}]}})
    nodes.append({"id": "pending_chest", "name": "Coffre à définir", "type": "reward", "position": [100, 500],
        "requires": [{"node": "first"}], "rewards_pending": not pending_ready,
        "rewards": {"claim": [{"id": "configured_test_prize", "type": "item", "amount": 1}] if pending_ready else []}})
    document["routes"] = [{"id": "tests", "name": "Contrats de progression", "nodes": nodes, "edges": []}]
    if catalog.load_document(document) != OK:
        push_error("Fixture parcours invalide : " + str(catalog.last_errors))
    return catalog

func _custom_progress(label: String, path: String = "") -> RefCounted:
    return Progress.new(_custom_catalog(), _path(label) if path.is_empty() else path)

func _catalog_rejects_invalid_data() -> bool:
    var catalog: RefCounted = Catalog.new()
    var original: Array = catalog.routes()
    var document: Dictionary = _document()
    if document.is_empty():
        return false
    document.teams[0].players[0].techniques = ["missing_technique"]
    if catalog.load_document(document) == OK or catalog.last_errors.is_empty() or catalog.routes() != original:
        return false
    document = _document()
    document.routes[0].nodes[0]["requires"] = [{"node": "missing_node"}]
    return catalog.load_document(document) != OK and not catalog.last_errors.is_empty() and catalog.routes() == original

func _catalog_pending_chests_are_optional() -> bool:
    var catalog: RefCounted = Catalog.new()
    var count: int = 0
    for route: Dictionary in catalog.routes():
        var pending: Dictionary = {}
        for node: Dictionary in route.nodes:
            if bool(node.get("rewards_pending", false)):
                if node.type != "reward" or not node.get("rewards", {}).get("claim", []).is_empty():
                    return false
                pending[node.id] = true
                count += 1
        # Les coffres encore sans contenu restent des détours facultatifs.
        for node: Dictionary in route.nodes:
            for key: String in ["requires", "requires_any"]:
                for condition: Dictionary in node.get(key, []):
                    if pending.has(String(condition.get("node", ""))):
                        return false
    return count >= 3 and catalog.last_errors.is_empty()

func _catalog_pending_contract() -> bool:
    var catalog: RefCounted = Catalog.new()
    var original: Array = catalog.routes()
    var document: Dictionary = _document()
    var pending: Dictionary = document.routes[0].nodes[-1]
    if pending.get("type", "") != "reward" or not bool(pending.get("rewards_pending", false)):
        return false
    pending.rewards_pending = "true"
    if catalog.load_document(document) == OK or catalog.routes() != original:
        return false
    pending.rewards_pending = true
    pending.rewards.claim = [{"id": "test", "type": "currency", "amount": 1}]
    if catalog.load_document(document) == OK or catalog.routes() != original:
        return false
    # Une fois le contenu configuré, désactiver le drapeau permet la réclame.
    pending.rewards_pending = false
    if catalog.load_document(document) != OK:
        return false
    var valid_routes: Array = catalog.routes()
    document.routes[0].nodes[0]["rewards_pending"] = false
    return catalog.load_document(document) != OK and catalog.routes() == valid_routes

func _fresh_progress() -> bool:
    var p: RefCounted = _fixture("fresh")
    var entry: Dictionary = _entry(p.catalog)
    return not entry.is_empty() and p.last_errors.is_empty() and p.is_unlocked(entry.route, entry.node) and p.best_rank(entry.route, entry.node).is_empty()

func _victory_records_rank() -> bool:
    var p: RefCounted = _fixture("victory")
    var result: Dictionary = _win(p)
    var entry: Dictionary = _entry(p.catalog)
    return result.get("error", OK) == OK and result.get("rank", "") == "B" and p.best_rank(entry.route, entry.node) == "B"

func _best_rank_never_regresses() -> bool:
    var p: RefCounted = _fixture("best")
    for sample: Array in [["b", 1, 0, "B"], ["s", 5, 0, "S"], ["a", 4, 1, "S"]]:
        var result: Dictionary = _win(p, sample[0], sample[1], sample[2])
        if result.get("error", OK) != OK or result.get("best_rank", "") != sample[3]:
            return false
    return true

func _draw_and_loss_no_rank() -> bool:
    var p: RefCounted = _fixture("no_rank")
    var before_unlocks: Array = _unlocked(p)
    for sample: Array in [["draw", 2, 2], ["loss", 2, 3]]:
        var result: Dictionary = _win(p, sample[0], sample[1], sample[2])
        if result.get("error", OK) != OK or not String(result.get("rank", "")).is_empty() or not result.get("rewards", []).is_empty():
            return false
    var entry: Dictionary = _entry(p.catalog)
    return p.best_rank(entry.route, entry.node).is_empty() and _unlocked(p) == before_unlocks

func _unlocked(p: RefCounted) -> Array:
    var unlocked: Array = []
    for route: Dictionary in p.catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if p.is_unlocked(String(route.id), String(node.id)):
                unlocked.append("%s/%s" % [route.id, node.id])
    return unlocked

func _results_survive_reload() -> bool:
    var catalog: RefCounted = Catalog.new()
    var path: String = _path("reload")
    var p: RefCounted = Progress.new(catalog, path)
    var entry: Dictionary = _entry(catalog)
    var result: Dictionary = _win(p, "reload_match", 5, 0)
    if result.get("error", OK) != OK:
        return false
    var reloaded: RefCounted = Progress.new(catalog, path)
    return reloaded.last_errors.is_empty() and reloaded.best_rank(entry.route, entry.node) == "S" and _unlocked(p) == _unlocked(reloaded) and _same_json(reloaded.state, p.state)

func _replay_stays_accessible() -> bool:
    var p: RefCounted = _fixture("replay")
    var entry: Dictionary = _entry(p.catalog)
    if _win(p, "perfect", 7, 0).get("error", OK) != OK:
        return false
    if not p.is_unlocked(entry.route, entry.node):
        return false
    var result: Dictionary = _win(p, "replay_loss", 0, 2)
    return result.get("error", OK) == OK and p.is_unlocked(entry.route, entry.node) and p.best_rank(entry.route, entry.node) == "S"

func _locked_match_rejected() -> bool:
    var p: RefCounted = _fixture("locked")
    var before: String = JSON.stringify(p.state)
    for route: Dictionary in p.catalog.routes():
        for node: Dictionary in route.get("nodes", []):
            if node.get("type", "") == "match" and not p.is_unlocked(String(route.id), String(node.id)):
                var result: Dictionary = p.record_result(String(route.id), String(node.id), 5, 0, "locked")
                return result.get("error", OK) != OK and JSON.stringify(p.state) == before
    return false

func _invalid_result_rejected() -> bool:
    var p: RefCounted = _fixture("invalid")
    var entry: Dictionary = _entry(p.catalog)
    if entry.is_empty():
        return false
    var before: String = JSON.stringify(p.state)
    var results: Array[Dictionary] = [p.record_result("missing", "missing", 1, 0, "missing"),
        p.record_result(entry.route, entry.node, -1, 0, "negative"),
        p.record_result(entry.route, entry.node, 1, 0, "")]
    for result: Dictionary in results:
        if result.get("error", OK) == OK:
            return false
    return JSON.stringify(p.state) == before

func _duplicate_result_is_idempotent() -> bool:
    var p: RefCounted = _fixture("duplicate")
    var first: Dictionary = _win(p, "once", 5, 0)
    var before: String = JSON.stringify(p.state)
    var duplicate: Dictionary = _win(p, "once", 5, 0)
    return first.get("error", OK) == OK and duplicate.get("error", OK) == OK and duplicate.get("duplicate", false) and duplicate.get("rewards", []).is_empty() and JSON.stringify(p.state) == before

func _match_id_collision_rejected() -> bool:
    var p: RefCounted = _fixture("collision")
    if _win(p, "same", 1, 0).get("error", OK) != OK:
        return false
    var before: String = JSON.stringify(p.state)
    var result: Dictionary = _win(p, "same", 5, 0)
    return result.get("error", OK) != OK and JSON.stringify(p.state) == before

func _first_and_repeat_rewards() -> bool:
    var p: RefCounted = _fixture("rewards")
    p.rng.seed = 470
    var first: Dictionary = _win(p, "first", 5, 0)
    var second: Dictionary = _win(p, "second", 5, 0)
    return first.get("error", OK) == OK and second.get("error", OK) == OK and first.get("first_win", false) and not second.get("first_win", true) and not first.get("rewards", []).is_empty() and not second.get("rewards", []).is_empty() and int(p.state.wallet.currency) > 0 and int(p.state.wallet.xp.get("soren_vale", 0)) > 0

func _unlock_requires_both_wins() -> bool:
    var p: RefCounted = _custom_progress("and")
    if p.is_unlocked("tests", "both"):
        return false
    if p.record_result("tests", "first", 1, 0, "first").get("error", OK) != OK or p.is_unlocked("tests", "both"):
        return false
    var result: Dictionary = p.record_result("tests", "second", 1, 0, "second")
    return result.get("error", OK) == OK and p.is_unlocked("tests", "both") and p.is_unlocked("tests", "first") and p.is_unlocked("tests", "second")

func _unlock_accepts_either_branch() -> bool:
    var p: RefCounted = _custom_progress("or")
    if p.is_unlocked("tests", "either"):
        return false
    p.record_result("tests", "first", 1, 0, "b")
    if p.is_unlocked("tests", "either"):
        return false
    p.record_result("tests", "second", 1, 0, "other")
    if not p.is_unlocked("tests", "either"):
        return false
    var alternate: RefCounted = _custom_progress("or_other")
    alternate.record_result("tests", "first", 5, 0, "s")
    return alternate.is_unlocked("tests", "either") and alternate.best_rank("tests", "second").is_empty()

func _unlock_requires_higher_rank() -> bool:
    var p: RefCounted = _custom_progress("rank")
    p.record_result("tests", "first", 3, 1, "b")
    if p.is_unlocked("tests", "rank_a"):
        return false
    p.record_result("tests", "first", 4, 1, "a")
    if not p.is_unlocked("tests", "rank_a"):
        return false
    p.record_result("tests", "first", 0, 1, "loss")
    return p.is_unlocked("tests", "rank_a") and p.best_rank("tests", "first") == "A"

func _special_flag_persists() -> bool:
    var path: String = _path("flag")
    var p: RefCounted = _custom_progress("unused", path)
    if p.is_unlocked("tests", "special") or p.set_flag("permit") != OK:
        return false
    var reloaded: RefCounted = _custom_progress("unused", path)
    return p.is_unlocked("tests", "special") and reloaded.last_errors.is_empty() and reloaded.is_unlocked("tests", "special") and bool(reloaded.state.flags.permit)

func _reward_node_requires_claim() -> bool:
    var p: RefCounted = _custom_progress("claim_gate")
    if p.claim_node("tests", "chest").get("error", OK) == OK:
        return false
    p.record_result("tests", "first", 1, 0, "win")
    if not p.is_unlocked("tests", "chest") or p.is_unlocked("tests", "after_chest"):
        return false
    var result: Dictionary = p.claim_node("tests", "chest")
    return result.get("error", OK) == OK and not result.get("rewards", []).is_empty() and p.is_unlocked("tests", "after_chest")

func _reward_node_unique_after_reload() -> bool:
    var path: String = _path("unique_chest")
    var p: RefCounted = _custom_progress("unused", path)
    p.record_result("tests", "first", 1, 0, "win")
    if p.claim_node("tests", "chest").get("error", OK) != OK:
        return false
    var reloaded: RefCounted = _custom_progress("unused", path)
    var before: String = JSON.stringify(reloaded.state)
    var duplicate: Dictionary = reloaded.claim_node("tests", "chest")
    return duplicate.get("error", OK) == OK and duplicate.get("duplicate", false) and duplicate.get("rewards", []).is_empty() and JSON.stringify(reloaded.state) == before and int(reloaded.state.wallet.inventory.recruitment.recruit_fragment) == 2

func _pending_chest_preserves_state() -> bool:
    var path: String = _path("pending_chest")
    var p: RefCounted = _custom_progress("unused", path)
    if p.record_result("tests", "first", 1, 0, "unlock_pending").get("error", OK) != OK or not p.is_unlocked("tests", "pending_chest"):
        return false
    var before: String = JSON.stringify(p.state)
    var before_file: String = FileAccess.get_file_as_string(path)
    var before_rng: int = p.rng.state
    var result: Dictionary = p.claim_node("tests", "pending_chest")
    var reloaded: RefCounted = _custom_progress("unused", path)
    return (result.get("error", OK) == ERR_UNAVAILABLE and not p.last_errors.is_empty()
        and result.get("rewards", []).is_empty() and not result.get("duplicate", true)
        and JSON.stringify(p.state) == before and p.rng.state == before_rng
        and FileAccess.get_file_as_string(path) == before_file
        and _same_json(reloaded.state, p.state) and reloaded.is_unlocked("tests", "pending_chest")
        and not bool(reloaded.state.routes.tests.nodes.pending_chest.claimed))

func _pending_chest_can_be_configured_later() -> bool:
    var path: String = _path("configured_chest")
    var pending: RefCounted = _custom_progress("unused", path)
    if pending.record_result("tests", "first", 5, 0, "ready_later").get("error", OK) != OK or pending.claim_node("tests", "pending_chest").get("error", OK) != ERR_UNAVAILABLE:
        return false
    # Seules les données du catalogue changent : aucun effacement/migration de
    # la sauvegarde, du rang ou des victoires n'est nécessaire.
    var p: RefCounted = Progress.new(_custom_catalog(true), path)
    if p.best_rank("tests", "first") != "S" or not p.is_unlocked("tests", "pending_chest"):
        return false
    var result: Dictionary = p.claim_node("tests", "pending_chest")
    if result.get("error", OK) != OK or result.get("rewards", []).size() != 1:
        return false
    var reloaded: RefCounted = Progress.new(_custom_catalog(true), path)
    var before: String = JSON.stringify(reloaded.state)
    var duplicate: Dictionary = reloaded.claim_node("tests", "pending_chest")
    return (reloaded.best_rank("tests", "first") == "S" and duplicate.get("error", OK) == OK
        and duplicate.get("duplicate", false) and duplicate.get("rewards", []).is_empty()
        and JSON.stringify(reloaded.state) == before
        and int(reloaded.state.wallet.inventory.item.configured_test_prize) == 1)

func _reward_rank_and_chance() -> bool:
    var p: RefCounted = _custom_progress("rank_rewards")
    var keys: Array[String] = ["soren_vale"]
    var first: Dictionary = p.record_result("tests", "first", 1, 0, "b", keys)
    if first.get("error", OK) != OK or int(p.state.wallet.currency) != 110 or int(p.state.wallet.inventory.item.unique_medal) != 1 or p.state.wallet.inventory.has("technique"):
        return false
    var second: Dictionary = p.record_result("tests", "first", 5, 0, "s", keys)
    if second.get("error", OK) != OK or int(p.state.wallet.currency) != 145 or int(p.state.wallet.inventory.technique.drift) != 1:
        return false
    p.record_result("tests", "first", 4, 1, "a", keys)
    return int(p.state.wallet.currency) == 155 and int(p.state.wallet.inventory.item.unique_medal) == 1 and int(p.state.wallet.inventory.technique.drift) == 2 and not p.state.wallet.inventory.has("equipment")

func _experience_counts_each_player_once() -> bool:
    var p: RefCounted = _custom_progress("xp")
    var keys: Array[String] = ["soren_vale", "soren_vale", "maelle_neris", ""]
    var result: Dictionary = p.record_result("tests", "first", 1, 0, "xp", keys)
    return result.get("error", OK) == OK and p.state.wallet.xp.size() == 2 and int(p.state.wallet.xp.soren_vale) == 5 and int(p.state.wallet.xp.maelle_neris) == 5

func _failed_write_rolls_back() -> bool:
    var base: String = _path("blocked")
    # Un fichier parent rend le chemin cible inexistant et non créable, même en root.
    var blocker: FileAccess = FileAccess.open(base, FileAccess.WRITE)
    if blocker == null:
        return false
    blocker.store_string("Ce fichier n'est pas un dossier.")
    blocker.close()
    var p: RefCounted = Progress.new(Catalog.new(), base + "/progress.json")
    var before: String = JSON.stringify(p.state)
    var rng_before: int = p.rng.state
    var result: Dictionary = _win(p, "write_failure", 5, 0)
    return result.get("error", OK) != OK and not p.last_errors.is_empty() and JSON.stringify(p.state) == before and p.rng.state == rng_before

func _corrupted_save_not_overwritten() -> bool:
    var path: String = _path("corrupt")
    var marker: String = "{ ce fichier de progression est invalide"
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(marker)
    file.close()
    var p: RefCounted = Progress.new(Catalog.new(), path)
    var before: String = JSON.stringify(p.state)
    var had_error: bool = not p.last_errors.is_empty()
    var result: Dictionary = _win(p, "unsafe_overwrite", 1, 0)
    return had_error and result.get("error", OK) != OK and JSON.stringify(p.state) == before and FileAccess.get_file_as_string(path) == marker

func _bad_reload_keeps_valid_memory() -> bool:
    var path: String = _path("bad_reload")
    var p: RefCounted = Progress.new(Catalog.new(), path)
    if _win(p, "valid", 5, 0).get("error", OK) != OK:
        return false
    var original_file: String = FileAccess.get_file_as_string(path)
    var original_state: Dictionary = p.state.duplicate(true)
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string("[broken json")
    file.close()
    if p.load_progress() == OK or p.state != original_state or _win(p, "blocked", 1, 0).get("error", OK) == OK:
        return false
    file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(original_file)
    file.close()
    return p.load_progress() == OK and _same_json(p.state, original_state) and _win(p, "recovered", 1, 0).get("error", OK) == OK

func _unknown_save_version_rejected() -> bool:
    var path: String = _path("unknown_version")
    var p: RefCounted = Progress.new(Catalog.new(), path)
    var document: Dictionary = p.state.duplicate(true)
    document["schema_version"] = 99
    var marker: String = JSON.stringify(document)
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(marker)
    file.close()
    var reloaded: RefCounted = Progress.new(Catalog.new(), path)
    return not reloaded.last_errors.is_empty() and _win(reloaded, "unknown", 1, 0).get("error", OK) != OK and FileAccess.get_file_as_string(path) == marker

func _external_save_change_not_overwritten() -> bool:
    var path: String = _path("concurrent_save")
    var p: RefCounted = Progress.new(Catalog.new(), path)
    if _win(p, "original", 1, 0).get("error", OK) != OK:
        return false
    var other_session: RefCounted = Progress.new(Catalog.new(), path)
    if _win(other_session, "newer", 5, 0).get("error", OK) != OK:
        return false
    var newer_file: String = FileAccess.get_file_as_string(path)
    var before: String = JSON.stringify(p.state)
    var result: Dictionary = _win(p, "obsolete", 3, 0)
    if result.get("error", OK) == OK or JSON.stringify(p.state) != before or FileAccess.get_file_as_string(path) != newer_file:
        return false
    return p.load_progress() == OK and _win(p, "retry_after_reload", 3, 0).get("error", OK) == OK

func _defense_duel(defense: float, configured: bool) -> RefCounted:
    var roster: Dictionary = Roster.build()
    var s: RefCounted = Session.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    s.get_player(22).profile.base_stats["defense"] = defense
    if configured and not s.configure_team(1, "Défense du parcours"):
        return s
    s.get_player(7).position = Vector2.ZERO
    s.get_player(22).position = Vector2(0, -1.8)
    s.ball.owner_id = 7
    s._follow_owner()
    s._duel_cooldown = 0.0
    if s.request_duel(7, 22, "field"):
        s.choose_duel("left")
    return s

func _configured_defense_affects_real_duel() -> bool:
    var weak: RefCounted = _defense_duel(30.0, true)
    var strong: RefCounted = _defense_duel(90.0, true)
    var legacy_weak: RefCounted = _defense_duel(30.0, false)
    var legacy_strong: RefCounted = _defense_duel(90.0, false)
    for s: RefCounted in [weak, strong, legacy_weak, legacy_strong]:
        if s.phase != Session.Phase.CINEMATIC or s.duel.get("kind", "") != "field":
            return false
    # Le résultat et les scores sont produits par choose_duel dans les quatre
    # sessions. Aucune issue ni aucun score n'est injecté dans leur état.
    return (float(strong.duel.defend_score) > float(weak.duel.defend_score)
        and is_equal_approx(float(strong.duel.attack_score), float(weak.duel.attack_score))
        and is_equal_approx(float(legacy_strong.duel.defend_score), float(legacy_weak.duel.defend_score)))

func _ai_long_shot_resolves_once() -> bool:
    var roster: Dictionary = Roster.build()
    var s: RefCounted = Session.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    if not s.configure_team(1, "Tireurs Magnus", "balanced", {"shoot_distance": 29.0}):
        return false
    # Dégager les joueurs de champ locaux laisse le duel au gardien ; le
    # porteur adverse est placé à 28 m du but qu'il attaque réellement.
    for player: IEGPlayerState in s.players:
        if not player.is_goalkeeper:
            player.position = Vector2(25, -25 if player.team_id == 0 else -15)
    var shooter: IEGPlayerState = s.get_player(27)
    shooter.position = s.attacking_goal(1) - Vector2(0, 28)
    shooter.profile.technique_ids.assign(["magnus_shot"])
    shooter.facing = Vector2.DOWN
    shooter.possession_grace = 0.0
    s.ball.owner_id = shooter.get_id()
    s._duel_cooldown = 0.0 # Situation en jeu, après la protection d'engagement.
    s._follow_owner()
    var commands: Dictionary = s.build_ai_commands()
    if not commands.has(shooter.get_id()) or not commands[shooter.get_id()].shoot:
        return false
    s.step(Command.new(), commands)
    if s.phase != Session.Phase.DUEL_CHOICE or s.duel.get("kind", "") != "keeper" or s.duel.get("actor_id", -1) != shooter.get_id():
        return false
    var energy_before: float = shooter.energy
    var technique_cost: float = float(s.catalog.get_definition("magnus_shot").cost)
    if not s.choose_duel("left") or s.phase != Session.Phase.CINEMATIC or s.duel.get("attack_technique", "") != "magnus_shot":
        return false
    var paid_energy: float = shooter.energy
    if not is_equal_approx(paid_energy, energy_before - technique_cost - 4.0):
        return false
    for _tick: int in range(600):
        if s.phase != Session.Phase.CINEMATIC:
            break
        s.step(Command.new())
    return (s.phase == Session.Phase.LIVE and bool(s.duel.get("applied", false))
        and s.duel.get("outcome", "") in ["goal", "capture", "deflection"]
        and is_equal_approx(shooter.energy, paid_energy))
