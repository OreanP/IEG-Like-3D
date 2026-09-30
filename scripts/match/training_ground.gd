extends Node3D
## Assemblage de la session locale, des entrées et de la présentation.
## La scène de terrain et les joueurs sont visibles dans l'éditeur.

const Session = preload("res://core/training_session.gd")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

@export_group("Contrôles")
@export_range(0.05, 0.45, 0.01) var stick_deadzone: float = 0.22
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(0.5, 5.0, 0.1) var stick_camera_speed: float = 2.25
@export_range(0.25, 2.0, 0.05) var shot_charge_seconds: float = 0.85
@export var auto_pause_on_focus_loss: bool = true

@onready var controls: IEGLocalPlayerInput = $LocalInput
@onready var camera_rig: IEGOrbitCamera = $CameraRig
@onready var hud: IEGTrainingHud = $HUD
@onready var players_root: Node3D = $Players
@onready var ball_view: Node3D = $BallView
@onready var aim_arrow: MeshInstance3D = $AimArrow
var session: IEGTrainingSession
var _views: Dictionary = {}
var _aim_mesh: ImmediateMesh = ImmediateMesh.new()
var _aim_material: StandardMaterial3D = StandardMaterial3D.new()
var _paused: bool = false
var _ready_complete: bool = false

func _ready() -> void:
    # La racine et l'UI traitent la reprise ; les personnages sont PAUSABLE.
    process_mode = Node.PROCESS_MODE_ALWAYS
    players_root.process_mode = Node.PROCESS_MODE_PAUSABLE
    controls.stick_deadzone = stick_deadzone
    controls.charge_seconds = shot_charge_seconds
    camera_rig.mouse_sensitivity = mouse_sensitivity
    camera_rig.stick_sensitivity = stick_camera_speed
    var roster: Array[IEGPlayerProfile] = []
    for child: Node in players_root.get_children():
        if child is IEGPlayerView:
            roster.append(child.profile)
    session = Session.new(roster)
    var index: int = 0
    for child: Node in players_root.get_children():
        if child is IEGPlayerView:
            var state: IEGPlayerState = session.players[index]
            if child.profile != state.profile:
                child.configure(state.profile)
            _views[state.get_id()] = child
            child.sync_state(state, state.get_id() == session.controlled_id, false, 1.0)
            child.reset_physics_interpolation()
            index += 1
    ball_view.position = session.ball.position
    ball_view.reset_physics_interpolation()
    _aim_material.albedo_color = Color("8aeee9")
    _aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _aim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    aim_arrow.mesh = _aim_mesh
    hud.resume_requested.connect(func(): _set_paused(false))
    hud.reset_requested.connect(_reset_from_menu)
    hud.quit_requested.connect(func(): get_tree().quit())
    camera_rig.snap(Vector3(session.controlled().position.x, 1.0, session.controlled().position.y))
    _ready_complete = true
    hud.refresh(0.0, session, controls)
    print("IEG Like GDScript S0 — entraînement chargé. Aucun composant C#.")

func _input(event: InputEvent) -> void:
    if _ready_complete and event.is_action_pressed("pause") and not event.is_echo():
        _set_paused(not _paused)
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if (_ready_complete and auto_pause_on_focus_loss
            and what == NOTIFICATION_APPLICATION_FOCUS_OUT):
        _set_paused(true)

func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if get_tree() != null:
        get_tree().paused = false

func _set_paused(value: bool) -> void:
    _paused = value
    get_tree().paused = value
    controls.set_enabled(not value)
    hud.set_paused(value)

func _reset_from_menu() -> void:
    _set_paused(false)
    var command: IEGGameCommand = Command.new()
    command.reset_drill = true
    session.step(command)
    _sync_views(Rules.TICK)
    for event: Dictionary in session.events:
        _present(event)

func _physics_process(_delta: float) -> void:
    if not _ready_complete or _paused:
        return
    if Engine.physics_ticks_per_second != 60:
        push_error("S0 nécessite 60 ticks physiques par seconde (réglage déjà fourni).")
        _set_paused(true)
        return
    var has_ball: bool = session.ball.owner_id == session.controlled_id and not session.is_resetting()
    var command: IEGGameCommand = controls.read_command(camera_rig, has_ball)
    session.step(command)
    _sync_views(Rules.TICK)
    for event: Dictionary in session.events:
        _present(event)

func _sync_views(delta: float) -> void:
    var target: IEGPlayerState = null
    if session.ball.owner_id == session.controlled_id:
        target = session.suggested_pass_target(controls.aim(camera_rig))
    for player: IEGPlayerState in session.players:
        var view: IEGPlayerView = _views[player.get_id()]
        view.sync_state(player, player.get_id() == session.controlled_id,
            target != null and player.get_id() == target.get_id(), delta)
    var before: Vector3 = ball_view.position
    ball_view.position = session.ball.position
    var movement: Vector3 = ball_view.position - before
    movement.y = 0.0
    if movement.length_squared() > 0.000001 and movement.length() < 2.0:
        ball_view.rotate(Vector3(movement.z, 0.0, -movement.x).normalized(),
            movement.length() / Rules.BALL_RADIUS)
    _draw_aim()

func _draw_aim() -> void:
    aim_arrow.visible = session.ball.owner_id == session.controlled_id and not session.is_resetting()
    _aim_mesh.clear_surfaces()
    if not aim_arrow.visible:
        return
    var aim: Vector2 = controls.aim(camera_rig).normalized()
    var direction: Vector3 = Vector3(aim.x, 0.0, aim.y)
    var side: Vector3 = Vector3(-aim.y, 0.0, aim.x)
    var start: Vector3 = session.ball.position
    start.y = 0.05
    var tip: Vector3 = start + direction * (2.0 + controls.charge * 3.0)
    var neck: Vector3 = tip - direction * 0.35
    var vertices: Array[Vector3] = [start - side * 0.025, neck - side * 0.025,
        neck + side * 0.025, start - side * 0.025, neck + side * 0.025,
        start + side * 0.025, tip, neck - side * 0.20, neck + side * 0.20]
    _aim_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _aim_material)
    for vertex: Vector3 in vertices:
        _aim_mesh.surface_add_vertex(vertex)
    _aim_mesh.surface_end()

func _process(delta: float) -> void:
    if not _ready_complete:
        return
    var view: IEGPlayerView = _views[session.controlled_id]
    var target: Vector3 = view.get_global_transform_interpolated().origin + Vector3.UP
    var to_ball: Vector3 = ball_view.get_global_transform_interpolated().origin - target
    target += to_ball.limit_length(5.0) * 0.18
    camera_rig.advance(delta, target, controls, _paused)
    hud.refresh(0.0 if _paused else delta, session, controls)

func _present(event: Dictionary) -> void:
    var kind: int = int(event["kind"])
    var actor_id: int = int(event["actor_id"])
    match kind:
        Session.EventKind.PASS:
            var passer: IEGPlayerView = _views[actor_id]
            passer.kick()
            hud.show_message("Passe vers le n°%02d — tu le contrôles maintenant." % int(event["target_id"]))
        Session.EventKind.SHOT:
            var shooter: IEGPlayerView = _views[actor_id]
            shooter.kick()
            hud.show_message("Tir !")
        Session.EventKind.RECEPTION:
            hud.show_message("Réception du n°%02d" % actor_id)
        Session.EventKind.GOAL:
            controls.cancel_charge()
            hud.show_message("BUT !  Remise en place…")
        Session.EventKind.OUT:
            controls.cancel_charge()
            hud.show_message("Ballon sorti — remise en place.")
        Session.EventKind.RESET:
            controls.cancel_charge()
            for view: IEGPlayerView in _views.values():
                view.reset_physics_interpolation()
            ball_view.reset_physics_interpolation()
            camera_rig.snap(Vector3(session.controlled().position.x, 1.0, session.controlled().position.y))
