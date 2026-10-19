extends Control
## Décor et connexions du parcours. La vue lit les accès, sans les modifier.

const LOCKED_COLOR := Color("818e98")
const OPEN_COLOR := Color("a5ffff")

var nodes: Array = []
var edges: Array = []
var available: Dictionary = {}
var cleared: Dictionary = {}
var selected_id: String = ""
var card_size := Vector2(132, 126)
var draw_background: bool = true

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func edge_is_locked(from: String, to: String) -> bool:
    # Une victoire en amont ne colore jamais le chemin d'un adversaire verrouillé.
    return not bool(available.get(from, false)) or not bool(available.get(to, false))

func edge_color(from: String, to: String) -> Color:
    return LOCKED_COLOR if edge_is_locked(from, to) else OPEN_COLOR

func _draw() -> void:
    if draw_background:
        _draw_hex_field()
    var positions: Dictionary = {}
    for node: Dictionary in nodes:
        var raw: Array = node.get("position", [40, 40])
        positions[String(node.get("id", ""))] = Vector2(float(raw[0]), float(raw[1])) + card_size * 0.5
    for edge: Variant in edges:
        var from_id: String = ""
        var to_id: String = ""
        if edge is Array and edge.size() >= 2:
            from_id = String(edge[0])
            to_id = String(edge[1])
        elif edge is Dictionary:
            from_id = String(edge.get("from", ""))
            to_id = String(edge.get("to", ""))
        if not positions.has(from_id) or not positions.has(to_id):
            continue
        var from: Vector2 = positions[from_id]
        var to: Vector2 = positions[to_id]
        var locked := edge_is_locked(from_id, to_id)
        var color := edge_color(from_id, to_id)
        draw_line(from + Vector2(0, 3), to + Vector2(0, 3), Color(0.03, 0.19, 0.27, 0.32), 12.0, true)
        draw_line(from, to, Color("a6b4ba") if locked else Color("e1ffff"), 8.0, true)
        draw_line(from, to, color.darkened(0.12) if locked else Color("2dccdf"), 4.0, true)
        draw_line(from - Vector2(0, 1.5), to - Vector2(0, 1.5), Color(0.9, 0.95, 0.97, 0.38 if locked else 0.85), 1.2, true)

func _draw_hex_field() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("228baf"))
    # Mosaïque originale, peu contrastée pour laisser les équipes au premier plan.
    var row: int = 0
    var y: float = -40.0
    while y < size.y + 40.0:
        var x: float = -44.0
        var column: int = 0
        while x < size.x + 60.0:
            var cy: float = y + (20.0 if column % 2 == 0 else 0.0)
            var tint: float = (sin(float(column * 23 + row * 7)) + 1.0) * 0.5
            var vertical: float = clampf(cy / maxf(size.y, 1.0), 0.0, 1.0)
            var fill := Color("42bbb9").lerp(Color("238dab"), vertical * 0.8)
            fill = fill.lerp(Color("66d4c8"), tint * 0.12)
            var polygon := PackedVector2Array([
                Vector2(x + 14, cy), Vector2(x + 44, cy), Vector2(x + 58, cy + 20),
                Vector2(x + 44, cy + 40), Vector2(x + 14, cy + 40), Vector2(x, cy + 20)
            ])
            draw_colored_polygon(polygon, fill)
            var outline := polygon.duplicate()
            outline.append(polygon[0])
            draw_polyline(outline, Color(0.7, 1.0, 0.95, 0.25), 2.0, true)
            draw_line(Vector2(x + 14, cy + 3), Vector2(x + 44, cy + 3), Color(0.87, 1.0, 0.95, 0.13), 1.0, true)
            x += 44.0
            column += 1
        y += 40.0
        row += 1
