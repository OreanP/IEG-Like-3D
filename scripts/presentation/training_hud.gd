class_name IEGTrainingHud
extends CanvasLayer
## Interface lisible à 1280x800 et extensible via l'échelle canvas_items.

signal resume_requested
signal reset_requested
signal quit_requested

var _root: Control
var _player_name: Label
var _status: Label
var _score: Label
var _controls: Label
var _device: Label
var _message: Label
var _energy: ProgressBar
var _charge: ProgressBar
var _pause: ColorRect
var _resume: Button
var _message_life: float = 0.0

func _ready() -> void:
    layer = 10
    _root = Control.new()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var brand: VBoxContainer = _panel(Vector2.ZERO, Rect2(24, 22, 354, 114))
    _text(brand, "IEG LIKE  /  GDSCRIPT", 16, Color("f5d691"))
    _text(brand, "Terrain d'entraînement", 23, Color("edf4f8"))
    _device = _text(brand, "Clavier / souris", 13, Color("adbfce"))
    _device.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var score_panel: VBoxContainer = _panel(Vector2(0.5, 0.0), Rect2(-105, 22, 210, 101))
    _text(score_panel, "FINITION LIBRE", 14, Color("adbfce")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _score = _text(score_panel, "00  BUT", 30, Color.WHITE)
    _score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var player_panel: VBoxContainer = _panel(Vector2(0.0, 1.0), Rect2(24, -195, 340, 171))
    _text(player_panel, "JOUEUR CONTRÔLÉ", 13, Color("adbfce"))
    _player_name = _text(player_panel, "07 / Joueur 07", 23, Color.WHITE)
    _status = _text(player_panel, "En possession", 14, Color("8aeee9"))
    _energy = _bar(player_panel, 100.0, Color("f1c36d"))
    _charge = _bar(player_panel, 1.0, Color("75deda"))
    var help: VBoxContainer = _panel(Vector2.ONE, Rect2(-486, -195, 462, 171))
    _text(help, "COMMANDES", 13, Color("adbfce"))
    _controls = _text(help, "", 15, Color("edf4f8"))
    _controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _message = Label.new()
    _message.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.add_theme_font_size_override("font_size", 22)
    _message.add_theme_color_override("font_color", Color("ffdc8b"))
    _message.add_theme_color_override("font_shadow_color", Color("14232b"))
    _message.add_theme_constant_override("shadow_offset_x", 2)
    _message.add_theme_constant_override("shadow_offset_y", 2)
    _root.add_child(_message)
    _message.anchor_left = 0.5
    _message.anchor_right = 0.5
    _message.offset_left = -490
    _message.offset_right = 490
    _message.offset_top = 151
    _message.offset_bottom = 191
    _build_pause()
    show_message("Vise un partenaire, puis fais une passe.")

func _build_pause() -> void:
    _pause = ColorRect.new()
    _pause.color = Color(0.035, 0.065, 0.105, 0.94)
    _pause.visible = false
    _pause.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_pause)
    _pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center: CenterContainer = CenterContainer.new()
    _pause.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var column: VBoxContainer = VBoxContainer.new()
    column.custom_minimum_size = Vector2(540, 0)
    column.add_theme_constant_override("separation", 18)
    center.add_child(column)
    _text(column, "PAUSE", 42, Color("f5d691")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var description: Label = _text(column,
        "Entraînement libre à trois joueurs\nPas encore d'adversaires ni de techniques spéciales.",
        19, Color("b6c9d6"))
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _resume = _button(column, "Reprendre", func(): resume_requested.emit())
    var reset_button: Button = _button(column, "Replacer les joueurs et le ballon", func(): reset_requested.emit())
    var quit_button: Button = _button(column, "Quitter l'entraînement", func(): quit_requested.emit())
    _resume.focus_neighbor_top = quit_button.get_path()
    _resume.focus_neighbor_bottom = reset_button.get_path()
    reset_button.focus_neighbor_top = _resume.get_path()
    reset_button.focus_neighbor_bottom = quit_button.get_path()
    quit_button.focus_neighbor_top = reset_button.get_path()
    quit_button.focus_neighbor_bottom = _resume.get_path()
    _text(column, "Start / Options / Échap : reprendre", 16,
        Color("adbfce")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_paused(value: bool) -> void:
    _pause.visible = value
    if value:
        _resume.grab_focus()
    else:
        _resume.release_focus()

func show_message(text: String) -> void:
    _message.text = text
    _message_life = 3.2

func refresh(delta: float, session: IEGTrainingSession, controls: IEGLocalPlayerInput) -> void:
    var player: IEGPlayerState = session.controlled()
    _player_name.text = "%02d  /  %s" % [player.profile.shirt_number, player.profile.display_name]
    if controls.charge > 0.0:
        _status.text = "Puissance du tir : %d %%" % roundi(controls.charge * 100.0)
    else:
        _status.text = "En possession  /  Endurance" if session.ball.owner_id == player.get_id() else "Sans ballon  /  Endurance"
    if player.sprint_exhausted:
        _status.text += " — récupération"
    _energy.value = player.energy
    _charge.value = controls.charge
    _charge.visible = controls.charge > 0.0
    _score.text = "%02d  BUT%s" % [session.goals, "S" if session.goals > 1 else ""]
    var pad_name: String = Input.get_joy_name(controls.last_gamepad) if controls.last_gamepad >= 0 else ""
    if controls.uses_gamepad:
        _device.text = "Manette : " + pad_name
        var ps: bool = (pad_name.to_lower().contains("sony")
            or pad_name.to_lower().contains("dual") or pad_name.to_lower().contains("playstation"))
        if ps:
            _controls.text = "Croix : passe   Carré maintenu : tir\nL1 : joueur   R2 : sprint   R3 : recentrer\nStick droit : caméra   Haut/Bas : zoom\nOptions : pause   Create/Share : replacer"
        else:
            _controls.text = "A : passe   X maintenu : tir\nLB : joueur   RT : sprint   R3 : recentrer\nStick droit : caméra   Haut/Bas : zoom\nStart : pause   View/Back : replacer"
    else:
        _device.text = "Clavier / souris · manette utilisable à tout moment"
        _controls.text = "ZQSD / WASD : bouger   Maj : sprint\nEspace : passe   Clic gauche / F : tir chargé\nTab : joueur   Clic droit glissé : caméra\nMolette : zoom   C : recentrer   R : replacer"
    _message_life = maxf(0.0, _message_life - delta)
    _message.visible = _message_life > 0.0

func _panel(anchor: Vector2, rectangle: Rect2) -> VBoxContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.028, 0.06, 0.10, 0.93)
    style.border_color = Color(0.24, 0.36, 0.43, 0.65)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_left = 17.0
    style.content_margin_right = 17.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    panel.add_theme_stylebox_override("panel", style)
    _root.add_child(panel)
    panel.anchor_left = anchor.x
    panel.anchor_right = anchor.x
    panel.anchor_top = anchor.y
    panel.anchor_bottom = anchor.y
    panel.offset_left = rectangle.position.x
    panel.offset_right = rectangle.end.x
    panel.offset_top = rectangle.position.y
    panel.offset_bottom = rectangle.end.y
    var column: VBoxContainer = VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 6)
    panel.add_child(column)
    return column

func _text(parent: Node, text: String, size: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _bar(parent: Node, maximum: float, color: Color) -> ProgressBar:
    var bar: ProgressBar = ProgressBar.new()
    bar.max_value = maximum
    bar.value = maximum
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 9)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background: StyleBoxFlat = StyleBoxFlat.new()
    background.bg_color = Color("253945")
    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = color
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 48)
    button.add_theme_font_size_override("font_size", 20)
    parent.add_child(button)
    button.pressed.connect(callback)
    return button
