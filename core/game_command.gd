class_name IEGGameCommand
extends RefCounted
## Intentions seulement. Un futur client réseau ne choisit pas le résultat.

var technique_id: String = ""
var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2(0.0, -1.0)
var pass_target_id: int = -1
var lob_pass: bool = false
var tackle: bool = false
var sprint: bool = false
var pass_ball: bool = false
var shoot: bool = false
var shot_charge: float = 0.0
var switch_player: bool = false
var reset_drill: bool = false

func to_dict() -> Dictionary:
    return {
        "technique_id": technique_id, "move": [move.x, move.y], "aim": [aim.x, aim.y],
        "pass_target_id": pass_target_id, "lob_pass": lob_pass, "tackle": tackle, "sprint": sprint, "pass_ball": pass_ball, "shoot": shoot,
        "shot_charge": shot_charge, "switch_player": switch_player,
        "reset_drill": reset_drill,
    }

static func from_dict(data: Dictionary) -> IEGGameCommand:
    var command: IEGGameCommand = IEGGameCommand.new()
    var technique: Variant = data.get("technique_id", "")
    if technique is String and technique.length() <= 80:
        command.technique_id = technique
    command.move = _read_vector(data.get("move", null), Vector2.ZERO)
    command.aim = _read_vector(data.get("aim", null), Vector2(0.0, -1.0))
    var target: Variant = data.get("pass_target_id", -1)
    if (target is int or target is float) and is_finite(float(target)):
        if float(target) == floor(float(target)) and float(target) >= -1.0 and float(target) <= 1000000.0:
            command.pass_target_id = int(target)
    command.lob_pass = data.get("lob_pass", false) == true
    command.tackle = data.get("tackle", false) == true
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
