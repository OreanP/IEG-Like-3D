class_name IEGLocalPlayerInput
extends Node
## Seul adaptateur qui lit les périphériques. La simulation reçoit des commandes.

const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

var stick_deadzone: float = 0.22
var charge_seconds: float = 0.85
var charge: float = 0.0
var uses_gamepad: bool = false
var last_gamepad: int = -1
var enabled: bool = true
var _charging: bool = false
var _block_shot_until_release: bool = false
var _mouse_delta: Vector2 = Vector2.ZERO
var _ignore_ticks: int = 0

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and event.pressed:
        uses_gamepad = true
        last_gamepad = event.device
    elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.35:
        uses_gamepad = true
        last_gamepad = event.device
    elif event is InputEventKey and event.pressed and not event.echo:
        uses_gamepad = false
    elif event is InputEventMouseButton:
        if event.pressed:
            uses_gamepad = false
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if enabled and event.pressed:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            else:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            _mouse_delta = Vector2.ZERO
    elif (enabled and event is InputEventMouseMotion
            and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
        # Une souris fournit un déplacement, pas une vitesse.
        _mouse_delta += event.relative
        uses_gamepad = false

func set_enabled(value: bool) -> void:
    enabled = value
    cancel_charge()
    _ignore_ticks = 2
    _mouse_delta = Vector2.ZERO
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func cancel_charge() -> void:
    charge = 0.0
    _charging = false
    _block_shot_until_release = Input.is_action_pressed("shoot")

func take_mouse_delta() -> Vector2:
    var result: Vector2 = _mouse_delta
    _mouse_delta = Vector2.ZERO
    return result

func camera_stick() -> Vector2:
    if not enabled:
        return Vector2.ZERO
    return Input.get_vector("look_left", "look_right", "look_up", "look_down", stick_deadzone)

func world_move(camera: IEGOrbitCamera) -> Vector2:
    var raw: Vector2 = Input.get_vector("move_left", "move_right",
        "move_forward", "move_back", stick_deadzone)
    var world: Vector3 = camera.planar_right() * raw.x + camera.planar_forward() * -raw.y
    return Vector2(world.x, world.z)

func aim(camera: IEGOrbitCamera) -> Vector2:
    var result: Vector2 = world_move(camera)
    if result.length_squared() < 0.015:
        var forward: Vector3 = camera.planar_forward()
        result = Vector2(forward.x, forward.z)
    return result

func read_command(camera: IEGOrbitCamera, has_ball: bool) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    if not enabled:
        return command
    if last_gamepad >= 0 and not Input.get_connected_joypads().has(last_gamepad):
        last_gamepad = -1
        uses_gamepad = false
        cancel_charge()
    if _ignore_ticks > 0:
        _ignore_ticks -= 1
        return command
    command.move = world_move(camera)
    command.aim = aim(camera)
    command.sprint = Input.is_action_pressed("sprint")
    command.switch_player = Input.is_action_just_pressed("switch_player")
    command.pass_ball = Input.is_action_just_pressed("pass_ball")
    command.reset_drill = Input.is_action_just_pressed("reset_drill")
    var held: bool = Input.is_action_pressed("shoot")
    if not held:
        _block_shot_until_release = false
    if not has_ball or command.switch_player or command.pass_ball or command.reset_drill:
        cancel_charge()
    elif held and not _block_shot_until_release:
        _charging = true
        charge = clampf(charge + Rules.TICK / maxf(charge_seconds, 0.1), 0.0, 1.0)
    elif not held and _charging:
        command.shoot = true
        command.shot_charge = charge
        charge = 0.0
        _charging = false
    return command
