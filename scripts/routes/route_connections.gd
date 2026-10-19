extends Control
## Décor et connexions du tableau. Aucune règle de progression dans cette vue.

var nodes: Array = []
var edges: Array = []
var available: Dictionary = {}
var cleared: Dictionary = {}
var selected_id: String = ""
var card_size := Vector2(190, 112)

func _draw() -> void:
    var grid := Color("203449")
    grid.a = 0.48
    for x: int in range(28, int(size.x), 44):
        for y: int in range(28, int(size.y), 44):
            draw_circle(Vector2(x, y), 1.0, grid)
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
        var middle: float = (from.x + to.x) * 0.5
        var line := PackedVector2Array([from, Vector2(middle, from.y), Vector2(middle, to.y), to])
        var color := Color("2e445a")
        if bool(cleared.get(from_id, false)):
            color = Color("4bd9c3") if bool(available.get(to_id, false)) else Color("56867f")
        draw_polyline(line, Color(0.02, 0.05, 0.08, 0.7), 9.0, true)
        draw_polyline(line, color, 3.0, true)
        var arrow_position := Vector2(middle, to.y)
        var direction: float = 1.0 if to.x >= from.x else -1.0
        draw_colored_polygon(PackedVector2Array([arrow_position + Vector2(direction * 6, 0), arrow_position + Vector2(-direction * 3, -4), arrow_position + Vector2(-direction * 3, 4)]), color)
