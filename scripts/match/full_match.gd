extends Node3D
## Match jouable complet. La session décide ; les vues et cinématiques représentent.

const Session = preload("res://core/match/match_session.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const Catalogue = preload("res://core/content/technique_catalog.gd")
const Cinematic = preload("res://scripts/presentation/duel_cinematic.gd")
const PlayerScene = preload("res://scenes/characters/player_view.tscn")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

@export_range(10.0, 2700.0, 1.0) var half_seconds: float = 300.0
@export_range(0.05, 0.45, 0.01) var stick_deadzone: float = 0.22
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(0.5, 5.0, 0.1) var stick_camera_speed: float = 2.25
@export_range(0.25, 2.0, 0.05) var shot_charge_seconds: float = 0.85
@export var auto_pause_on_focus_loss: bool = true

@onready var controls: IEGLocalPlayerInput = $LocalInput
@onready var camera_rig: IEGOrbitCamera = $CameraRig
@onready var hud: IEGMatchHud = $HUD
@onready var players_root: Node3D = $Players
@onready var ball_view: Node3D = $BallView
@onready var aim_arrow: MeshInstance3D = $AimArrow
@onready var shooting_zone: MeshInstance3D = $ShootingZone
@onready var arena: Node3D = $Arena

var session
var _catalogue = Catalogue.new()
var _cinematic: Node3D
var _views: Dictionary = {}
var _aim_mesh := ImmediateMesh.new()
var _aim_material := StandardMaterial3D.new()
var _zone_mesh := ImmediateMesh.new()
var _zone_material := StandardMaterial3D.new()
var _zone_line_material := StandardMaterial3D.new()
var _paused: bool = false
var _ready_complete: bool = false
var _last_controlled_id: int = -1
var _observed_phase: int = -1
var _armed_technique: String = ""
var _editor_layer: CanvasLayer
var _editor_previous_focus: Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if OS.get_cmdline_user_args().has("--smoke"):
        half_seconds = 2.0
        auto_pause_on_focus_loss = false
    controls.stick_deadzone = stick_deadzone
    controls.charge_seconds = shot_charge_seconds
    camera_rig.mouse_sensitivity = mouse_sensitivity
    camera_rig.stick_sensitivity = stick_camera_speed
    camera_rig.distance = 22.0
    var roster: Dictionary = Roster.build()
    session = Session.new(roster.profiles, roster.starts, roster.teams, roster.keepers, half_seconds)
    for state: IEGPlayerState in session.players:
        var view: IEGPlayerView = PlayerScene.instantiate()
        view.name = "Player%02d" % state.get_id()
        view.profile = state.profile
        view.team_id = state.team_id
        view.is_goalkeeper = state.is_goalkeeper
        players_root.add_child(view)
        _views[state.get_id()] = view
        view.sync_state(state, state.get_id() == session.controlled_id, false, Rules.TICK)
        view.reset_physics_interpolation()
    _cinematic = Cinematic.new()
    _cinematic.name = "DuelCinematic"
    add_child(_cinematic)
    _aim_material.albedo_color = Color("8aeee9")
    _aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _aim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    aim_arrow.mesh = _aim_mesh
    _zone_material.albedo_color = Color(0.25, 0.85, 0.93, 0.13)
    _zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _zone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _zone_material.no_depth_test = false
    _zone_line_material.albedo_color = Color(0.45, 0.95, 1, 0.85)
    _zone_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _zone_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shooting_zone.mesh = _zone_mesh
    hud.set_catalogue(_catalogue.all_definitions())
    hud.pause_requested.connect(func(): _set_paused(true))
    hud.resume_requested.connect(func(): _set_paused(false))
    hud.menu_opened.connect(_pause_for_menu)
    hud.rematch_requested.connect(_rematch)
    hud.training_requested.connect(_open_training)
    hud.editor_requested.connect(_open_editor)
    hud.duel_choice_requested.connect(_choose_duel)
    hud.second_half_requested.connect(_start_second_half)
    hud.special_shot_requested.connect(_arm_special)
    hud.tactic_requested.connect(_activate_tactic)
    hud.modifier_requested.connect(_activate_modifier)
    ball_view.position = session.ball.position
    ball_view.reset_physics_interpolation()
    camera_rig.snap(Vector3(session.controlled().position.x, 1, session.controlled().position.y))
    _ready_complete = true
    _sync_phase()
    _sync_views(Rules.TICK)
    hud.refresh(0, session, controls, false)
    hud.show_message("Match 11 contre 11 · Deux mi-temps de %d minutes." % maxi(1, ceili(half_seconds / 60)))
    print("IEG match : 22 joueurs, terrain 60 × 90 m, 2 × %.0f secondes." % half_seconds)

func _input(event: InputEvent) -> void:
    if not _ready_complete or event.is_echo() or is_instance_valid(_editor_layer):
        return
    if event.is_action_pressed("pause"):
        if session.phase == session.Phase.LIVE:
            _set_paused(not _paused)
        get_viewport().set_input_as_handled()
    elif InputMap.has_action("special_menu") and event.is_action_pressed("special_menu"):
        if session.phase == session.Phase.LIVE:
            if _paused:
                _set_paused(false)
            else:
                hud.open_actions("TIR")
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if (_ready_complete and not is_instance_valid(_editor_layer) and auto_pause_on_focus_loss and what == NOTIFICATION_APPLICATION_FOCUS_OUT
            and session.phase == session.Phase.LIVE):
        _set_paused(true)

func _exit_tree() -> void:
    if _cinematic != null:
        _cinematic.stop()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if get_tree() != null:
        get_tree().paused = false

func _physics_process(_delta: float) -> void:
    if not _ready_complete or _paused or is_instance_valid(_editor_layer):
        return
    if Engine.physics_ticks_per_second != 60:
        push_error("Le match nécessite 60 ticks physiques par seconde.")
        _set_paused(true)
        return
    _sync_phase()
    if _last_controlled_id != session.controlled_id:
        controls.cancel_charge()
        controls.pass_target_id = -1
        _last_controlled_id = session.controlled_id
    var command: IEGGameCommand = Command.new()
    var ai_commands: Dictionary = {}
    if session.phase == session.Phase.LIVE:
        var has_ball: bool = session.ball.owner_id == session.controlled_id and not session.is_resetting()
        command = controls.read_command(camera_rig, has_ball, session)
        # Le raccourci de remise à zéro appartient au terrain d'entraînement.
        command.reset_drill = false
        if command.shoot and not _armed_technique.is_empty():
            command.technique_id = _armed_technique
            _armed_technique = ""
            hud.clear_armed_technique()
        ai_commands = session.build_ai_commands()
    session.step(command, ai_commands)
    _sync_phase()
    if session.phase == session.Phase.CINEMATIC:
        if _cinematic.active:
            _cinematic.advance(Rules.TICK)
    else:
        _sync_views(Rules.TICK)
    for event: Dictionary in session.events:
        _present(event)

func _process(delta: float) -> void:
    if not _ready_complete or is_instance_valid(_editor_layer):
        return
    if session.phase != session.Phase.CINEMATIC:
        var target_view: IEGPlayerView = _views[session.controlled_id]
        var target: Vector3 = target_view.get_global_transform_interpolated().origin + Vector3.UP
        var to_ball: Vector3 = ball_view.get_global_transform_interpolated().origin - target
        target += to_ball.limit_length(8) * 0.18
        camera_rig.advance(delta, target, controls, _paused or session.phase != session.Phase.LIVE)
    hud.refresh(0 if _paused else delta, session, controls, _paused)

func _sync_phase() -> void:
    if _observed_phase == session.phase:
        return
    var previous: int = _observed_phase
    _observed_phase = session.phase
    controls.set_enabled(session.phase == session.Phase.LIVE and not _paused)
    if previous == session.Phase.CINEMATIC and _cinematic.active:
        _cinematic.stop()
    _set_animations_active(session.phase == session.Phase.LIVE and not _paused)
    if session.phase == session.Phase.CINEMATIC:
        aim_arrow.visible = false
        shooting_zone.visible = false
        var actor: Node3D = _views.get(int(session.duel.get("actor_id", -1)))
        var target: Node3D = _views.get(int(session.duel.get("target_id", -1)))
        _cinematic.begin(session.duel, actor, target, ball_view)
    elif session.phase == session.Phase.HALFTIME:
        hud.show_message("Mi-temps · choisissez la disposition des deux équipes.", 5)
    elif session.phase == session.Phase.LIVE and previous >= 0:
        _sync_views(Rules.TICK)
    if session.phase != session.Phase.LIVE:
        controls.cancel_charge()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_paused(value: bool) -> void:
    if session.phase != session.Phase.LIVE:
        return
    _paused = value
    controls.set_enabled(not value)
    _set_animations_active(not value)
    hud.set_paused(value)

func _pause_for_menu() -> void:
    _paused = true
    controls.set_enabled(false)
    _set_animations_active(false)

func _set_animations_active(active: bool) -> void:
    for view: Node in _views.values():
        for animation: Node in view.find_children("*", "AnimationPlayer", true, false):
            animation.active = active

func _sync_views(delta: float) -> void:
    var target: IEGPlayerState = null
    if session.ball.owner_id == session.controlled_id:
        target = session.get_player(controls.pass_target_id) if controls.pass_target_id >= 0 else session.suggested_pass_target(controls.aim(camera_rig))
    for player: IEGPlayerState in session.players:
        var view: IEGPlayerView = _views[player.get_id()]
        view.sync_state(player, player.get_id() == session.controlled_id, target != null and player.get_id() == target.get_id(), delta)
    var before: Vector3 = ball_view.position
    ball_view.position = session.ball.position
    var movement: Vector3 = ball_view.position - before
    movement.y = 0
    if movement.length_squared() > 0.000001 and movement.length() < 2:
        ball_view.rotate(Vector3(movement.z, 0, -movement.x).normalized(), movement.length() / Rules.BALL_RADIUS)
    _draw_aim()
    _draw_shooting_zone()

func _draw_aim() -> void:
    aim_arrow.visible = session.phase == session.Phase.LIVE and session.ball.owner_id == session.controlled_id and not session.is_resetting()
    _aim_mesh.clear_surfaces()
    if not aim_arrow.visible:
        return
    var aim: Vector2 = controls.aim(camera_rig).normalized()
    var direction := Vector3(aim.x, 0, aim.y)
    var side := Vector3(-aim.y, 0, aim.x)
    var start: Vector3 = session.ball.position
    start.y = 0.07
    var tip: Vector3 = start + direction * (2 + controls.charge * 3)
    var neck: Vector3 = tip - direction * 0.35
    var vertices: Array[Vector3] = [start - side * 0.035, neck - side * 0.035, neck + side * 0.035, start - side * 0.035, neck + side * 0.035, start + side * 0.035, tip, neck - side * 0.23, neck + side * 0.23]
    _aim_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _aim_material)
    for vertex: Vector3 in vertices:
        _aim_mesh.surface_add_vertex(vertex)
    _aim_mesh.surface_end()

func _draw_shooting_zone() -> void:
    _zone_mesh.clear_surfaces()
    shooting_zone.visible = false
    if session.phase != session.Phase.LIVE and session.phase != session.Phase.DUEL_CHOICE:
        return
    var shooter: IEGPlayerState = session.get_player(session.ball.owner_id)
    if shooter == null or shooter.is_goalkeeper or session.is_resetting():
        return
    var goal: Vector2 = session.attacking_goal(shooter.team_id)
    var selected_technique: String = _armed_technique if shooter.get_id() == session.controlled_id else ""
    var shot_range: float = session.shot_range(shooter, selected_technique)
    if shooter.position.distance_to(goal) > shot_range:
        return
    shooting_zone.visible = true
    var start := Vector3(shooter.position.x, 0.055, shooter.position.y)
    var left := Vector3(-session.goal_half_width, 0.055, goal.y)
    var right := Vector3(session.goal_half_width, 0.055, goal.y)
    _zone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _zone_material)
    for vertex: Vector3 in [start, left, right]:
        _zone_mesh.surface_add_vertex(vertex)
    _zone_mesh.surface_end()
    _zone_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _zone_line_material)
    for vertex: Vector3 in [start, left, left, right, right, start]:
        _zone_mesh.surface_add_vertex(vertex + Vector3.UP * 0.012)
    _zone_mesh.surface_end()

func _choose_duel(choice: String, technique_id: String) -> void:
    if session.choose_duel(choice, technique_id):
        _sync_phase()
        hud.refresh(0, session, controls, _paused)
    else:
        hud.show_message("Choix indisponible : vérifiez la catégorie et l'énergie.")

func _start_second_half(formations: Dictionary) -> void:
    if not session.start_second_half(formations):
        return
    _sync_phase()
    _sync_views(Rules.TICK)
    for view: IEGPlayerView in _views.values():
        view.reset_physics_interpolation()
    ball_view.reset_physics_interpolation()
    camera_rig.snap(Vector3(session.controlled().position.x, 1, session.controlled().position.y))
    arena.set_second_half(true)
    hud.refresh(0, session, controls, false)
    hud.show_message("Deuxième mi-temps · camps inversés.")

func _arm_special(technique_id: String) -> void:
    var definition: Dictionary = _catalogue.get_definition(technique_id)
    if definition.is_empty() or str(definition.get("category", "")) != "TIR":
        return
    _armed_technique = technique_id
    hud.set_armed_technique(definition)

func _activate_tactic(id: String) -> void:
    if session.set_tactic(0, id):
        hud.show_message("Tactique : " + str(_catalogue.get_definition(id).get("name", id)))
    else:
        hud.show_message("Tactique indisponible.")

func _activate_modifier(id: String) -> void:
    var partner: int = -1
    var definition: Dictionary = _catalogue.get_definition(id)
    if str(definition.get("category", "")) == "RESONANCE":
        var properties: Dictionary = definition.get("properties", {})
        var profile_a: int = int(properties.get("profile_a", 7))
        var profile_b: int = int(properties.get("profile_b", 10))
        var preferred: int = profile_b if session.controlled_id == profile_a else profile_a
        for state: IEGPlayerState in session.players:
            if state.team_id == 0 and state.get_id() != session.controlled_id and not state.is_goalkeeper:
                partner = state.get_id()
                if state.get_id() == preferred:
                    break
    if session.activate_modifier(session.controlled_id, id, partner):
        hud.show_message("Activation : " + str(definition.get("name", id)))
    else:
        var reason: String = str(session.modifier_error)
        hud.show_message(reason if not reason.is_empty() else "Activation refusée : vérifiez l'énergie et le partenaire.", 5.0)

func _rematch() -> void:
    _paused = false
    get_tree().reload_current_scene()

func _open_editor() -> void:
    if is_instance_valid(_editor_layer) or session.phase == session.Phase.CINEMATIC:
        return
    controls.set_enabled(false)
    _set_animations_active(false)
    _editor_previous_focus = get_viewport().gui_get_focus_owner()
    hud.visible = false
    _editor_layer = CanvasLayer.new()
    _editor_layer.name = "ContentEditorOverlay"
    _editor_layer.layer = 30
    add_child(_editor_layer)
    var editor_scene: PackedScene = load("res://scenes/content_editor.tscn")
    var editor: Control = editor_scene.instantiate()
    editor.embedded_mode = true
    editor.match_requested.connect(_close_editor)
    _editor_layer.add_child(editor)
    editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _close_editor() -> void:
    if is_instance_valid(_editor_layer):
        _editor_layer.queue_free()
    _editor_layer = null
    hud.visible = true
    controls.set_enabled(session.phase == session.Phase.LIVE and not _paused)
    _set_animations_active(session.phase == session.Phase.LIVE and not _paused)
    if (_paused or session.phase != session.Phase.LIVE) and is_instance_valid(_editor_previous_focus):
        _editor_previous_focus.grab_focus.call_deferred()
    elif is_instance_valid(_editor_previous_focus):
        _editor_previous_focus.release_focus()
    _editor_previous_focus = null
    _catalogue = Catalogue.new()
    session.catalog = _catalogue
    hud.set_catalogue(_catalogue.all_definitions())
    if not session.duel.is_empty():
        session.duel["techniques"] = _catalogue.all_definitions()
    if not _armed_technique.is_empty() and _catalogue.get_definition(_armed_technique).get("category", "") != "TIR":
        _armed_technique = ""
        hud.clear_armed_technique()
    hud.show_message("Retour au match · les contenus sauvegardés sont chargés.")

func _open_training() -> void:
    get_tree().change_scene_to_file("res://scenes/training_ground.tscn")

func _present(event: Dictionary) -> void:
    var kind: int = int(event.get("kind", -1))
    var actor_id: int = int(event.get("actor_id", -1))
    match kind:
        Session.EventKind.PASS, Session.EventKind.KEEPER_RELEASE:
            if _views.has(actor_id):
                _views[actor_id].kick()
        Session.EventKind.SHOT:
            if _views.has(actor_id) and session.phase != session.Phase.CINEMATIC:
                _views[actor_id].kick()
        Session.EventKind.GOAL:
            controls.cancel_charge()
            hud.show_message("BUT !  %s  %d — %d  %s" % [session.team_names[0], session.team_goals[0], session.team_goals[1], session.team_names[1]], 4)
        Session.EventKind.OUT:
            controls.cancel_charge()
            hud.show_message("Sortie du ballon · reprise du jeu.")
        Session.EventKind.KEEPER_CAPTURE:
            controls.cancel_charge()
            if _views.has(actor_id):
                _views[actor_id].represent_save(true)
            hud.show_message("Capture du gardien · relance disponible.")
        Session.EventKind.KEEPER_DEFLECTION:
            if _views.has(actor_id):
                _views[actor_id].represent_save(false)
            hud.show_message("Déviation · ballon libre.")
        Session.EventKind.RESET:
            controls.cancel_charge()
            for view: IEGPlayerView in _views.values():
                view.reset_physics_interpolation()
            ball_view.reset_physics_interpolation()
