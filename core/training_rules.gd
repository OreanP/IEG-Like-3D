class_name IEGTrainingRules
extends RefCounted
## Les positions tactiques sont Vector2(x, z). La présentation reste 3D.

const TICK: float = 1.0 / 60.0
const HALF_WIDTH: float = 12.0
const HALF_LENGTH: float = 18.0
const GOAL_HALF_WIDTH: float = 3.0
const GOAL_HEIGHT: float = 2.4
const BALL_RADIUS: float = 0.19
const PLAYER_RADIUS: float = 0.38
const GRAVITY: float = 9.81

static func limit_input(value: Vector2) -> Vector2:
    if not value.is_finite():
        return Vector2.ZERO
    # Évite un calcul de longueur sur des valeurs démesurées.
    var safe: Vector2 = value.clamp(Vector2(-100.0, -100.0), Vector2(100.0, 100.0))
    return safe.limit_length(1.0)

static func direction(value: Vector2, fallback: Vector2) -> Vector2:
    var safe: Vector2 = limit_input(value)
    return safe.normalized() if safe.length_squared() > 0.0001 else fallback

static func on_ground(value: Vector2, height: float = BALL_RADIUS) -> Vector3:
    return Vector3(value.x, height, value.y)

static func planar(value: Vector3) -> Vector2:
    return Vector2(value.x, value.z)

static func closest_segment_time(a: Vector2, b: Vector2, point: Vector2) -> float:
    var segment: Vector2 = b - a
    if segment.length_squared() < 0.000001:
        return 0.0
    return clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)

static func goal_crossing_time(start: Vector3, finish: Vector3) -> float:
    # Il faut que le ballon entier ait franchi la ligne. Test balayé anti-tunneling.
    for side: int in [-1, 1]:
        var plane: float = float(side) * (HALF_LENGTH + BALL_RADIUS)
        if float(side) * start.z >= HALF_LENGTH + BALL_RADIUS:
            continue
        if float(side) * finish.z < HALF_LENGTH + BALL_RADIUS:
            continue
        var dz: float = finish.z - start.z
        if absf(dz) < 0.00001:
            continue
        var t: float = (plane - start.z) / dz
        var hit: Vector3 = start.lerp(finish, t)
        if (absf(hit.x) <= GOAL_HALF_WIDTH - BALL_RADIUS
                and hit.y >= BALL_RADIUS - 0.01
                and hit.y <= GOAL_HEIGHT - BALL_RADIUS):
            return t
    return INF

static func crosses_goal(start: Vector3, finish: Vector3) -> bool:
    return is_finite(goal_crossing_time(start, finish))

static func contact_time(start: Vector3, finish: Vector3, center: Vector2,
        radius: float, max_height: float) -> float:
    # Premier contact dans un cylindre, pas le point le plus proche : évite le
    # tunneling et respecte l'ordre réception/arrêt/franchissement de la ligne.
    var a: Vector2 = planar(start) - center
    var d: Vector2 = planar(finish - start)
    var enter: float = 0.0
    var leave: float = 1.0
    if d.length_squared() > 0.000001:
        var b: float = a.dot(d)
        var discriminant: float = b * b - d.length_squared() * (a.length_squared() - radius * radius)
        if discriminant < 0.0:
            return INF
        enter = maxf(0.0, (-b - sqrt(discriminant)) / d.length_squared())
        leave = minf(1.0, (-b + sqrt(discriminant)) / d.length_squared())
    elif a.length() > radius:
        return INF
    var dy: float = finish.y - start.y
    if dy < -0.000001:
        enter = maxf(enter, (max_height - start.y) / dy)
    elif dy > 0.000001:
        leave = minf(leave, (max_height - start.y) / dy)
    elif start.y > max_height:
        return INF
    return enter if enter <= leave and enter <= 1.0 and leave >= 0.0 else INF
