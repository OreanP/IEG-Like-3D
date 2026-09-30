class_name IEGGameCommand
extends RefCounted
## Intentions seulement. Un futur client réseau ne choisit pas le résultat.

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2(0.0, -1.0)
var sprint: bool = false
var pass_ball: bool = false
var shoot: bool = false
var shot_charge: float = 0.0
var switch_player: bool = false
var reset_drill: bool = false

func to_dict() -> Dictionary:
    return {
        "move": [move.x, move.y], "aim": [aim.x, aim.y],
        "sprint": sprint, "pass_ball": pass_ball, "shoot": shoot,
        "shot_charge": shot_charge, "switch_player": switch_player,
        "reset_drill": reset_drill,
    }

static func from_dict(data: Dictionary) -> IEGGameCommand:
    var command: IEGGameCommand = IEGGameCommand.new()
    command.move = _read_vector(data.get("move", null), Vector2.ZERO)
    command.aim = _read_vector(data.get("aim", null), Vector2(0.0, -1.0))
    command.sprint = data.get("sprint", false) == true
    command.pass_ball = data.get("pass_ball", false) == true
    command.shoot = data.get("shoot", false) == true
    command.switch_player = data.get("switch_player", false) == true
    command.reset_drill = data.get("reset_drill", false) == true
    var charge_value: Variant = data.get("shot_charge", 0.0)
    if (charge_value is float or charge_value is int) and is_finite(float(charge_value)):
        command.shot_charge = clampf(float(charge_value), 0.0, 1.0)
    return command

static func _read_vector(value: Variant, fallback: Vector2) -> Vector2:
    if not value is Array or value.size() != 2:
        return fallback
    for component: Variant in value:
        if not (component is int or component is float):
            return fallback
        if not is_finite(float(component)):
            return fallback
    return Vector2(clampf(float(value[0]), -1.0, 1.0),
        clampf(float(value[1]), -1.0, 1.0)).limit_length(1.0)
