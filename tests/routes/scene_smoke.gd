extends SceneTree
## Boucle réelle tableau → FullMatch → score physique → sauvegarde → tableau.
## Fixtures annoncées : chrono raccourci et ballon placé près de la ligne.
## Aucun score ni rang n'est affecté directement dans cette vérification.
const Progress = preload("res://core/routes/route_progress.gd")
const Session = preload("res://core/match/match_session.gd")
const Rules = preload("res://core/training_rules.gd")
var _total: int = 0
var _passed: int = 0
var _runner: Node
var _original_progress: RefCounted
var _path: String = "user://test_route_scene_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + "SCÈNE PARCOURS : " + label)

func _frames(count: int = 3) -> void:
    for _index: int in range(count):
        await process_frame

func _finish(ground: Node3D, scoring_team: int) -> void:
    var session = ground.session
    session.half_duration = 0.3
    if scoring_team >= 0:
        for player: IEGPlayerState in session.players:
            player.position = Vector2(24, 0)
        session.ball.owner_id = -1
        var direction: float = session.attack_direction(scoring_team)
        session.ball.position = Vector3(0, 0.6, direction * 44.8)
        session.ball.velocity = Vector3(0, 0, direction * 35)
        ground._physics_process(Rules.TICK)
        _check(session.team_goals[scoring_team] == 1, "Le franchissement physique de la ligne attribue le but au bon camp")
    var ticks: int = 0
    while session.phase != Session.Phase.FINISHED and ticks < 1500:
        if session.phase == Session.Phase.HALFTIME:
            ground.hud.second_half_requested.emit({0: "balanced", 1: session.formations[1]})
        elif session.phase == Session.Phase.DUEL_CHOICE:
            ground.hud.duel_choice_requested.emit("left", "")
        ground._physics_process(Rules.TICK)
        ticks += 1
    ground._sync_phase()
    ground.hud.refresh(0, session, ground.controls, false)
    _check(session.phase == Session.Phase.FINISHED, "Deux périodes jouées par le moteur, jusqu'au coup de sifflet final")

func _run() -> void:
    _runner = root.get_node("RouteRun")
    _original_progress = _runner.progress
    _runner.progress = Progress.new(_runner.catalog, _path)
    _runner.last_result.clear()
    _check(change_scene_to_file("res://scenes/routes.tscn") == OK, "Ouverture du vrai tableau")
    await _frames()
    var board: Control = current_scene
    var first_route: Dictionary = _runner.catalog.routes()[0]
    var route_id: String = String(first_route["id"])
    var node_id: String = ""
    var locked_id: String = ""
    for node: Dictionary in first_route["nodes"]:
        if node["type"] == "match":
            if node_id.is_empty() and _runner.progress.is_unlocked(route_id, node["id"]):
                node_id = node["id"]
            elif locked_id.is_empty() and not _runner.progress.is_unlocked(route_id, node["id"]):
                locked_id = node["id"]
    _check(not node_id.is_empty() and not locked_id.is_empty(), "Un premier adversaire accessible et une progression verrouillée")
    board.select_node(locked_id)
    _check(board._detail_action.disabled, "Fiche verrouillée consultable, bouton Jouer inactif")
    _check(_runner.launch_match(route_id, locked_id) == ERR_UNAUTHORIZED, "Le gestionnaire refuse aussi le lancement d'un match verrouillé")
    board.select_node(node_id)
    await _frames()
    _check(not board._detail_action.disabled, "Bouton Jouer disponible pour le premier match")
    board._detail_action.pressed.emit()
    await _frames()
    var ground: Node3D = current_scene
    ground.auto_pause_on_focus_loss = false
    ground.set_physics_process(false)
    var session = ground.session
    var team: Dictionary = _runner.catalog.team(String(_runner.catalog.node(route_id, node_id)["team_id"]))
    _check(session is Session and session.players.size() == 22, "Le bouton lance la scène et la session ordinaires avec 22 joueurs")
    _check(session.team_names[1] == team["name"] and session.get_player(21).profile.content_key == team["players"][0]["id"], "Les onze profils de l'adversaire sélectionné sont utilisés")
    _check(session.half_duration == 300.0 and session.formations[1] == team["formation"], "Durée complète et formation du catalogue appliquées")
    _check(session.team_ai[1]["shot_charge"] == float(team["ai"]["shot_charge"]) and session.profile_stats_enabled, "Les paramètres IA et les statistiques de base agissent dans le moteur partagé")
    var shooter: IEGPlayerState = session.get_player(27)
    var original_position: Vector2 = shooter.position
    var original_owner: int = session.ball.owner_id
    shooter.position = session.attacking_goal(1) - Vector2(0, float(team["ai"]["shoot_distance"]) - 0.1)
    session.ball.owner_id = shooter.get_id()
    var ai_command: IEGGameCommand = session.build_ai_commands()[shooter.get_id()]
    _check(ai_command.shoot and is_equal_approx(ai_command.shot_charge, float(team["ai"]["shot_charge"])), "Le profil IA déclenche un vrai ordre de tir dans sa portée configurée")
    shooter.position = original_position
    session.ball.owner_id = original_owner
    var early: Dictionary = _runner.complete_match(session, ground._route_context)
    _check(int(early.get("error", OK)) != OK if early.get("error") is int else not str(early.get("error", "")).is_empty(), "Aucun résultat accepté avant la fin réelle du match")
    _check(_runner.progress.best_rank(route_id, node_id).is_empty() and not FileAccess.file_exists(_path), "Le lancement ne gagne rien et ne fabrique aucune sauvegarde de victoire")
    var initial_run: String = ground._route_context["run_id"]
    _finish(ground, 0)
    _check(_runner.last_result.get("rank", "") == "B" and _runner.progress.best_rank(route_id, node_id) == "B", "Le vrai but mène à une victoire 1–0 et au rang B enregistré")
    var coins: int = _runner.progress.state["wallet"]["currency"]
    ground._save_route_result()
    _check(_runner.progress.state["wallet"]["currency"] == coins, "Réafficher le résultat ne distribue pas deux fois les gains")
    var reloaded = Progress.new(_runner.catalog, _path)
    _check(reloaded.best_rank(route_id, node_id) == "B", "Le meilleur rang est relu depuis le disque")
    var wrong_context: Dictionary = ground._route_context.duplicate(true)
    wrong_context["node_id"] = locked_id
    var rejected: Dictionary = _runner.complete_match(session, wrong_context)
    _check(not str(rejected.get("error", "")).is_empty(), "Un résultat terminé ne peut pas être attribué à un autre nœud avec le même token")
    ground.hud.routes_requested.emit()
    await _frames()
    board = current_scene
    _check(board.has_method("select_node") and board.selected_node_id == node_id and board._notice_panel.visible, "Retour au tableau avec résultat et rencontre sélectionnée")
    _check(_runner.progress.is_unlocked(route_id, locked_id), "La première victoire débloque la suite sans rejouer")
    board._detail_action.pressed.emit()
    await _frames()
    ground = current_scene
    ground.auto_pause_on_focus_loss = false
    ground.set_physics_process(false)
    _check(ground._route_context["run_id"] != initial_run, "Rejouer crée une nouvelle rencontre contre le même adversaire")
    _finish(ground, -1)
    _check(_runner.last_result["rank"] == "" and _runner.progress.best_rank(route_id, node_id) == "B", "Le nul ne donne aucun rang et conserve le meilleur historique")
    _check(_runner.progress.state["wallet"]["currency"] == coins, "Le match nul ne distribue aucune récompense")
    ground.hud.rematch_requested.emit()
    await _frames()
    ground = current_scene
    ground.auto_pause_on_focus_loss = false
    ground.set_physics_process(false)
    _finish(ground, 1)
    _check(_runner.last_result["rank"] == "" and ground.session.winner_team == 1, "Un vrai but adverse produit une défaite sans rang")
    _check(_runner.progress.state["wallet"]["currency"] == coins, "La défaite ne distribue aucune récompense")
    ground.hud.routes_requested.emit()
    await _frames()
    _check(current_scene.has_method("select_node") and _runner.progress.is_unlocked(route_id, node_id), "Le match reste accessible après victoire, nul et défaite")
    _runner.abandon_match()
    current_scene.queue_free()
    current_scene = null
    await _frames()
    _runner.progress = _original_progress
    _runner.last_result.clear()
    for path: String in [_path, _path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("Scène parcours : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
