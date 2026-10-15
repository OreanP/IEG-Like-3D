class_name IEGPlayerState
extends RefCounted
## État mutable, indépendant des nœuds visuels.

var speed_multiplier: float = 1.0
var dazed_time: float = 0.0
var keeper_stamina: float = 100.0
var modifier_id: String = ""
var modifier_time: float = 0.0
var modifier_energy: float = 0.0
var modifier_partner_id: int = -1
var is_goalkeeper: bool = false
var keeper_hold_time: float = 0.0
var team_id: int = 0
var tackle_cooldown: float = 0.0
var recovery_time: float = 0.0
var possession_grace: float = 0.0
var profile: IEGPlayerProfile
var position: Vector2 = Vector2.ZERO
var spawn: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0.0, -1.0)
var energy: float = 100.0
var sprint_exhausted: bool = false

func _init(source: IEGPlayerProfile, start: Vector2, team: int = 0, goalkeeper: bool = false) -> void:
    is_goalkeeper = goalkeeper
    team_id = team
    profile = source
    position = start
    spawn = start

func get_id() -> int:
    return profile.player_id

func reset() -> void:
    position = spawn
    velocity = Vector2.ZERO
    facing = Vector2.UP if team_id == 0 else Vector2.DOWN
    speed_multiplier = 1.0
    dazed_time = 0.0
    keeper_stamina = 100.0
    modifier_id = ""
    modifier_time = 0.0
    modifier_energy = 0.0
    modifier_partner_id = -1
    keeper_hold_time = 0.0
    tackle_cooldown = 0.0
    recovery_time = 0.0
    possession_grace = 0.0
    energy = 100.0
    sprint_exhausted = false
