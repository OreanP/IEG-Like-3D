class_name IEGBallState
extends RefCounted

enum Mode { HELD, PASS, SHOT, FREE }

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var owner_id: int = -1
var mode: Mode = Mode.HELD
