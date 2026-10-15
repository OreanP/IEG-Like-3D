extends SceneTree
## Assemblage et parcours des interfaces réelles du match. À lancer dans Godot.
const MatchScene = preload("res://scenes/full_match.tscn")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")
var _passed: int = 0
var _total: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + "SCÈNE MATCH : " + description)

func _refresh(ground: Node3D) -> void:
    ground._sync_phase()
    ground._sync_views(Rules.TICK)
    ground.hud.refresh(0, ground.session, ground.controls, false)

func _run() -> void:
    var ground: Node3D = MatchScene.instantiate()
    ground.auto_pause_on_focus_loss = false
    root.add_child(ground)
    ground.set_physics_process(false)
    await process_frame
    var session = ground.session
    var hud = ground.hud
    var blue: int = 0
    var red: int = 0
    var keepers: int = 0
    for state: IEGPlayerState in session.players:
        blue += 1 if state.team_id == 0 else 0
        red += 1 if state.team_id == 1 else 0
        keepers += 1 if state.is_goalkeeper else 0
    _check(session.players.size() == 22 and blue == 11 and red == 11 and keepers == 2, "22 joueurs, deux équipes complètes et deux gardiens")
    _check(session.half_duration == 300.0 and hud._clock.text.contains("05:00"), "Match de deux mi-temps de cinq minutes")
    _check(ground.players_root.get_child_count() == 22, "Chaque joueur possède sa vue Godot")
    _check(is_equal_approx(absf(session.attacking_goal(0).y), 45.0), "Terrain de match long de 90 mètres")
    _check(session.controlled().team_id == 0 and not session.controlled().is_goalkeeper, "Engagement et sélection d'un joueur allié de champ")
    _check(hud._keeper_bars.size() == 2 and hud._keeper_bars[0].value == 100 and hud._keeper_bars[1].value == 100, "Deux jauges d'endurance de gardien")
    # L'adaptateur ignore deux lectures après une activation pour éviter
    # qu'une validation de menu produise simultanément une action de jeu.
    ground.controls.read_command(ground.camera_rig, true, session)
    ground.controls.read_command(ground.camera_rig, true, session)
    Input.action_press("move_right", 0.6)
    var c: IEGGameCommand = ground.controls.read_command(ground.camera_rig, true, session)
    _check(c.move.x > 0 and c.move.length() < 1, "Déplacement analogique transmis par les vraies entrées")
    Input.action_release("move_right")
    Input.action_press("lob_pass")
    c = ground.controls.read_command(ground.camera_rig, true, session)
    _check(c.pass_ball and c.lob_pass, "Passe lobée transmise par les vraies entrées")
    Input.action_release("lob_pass")
    _check(InputMap.has_action("special_menu"), "Menu de techniques accessible par une action d'entrée")
    hud.open_actions("KARMA")
    _check(ground._paused and hud._mode == "actions_KARMA", "Menu Karma accessible pendant le match")
    hud._activate_content("KARMA", "tempest_karma")
    _check(not ground._paused and session.get_player(7).modifiers.has("KARMA"), "Activation du Karma par le vrai menu")
    hud.open_actions("RESONANCE")
    hud._activate_content("RESONANCE", "twin_resonance")
    _refresh(ground)
    _check(session.get_active_modifiers(7).size() == 2 and hud._modifier_bars["KARMA"].visible and hud._modifier_bars["RESONANCE"].visible and hud._modifier_labels["KARMA"].text.contains("Karma") and hud._modifier_labels["RESONANCE"].text.contains("Resonance"), "Karma et Resonance cumulés avec deux réserves visibles")
    _check(hud._team_modifier_counts[0].text.contains("Karma 1/3") and hud._team_modifier_counts[0].text.contains("Resonance 1/3") and hud._team_modifier_counts[1].text.contains("Karma 0/3") and hud._team_modifier_counts[1].text.contains("Resonance 0/3"), "Compteurs Karma et Resonance séparés pour les deux équipes")
    var clock: float = session.elapsed_half
    hud.pause_requested.emit()
    ground._physics_process(Rules.TICK)
    _check(ground._paused and session.elapsed_half == clock and hud._mode == "pause", "Pause utilisateur arrête le chrono et présente le menu")
    hud.resume_requested.emit()
    _check(not ground._paused, "Bouton Reprendre réactive le match")

    # Face-à-face de champ dans la scène réelle, sans déplacer les autres rôles.
    session.get_player(7).position = Vector2.ZERO
    session.get_player(27).position = Vector2(0, -1.8)
    session.ball.owner_id = 7
    session._duel_cooldown = 0.0
    session._follow_owner()
    var started: bool = session.request_duel(7, 27, "field")
    _refresh(ground)
    _check(started and hud._mode == "duel" and hud._overlay.visible, "Choix gauche/droite/technique présenté pour un duel de champ")
    _check(root.gui_get_focus_owner() is Button, "Un bouton de duel a le focus pour la manette et le clavier")
    var before: Vector2 = session.get_player(7).position
    clock = session.elapsed_half
    hud.duel_choice_requested.emit("special", "combat_blade")
    _check(session.phase == session.Phase.CINEMATIC and ground._cinematic.active and hud._mode == "cinematic", "Le vrai bouton de technique lance la cinématique")
    _check(hud._cinematic_scores.text.contains("◆") and hud._cinematic_winner.text.is_empty(), "Scores et gagnant restent masqués pendant l'introduction")
    for _tick: int in range(80):
        ground._physics_process(Rules.TICK)
    _refresh(ground)
    _check(session.get_player(7).position == before and session.elapsed_half == clock, "La cinématique déplace les vues sans avancer le monde ni le chrono")
    for _tick: int in range(12):
        ground._physics_process(Rules.TICK)
    hud.refresh(0, session, ground.controls, false)
    _check(not hud._cinematic_scores.text.contains("◆") and not hud._cinematic_winner.text.is_empty(), "Scores et vainqueur révélés pendant la cinématique")
    for _tick: int in range(250):
        if session.phase != session.Phase.CINEMATIC:
            break
        ground._physics_process(Rules.TICK)
    _refresh(ground)
    _check(session.phase == session.Phase.LIVE and not ground._cinematic.active, "Retour au jeu live après le résultat")
    var loser: IEGPlayerState = session.get_player(27)
    var transparent: bool = false
    var view: Node3D = ground._views[27]
    for mesh: Node in view.get_node("VisualModel").find_children("*", "MeshInstance3D", true, false):
        if mesh.transparency >= 0.5:
            transparent = true
    _check(loser.dazed_time > 0 and transparent, "Joueur dribblé inactif et semi-transparent après la reprise")

    # Vérification de la géométrie de la zone de tir avec le vrai maillage.
    session.get_player(7).position = Vector2(0, -31)
    session.get_player(21).position = Vector2(0, -41)
    session.ball.owner_id = 7
    session._follow_owner()
    for _tick: int in range(70):
        session.step(Command.new())
    _refresh(ground)
    _check(ground.shooting_zone.visible and ground.shooting_zone.mesh.get_surface_count() == 2, "Triangle tireur/deux coins de la cage affiché dans la zone de tir")
    started = session.request_duel(7, 21, "keeper")
    _refresh(ground)
    _check(started and hud._mode == "duel" and ground.shooting_zone.visible, "Le triangle reste visible pendant le choix tireur/gardien")
    hud.duel_choice_requested.emit("special", "orbital_shot")
    _check(session.phase == session.Phase.CINEMATIC and not ground.shooting_zone.visible, "Le duel gardien/tireur passe en cinématique")
    for _tick: int in range(250):
        if session.phase != session.Phase.CINEMATIC:
            break
        ground._physics_process(Rules.TICK)
    _refresh(ground)
    _check(hud._keeper_bars[1].value == session.get_player(21).keeper_stamina, "La jauge reflète l'endurance réelle du gardien après son affrontement")

    for _tick: int in range(120):
        if not session.is_resetting():
            break
        session.step(Command.new())
    session.elapsed_half = session.half_duration - Rules.TICK * 0.5
    session.step(Command.new())
    _refresh(ground)
    _check(session.phase == session.Phase.HALFTIME and hud._mode == "halftime" and hud._formation_blue.item_count == 3 and hud._formation_red.item_count == 3, "Mi-temps avec trois dispositions modifiables pour chaque équipe")
    var same_session = ground.session
    clock = session.elapsed_half
    ground._open_editor()
    await process_frame
    ground._physics_process(Rules.TICK)
    _check(is_instance_valid(ground._editor_layer) and not hud.visible and ground.session == same_session and session.elapsed_half == clock, "Atelier ouvert à la mi-temps sans perdre ni avancer le match")
    ground._close_editor()
    await process_frame
    _check(not is_instance_valid(ground._editor_layer) and hud.visible and ground.session == same_session and session.phase == session.Phase.HALFTIME and session.elapsed_half == clock, "Retour de l'atelier conserve le match, le chrono et la mi-temps")
    var first_goal: Vector2 = session.attacking_goal(0)
    hud._formation_blue.select(1)
    hud._formation_red.select(2)
    hud._resume_second_half()
    _check(session.phase == session.Phase.LIVE and session.period == 2 and session.attacking_goal(0) == -first_goal, "Validation de la disposition et changement de camp par l'interface")
    session.elapsed_half = session.half_duration - Rules.TICK * 0.5
    session.step(Command.new())
    _refresh(ground)
    _check(session.phase == session.Phase.FINISHED and hud._mode == "finished" and hud._overlay.visible, "Fin du match et écran du résultat")
    ground.queue_free()
    await process_frame
    print("Scène match : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
