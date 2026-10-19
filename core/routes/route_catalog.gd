class_name IEGRouteCatalog
extends RefCounted
## Données de parcours et adaptation vers les vrais profils du moteur de match.
## Le catalogue ne joue aucun match et ne fabrique aucun résultat.

const DATA_PATH: String = "res://data/routes/demo_routes.json"
const SCHEMA_VERSION: int = 1
const Rank = preload("res://core/routes/route_rank.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const Profile = preload("res://core/player_profile.gd")
const Content = preload("res://core/content/technique_catalog.gd")
const STAT_KEYS: PackedStringArray = ["shot", "dribble", "technique", "defense", "keeper"]
const NODE_TYPES: PackedStringArray = ["match", "reward", "gate", "branch"]
const REWARD_TYPES: PackedStringArray = ["currency", "xp", "item", "technique", "equipment", "recruitment"]

var rank_rules: Dictionary = Rank.DEFAULT_RULES.duplicate(true)
var last_errors: PackedStringArray = []
var _routes: Array[Dictionary] = []
var _teams: Dictionary = {}

func _init(path: String = DATA_PATH) -> void:
    load_file(path)

func routes() -> Array[Dictionary]:
    return _routes.duplicate(true)

func route(id: String) -> Dictionary:
    for entry: Dictionary in _routes:
        if str(entry["id"]) == id:
            return entry.duplicate(true)
    return {}

func node(route_id: String, node_id: String) -> Dictionary:
    var selected: Dictionary = route(route_id)
    for entry: Dictionary in selected.get("nodes", []):
        if str(entry["id"]) == node_id:
            return entry.duplicate(true)
    return {}

func team(id: String) -> Dictionary:
    return _teams.get(id, {}).duplicate(true)

func build_roster(team_id: String) -> Dictionary:
    var opponent: Dictionary = team(team_id)
    if opponent.is_empty():
        return {}
    var result: Dictionary = Roster.build()
    var formation: String = str(opponent["formation"])
    var profiles: Array[IEGPlayerProfile] = result["profiles"]
    for index: int in range(11):
        var source: Dictionary = opponent["players"][index]
        var profile: IEGPlayerProfile = Profile.new()
        profile.player_id = 21 + index
        profile.shirt_number = int(source["shirt_number"])
        profile.content_key = str(source["id"])
        profile.display_name = str(source["name"])
        profile.base_stats = source["stats"].duplicate(true)
        profile.run_speed = float(source["run_speed"])
        profile.sprint_speed = float(source["sprint_speed"])
        profile.kit_color = Color(str(opponent["keeper_color"]) if index == 0 else str(opponent["kit_color"]))
        profile.skin_color = Color(str(source["skin_color"]))
        profile.hair_color = Color(str(source["hair_color"]))
        profile.technique_ids.assign(source["techniques"])
        profile.karma_ids.assign(source.get("karmas", []))
        profiles[index + 11] = profile
    # Les bases restent neutres : le moteur applique la formation au coup
    # d'envoi et à la mi-temps, sans multiplier deux fois sa largeur.
    result["opponent"] = opponent
    result["team_name"] = str(opponent["name"])
    result["emblem"] = str(opponent["emblem"])
    result["formation"] = formation
    result["ai"] = opponent["ai"].duplicate(true)
    result["half_seconds"] = float(opponent.get("half_seconds", 300.0))
    return result

func load_file(path: String) -> Error:
    last_errors.clear()
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        last_errors.append("Catalogue de parcours illisible : " + path)
        return FileAccess.get_open_error()
    if file.get_length() > 2097152:
        file.close()
        last_errors.append("Le catalogue de parcours dépasse 2 Mio.")
        return ERR_INVALID_DATA
    var json: JSON = JSON.new()
    var error: Error = json.parse(file.get_as_text())
    file.close()
    if error != OK or not json.data is Dictionary:
        last_errors.append("Catalogue JSON invalide : %s (ligne %d)." % [json.get_error_message(), json.get_error_line()])
        return ERR_PARSE_ERROR
    return load_document(json.data)

func load_document(document: Dictionary) -> Error:
    last_errors = validate_document(document)
    if not last_errors.is_empty():
        return ERR_INVALID_DATA
    var next_routes: Array[Dictionary] = []
    var next_teams: Dictionary = {}
    for entry: Dictionary in document["routes"]:
        next_routes.append(entry.duplicate(true))
    for entry: Dictionary in document["teams"]:
        next_teams[str(entry["id"])] = entry.duplicate(true)
    _routes = next_routes
    _teams = next_teams
    rank_rules = document["rank_rules"].duplicate(true)
    return OK

func validate_document(document: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = []
    if not _integer(document.get("version"), 1, SCHEMA_VERSION):
        errors.append("Version de catalogue inconnue ; version 1 attendue.")
    var rules: Variant = document.get("rank_rules")
    if not rules is Dictionary:
        errors.append("rank_rules doit être un objet.")
    else:
        for key: String in Rank.DEFAULT_RULES:
            if not _integer(rules.get(key), 0 if key == "s_goals_against" else 1, 1000):
                errors.append("Règle de rang invalide : " + key)
    if not document.get("teams") is Array or not document.get("routes") is Array:
        errors.append("teams et routes doivent être des tableaux.")
        return errors
    if document["teams"].is_empty() or document["teams"].size() > 256 or document["routes"].is_empty() or document["routes"].size() > 64:
        errors.append("Le catalogue doit contenir 1 à 256 équipes et 1 à 64 parcours.")
        return errors
    var team_ids: Dictionary = {}
    var player_ids: Dictionary = {}
    var content: IEGTechniqueCatalog = Content.new()
    for raw: Variant in document["teams"]:
        if not raw is Dictionary:
            errors.append("Une équipe doit être un objet.")
            continue
        var id: String = str(raw.get("id", ""))
        if not _valid_id(raw.get("id")) or team_ids.has(id):
            errors.append("Identifiant d'équipe invalide ou répété : " + id)
        team_ids[id] = true
        _validate_team(raw, content, player_ids, errors)
    var route_ids: Dictionary = {}
    for raw: Variant in document["routes"]:
        if not raw is Dictionary:
            errors.append("Un parcours doit être un objet.")
            continue
        var id: String = str(raw.get("id", ""))
        if not _valid_id(raw.get("id")) or route_ids.has(id):
            errors.append("Identifiant de parcours invalide ou répété : " + id)
        route_ids[id] = true
        _validate_route(raw, team_ids, errors)
    return errors

func _validate_team(data: Dictionary, content: IEGTechniqueCatalog, player_ids: Dictionary, errors: PackedStringArray) -> void:
    var prefix: String = "Équipe %s : " % str(data.get("id", "?"))
    if not _text(data.get("name")) or not data.get("formation") in ["balanced", "wide", "press"]:
        errors.append(prefix + "nom ou formation invalide.")
    for key: String in ["kit_color", "keeper_color", "accent_color"]:
        if not data.get(key) is String or not Color.html_is_valid(str(data.get(key, ""))):
            errors.append(prefix + "couleur invalide : " + key)
    var emblem: String = str(data.get("emblem", ""))
    if not data.get("emblem") is String or not emblem.begins_with("res://") or (not ResourceLoader.exists(emblem) and not FileAccess.file_exists(emblem)):
        errors.append(prefix + "emblème introuvable.")
    if not _integer(data.get("recommended_level"), 1, 99) or not _number(data.get("half_seconds"), 10.0, 2700.0):
        errors.append(prefix + "niveau ou durée invalide.")
    if not data.get("ai") is Dictionary:
        errors.append(prefix + "profil IA absent.")
    else:
        var ai: Dictionary = data["ai"]
        for entry: Array in [["pressure", 0.0, 1.0], ["shoot_distance", 5.0, 30.0], ["shot_charge", 0.0, 1.0], ["sprint_distance", 1.0, 25.0]]:
            if not _number(ai.get(entry[0]), float(entry[1]), float(entry[2])):
                errors.append(prefix + "paramètre IA invalide : " + str(entry[0]))
    if not data.get("players") is Array or data.get("players", []).size() != 11:
        errors.append(prefix + "11 joueurs requis, gardien en première position.")
        return
    var shirts: Dictionary = {}
    for raw: Variant in data["players"]:
        if not raw is Dictionary:
            errors.append(prefix + "chaque joueur doit être un objet.")
            continue
        var id: String = str(raw.get("id", ""))
        if not _valid_id(raw.get("id")) or player_ids.has(id):
            errors.append(prefix + "identifiant de joueur invalide ou répété : " + id)
        player_ids[id] = true
        if not _text(raw.get("name")) or not _integer(raw.get("shirt_number"), 1, 99) or shirts.has(raw.get("shirt_number")):
            errors.append(prefix + "nom ou numéro de joueur invalide/répété.")
        shirts[raw.get("shirt_number", -1)] = true
        if not _number(raw.get("run_speed"), 1.0, 12.0) or not _number(raw.get("sprint_speed"), 1.0, 16.0) or float(raw.get("sprint_speed", 0.0)) < float(raw.get("run_speed", 1.0)):
            errors.append(prefix + "vitesses de joueur invalides.")
        for key: String in ["skin_color", "hair_color"]:
            if not raw.get(key) is String or not Color.html_is_valid(str(raw.get(key, ""))):
                errors.append(prefix + "couleur de joueur invalide : " + key)
        if not raw.get("stats") is Dictionary:
            errors.append(prefix + "statistiques de joueur absentes.")
        else:
            for key: String in STAT_KEYS:
                if not _number(raw["stats"].get(key), 1.0, 150.0):
                    errors.append(prefix + "statistique de joueur invalide : " + key)
        for key: String in ["techniques", "karmas"]:
            if not raw.get(key, []) is Array or (key == "techniques" and not raw.has(key)):
                errors.append(prefix + "tableau de techniques invalide.")
                continue
            var seen: Dictionary = {}
            for reference: Variant in raw.get(key, []):
                var definition: Dictionary = content.get_definition(str(reference))
                var valid_category: bool = str(definition.get("category", "")) in (["KARMA"] if key == "karmas" else ["TIR", "ATT", "DEF", "GAR"])
                if not reference is String or not valid_category or seen.has(reference):
                    errors.append(prefix + "technique inconnue, répétée ou mal classée : " + str(reference))
                seen[reference] = true

func _validate_route(data: Dictionary, team_ids: Dictionary, errors: PackedStringArray) -> void:
    var prefix: String = "Parcours %s : " % str(data.get("id", "?"))
    if not _text(data.get("name")) or not data.get("nodes") is Array or not data.get("edges") is Array:
        errors.append(prefix + "nom, nodes ou edges invalide.")
        return
    if data["nodes"].is_empty() or data["nodes"].size() > 256:
        errors.append(prefix + "1 à 256 nœuds requis.")
        return
    var nodes: Dictionary = {}
    var dependency_graph: Dictionary = {}
    var edge_graph: Dictionary = {}
    for raw: Variant in data["nodes"]:
        if not raw is Dictionary:
            errors.append(prefix + "un nœud doit être un objet.")
            continue
        var id: String = str(raw.get("id", ""))
        if not _valid_id(raw.get("id")) or nodes.has(id):
            errors.append(prefix + "identifiant de nœud invalide ou répété : " + id)
        nodes[id] = raw
        dependency_graph[id] = []
        edge_graph[id] = []
        if not _text(raw.get("name")) or not NODE_TYPES.has(str(raw.get("type", ""))):
            errors.append(prefix + "nom ou type de nœud invalide : " + id)
        var position: Variant = raw.get("position")
        if not position is Array or position.size() != 2:
            errors.append(prefix + "position [x,y] requise : " + id)
        elif not _number(position[0], -10000.0, 10000.0) or not _number(position[1], -10000.0, 10000.0):
            errors.append(prefix + "position non finie ou hors limites : " + id)
        if str(raw.get("type", "")) == "match":
            if not team_ids.has(str(raw.get("team_id", ""))) or not _integer(raw.get("recommended_level"), 1, 99):
                errors.append(prefix + "équipe ou niveau du match invalide : " + id)
        if raw.has("rewards_pending"):
            if not raw["rewards_pending"] is bool or str(raw.get("type", "")) != "reward":
                errors.append(prefix + "rewards_pending doit être un booléen réservé aux coffres : " + id)
            elif raw["rewards_pending"] and raw.get("rewards", {}) is Dictionary:
                var claim: Variant = raw.get("rewards", {}).get("claim", [])
                if claim is Array and not claim.is_empty():
                    errors.append(prefix + "un coffre en attente ne peut pas avoir de récompenses claim : " + id)
        _validate_rewards(raw.get("rewards", {}), prefix + id + " : ", errors)
    for id: String in nodes:
        var selected: Dictionary = nodes[id]
        for key: String in ["requires", "requires_any"]:
            if not selected.get(key, []) is Array:
                errors.append(prefix + "conditions non valides : " + id)
                continue
            for condition: Variant in selected.get(key, []):
                if not condition is Dictionary:
                    errors.append(prefix + "une condition doit être un objet : " + id)
                    continue
                if condition.has("flag"):
                    if not _valid_id(condition["flag"]) or condition.has("node"):
                        errors.append(prefix + "drapeau invalide : " + id)
                elif condition.has("node"):
                    var reference: String = str(condition["node"])
                    if not nodes.has(reference) or reference == id:
                        errors.append(prefix + "référence de condition inconnue/récursive : " + reference)
                    else:
                        dependency_graph[id].append(reference)
                        if condition.has("rank") and (Rank.value(str(condition["rank"])) == 0 or str(nodes[reference].get("type", "")) != "match"):
                            errors.append(prefix + "un rang B/A/S doit référencer un match : " + id)
                else:
                    errors.append(prefix + "condition sans node ni flag : " + id)
    for edge: Variant in data["edges"]:
        if not edge is Array or edge.size() != 2:
            errors.append(prefix + "chaque liaison doit être [départ, arrivée].")
            continue
        var from: String = str(edge[0])
        var to: String = str(edge[1])
        if not nodes.has(from) or not nodes.has(to) or from == to:
            errors.append(prefix + "liaison vers un nœud inconnu ou identique.")
        elif edge_graph[from].has(to):
            errors.append(prefix + "liaison répétée : " + from + " → " + to)
        else:
            edge_graph[from].append(to)
    if _has_cycle(dependency_graph):
        errors.append(prefix + "cycle de conditions de déblocage.")
    if _has_cycle(edge_graph):
        errors.append(prefix + "cycle dans les liaisons du tableau.")

func _validate_rewards(raw: Variant, prefix: String, errors: PackedStringArray) -> void:
    if not raw is Dictionary:
        errors.append(prefix + "rewards doit être un objet.")
        return
    for key: String in ["first_win", "repeat", "claim"]:
        if not raw.get(key, []) is Array:
            errors.append(prefix + "récompenses : tableau " + key + " attendu.")
            continue
        var seen: Dictionary = {}
        for entry: Variant in raw.get(key, []):
            if not entry is Dictionary:
                errors.append(prefix + "une récompense doit être un objet.")
                continue
            var id: String = str(entry.get("id", ""))
            if not _valid_id(entry.get("id")) or seen.has(id) or not REWARD_TYPES.has(str(entry.get("type", ""))):
                errors.append(prefix + "id/type de récompense invalide ou répété : " + id)
            seen[id] = true
            if not _integer(entry.get("amount", 1), 1, 1000000) or Rank.value(str(entry.get("min_rank", "B"))) == 0 or not _number(entry.get("chance", 1.0), 0.0, 1.0):
                errors.append(prefix + "quantité, rang ou chance de récompense invalide : " + id)

func _has_cycle(graph: Dictionary) -> bool:
    var visiting: Dictionary = {}
    var visited: Dictionary = {}
    for id: String in graph:
        if _visit_cycle(id, graph, visiting, visited):
            return true
    return false

func _visit_cycle(id: String, graph: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
    if visiting.has(id):
        return true
    if visited.has(id):
        return false
    visiting[id] = true
    for next: String in graph.get(id, []):
        if _visit_cycle(next, graph, visiting, visited):
            return true
    visiting.erase(id)
    visited[id] = true
    return false

func _valid_id(raw: Variant) -> bool:
    if not raw is String or raw.is_empty() or raw.length() > 64:
        return false
    var value: String = raw
    if value[0] < "a" or value[0] > "z":
        return false
    for character: String in value:
        if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
            return false
    return true

func _text(raw: Variant) -> bool:
    return raw is String and not raw.strip_edges().is_empty() and raw.length() <= 160

func _number(raw: Variant, minimum: float, maximum: float) -> bool:
    return (raw is int or raw is float) and is_finite(float(raw)) and float(raw) >= minimum and float(raw) <= maximum

func _integer(raw: Variant, minimum: int, maximum: int) -> bool:
    return _number(raw, float(minimum), float(maximum)) and float(raw) == floorf(float(raw))
