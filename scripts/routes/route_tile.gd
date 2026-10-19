extends Button
## Socle du parcours : emblème, coffre ou liaison. Aucune règle de progression.

const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")
const TILE_SIZE := Vector2(132, 126)
const ICONS := {
    "reward": "res://assets/ui/routes/chest_closed.svg",
    "gate": "res://assets/ui/routes/gate.svg",
    "branch": "res://assets/ui/routes/branch.svg"
}
const RANK_COLORS := {"B": Color("dfac6a"), "A": Color("dcebf2"), "S": Color("ffd269")}

var accessible: bool = false
var kind: String = "match"
var rank: String = ""
var pending: bool = false
var is_selected: bool = false
var _claimed: bool = false
var _start: bool = false
var _label: String = ""
var _icon: Texture2D
var _lock: Texture2D
var _level: int = 0
var _gray_material: ShaderMaterial

func _ready() -> void:
    custom_minimum_size = TILE_SIZE
    size = TILE_SIZE
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
        add_theme_stylebox_override(state, StyleBoxEmpty.new())
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)
    _update_material()

func configure(node: Dictionary, team: Dictionary, unlocked: bool, best_rank: String, claimed: bool) -> void:
    accessible = unlocked
    kind = String(node.get("type", "match"))
    rank = best_rank if best_rank in ["B", "A", "S"] else ""
    _claimed = claimed
    pending = bool(node.get("rewards_pending", false))
    _start = String(node.get("presentation", "")) == "start"
    _label = String(team.get("name", node.get("name", "Étape")))
    _level = int(node.get("recommended_level", team.get("level", 1))) if kind == "match" else 0
    var path: String = String(team.get("emblem", "")) if kind == "match" else String(ICONS.get(kind, ""))
    if kind == "reward" and claimed:
        path = "res://assets/ui/routes/chest_open.svg"
    _icon = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
    _lock = load("res://assets/ui/routes/lock.svg") as Texture2D
    tooltip_text = _label + (" · Accessible" if accessible else " · Verrouillé")
    if _level > 0:
        tooltip_text += " · Niveau %d" % _level
    if not rank.is_empty():
        tooltip_text += " · Meilleur rang " + rank
    _update_material()
    queue_redraw()

func set_selected(value: bool) -> void:
    is_selected = value
    queue_redraw()

func _update_material() -> void:
    if _gray_material == null:
        var shader := Shader.new()
        # En fragment canvas_item, COLOR inclut déjà la texture et la couleur du draw.
        shader.code = "shader_type canvas_item;\nuniform bool locked = false;\nvoid fragment() {\n vec4 c = COLOR;\n if (locked) { float luminance = dot(c.rgb, vec3(0.299, 0.587, 0.114)); c.rgb = vec3(luminance) * 0.78; }\n COLOR = c;\n}\n"
        _gray_material = ShaderMaterial.new()
        _gray_material.shader = shader
        material = _gray_material
    _gray_material.set_shader_parameter("locked", not accessible)

func _draw() -> void:
    var hover: bool = is_hovered() or has_focus()
    var base := PackedVector2Array([Vector2(8, 65), Vector2(30, 44), Vector2(102, 44), Vector2(124, 65), Vector2(102, 91), Vector2(30, 91)])
    var rim := PackedVector2Array([Vector2(8, 65), Vector2(30, 91), Vector2(102, 91), Vector2(124, 65), Vector2(124, 72), Vector2(102, 99), Vector2(30, 99), Vector2(8, 72)])
    var shadow := PackedVector2Array()
    for point: Vector2 in base:
        shadow.append(point + Vector2(0, 10))
    draw_colored_polygon(shadow, Color(0.02, 0.19, 0.32, 0.28))
    draw_colored_polygon(rim, Color("155ca5") if not _start else Color("267242"))
    draw_colored_polygon(base, Color("1b91dc") if not _start else Color("37b658"))
    var top := PackedVector2Array([Vector2(13, 65), Vector2(32, 48), Vector2(100, 48), Vector2(119, 65), Vector2(100, 86), Vector2(32, 86)])
    draw_colored_polygon(top, Color("26b8ed") if not _start else Color("55cf69"))
    draw_colored_polygon(PackedVector2Array([Vector2(13, 65), Vector2(32, 48), Vector2(100, 48), Vector2(119, 65)]), Color(0.7, 1.0, 1.0, 0.22))
    var outline := base.duplicate()
    outline.append(base[0])
    draw_polyline(outline, Color("e4ffff"), 2.4, true)
    draw_polyline(PackedVector2Array([Vector2(30, 95), Vector2(102, 95), Vector2(122, 73)]), Color("6cdbff"), 1.2, true)
    if hover or is_selected:
        draw_polyline(outline, VisualTheme.GOLD if is_selected else Color.WHITE, 4.0 if is_selected else 3.0, true)
    if _start:
        _text("DÉPART", Rect2(12, 48, 108, 27), 18, Color("efffe1"), true)
    elif _icon != null:
        var icon_size := Vector2(72, 72)
        var ratio: float = float(_icon.get_width()) / maxf(float(_icon.get_height()), 1.0)
        if ratio < 1.0:
            icon_size.x *= ratio
        else:
            icon_size.y /= ratio
        var icon_position := Vector2((TILE_SIZE.x - icon_size.x) * 0.5, 3 + (72 - icon_size.y) * 0.5)
        draw_texture_rect(_icon, Rect2(icon_position + Vector2(0, 3), icon_size), false, Color(0.04, 0.12, 0.22, 0.45))
        draw_texture_rect(_icon, Rect2(icon_position, icon_size), false)
    else:
        _text("FC", Rect2(30, 18, 72, 55), 30, Color.WHITE, true)
    if is_selected:
        draw_colored_polygon(PackedVector2Array([Vector2(57, 0), Vector2(75, 0), Vector2(66, 9)]), VisualTheme.GOLD)
    if not accessible and _lock != null:
        draw_circle(Vector2(28, 35), 13, Color("223b53"))
        draw_texture_rect(_lock, Rect2(18, 24, 20, 21), false)
    if not rank.is_empty():
        draw_circle(Vector2(105, 27), 14.5, Color("19334b"))
        draw_arc(Vector2(105, 27), 14.5, 0, TAU, 32, RANK_COLORS[rank], 2, true)
        _text(rank, Rect2(90, 11, 30, 30), 22, RANK_COLORS[rank], true)
    elif kind == "reward" and _claimed:
        _text("✓", Rect2(92, 9, 28, 28), 21, Color("e8f9d6"), true)
    if _level > 0:
        draw_style_box(_capsule(), Rect2(44, 84, 44, 17))
        _text("NIV. %d" % _level, Rect2(42, 83, 48, 17), 9, Color("e8fbff"))
    draw_style_box(_caption_box(), Rect2(2, 103, 128, 21))
    _text(_label, Rect2(5, 104, 122, 18), 10, Color("f4ffff"))

func _capsule() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("12547f")
    style.set_corner_radius_all(6)
    return style

func _caption_box() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.04, 0.2, 0.29, 0.5)
    style.set_corner_radius_all(5)
    return style

func _text(value: String, rect: Rect2, font_size: int, color: Color, display: bool = false) -> void:
    var font: Font = VisualTheme.display_font() if display else VisualTheme.bold_font()
    var shown := value
    while font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x and shown.length() > 1:
        shown = shown.substr(0, shown.length() - 2) + "…"
    var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var baseline: float = rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
    draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, baseline), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _has_point(point: Vector2) -> bool:
    return Rect2(8, 0, 116, 101).has_point(point)
