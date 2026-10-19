extends Node
## Liaison entre le tableau et le même FullMatch que les rencontres libres.
## Aucun résultat n'est fabriqué ici : seule une session liée et terminée est acceptée.

const Catalog = preload("res://core/routes/route_catalog.gd")
const Progress = preload("res://core/routes/route_progress.gd")
const MATCH_SCENE: String = "res://scenes/full_match.tscn"
const BOARD_SCENE: String = "res://scenes/routes.tscn"
var catalog = Catalog.new()
var progress = Progress.new(catalog)
var active_match: Dictionary = {}
var last_result: Dictionary = {}
var selected_route: String = ""
var selected_node: String = ""
var _pending: bool = false
var _bound_session: RefCounted

func launch_match(route_id: String, node_id: String) -> Error:
    var definition: Dictionary = catalog.node(route_id, node_id)
    if definition.get("type", "") != "match" or not progress.is_unlocked(route_id, node_id):
        return ERR_UNAUTHORIZED
    if catalog.team(String(definition.get("team_id", ""))).is_empty():
        return ERR_INVALID_DATA
    selected_route = route_id
    selected_node = node_id
    active_match = {"route_id": route_id, "node_id": node_id,
        "team_id": definition["team_id"],
        "run_id": "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]}
    _pending = true
    _bound_session = null
    last_result.clear()
    var error: Error = get_tree().change_scene_to_file(MATCH_SCENE)
    if error != OK:
        abandon_match()
    return error

func take_match_context() -> Dictionary:
    if not _pending:
        return {}
    _pending = false
    return active_match.duplicate(true)

func bind_match(session: RefCounted, context: Dictionary) -> void:
    if _matches_context(context):
        _bound_session = session

func complete_match(session: RefCounted, context: Dictionary) -> Dictionary:
    if (not _matches_context(context) or session != _bound_session
            or session.phase != session.Phase.FINISHED):
        return {"error": "La rencontre n'est pas terminée ou ne correspond pas au parcours."}
    var player_keys: Array[String] = []
    for player: IEGPlayerState in session.players:
        if player.team_id == session.LOCAL_TEAM:
            player_keys.append(player.profile.content_key)
    # Une nouvelle tentative explicite peut reprendre après réparation du
    # fichier ou modification par une autre instance, sans jamais le réinitialiser.
    if last_result.get("run_id", "") == context["run_id"] and int(last_result.get("save_error", OK)) != OK:
        progress.load_progress()
    var result: Dictionary = progress.record_result(String(context["route_id"]), String(context["node_id"]),
        int(session.team_goals[0]), int(session.team_goals[1]), String(context["run_id"]), player_keys)
    result["route_id"] = context["route_id"]
    result["node_id"] = context["node_id"]
    result["goals_for"] = int(session.team_goals[0])
    result["goals_against"] = int(session.team_goals[1])
    result["run_id"] = context["run_id"]
    result["error_message"] = " ".join(progress.last_errors)
    last_result = result.duplicate(true)
    return result

func _matches_context(context: Dictionary) -> bool:
    if context.is_empty() or active_match.is_empty():
        return false
    for key: String in ["run_id", "route_id", "node_id", "team_id"]:
        if not context.has(key) or context[key] != active_match.get(key):
            return false
    return true

func abandon_match() -> void:
    active_match.clear()
    _pending = false
    _bound_session = null

func open_board() -> Error:
    abandon_match()
    return get_tree().change_scene_to_file(BOARD_SCENE)

func launch_free_match() -> Error:
    abandon_match()
    last_result.clear()
    return get_tree().change_scene_to_file(MATCH_SCENE)

func launch_training() -> Error:
    abandon_match()
    return get_tree().change_scene_to_file("res://scenes/training_ground.tscn")
