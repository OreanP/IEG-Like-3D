class_name IEGPlayerState
extends RefCounted
## État mutable, indépendant des nœuds visuels.

var profile: IEGPlayerProfile
var position: Vector2 = Vector2.ZERO
var spawn: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, -1.0)
var energy: float = 100.0
var sprint_exhausted: bool = false

func _init(source: IEGPlayerProfile, start: Vector2) -> void:
    profile = source
    position = start
    spawn = start

func get_id() -> int:
    return profile.player_id

func reset() -> void:
    position = spawn
    velocity = Vector2.ZERO
    facing = Vector2(0.0, -1.0)
    energy = 100.0
    sprint_exhausted = false
