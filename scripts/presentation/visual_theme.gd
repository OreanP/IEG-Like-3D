class_name IEGVisualTheme
extends RefCounted
## Identité commune des interfaces, indépendante des règles de match.

const NAVY := Color("101e31")
const NAVY_LIGHT := Color("1b3047")
const INK := Color("f4f0df")
const PAPER := Color("f4f0df")
const MUTED := Color("a3b4c4")
const GOLD := Color("e5af65")
const AQUA := Color("4bd9c3")
const AZUR := Color("468ee6")
const CARMIN := Color("d9586c")
const REGULAR = preload("res://assets/ui/fonts/OpenSans-Regular.ttf")
const SEMIBOLD = preload("res://assets/ui/fonts/OpenSans-Semibold.ttf")
const DISPLAY = preload("res://assets/ui/fonts/OpenSans-CondensedBold.ttf")

static func font() -> Font:
    return REGULAR

static func bold_font() -> Font:
    return SEMIBOLD

static func display_font() -> Font:
    return DISPLAY

static func surface(color: Color = NAVY, border: Color = Color("2a4055"), radius: int = 7) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(radius)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 9
    box.content_margin_bottom = 9
    return box

static func make_theme() -> Theme:
    var result := Theme.new()
    result.default_font = REGULAR
    result.default_font_size = 14
    for kind: String in ["Label", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "TextEdit", "ItemList", "PopupMenu"]:
        result.set_color("font_color", kind, INK)
        result.set_color("font_disabled_color", kind, Color("65788a"))
        result.set_color("font_hover_color", kind, Color.WHITE)
        result.set_color("font_focus_color", kind, Color.WHITE)
    result.set_font("font", "Button", SEMIBOLD)
    result.set_font("font", "OptionButton", SEMIBOLD)
    result.set_stylebox("panel", "PanelContainer", surface(Color(0.04, 0.075, 0.12, 0.96)))
    for kind: String in ["Button", "OptionButton"]:
        result.set_stylebox("normal", kind, surface(Color("1b3047")))
        result.set_stylebox("hover", kind, surface(Color("263e55"), Color("5d7b92")))
        result.set_stylebox("pressed", kind, surface(Color("294c5d"), AQUA))
        result.set_stylebox("disabled", kind, surface(Color("132337"), Color("1f3244")))
        var focus := surface(Color(0, 0, 0, 0), GOLD)
        focus.set_border_width_all(2)
        result.set_stylebox("focus", kind, focus)
    for kind: String in ["LineEdit", "TextEdit"]:
        result.set_stylebox("normal", kind, surface(Color("0b1727"), Color("30465c"), 4))
        result.set_stylebox("read_only", kind, surface(Color("132337"), Color("23394f"), 4))
        result.set_stylebox("focus", kind, surface(Color(0, 0, 0, 0), GOLD, 4))
        result.set_color("caret_color", kind, AQUA)
        result.set_color("selection_color", kind, Color("32597b"))
    result.set_stylebox("panel", "ItemList", surface(Color("0c1828")))
    result.set_stylebox("selected", "ItemList", surface(Color("29475a"), AQUA, 4))
    result.set_stylebox("selected_focus", "ItemList", surface(Color("29475a"), GOLD, 4))
    result.set_stylebox("panel", "PopupMenu", surface(Color("132338")))
    result.set_stylebox("hover", "PopupMenu", surface(Color("29475a"), AQUA, 3))
    result.set_color("font_selected_color", "ItemList", Color.WHITE)
    result.set_color("guide_color", "ItemList", Color("294055"))
    result.set_constant("v_separation", "ItemList", 9)
    result.set_constant("h_separation", "ItemList", 8)
    result.set_constant("separation", "VBoxContainer", 8)
    result.set_constant("separation", "HBoxContainer", 10)
    result.set_stylebox("background", "ProgressBar", surface(Color("20364b"), Color("20364b"), 3))
    result.set_stylebox("fill", "ProgressBar", surface(AQUA, AQUA, 3))
    result.set_stylebox("panel", "AcceptDialog", surface(Color("132338")))
    return result
