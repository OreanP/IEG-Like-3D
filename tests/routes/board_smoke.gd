extends SceneTree
## Contrôle réel du tableau : cadrage local, navigation et accès aux actions.
## Les résultats d'appoint sont des fixtures de progression, isolées de la
## sauvegarde normale ; aucune rencontre de cette suite n'est déclarée jouée.
const Progress = preload("res://core/routes/route_progress.gd")
var _total: int = 0
var _passed: int = 0
var _runner: Node
var _previous_progress: RefCounted
var _previous_route: String
var _previous_node: String
var _previous_result: Dictionary
var _path: String = "user://test_route_board_%d.json" % Time.get_ticks_usec()
var _original_window_size: Vector2i

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + "CARTE PARCOURS : " + label)

func _frames(count: int = 4) -> void:
    for _index: int in count:
        await process_frame

func _settle() -> void:
    await create_timer(0.4).timeout
    await _frames()

func _is_centered(board: Control) -> bool:
    var tile: Control = board._buttons[board.selected_node_id]
    return tile.get_global_rect().get_center().distance_to(board._map_view.get_global_rect().get_center()) < 2.0

func _joy(button_index: int) -> void:
    var press := InputEventJoypadButton.new()
    press.button_index = button_index
    press.pressed = true
    root.push_input(press, true)
    await _frames(2)
    var release := InputEventJoypadButton.new()
    release.button_index = button_index
    release.pressed = false
    root.push_input(release, true)
    await _frames(2)

func _capture(name: String) -> void:
    var directory: String = OS.get_environment("IEG_ROUTE_CAPTURE_DIR")
    if directory.is_empty() or DisplayServer.get_name() == "headless":
        return
    DirAccess.make_dir_recursive_absolute(directory)
    # Éloigner le pointeur pour photographier l'interface sans infobulle.
    Input.warp_mouse(Vector2(2, 2))
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(2, 2)
    root.push_input(motion, true)
    await _frames(3)
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var error: Error = image.save_png(directory.path_join(name + ".png"))
    _check(error == OK, "Capture moteur enregistrée : " + name)

func _run() -> void:
    _runner = root.get_node("RouteRun")
    _previous_progress = _runner.progress
    _previous_route = _runner.selected_route
    _previous_node = _runner.selected_node
    _previous_result = _runner.last_result.duplicate(true)
    _runner.progress = Progress.new(_runner.catalog, _path)
    _runner.selected_route = ""
    _runner.selected_node = ""
    _runner.last_result.clear()
    _original_window_size = root.size
    root.size = Vector2i(1280, 800)
    _check(change_scene_to_file("res://scenes/routes.tscn") == OK, "Ouverture du tableau de parcours")
    await _frames(8)
    var board: Control = current_scene
    var route: Dictionary = _runner.catalog.routes()[0]
    var route_id: String = String(route["id"])
    board.select_route(route_id)
    await _frames()
    var first_id: String = ""
    var far_id: String = ""
    var pending_id: String = ""
    var farthest: float = -INF
    for node: Dictionary in route["nodes"]:
        var id: String = String(node["id"])
        if first_id.is_empty() and node["type"] == "match" and _runner.progress.is_unlocked(route_id, id):
            first_id = id
        var distance: float = Vector2(node["position"][0], node["position"][1]).length_squared()
        if distance > farthest:
            far_id = id
            farthest = distance
        if pending_id.is_empty() and node["type"] == "reward" and bool(node.get("rewards_pending", false)):
            pending_id = id
    _check(not first_id.is_empty() and not far_id.is_empty(), "Un adversaire de départ et des cases éloignées existent")
    _check(board._map_view.clip_contents, "La carte est découpée à la fenêtre locale")
    _check(is_equal_approx(board.map_zoom, 1.35), "La carte démarre avec un cadrage rapproché")
    board.select_node(first_id)
    board.center_selected(false)
    await _frames()
    _check(_is_centered(board), "La case de départ est au centre de la vue locale")
    var first_tile: Control = board._buttons[first_id]
    _check(first_tile.accessible and String(first_tile.rank).is_empty(), "La première rencontre est disponible sans rang fabriqué")
    _check(not board._detail_action.disabled, "La fiche de départ donne accès au vrai match")
    _check(first_tile.material is ShaderMaterial and not bool(first_tile.material.get_shader_parameter("locked")), "Les emblèmes accessibles conservent leurs couleurs")
    await _capture("route-local-start-1280")
    board.select_node(far_id)
    board.center_selected(false)
    await _frames()
    _check(_is_centered(board), "La sélection d'une case éloignée recentre la carte")
    _check(board._buttons[far_id].is_selected and not first_tile.is_selected, "Une seule case porte la sélection courante")
    _check(not board._buttons[far_id].accessible and board._detail_action.disabled, "Une case verrouillée reste consultable sans action de jeu")
    _check(board._buttons[far_id].material is ShaderMaterial and bool(board._buttons[far_id].material.get_shader_parameter("locked")), "La désaturation couvre les emblèmes et cases inaccessibles")
    await _capture("route-local-locked-1280")
    board.set_map_zoom(9.0, false)
    await _frames()
    _check(is_equal_approx(board.map_zoom, 1.8) and _is_centered(board), "Le zoom maximal est borné et préserve la case centrale")
    board.set_map_zoom(0.01, false)
    await _frames()
    _check(is_equal_approx(board.map_zoom, 0.8) and _is_centered(board), "Le dézoom est borné et préserve la case centrale")
    board.set_map_zoom(1.55, false)
    board.select_node(first_id)
    board.center_selected(false)
    await _frames()
    _check(is_equal_approx(board.map_zoom, 1.55) and _is_centered(board), "Changer de case conserve le zoom choisi")
    var zoom_before: float = board.map_zoom
    board._zoom_in.pressed.emit()
    await _settle()
    _check(board.map_zoom > zoom_before, "Le bouton + rapproche la vue")
    board._zoom_out.pressed.emit()
    await _settle()
    _check(board.map_zoom < zoom_before + 0.01, "Le bouton − éloigne la vue")
    var drag_start: Vector2 = board._map_view.get_global_rect().get_center() + Vector2(0, 90)
    var drag := InputEventMouseButton.new()
    drag.button_index = MOUSE_BUTTON_MIDDLE
    drag.position = drag_start
    drag.pressed = true
    root.push_input(drag, true)
    var motion := InputEventMouseMotion.new()
    motion.position = drag_start + Vector2(130, 55)
    motion.relative = Vector2(130, 55)
    motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    root.push_input(motion, true)
    drag = InputEventMouseButton.new()
    drag.button_index = MOUSE_BUTTON_MIDDLE
    drag.position = motion.position
    drag.pressed = false
    root.push_input(drag, true)
    await _frames()
    _check(not _is_centered(board), "Le glisser central permet d'explorer les environs sans changer de case")
    board._center_button.pressed.emit()
    await _settle()
    _check(_is_centered(board), "Le bouton de recentrage ramène la case courante au centre")
    root.size = Vector2i(960, 600)
    await _frames(8)
    _check(_is_centered(board), "Le redimensionnement en 960×600 maintient la sélection au centre")
    _check(board._map_view.get_global_rect().size.x > 260 and board._map_view.get_global_rect().size.y > 220, "La vue locale reste utilisable sur la petite fenêtre (%s)" % board._map_view.get_global_rect().size)
    board._buttons[first_id].grab_focus()
    await _joy(JOY_BUTTON_DPAD_RIGHT)
    await _settle()
    _check(board.selected_node_id != first_id, "La croix de la manette passe à une case voisine")
    _check(_is_centered(board), "La navigation manette suit la sélection avec la caméra")
    board.select_node(first_id)
    board._buttons[first_id].grab_focus()
    await _joy(JOY_BUTTON_A)
    _check(root.gui_get_focus_owner() == board._detail_action, "A donne le focus au bouton de la fiche sans lancer de match immédiatement (focus : %s)" % str(root.gui_get_focus_owner()))
    _check(current_scene == board, "La sélection d'une case laisse le joueur consulter la fiche")
    await _joy(JOY_BUTTON_Y)
    await _frames()
    _check(board._detail_expanded and not board._map_view.is_visible_in_tree(), "Y ouvre une fiche complète sans écraser la carte")
    _check(board._detail_action.is_visible_in_tree() and board._detail_action.get_global_rect().end.y <= root.get_visible_rect().end.y, "Le bouton Jouer reste visible dans la fiche agrandie à 960×600")
    await _capture("route-details-960")
    await _joy(JOY_BUTTON_B)
    await _frames()
    _check(not board._detail_expanded and board._map_view.is_visible_in_tree(), "B ferme la fiche agrandie et retrouve la carte")
    _check(root.gui_get_focus_owner() == board._buttons[first_id], "Le retour de fiche rend le focus à la case courante")
    # Fixtures de résultats : la suite de boucle réelle reste scene_smoke.gd.
    var fixture: Dictionary = _runner.progress.record_result(route_id, first_id, 1, 0, "board-fixture-first")
    _check(int(fixture.get("error", ERR_BUG)) == OK, "La progression d'appoint est enregistrée uniquement dans le fichier de test")
    board.select_route(route_id)
    if not pending_id.is_empty():
        board.select_node(pending_id)
        board.center_selected(false)
        await _frames()
        _check(board._buttons[pending_id].accessible and board._buttons[pending_id].kind == "reward" and board._buttons[pending_id].pending, "Un coffre réservé est une vraie case avec contenu à définir")
        _check(board._detail_action.disabled, "Un coffre sans butin défini ne propose pas de récupération")
        await _capture("route-local-chest-960")
    else:
        _check(false, "Le tableau de démonstration expose un coffre au contenu à définir")
    # Le deuxième tableau contient un adversaire exigeant A ; B le laisse gris,
    # bien que la rencontre en amont ait réellement un historique de victoire.
    var coast: String = "harbour_rematches"
    var result: Dictionary = _runner.progress.record_result(coast, "coast_start", 1, 0, "board-fixture-coast-start")
    _check(int(result.get("error", ERR_BUG)) == OK, "Une première victoire de fixture ouvre le littoral")
    result = _runner.progress.record_result(coast, "coast_amber", 1, 0, "board-fixture-coast-amber")
    _check(int(result.get("error", ERR_BUG)) == OK, "Une seconde victoire B ne remplit pas la condition A")
    board.select_route(coast)
    board.select_node("coast_quartz")
    board.center_selected(false)
    await _frames()
    _check(board._connections.cleared.get("coast_amber", false) and not board._buttons["coast_quartz"].accessible, "L'amont est gagné tandis que le match exigeant A reste verrouillé")
    _check(board._connections.edge_is_locked("coast_amber", "coast_quartz"), "Le chemin menant au match verrouillé reste fermé malgré la victoire en amont")
    var locked_color: Color = board._connections.edge_color("coast_amber", "coast_quartz")
    _check(locked_color.s < 0.2, "Les chemins inaccessibles utilisent une teinte grisée")
    _check(not board._connections.edge_is_locked("coast_start", "coast_amber"), "Le chemin entre deux matchs ouverts reste actif")
    await _capture("route-local-rank-gate-960")
    await _finish()

func _finish() -> void:
    if current_scene != null:
        current_scene.queue_free()
        current_scene = null
    await _frames()
    _runner.progress = _previous_progress
    _runner.selected_route = _previous_route
    _runner.selected_node = _previous_node
    _runner.last_result = _previous_result
    root.size = _original_window_size
    for path: String in [_path, _path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("Carte parcours : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
