class_name IEGMatchHud
extends CanvasLayer
## Interface du match : les boutons transmettent des intentions à la simulation.

signal pause_requested
signal resume_requested
signal rematch_requested
signal training_requested
signal editor_requested
signal duel_choice_requested(choice: String, technique_id: String)
signal second_half_requested(formations: Dictionary)
signal special_shot_requested(technique_id: String)
signal tactic_requested(tactic_id: String)
signal modifier_requested(content_id: String)
signal menu_opened

const INK := Color("edf4f8")
const MUTED := Color("adc3d2")
const GOLD := Color("ffda8c")
const AQUA := Color("7ae8dc")
var _root: Control
var _score: Label
var _clock: Label
var _phase_label: Label
var _player: Label
var _status: Label
var _help: Label
var _message: Label
var _energy: ProgressBar
var _charge: ProgressBar
var _modifier_labels: Dictionary = {}
var _modifier_bars: Dictionary = {}
var _keeper_bars: Array[ProgressBar] = []
var _keeper_labels: Array[Label] = []
var _team_modifier_counts: Array[Label] = []
var _overlay: ColorRect
var _column: VBoxContainer
var _mode: String = ""
var _message_life: float = 0.0
var _last_phase: int = -1
var _session
var _definitions: Array = []
var _formation_blue: OptionButton
var _formation_red: OptionButton
var _cinematic_title: Label
var _cinematic_scores: Label
var _cinematic_winner: Label
var _cinema_panel: Control
var _live_panels: Array[Control] = []
var _modal_notice: Label
var _armed_name: String = ""
var _duel_tech_buttons: Array[Button] = []

func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var brand: VBoxContainer = _panel(Vector2.ZERO, Rect2(20, 18, 246, 101))
    _live_panels.append(brand.get_parent())
    _text(brand, "IEG  /  MATCH", 20, GOLD)
    _phase_label = _text(brand, "11 contre 11 · 60 × 90 m", 14, MUTED)
    _text(brand, "Azur  /  Carmin", 14, INK)
    var scores: VBoxContainer = _panel(Vector2(0.5, 0), Rect2(-220, 18, 440, 108))
    _score = _text(scores, "AZUR   0 — 0   CARMIN", 27, INK)
    _score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _clock = _text(scores, "1re MI-TEMPS  ·  05:00", 19, GOLD)
    _clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var tools: VBoxContainer = _panel(Vector2(1, 0), Rect2(-250, 18, 230, 101))
    _live_panels.append(tools.get_parent())
    var row := HBoxContainer.new()
    tools.add_child(row)
    _button(row, "Pause", func(): pause_requested.emit(), 37)
    _button(row, "Atelier", func(): editor_requested.emit(), 37)
    _text(tools, "Start / Échap · V : actions", 13, MUTED)
    var keeper_panel: VBoxContainer = _panel(Vector2(0.5, 0), Rect2(-230, 134, 460, 88))
    _live_panels.append(keeper_panel.get_parent())
    var keeper_row := HBoxContainer.new()
    keeper_row.add_theme_constant_override("separation", 24)
    keeper_panel.add_child(keeper_row)
    for team: int in range(2):
        var keeper_column := VBoxContainer.new()
        keeper_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        keeper_row.add_child(keeper_column)
        _keeper_labels.append(_text(keeper_column, "Gardien " + ("Azur" if team == 0 else "Carmin"), 13, AQUA if team == 0 else Color("ff9d9a")))
        _keeper_bars.append(_bar(keeper_column, 100, AQUA if team == 0 else Color("ff9d9a")))
        _team_modifier_counts.append(_text(keeper_column, "Karma 0/3 · Resonance 0/3", 12, MUTED))
    var player_panel: VBoxContainer = _panel(Vector2(0, 1), Rect2(20, -290, 332, 270))
    _live_panels.append(player_panel.get_parent())
    _player = _text(player_panel, "Joueur", 21, INK)
    _status = _text(player_panel, "Endurance", 13, MUTED)
    _energy = _bar(player_panel, 100, GOLD)
    _charge = _bar(player_panel, 1, AQUA)
    for category: String in ["KARMA", "RESONANCE"]:
        var color: Color = AQUA if category == "KARMA" else Color("c3a2ff")
        var modifier_label: Label = _text(player_panel, "", 13, color)
        var modifier_bar: ProgressBar = _bar(player_panel, 100, color)
        _modifier_labels[category] = modifier_label
        _modifier_bars[category] = modifier_bar
        modifier_label.visible = false
        modifier_bar.visible = false
    var player_tools := HBoxContainer.new()
    player_panel.add_child(player_tools)
    _button(player_tools, "Techniques", func(): open_actions("TIR"), 32)
    _button(player_tools, "Tactique", func(): open_actions("TAC"), 32)
    var modifiers := HBoxContainer.new()
    player_panel.add_child(modifiers)
    _button(modifiers, "Karma", func(): open_actions("KARMA"), 30)
    _button(modifiers, "Resonance", func(): open_actions("RESONANCE"), 30)
    var help_panel: VBoxContainer = _panel(Vector2.ONE, Rect2(-485, -177, 465, 157))
    _live_panels.append(help_panel.get_parent())
    _help = _text(help_panel, "", 14, INK)
    _help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _message = _text(_root, "", 20, GOLD)
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.anchor_left = 0.5
    _message.anchor_right = 0.5
    _message.offset_left = -480
    _message.offset_right = 480
    _message.offset_top = 220
    _message.offset_bottom = 254
    _message.add_theme_color_override("font_shadow_color", Color("14232b"))
    _message.add_theme_constant_override("shadow_offset_x", 2)
    _message.add_theme_constant_override("shadow_offset_y", 2)
    _overlay = ColorRect.new()
    _overlay.color = Color(0.015, 0.035, 0.065, 0.90)
    _overlay.visible = false
    _root.add_child(_overlay)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    _overlay.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(680, 560)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    center.add_child(scroll)
    _column = VBoxContainer.new()
    _column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _column.add_theme_constant_override("separation", 14)
    scroll.add_child(_column)
    var cinema: VBoxContainer = _panel(Vector2(0.5, 1), Rect2(-350, -185, 700, 165))
    _cinema_panel = cinema.get_parent()
    _cinema_panel.visible = false
    _cinematic_title = _text(cinema, "", 19, AQUA)
    _cinematic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cinematic_scores = _text(cinema, "", 42, INK)
    _cinematic_scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cinematic_winner = _text(cinema, "", 23, GOLD)
    _cinematic_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_catalogue(definitions: Array) -> void:
    _definitions = definitions

func show_message(value: String, seconds: float = 3.2) -> void:
    _message.text = value
    _message_life = seconds
    _root.move_child(_message, _root.get_child_count() - 1)
    if is_instance_valid(_modal_notice):
        _modal_notice.text = value

func set_armed_technique(definition: Dictionary) -> void:
    _armed_name = str(definition.get("name", definition.get("display_name", "")))
    show_message("Technique préparée : %s · chargez un tir." % _armed_name)

func clear_armed_technique() -> void:
    _armed_name = ""

func refresh(delta: float, session, controls: IEGLocalPlayerInput, paused: bool) -> void:
    _session = session
    var player: IEGPlayerState = session.controlled()
    _score.text = "%s   %d — %d   %s" % [session.team_names[0].to_upper(), session.team_goals[0], session.team_goals[1], session.team_names[1].to_upper()]
    var remaining: int = maxi(0, ceili(session.half_duration - session.elapsed_half))
    var frozen: bool = session.phase != session.Phase.LIVE
    _clock.text = "%s · %02d:%02d%s" % ["1re MI-TEMPS" if session.period == 1 else "2e MI-TEMPS", remaining / 60, remaining % 60, "  ⏸" if frozen or paused else ""]
    _phase_label.text = "11 contre 11 · 60 × 90 m"
    _player.text = "%02d / %s" % [player.profile.shirt_number, player.profile.display_name]
    _status.text = "Porteur · Endurance" if session.ball.owner_id == player.get_id() else "Sans ballon · Endurance"
    if player.is_goalkeeper:
        _status.text = "Gardien · Passe / lob pour relancer"
    if not _armed_name.is_empty():
        _status.text = "Prêt : " + _armed_name
    _energy.value = player.energy
    _charge.visible = controls.charge > 0
    _charge.value = controls.charge
    _refresh_modifiers(session, player)
    for state: IEGPlayerState in session.players:
        if state.is_goalkeeper:
            var value: float = float(state.get("keeper_stamina"))
            _keeper_bars[state.team_id].value = value
            _keeper_labels[state.team_id].text = "Gardien %s · %d / 100" % [session.team_names[state.team_id], roundi(value)]
    for team: int in range(2):
        _team_modifier_counts[team].text = "Karma %d/3 · Resonance %d/3" % [session.count_active_modifiers(team, "KARMA"), session.count_active_modifiers(team, "RESONANCE")]
    _help.text = ("Stick G : déplacement · RT : sprint\nA : passe · Y : lob · X : tir chargé · B : tacle\nRB : cible · LB : joueur · Stick D : caméra\nL3 / V : techniques et tactiques · Start : pause"
        if controls.uses_gamepad else "ZQSD / WASD : mouvement · Maj : sprint\nEspace : passe · G : lob · E : tacle · Q : cible\nF / clic G : tir chargé · Tab : joueur\nClic D : caméra · V : actions · Échap : pause")
    _message_life = maxf(0, _message_life - delta)
    _message.visible = _message_life > 0 and session.phase == session.Phase.LIVE
    if session.phase != _last_phase:
        _last_phase = session.phase
        match session.phase:
            session.Phase.DUEL_CHOICE: _show_duel()
            session.Phase.CINEMATIC: _show_cinematic()
            session.Phase.HALFTIME: _show_halftime()
            session.Phase.FINISHED: _show_finished()
            session.Phase.LIVE:
                if _mode in ["duel", "cinematic", "halftime", "finished"]:
                    close_overlay()
    if session.phase == session.Phase.CINEMATIC:
        _update_cinematic()

func set_paused(value: bool) -> void:
    if value:
        _show_pause()
    elif _mode == "pause" or _mode.begins_with("actions"):
        close_overlay()

func close_overlay() -> void:
    _overlay.visible = false
    _cinema_panel.visible = false
    for panel: Control in _live_panels:
        panel.visible = true
    _mode = ""
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()

func _reset_overlay(mode: String, title: String, description: String = "") -> void:
    _mode = mode
    _modal_notice = null
    _cinema_panel.visible = false
    for panel: Control in _live_panels:
        panel.visible = true
    _overlay.color = Color(0.015, 0.035, 0.065, 0.90)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    for child: Node in _column.get_children():
        child.free()
    _duel_tech_buttons.clear()
    _overlay.visible = true
    var heading: Label = _text(_column, title, 36, GOLD)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if not description.is_empty():
        var subtitle: Label = _text(_column, description, 17, MUTED)
        subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _show_pause() -> void:
    _reset_overlay("pause", "PAUSE", "Match 11 contre 11 · Le chrono est arrêté.")
    var first: Button = _button(_column, "Reprendre le match", func(): resume_requested.emit())
    _button(_column, "Techniques de tir", func(): open_actions("TIR"))
    _button(_column, "Tactiques collectives", func(): open_actions("TAC"))
    _button(_column, "Karma / Resonance", func(): open_actions("KARMA"))
    _button(_column, "Ouvrir l'atelier des techniques", func(): editor_requested.emit())
    _button(_column, "Retour au terrain d'entraînement", func(): training_requested.emit())
    first.grab_focus()

func _show_duel() -> void:
    var duel: Dictionary = _session.duel
    var attack: bool = str(duel.get("local_role", "attack")) == "attack"
    var keeper: bool = str(duel.get("kind", "field")) == "keeper"
    var block: bool = str(duel.get("kind", "field")) == "block"
    var category: String = ("TIR" if attack else "GAR") if keeper else (("TIR" if attack else "DEF") if block else ("ATT" if attack else "DEF"))
    var title: String = "TIREUR / GARDIEN" if keeper else ("TIR / BLOCAGE" if block else "FACE-À-FACE")
    var intent: String = ("Choisissez le côté de votre tir." if attack else "Anticipez le côté du tir.") if keeper or block else ("Choisissez votre dribble." if attack else "Choisissez votre intervention.")
    _reset_overlay("duel", title, intent + "\nTemps arrêté · aucun choix automatique pour le joueur.")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    _column.add_child(row)
    var first: Button = _button(row, "← Gauche", func(): duel_choice_requested.emit("left", ""), 58)
    _button(row, "Droite →", func(): duel_choice_requested.emit("right", ""), 58)
    _text(_column, "TECHNIQUE SPÉCIALE · " + category, 16, AQUA)
    for definition: Dictionary in _for_category(category):
        var id: String = str(definition.get("id", ""))
        var special: Button = _button(_column, "%s  ·  %s" % [_definition_name(definition), _cost_text(definition)], func(): duel_choice_requested.emit("special", id))
        _duel_tech_buttons.append(special)
        _description(definition)
    _text(_column, "Croix directionnelle / flèches : naviguer · A / Entrée : valider", 14, MUTED)
    _modal_notice = _text(_column, "", 15, GOLD)
    _modal_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    first.grab_focus()

func _show_cinematic() -> void:
    _mode = "cinematic"
    _overlay.visible = false
    _cinema_panel.visible = true
    _modal_notice = null
    for panel: Control in _live_panels:
        panel.visible = false
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()
    _update_cinematic()

func _update_cinematic() -> void:
    var duel: Dictionary = _session.duel
    var revealed: bool = _session.cinematic_elapsed >= float(duel.get("reveal_time", 1.4))
    var attack_tech: String = _name_for_id(str(duel.get("attack_technique", "")))
    var defend_tech: String = _name_for_id(str(duel.get("defend_technique", "")))
    _cinematic_title.text = "%s  ×  %s" % [attack_tech if not attack_tech.is_empty() else "Action normale", defend_tech if not defend_tech.is_empty() else "Intervention normale"]
    _cinematic_scores.text = "%d  —  %d" % [duel.get("attack_score", 0), duel.get("defend_score", 0)] if revealed else "◆       ◆"
    if revealed:
        var winner: IEGPlayerState = _session.get_player(int(duel.get("winner_id", -1)))
        _cinematic_winner.text = "%s remporte le duel" % winner.profile.display_name if winner != null else "Résultat confirmé"
    else:
        _cinematic_winner.text = ""

func _show_halftime() -> void:
    _reset_overlay("halftime", "MI-TEMPS", "Les équipes changent de camp. Ajustez leur disposition avant de reprendre.")
    _text(_column, "Azur", 21, AQUA)
    _formation_blue = _formation_selector()
    _text(_column, "Carmin", 21, Color("ff9d9a"))
    _formation_red = _formation_selector()
    _text(_column, "Équilibrée : 4-4-2 · Large : ailes écartées · Pressing : bloc plus haut", 16, MUTED)
    var resume: Button = _button(_column, "Commencer la deuxième mi-temps", _resume_second_half)
    _button(_column, "Atelier des techniques", func(): editor_requested.emit())
    resume.grab_focus()

func _formation_selector() -> OptionButton:
    var select := OptionButton.new()
    select.custom_minimum_size = Vector2(0, 48)
    select.add_theme_font_size_override("font_size", 20)
    _column.add_child(select)
    select.add_item("Équilibrée  /  4-4-2")
    select.add_item("Large  /  ailes ouvertes")
    select.add_item("Pressing  /  bloc haut")
    return select

func _resume_second_half() -> void:
    var ids: Array[String] = ["balanced", "wide", "press"]
    second_half_requested.emit({0: ids[_formation_blue.selected], 1: ids[_formation_red.selected]})

func _show_finished() -> void:
    var outcome: String = "Match nul"
    if _session.winner_team >= 0:
        outcome = "Victoire de " + _session.team_names[_session.winner_team]
    _reset_overlay("finished", "FIN DU MATCH", outcome)
    var result: Label = _text(_column, "%s  %d — %d  %s" % [_session.team_names[0], _session.team_goals[0], _session.team_goals[1], _session.team_names[1]], 42, INK)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var first: Button = _button(_column, "Rejouer un match", func(): rematch_requested.emit())
    _button(_column, "Consulter et éditer les techniques", func(): editor_requested.emit())
    _button(_column, "Retour à l'entraînement", func(): training_requested.emit())
    first.grab_focus()

func open_actions(category: String = "TIR") -> void:
    if _session == null or _session.phase != _session.Phase.LIVE:
        return
    menu_opened.emit()
    var names: Dictionary = {"TIR": "TECHNIQUES DE TIR", "TAC": "TACTIQUES", "KARMA": "Karma", "RESONANCE": "Resonance"}
    var description: String = "Le chrono est arrêté pendant ce choix."
    if category in ["KARMA", "RESONANCE"]:
        description += "\nKarma et Resonance peuvent se cumuler sur un joueur.\nTrois Karma et trois Resonance maximum par équipe."
        description += "\nActifs dans votre équipe : Karma %d/3 · Resonance %d/3" % [_session.count_active_modifiers(0, "KARMA"), _session.count_active_modifiers(0, "RESONANCE")]
    _reset_overlay("actions_" + category, str(names.get(category, category)), description)
    var first: Button = null
    for definition: Dictionary in _for_category(category):
        var id: String = str(definition.get("id", ""))
        var button: Button = _button(_column, "%s  ·  %s" % [_definition_name(definition), _cost_text(definition)], func(): _activate_content(category, id))
        if first == null:
            first = button
        _description(definition)
    if first == null:
        _text(_column, "Aucune entrée disponible dans cette catégorie.", 18, MUTED)
    if category == "KARMA":
        _button(_column, "Voir les Resonance", func(): open_actions("RESONANCE"))
    elif category == "RESONANCE":
        _button(_column, "Voir les Karma", func(): open_actions("KARMA"))
    var back: Button = _button(_column, "Reprendre le match", func(): resume_requested.emit())
    (first if first != null else back).grab_focus()

func _activate_content(category: String, id: String) -> void:
    match category:
        "TIR": special_shot_requested.emit(id)
        "TAC": tactic_requested.emit(id)
        _: modifier_requested.emit(id)
    resume_requested.emit()

func _for_category(category: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for definition: Dictionary in _definitions:
        if str(definition.get("category", "")) == category:
            result.append(definition)
    return result

func _refresh_modifiers(session, player: IEGPlayerState) -> void:
    for category: String in _modifier_labels:
        _modifier_labels[category].visible = false
        _modifier_bars[category].visible = false
    for modifier: Dictionary in session.get_active_modifiers(player.get_id()):
        var category: String = str(modifier.get("category", ""))
        if not _modifier_labels.has(category):
            continue
        var label: Label = _modifier_labels[category]
        var bar: ProgressBar = _modifier_bars[category]
        var name: String = "Karma" if category == "KARMA" else "Resonance"
        var id: String = str(modifier.get("id", ""))
        var remaining: int = maxi(0, ceili(float(modifier.get("time", 0))))
        var energy: float = maxf(0, float(modifier.get("energy", 0)))
        label.text = "%s · %02d:%02d · %.0f réserve" % [name, remaining / 60, remaining % 60, energy]
        label.tooltip_text = _name_for_id(id)
        bar.max_value = _modifier_max_energy(id)
        bar.value = energy
        label.visible = true
        bar.visible = true

func _modifier_max_energy(id: String) -> float:
    for definition: Dictionary in _definitions:
        if str(definition.get("id", "")) == id:
            var properties: Dictionary = definition.get("properties", {})
            return maxf(1.0, float(properties.get("energy_max", 100.0)))
    return 100.0

func _definition_name(definition: Dictionary) -> String:
    return str(definition.get("name", definition.get("display_name", definition.get("id", "Technique"))))

func _name_for_id(id: String) -> String:
    for definition: Dictionary in _definitions:
        if str(definition.get("id", "")) == id:
            return _definition_name(definition)
    return ""

func _cost_text(definition: Dictionary) -> String:
    var cost: float = float(definition.get("cost", definition.get("energy_cost", 0)))
    return "%d énergie" % roundi(cost) if cost > 0 else "activation"

func _description(definition: Dictionary) -> void:
    var label: Label = _text(_column, str(definition.get("description", "")), 15, MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _panel(anchor: Vector2, rectangle: Rect2) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.045, 0.08, 0.94)))
    _root.add_child(panel)
    panel.anchor_left = anchor.x
    panel.anchor_right = anchor.x
    panel.anchor_top = anchor.y
    panel.anchor_bottom = anchor.y
    panel.offset_left = rectangle.position.x
    panel.offset_right = rectangle.end.x
    panel.offset_top = rectangle.position.y
    panel.offset_bottom = rectangle.end.y
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    panel.add_child(column)
    return column

func _style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color("395667")
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 11
    style.content_margin_bottom = 11
    return style

func _text(parent: Node, value: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _bar(parent: Node, maximum: float, color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.max_value = maximum
    bar.value = maximum
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 9)
    var background := StyleBoxFlat.new()
    background.bg_color = Color("233a48")
    background.set_corner_radius_all(4)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _button(parent: Node, value: String, callback: Callable, height: float = 46) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, height)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 18 if height > 37 else 13)
    button.add_theme_stylebox_override("normal", _style(Color("153448")))
    button.add_theme_stylebox_override("hover", _style(Color("245871")))
    button.add_theme_stylebox_override("focus", _style(Color("32657c")))
    parent.add_child(button)
    button.pressed.connect(callback)
    return button
