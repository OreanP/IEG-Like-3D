class_name IEGRouteProgress
extends RefCounted
## Progression des parcours. Reçoit uniquement un résultat de match terminé ;
## ne joue aucun match, ne calcule aucun score et ne modifie pas la simulation.

const Catalog = preload("res://core/routes/route_catalog.gd")
const Rank = preload("res://core/routes/route_rank.gd")
const JsonStore = preload("res://core/persistence/json_store.gd")
const STORAGE_PATH: String = "user://route_progress_v1.json"
const SCHEMA_VERSION: int = 1
const MAX_BYTES: int = 16777216
const INVENTORY_TYPES: PackedStringArray = ["item", "technique", "equipment", "recruitment"]

var catalog: RefCounted
var state: Dictionary = {}
var last_errors: PackedStringArray = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _storage_path: String
var _write_blocked: bool = false
var _disk_fingerprint: String = ""

func _init(route_catalog: RefCounted = null, storage_path: String = STORAGE_PATH) -> void:
    catalog = route_catalog if route_catalog != null else Catalog.new()
    _storage_path = storage_path
    rng.randomize()
    state = _empty_state()
    load_progress()

func load_progress() -> Error:
    last_errors.clear()
    if not FileAccess.file_exists(_storage_path):
        state = _empty_state()
        _write_blocked = false
        _disk_fingerprint = ""
        refresh_unlocks()
        return OK
    var file: FileAccess = FileAccess.open(_storage_path, FileAccess.READ)
    if file == null:
        _write_blocked = true
        var open_error: Error = FileAccess.get_open_error()
        last_errors.append("Impossible de lire la progression : " + error_string(open_error))
        return open_error
    if file.get_length() > MAX_BYTES:
        file.close()
        return _bad_load(ERR_INVALID_DATA, "La progression dépasse la taille maximale autorisée.")
    var parser: JSON = JSON.new()
    var parse_error: Error = parser.parse(file.get_as_text())
    file.close()
    if parse_error != OK:
        return _bad_load(parse_error, "Progression illisible, ligne %d : %s. Le fichier original est préservé." % [parser.get_error_line(), parser.get_error_message()])
    if not parser.data is Dictionary or not _valid_state(parser.data):
        return _bad_load(ERR_INVALID_DATA, "Format de progression invalide ou version inconnue. Le fichier original est préservé.")
    state = parser.data.duplicate(true)
    _write_blocked = false
    _disk_fingerprint = FileAccess.get_sha256(_storage_path)
    refresh_unlocks()
    return OK

func is_unlocked(route_id: String, node_id: String) -> bool:
    if catalog.node(route_id, node_id).is_empty():
        return false
    return bool(_node_state(route_id, node_id).get("unlocked", false))

func best_rank(route_id: String, node_id: String) -> String:
    return str(_node_state(route_id, node_id).get("best_rank", ""))

func refresh_unlocks() -> Array[Dictionary]:
    var newly_unlocked: Array[Dictionary] = []
    # Les portes et bifurcations peuvent se suivre ; point fixe borné par le
    # nombre de nœuds. Les arêtes servent au dessin, seules les conditions font foi.
    var changed: bool = true
    while changed:
        changed = false
        for route_data: Dictionary in catalog.routes():
            var route_id: String = str(route_data["id"])
            for node_data: Dictionary in route_data.get("nodes", []):
                var node_id: String = str(node_data["id"])
                var node_state: Dictionary = _ensure_node(route_id, node_id)
                if not node_state["unlocked"] and _conditions_met(route_id, node_data):
                    node_state["unlocked"] = true
                    newly_unlocked.append({"route": route_id, "node": node_id})
                    changed = true
    return newly_unlocked

func record_result(route_id: String, node_id: String, goals_for: int, goals_against: int, match_id: String, player_keys: Array[String] = []) -> Dictionary:
    var outcome: Dictionary = _outcome(route_id, node_id)
    if _write_blocked:
        return _failure(outcome, ERR_FILE_CORRUPT, "La progression n'est pas enregistrée : corrigez ou sauvegardez le fichier illisible avant de le recharger.")
    last_errors.clear()
    var definition: Dictionary = catalog.node(route_id, node_id)
    if definition.is_empty() or str(definition.get("type", "")) != "match":
        return _failure(outcome, ERR_INVALID_PARAMETER, "Ce nœud n'est pas un match du parcours.")
    if goals_for < 0 or goals_against < 0 or match_id.strip_edges().is_empty() or match_id.length() > 256:
        return _failure(outcome, ERR_INVALID_PARAMETER, "Le score doit être positif ou nul et la rencontre doit avoir un identifiant unique.")
    if state["processed_matches"].has(match_id):
        var previous: Dictionary = state["processed_matches"][match_id]
        if str(previous["route"]) != route_id or str(previous["node"]) != node_id or int(previous["gf"]) != goals_for or int(previous["ga"]) != goals_against:
            return _failure(outcome, ERR_INVALID_DATA, "Cet identifiant de rencontre appartient déjà à un autre résultat.")
        outcome["rank"] = str(previous["rank"])
        outcome["best_rank"] = best_rank(route_id, node_id)
        outcome["duplicate"] = true
        return outcome
    if not is_unlocked(route_id, node_id):
        return _failure(outcome, ERR_UNAUTHORIZED, "Ce match n'est pas encore débloqué.")
    var before: Dictionary = state.duplicate(true)
    var rng_before: int = rng.state
    var node_state: Dictionary = _ensure_node(route_id, node_id)
    var earned_rank: String = Rank.calculate(goals_for, goals_against, catalog.rank_rules)
    node_state["played"] = int(node_state["played"]) + 1
    var rewards: Array[Dictionary] = []
    var first_win: bool = false
    if not earned_rank.is_empty():
        first_win = int(node_state["wins"]) == 0
        node_state["wins"] = int(node_state["wins"]) + 1
        if Rank.value(earned_rank) > Rank.value(str(node_state["best_rank"])):
            node_state["best_rank"] = earned_rank
        var reward_tables: Dictionary = definition.get("rewards", {})
        if first_win:
            rewards.append_array(_grant_rewards(reward_tables.get("first_win", []), earned_rank, player_keys, true))
        rewards.append_array(_grant_rewards(reward_tables.get("repeat", []), earned_rank, player_keys, false))
    elif goals_for == goals_against:
        node_state["draws"] = int(node_state["draws"]) + 1
    else:
        node_state["losses"] = int(node_state["losses"]) + 1
    var newly_unlocked: Array[Dictionary] = refresh_unlocks()
    outcome.merge({"rank": earned_rank, "best_rank": str(node_state["best_rank"]), "first_win": first_win, "rewards": rewards, "newly_unlocked": newly_unlocked}, true)
    state["processed_matches"][match_id] = {"route": route_id, "node": node_id, "gf": goals_for, "ga": goals_against, "rank": earned_rank}
    var save_error: Error = _save()
    if save_error != OK:
        state = before
        rng.state = rng_before
        outcome["best_rank"] = best_rank(route_id, node_id)
        outcome["first_win"] = false
        outcome["rewards"] = []
        outcome["newly_unlocked"] = []
        outcome["save_error"] = save_error
        outcome["error"] = save_error
    return outcome

func claim_node(route_id: String, node_id: String) -> Dictionary:
    var outcome: Dictionary = _outcome(route_id, node_id)
    if _write_blocked:
        return _failure(outcome, ERR_FILE_CORRUPT, "La progression illisible est préservée ; récompense non enregistrée.")
    last_errors.clear()
    var definition: Dictionary = catalog.node(route_id, node_id)
    if definition.is_empty() or str(definition.get("type", "")) != "reward":
        return _failure(outcome, ERR_INVALID_PARAMETER, "Ce nœud n'est pas une récompense.")
    if not is_unlocked(route_id, node_id):
        return _failure(outcome, ERR_UNAUTHORIZED, "Cette récompense n'est pas encore accessible.")
    var node_state: Dictionary = _ensure_node(route_id, node_id)
    if node_state["claimed"]:
        outcome["duplicate"] = true
        return outcome
    var before: Dictionary = state.duplicate(true)
    var rng_before: int = rng.state
    node_state["claimed"] = true
    var reward_tables: Dictionary = definition.get("rewards", {})
    outcome["rewards"] = _grant_rewards(reward_tables.get("claim", []), "S", [], true)
    outcome["newly_unlocked"] = refresh_unlocks()
    var save_error: Error = _save()
    if save_error != OK:
        state = before
        rng.state = rng_before
        outcome["rewards"] = []
        outcome["newly_unlocked"] = []
        outcome["error"] = save_error
        outcome["save_error"] = save_error
    return outcome

func set_flag(flag: String, value: bool = true) -> Error:
    if _write_blocked:
        last_errors.append("La progression illisible est préservée ; condition non enregistrée.")
        return ERR_FILE_CORRUPT
    last_errors.clear()
    if flag.strip_edges().is_empty():
        return ERR_INVALID_PARAMETER
    var before: Dictionary = state.duplicate(true)
    state["flags"][flag] = value
    refresh_unlocks()
    var save_error: Error = _save()
    if save_error != OK:
        state = before
    return save_error

func _conditions_met(route_id: String, definition: Dictionary) -> bool:
    for requirement: Dictionary in definition.get("requires", []):
        if not _requirement_met(route_id, requirement):
            return false
    var any_requirements: Array = definition.get("requires_any", [])
    if not any_requirements.is_empty():
        for requirement: Dictionary in any_requirements:
            if _requirement_met(route_id, requirement):
                return true
        return false
    return true

func _requirement_met(route_id: String, requirement: Dictionary) -> bool:
    if requirement.has("flag"):
        return bool(state["flags"].get(str(requirement["flag"]), false))
    var required_route: String = str(requirement.get("route", route_id))
    var required_node: String = str(requirement.get("node", ""))
    var definition: Dictionary = catalog.node(required_route, required_node)
    if definition.is_empty():
        return false
    var progress: Dictionary = _node_state(required_route, required_node)
    match str(definition.get("type", "")):
        "match":
            return int(progress.get("wins", 0)) > 0 and Rank.value(str(progress.get("best_rank", ""))) >= Rank.value(str(requirement.get("rank", "B")))
        "reward":
            return bool(progress.get("claimed", false))
        "gate", "branch":
            return bool(progress.get("unlocked", false))
    return false

func _grant_rewards(entries: Array, earned_rank: String, player_keys: Array[String], guaranteed: bool) -> Array[Dictionary]:
    var granted: Array[Dictionary] = []
    for raw: Variant in entries:
        if not raw is Dictionary:
            continue
        var reward: Dictionary = raw
        if Rank.value(earned_rank) < Rank.value(str(reward.get("min_rank", "B"))):
            continue
        var chance: float = clampf(float(reward.get("chance", 1.0)), 0.0, 1.0)
        if not guaranteed and (chance <= 0.0 or (chance < 1.0 and rng.randf() >= chance)):
            continue
        var amount: int = maxi(0, int(reward.get("amount", 1)))
        var type: String = str(reward.get("type", ""))
        var reward_id: String = str(reward.get("id", ""))
        if amount <= 0:
            continue
        if type == "currency":
            state["wallet"]["currency"] = int(state["wallet"]["currency"]) + amount
        elif type == "xp":
            # Une clé de profil stable par participant ; aucune multiplication
            # d'XP si le même joueur figure plusieurs fois dans l'appel.
            var credited: Dictionary = {}
            for player_key: String in player_keys:
                if player_key.is_empty() or credited.has(player_key):
                    continue
                credited[player_key] = true
                state["wallet"]["xp"][player_key] = int(state["wallet"]["xp"].get(player_key, 0)) + amount
            if credited.is_empty():
                continue
        elif INVENTORY_TYPES.has(type) and not reward_id.is_empty():
            if not state["wallet"]["inventory"].has(type):
                state["wallet"]["inventory"][type] = {}
            var inventory: Dictionary = state["wallet"]["inventory"][type]
            inventory[reward_id] = int(inventory.get(reward_id, 0)) + amount
        else:
            continue
        var receipt: Dictionary = reward.duplicate(true)
        receipt["amount"] = amount
        granted.append(receipt)
    return granted

func _node_state(route_id: String, node_id: String) -> Dictionary:
    return state.get("routes", {}).get(route_id, {}).get("nodes", {}).get(node_id, {})

func _ensure_node(route_id: String, node_id: String) -> Dictionary:
    if not state["routes"].has(route_id):
        state["routes"][route_id] = {"nodes": {}}
    var nodes: Dictionary = state["routes"][route_id]["nodes"]
    if not nodes.has(node_id):
        nodes[node_id] = {"unlocked": false, "best_rank": "", "wins": 0, "played": 0, "draws": 0, "losses": 0, "claimed": false}
    return nodes[node_id]

func _outcome(route_id: String, node_id: String) -> Dictionary:
    return {"rank": "", "best_rank": best_rank(route_id, node_id), "first_win": false, "rewards": [], "newly_unlocked": [], "error": OK, "save_error": OK, "duplicate": false}

func _failure(outcome: Dictionary, code: Error, message: String) -> Dictionary:
    last_errors.append(message)
    outcome["error"] = code
    if _write_blocked:
        outcome["save_error"] = code
    return outcome

func _bad_load(code: Error, message: String) -> Error:
    _write_blocked = true
    last_errors.append(message)
    # Garder le dernier état valide en mémoire. Un nouvel objet reste jouable
    # depuis les premiers nœuds, sans écraser la sauvegarde endommagée.
    refresh_unlocks()
    return code

func _save() -> Error:
    if not _valid_state(state):
        last_errors.append("La progression proposée ne respecte pas le format version 1 ; aucune écriture effectuée.")
        return ERR_INVALID_DATA
    # Ne pas remplacer un fichier modifié ou devenu illisible depuis son
    # chargement (autre instance du jeu, édition manuelle, restauration).
    var current_fingerprint: String = FileAccess.get_sha256(_storage_path) if FileAccess.file_exists(_storage_path) else ""
    if current_fingerprint != _disk_fingerprint:
        last_errors.append("La sauvegarde a changé depuis son chargement. Rechargez la progression avant de l'enregistrer ; le fichier présent est préservé.")
        return ERR_BUSY
    var save_error: Error = JsonStore.write_document(_storage_path, JSON.stringify(state, "  "), last_errors, MAX_BYTES)
    if save_error == OK:
        _disk_fingerprint = FileAccess.get_sha256(_storage_path)
    return save_error

func _empty_state() -> Dictionary:
    return {"schema_version": SCHEMA_VERSION, "routes": {}, "wallet": {"currency": 0, "xp": {}, "inventory": {}}, "processed_matches": {}, "flags": {}}

func _valid_state(document: Dictionary) -> bool:
    if not _natural(document.get("schema_version")) or int(document["schema_version"]) != SCHEMA_VERSION:
        return false
    for key: String in ["routes", "wallet", "processed_matches", "flags"]:
        if not document.get(key) is Dictionary:
            return false
    var wallet: Dictionary = document["wallet"]
    if not _natural(wallet.get("currency")) or not _natural_map(wallet.get("xp")) or not wallet.get("inventory") is Dictionary:
        return false
    for type: Variant in wallet["inventory"]:
        if not type is String or not INVENTORY_TYPES.has(type) or not _natural_map(wallet["inventory"][type]):
            return false
    for flag: Variant in document["flags"]:
        if not flag is String or not document["flags"][flag] is bool:
            return false
    for route_id: Variant in document["routes"]:
        if not route_id is String or not document["routes"][route_id] is Dictionary or not document["routes"][route_id].get("nodes") is Dictionary:
            return false
        for node_id: Variant in document["routes"][route_id]["nodes"]:
            if not node_id is String or not _valid_node(document["routes"][route_id]["nodes"][node_id]):
                return false
    for match_id: Variant in document["processed_matches"]:
        if not match_id is String or match_id.is_empty() or not document["processed_matches"][match_id] is Dictionary:
            return false
        var entry: Dictionary = document["processed_matches"][match_id]
        if not entry.get("route") is String or not entry.get("node") is String or not _natural(entry.get("gf")) or not _natural(entry.get("ga")) or not entry.get("rank") is String or str(entry["rank"]) not in ["", "B", "A", "S"]:
            return false
    return true

func _valid_node(raw: Variant) -> bool:
    if not raw is Dictionary:
        return false
    var progress: Dictionary = raw
    if not progress.get("unlocked") is bool or not progress.get("claimed") is bool or not progress.get("best_rank") is String or str(progress["best_rank"]) not in ["", "B", "A", "S"]:
        return false
    for counter: String in ["wins", "played", "draws", "losses"]:
        if not _natural(progress.get(counter)):
            return false
    if int(progress["played"]) != int(progress["wins"]) + int(progress["draws"]) + int(progress["losses"]):
        return false
    return str(progress["best_rank"]).is_empty() == (int(progress["wins"]) == 0)

func _natural_map(raw: Variant) -> bool:
    if not raw is Dictionary:
        return false
    for key: Variant in raw:
        if not key is String or not _natural(raw[key]):
            return false
    return true

func _natural(raw: Variant) -> bool:
    return (raw is int or raw is float) and is_finite(float(raw)) and float(raw) >= 0.0 and float(raw) == floorf(float(raw)) and float(raw) <= 9007199254740991.0
