class_name IEGOrbitCamera
extends Node3D
## Caméra orbitale. Mouvement manette relatif à son orientation horizontale.

@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(0.5, 5.0, 0.1) var stick_sensitivity: float = 2.25
@export_range(9.0, 24.0, 0.5) var distance: float = 16.0
var _yaw: float = 0.0
var _pitch: float = 0.55
var _focus: Vector3 = Vector3.ZERO
@onready var camera: Camera3D = $Camera3D

func planar_forward() -> Vector3:
    return Vector3(-sin(_yaw), 0.0, -cos(_yaw))

func planar_right() -> Vector3:
    return Vector3(cos(_yaw), 0.0, -sin(_yaw))

func snap(target: Vector3) -> void:
    _focus = target
    _yaw = 0.0
    _pitch = 0.55
    _apply_transform()

# Paramètre non typé pour éviter une dépendance cyclique caméra <-> adaptateur.
func advance(delta: float, target: Vector3, controls, paused: bool) -> void:
    if not paused:
        var mouse: Vector2 = controls.take_mouse_delta()
        var stick: Vector2 = controls.camera_stick()
        _yaw -= mouse.x * mouse_sensitivity + stick.x * stick_sensitivity * delta
        _pitch = clampf(_pitch + mouse.y * mouse_sensitivity
            + stick.y * stick_sensitivity * delta, 0.23, 1.12)
        if Input.is_action_just_pressed("recenter"):
            _yaw = 0.0
            _pitch = 0.55
        if Input.is_action_just_pressed("zoom_in"):
            distance = maxf(9.0, distance - 1.5)
        if Input.is_action_just_pressed("zoom_out"):
            distance = minf(24.0, distance + 1.5)
        _focus = _focus.lerp(target, 1.0 - exp(-8.0 * delta))
    _apply_transform()

func _apply_transform() -> void:
    var offset: Vector3 = Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
    camera.global_position = _focus + offset * distance
    camera.look_at(_focus, Vector3.UP)
