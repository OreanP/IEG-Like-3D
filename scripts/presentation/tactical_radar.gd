class_name IEGTacticalRadar
extends Control
## Lecture du match uniquement : permet de lire le placement hors champ.
const Art = preload("res://scripts/presentation/visual_theme.gd")
var _players: Array[Dictionary] = []
var _ball: Vector2 = Vector2.ZERO
var _controlled: int = -1

func _ready() -> void:
    custom_minimum_size = Vector2(194, 142)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    tooltip_text = "Position des joueurs et du ballon"

func update_match(session) -> void:
    _players.clear()
    for state: IEGPlayerState in session.players:
        _players.append({"id": state.get_id(), "team": state.team_id, "point": state.position,
            "inactive": state.dazed_time > 0.0})
    _controlled = session.controlled_id
    _ball = Vector2(session.ball.position.x, session.ball.position.z)
    queue_redraw()

func _map(point: Vector2, pitch: Rect2) -> Vector2:
    return pitch.position + Vector2(clampf((point.y + 45.0) / 90.0, 0.0, 1.0),
        clampf((point.x + 30.0) / 60.0, 0.0, 1.0)) * pitch.size

func _draw() -> void:
    var frame := Rect2(Vector2.ZERO, Vector2(194, 142))
    draw_style_box(Art.surface(Color(0.035, 0.07, 0.115, 0.86), Color(0.3, 0.42, 0.52, 0.5), 7), frame)
    draw_string(Art.bold_font(), Vector2(17, 18), "VUE DU TERRAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Art.MUTED)
    var pitch := Rect2(17, 29, 160, 98)
    var paint := Color(0.68, 0.79, 0.77, 0.35)
    draw_rect(pitch, Color(0.12, 0.28, 0.23, 0.24))
    draw_rect(pitch, paint, false, 1.0)
    draw_line(Vector2(97, 29), Vector2(97, 127), paint, 1.0, true)
    draw_arc(Vector2(97, 78), 13, 0, TAU, 36, paint, 1.0, true)
    draw_rect(Rect2(17, 51, 26, 54), paint, false, 1.0)
    draw_rect(Rect2(151, 51, 26, 54), paint, false, 1.0)
    draw_rect(Rect2(13, 69, 4, 18), paint, false, 1.0)
    draw_rect(Rect2(177, 69, 4, 18), paint, false, 1.0)
    for player: Dictionary in _players:
        var at: Vector2 = _map(player["point"], pitch)
        var color: Color = Art.AZUR if player["team"] == 0 else Art.CARMIN
        if bool(player["inactive"]):
            color.a = 0.4
        var selected: bool = player["id"] == _controlled
        if selected:
            draw_circle(at, 5.2, Art.GOLD, false, 1.2, true)
        draw_circle(at, 2.8 if selected else 2.4, color, true, -1, true)
    var ball_at: Vector2 = _map(_ball, pitch)
    draw_circle(ball_at, 2.2, Art.INK, true, -1, true)

