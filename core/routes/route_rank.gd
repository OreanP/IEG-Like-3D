class_name IEGRouteRank
extends RefCounted
## Une seule règle de notation pour les parcours, sans dépendance à leur interface.

const DEFAULT_RULES: Dictionary = {
    "a_goal_difference": 3,
    "s_goals_for": 5,
    "s_goals_against": 0,
}

static func calculate(goals_for: int, goals_against: int, config: Dictionary = {}) -> String:
    if goals_for < 0 or goals_against < 0 or goals_for <= goals_against:
        return ""
    var s_for: int = _threshold(config, "s_goals_for", 1)
    var s_against: int = _threshold(config, "s_goals_against", 0)
    if goals_for >= s_for and goals_against <= s_against:
        return "S"
    if goals_for - goals_against >= _threshold(config, "a_goal_difference", 1):
        return "A"
    return "B"

static func value(rank: String) -> int:
    match rank:
        "B": return 1
        "A": return 2
        "S": return 3
    return 0

static func _threshold(config: Dictionary, key: String, minimum: int) -> int:
    var raw: Variant = config.get(key, DEFAULT_RULES[key])
    if (raw is int or raw is float) and is_finite(float(raw)) and float(raw) == floorf(float(raw)) and float(raw) >= minimum and float(raw) <= 1000.0:
        return int(raw)
    return int(DEFAULT_RULES[key])
