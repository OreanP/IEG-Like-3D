class_name IEGMatchHud
extends CanvasLayer
## Interface du match : les boutons transmettent des intentions à la simulation.

signal pause_requested
signal resume_requested
signal rematch_requested
signal training_requested
signal routes_requested
signal result_save_requested
signal editor_requested
signal duel_choice_requested(choice: String, technique_id: String)
signal second_half_requested(formations: Dictionary)
signal special_shot_requested(technique_id: String)
signal tactic_requested(tactic_id: String)
signal modifier_requested(content_id: String, player_id: int)
signal modifier_release_requested(category: String, player_id: int)
signal menu_opened

const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")
const PlayerPortrait = preload("res://scripts/presentation/player_portrait.gd")
const INK := Color("f4f0df")
const MUTED := Color("a6b9c8")
const GOLD := Color("e5af65")
const AQUA := Color("4bd9c3")
const CORAL := Color("e58d86")
const NAVY := Color("101e31")
var _root: Control
var _score: Label
var _score_teams: Array[Label] = []
var _opponent_crest: TextureRect
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
var _karma_pg_label: Label
var _karma_pg_bar: ProgressBar
var _stat_label: Label
var _inherited_label: Label
var _action_player_id: int = -1
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
var _duel_portraits: Array[Control] = []
var _player_panel: PanelContainer
var _player_column: VBoxContainer
var _menu_panel: PanelContainer
var _menu_scroll: ScrollContainer
var _help_panel: Control
var _help_button: Button
var _help_open: bool = false
var _control_hint: Label
var _tools_panel: Control
var _score_panel: Control
var _keeper_panel: Control
var _last_player_height: float = 0.0
var _radar: Control
var routes_available: bool = false
var is_route_match: bool = false
var _route_result: Dictionary = {}

func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    _root.theme = VisualTheme.make_theme()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # Une seule régie TV ; le terrain reste le point d'attention.
    var scores: VBoxContainer = _panel(Vector2.ZERO, Rect2(24, 22, 414, 86))
    _score_panel = scores.get_parent()
    _live_panels.append(_score_panel)
    var scoreboard_header := HBoxContainer.new()
    scores.add_child(scoreboard_header)
    _phase_label = _text(scoreboard_header, "MATCH AMICAL · 11 V 11", 11, MUTED)
    _phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _clock = _text(scoreboard_header, "1re · 05:00", 14, GOLD)
    _clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    var score_line := HBoxContainer.new()
    score_line.add_theme_constant_override("separation", 10)
    scores.add_child(score_line)
    _crest(score_line, "res://assets/ui/azur_crest.svg", 29)
    var home_name: Label = _text(score_line, "AZUR", 14, INK)
    home_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    home_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    home_name.clip_text = true
    _score = _text(score_line, "0 — 0", 26, INK)
    _score.add_theme_font_override("font", VisualTheme.display_font())
    _score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var away_name: Label = _text(score_line, "CARMIN", 14, INK)
    away_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    away_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    away_name.clip_text = true
    away_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _score_teams = [home_name, away_name]
    _opponent_crest = _crest(score_line, "res://assets/ui/carmin_crest.svg", 29)

    var keepers: VBoxContainer = _panel(Vector2.ZERO, Rect2(24, 112, 414, 64))
    _keeper_panel = keepers.get_parent()
    _live_panels.append(_keeper_panel)
    var keeper_row := HBoxContainer.new()
    keeper_row.add_theme_constant_override("separation", 22)
    keepers.add_child(keeper_row)
    for team: int in range(2):
        var keeper_column := VBoxContainer.new()
        keeper_column.add_theme_constant_override("separation", 4)
        keeper_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        keeper_row.add_child(keeper_column)
        var color: Color = AQUA if team == 0 else CORAL
        _keeper_labels.append(_text(keeper_column, "GARDIEN " + ("AZUR" if team == 0 else "CARMIN"), 11, color))
        var keeper_bar: ProgressBar = _bar(keeper_column, 100, color)
        keeper_bar.custom_minimum_size.y = 3
        _keeper_bars.append(keeper_bar)
        _team_modifier_counts.append(_text(keeper_column, "Karma 0/3 · Resonance 0/3", 11, MUTED))

    var tools: VBoxContainer = _panel(Vector2(1, 0), Rect2(-216, 22, 192, 44))
    _tools_panel = tools.get_parent()
    _live_panels.append(_tools_panel)
    var tools_row := HBoxContainer.new()
    tools_row.add_theme_constant_override("separation", 8)
    tools.add_child(tools_row)
    _button(tools_row, "Pause", func(): pause_requested.emit(), 30)
    _button(tools_row, "Atelier", func(): editor_requested.emit(), 30)

    _player_column = _panel(Vector2(0, 1), Rect2(24, -210, 338, 188))
    _player_panel = _player_column.get_parent()
    _live_panels.append(_player_panel)
    var player_eyebrow := HBoxContainer.new()
    _player_column.add_child(player_eyebrow)
    var selected_label: Label = _text(player_eyebrow, "JOUEUR SÉLECTIONNÉ", 11, AQUA)
    selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _text(player_eyebrow, "AZUR", 11, MUTED)
    _player = _text(_player_column, "Joueur", 25, INK)
    _player.add_theme_font_override("font", VisualTheme.display_font())
    _status = _text(_player_column, "Porteur · Endurance", 12, MUTED)
    _energy = _bar(_player_column, 100, GOLD)
    _charge = _bar(_player_column, 1, AQUA)
    _charge.visible = false
    _karma_pg_label = _text(_player_column, "", 11, GOLD)
    _karma_pg_bar = _bar(_player_column, 300, GOLD)
    _karma_pg_label.visible = false
    _karma_pg_bar.visible = false
    for category: String in ["KARMA", "RESONANCE"]:
        var color: Color = AQUA if category == "KARMA" else Color("c2ade9")
        var modifier_label: Label = _text(_player_column, "", 11, color)
        var modifier_bar: ProgressBar = _bar(_player_column, 100, color)
        _modifier_labels[category] = modifier_label
        _modifier_bars[category] = modifier_bar
        modifier_label.visible = false
        modifier_bar.visible = false
    _stat_label = _text(_player_column, "", 11, GOLD)
    _stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _inherited_label = _text(_player_column, "", 11, AQUA)
    _inherited_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var player_tools := HBoxContainer.new()
    player_tools.add_theme_constant_override("separation", 5)
    _player_column.add_child(player_tools)
    _button(player_tools, "Techniques", func(): open_actions("TIR"), 30)
    _button(player_tools, "Tactique", func(): open_actions("TAC"), 30)
    _button(player_tools, "Karma", func(): open_actions("KARMA"), 30)
    _button(player_tools, "Resonance", func(): open_actions("RESONANCE"), 30)

    # L'aide détaillée ne recouvre le terrain que sur demande.
    var help: VBoxContainer = _panel(Vector2.ONE, Rect2(-424, -368, 400, 142))
    _help_panel = help.get_parent()
    _live_panels.append(_help_panel)
    _text(help, "COMMANDES", 12, GOLD)
    _help = _text(help, "", 13, INK)
    _help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _help_panel.visible = false
    _help_button = _button(_root, "?  Commandes", _toggle_help, 32)
    _help_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    _help_button.offset_left = -156
    _help_button.offset_right = -24
    _help_button.offset_top = -208
    _help_button.offset_bottom = -176
    _live_panels.append(_help_button)
    _control_hint = _text(_root, "V · Actions    Échap · Pause", 11, INK)
    _control_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    _control_hint.offset_left = -310
    _control_hint.offset_right = -170
    _control_hint.offset_top = -199
    _control_hint.offset_bottom = -178
    _control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _control_hint.add_theme_color_override("font_shadow_color", NAVY)
    _control_hint.add_theme_constant_override("shadow_offset_y", 1)
    _live_panels.append(_control_hint)
    if ResourceLoader.exists("res://scripts/presentation/tactical_radar.gd"):
        var radar_script: Script = load("res://scripts/presentation/tactical_radar.gd")
        _radar = radar_script.new()
        _root.add_child(_radar)
        _radar.anchor_left = 1
        _radar.anchor_right = 1
        _radar.anchor_top = 1
        _radar.anchor_bottom = 1
        _radar.offset_left = -218
        _radar.offset_right = -24
        _radar.offset_top = -166
        _radar.offset_bottom = -24
        _live_panels.append(_radar)

    _message = _text(_root, "", 18, INK)
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.anchor_left = 0.5
    _message.anchor_right = 0.5
    _message.offset_left = -420
    _message.offset_right = 420
    _message.offset_top = 190
    _message.offset_bottom = 228
    _message.add_theme_color_override("font_shadow_color", NAVY)
    _message.add_theme_constant_override("shadow_offset_x", 1)
    _message.add_theme_constant_override("shadow_offset_y", 2)

    _overlay = ColorRect.new()
    _overlay.color = Color(0.025, 0.055, 0.09, 0.70)
    _overlay.visible = false
    _root.add_child(_overlay)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _menu_panel = PanelContainer.new()
    _menu_panel.add_theme_stylebox_override("panel", _menu_style())
    _overlay.add_child(_menu_panel)
    _menu_panel.anchor_left = 0.5
    _menu_panel.anchor_right = 0.5
    _menu_panel.anchor_top = 0.5
    _menu_panel.anchor_bottom = 0.5
    _menu_scroll = ScrollContainer.new()
    _menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _menu_scroll.follow_focus = true
    _menu_panel.add_child(_menu_scroll)
    _column = VBoxContainer.new()
    _column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _column.add_theme_constant_override("separation", 12)
    _menu_scroll.add_child(_column)

    var cinema: VBoxContainer = _panel(Vector2(0.5, 1), Rect2(-310, -126, 620, 104))
    _cinema_panel = cinema.get_parent()
    _cinema_panel.visible = false
    _cinematic_title = _text(cinema, "", 13, AQUA)
    _cinematic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cinematic_scores = _text(cinema, "", 30, INK)
    _cinematic_scores.add_theme_font_override("font", VisualTheme.display_font())
    _cinematic_scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _cinematic_winner = _text(cinema, "", 14, GOLD)
    _cinematic_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    get_viewport().size_changed.connect(_layout)
    _layout.call_deferred()

func _toggle_help() -> void:
    _help_open = not _help_open
    _help_panel.visible = _help_open
    _help_button.text = "×  Fermer l'aide" if _help_open else "?  Commandes"

func _layout() -> void:
    if not is_instance_valid(_root) or not is_inside_tree():
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var portrait_size: Vector2 = Vector2(84, 92) if viewport_size.y < 700 else Vector2(128, 140)
    for portrait: Control in _duel_portraits:
        if is_instance_valid(portrait) and portrait.custom_minimum_size != portrait_size:
            portrait.custom_minimum_size = portrait_size
    var menu_width: float = minf(728, viewport_size.x - 64)
    var menu_height: float = minf(maxf(240, _column.get_combined_minimum_size().y + 48), viewport_size.y - 72)
    _menu_panel.offset_left = -menu_width * 0.5
    _menu_panel.offset_right = menu_width * 0.5
    _menu_panel.offset_top = -menu_height * 0.5
    _menu_panel.offset_bottom = menu_height * 0.5
    _menu_scroll.custom_minimum_size = Vector2(menu_width - 48, menu_height - 48)
    var player_height: float = _player_column.get_combined_minimum_size().y + 22
    _player_panel.offset_top = -player_height - 22
    _player_panel.offset_bottom = -22
    _last_player_height = player_height

func _crest(parent: Node, path: String, side: float) -> TextureRect:
    if not ResourceLoader.exists(path):
        return null
    var crest := TextureRect.new()
    crest.texture = load(path)
    crest.custom_minimum_size = Vector2(side, side)
    crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(crest)
    return crest

func set_opponent_emblem(path: String) -> void:
    if ResourceLoader.exists(path):
        _opponent_crest.texture = load(path)

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
    if is_instance_valid(_radar):
        _radar.call("update_match", session)
    _score.text = "%d — %d" % [session.team_goals[0], session.team_goals[1]]
    for team: int in [0, 1]:
        _score_teams[team].text = session.team_names[team].to_upper()
        _score_teams[team].tooltip_text = session.team_names[team]
    var remaining: int = maxi(0, ceili(session.half_duration - session.elapsed_half))
    var frozen: bool = session.phase != session.Phase.LIVE
    _clock.text = "%s · %02d:%02d%s" % ["1re" if session.period == 1 else "2e", remaining / 60, remaining % 60, "  II" if frozen or paused else ""]
    _phase_label.text = "MATCH AMICAL · 11 V 11"
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
            _keeper_labels[state.team_id].text = "GARDIEN %s · %d" % [session.team_names[state.team_id].to_upper(), roundi(value)]
    for team: int in range(2):
        _team_modifier_counts[team].text = "Karma %d/3 · Resonance %d/3" % [session.count_active_modifiers(team, "KARMA"), session.count_active_modifiers(team, "RESONANCE")]
    _help.text = ("Stick G : déplacement · RT : sprint\nA : passe · Y : lob · X : tir chargé · B : tacle\nRB : cible · LB : joueur · Stick D : caméra\nL3 / V : techniques et tactiques · Start : pause"
        if controls.uses_gamepad else "ZQSD / WASD : mouvement · Maj : sprint\nEspace : passe · G : lob · E : tacle · Q : cible\nF / clic G : tir chargé · Tab : joueur\nClic D : caméra · V : actions · Échap : pause")
    _control_hint.text = "L3 · Actions    Start · Pause" if controls.uses_gamepad else "V · Actions    Échap · Pause"
    var desired_height: float = _player_column.get_combined_minimum_size().y + 22
    if absf(desired_height - _last_player_height) > 1.0:
        _layout.call_deferred()
    _message_life = maxf(0, _message_life - delta)
    _message.visible = _message_life > 0 and session.phase == session.Phase.LIVE and not _overlay.visible
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
    _help_panel.visible = _help_open
    _mode = ""
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null:
        focused.release_focus()

func _reset_overlay(mode: String, title: String, description: String = "") -> void:
    _mode = mode
    _message.visible = false
    _layout.call_deferred()
    _modal_notice = null
    _cinema_panel.visible = false
    for panel: Control in _live_panels:
        panel.visible = false
    _overlay.color = Color(0.025, 0.055, 0.09, 0.70)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    for child: Node in _column.get_children():
        child.free()
    _duel_tech_buttons.clear()
    _duel_portraits.clear()
    _overlay.visible = true
    _text(_column, "IEG  /  MATCH", 11, AQUA)
    var heading: Label = _text(_column, title, 32, INK)
    heading.add_theme_font_override("font", VisualTheme.display_font())
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if not description.is_empty():
        var subtitle: Label = _text(_column, description, 14, MUTED)
        subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _show_pause() -> void:
    _reset_overlay("pause", "Le match vous attend", "PAUSE · Le chrono est arrêté.")
    var first: Button = _button(_column, "Reprendre le match", func(): resume_requested.emit())
    _button(_column, "Techniques de tir", func(): open_actions("TIR"))
    _button(_column, "Tactiques collectives", func(): open_actions("TAC"))
    _button(_column, "Karma / Resonance", func(): open_actions("KARMA"))
    _button(_column, "Ouvrir l'atelier des techniques", func(): editor_requested.emit())
    _button(_column, "Retour au terrain d'entraînement", func(): training_requested.emit())
    if routes_available:
        _button(_column, "Abandonner et revenir aux parcours" if is_route_match else "Revenir aux parcours", func(): routes_requested.emit())
    first.grab_focus()

func _show_duel() -> void:
    var duel: Dictionary = _session.duel
    var attack: bool = str(duel.get("local_role", "attack")) == "attack"
    var keeper: bool = str(duel.get("kind", "field")) == "keeper"
    var block: bool = str(duel.get("kind", "field")) == "block"
    var category: String = ("TIR" if attack else "GAR") if keeper else (("TIR" if attack else "DEF") if block else ("ATT" if attack else "DEF"))
    var title: String = "TIREUR / GARDIEN" if keeper else ("TIR / BLOCAGE" if block else "FACE-À-FACE")
    var intent: String = ("Choisissez le côté de votre tir." if attack else "Anticipez le côté du tir.") if keeper or block else ("Choisissez votre dribble." if attack else "Choisissez votre intervention.")
    _reset_overlay("duel", title, intent + " Temps arrêté.")
    var confrontation := HBoxContainer.new()
    confrontation.add_theme_constant_override("separation", 14)
    _column.add_child(confrontation)
    var attacker: IEGPlayerState = _session.get_player(int(duel.get("actor_id", -1)))
    var defender: IEGPlayerState = _session.get_player(int(duel.get("target_id", -1)))
    _duel_portrait(confrontation, attacker, "TIREUR" if keeper or block else "ATTAQUE")
    var versus: Label = _text(confrontation, "VS", 27, GOLD)
    versus.add_theme_font_override("font", VisualTheme.display_font())
    versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _duel_portrait(confrontation, defender, "GARDIEN" if keeper else "DÉFENSE")
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    _column.add_child(row)
    var first: Button = _button(row, "← Gauche", func(): duel_choice_requested.emit("left", ""), 58)
    _button(row, "Droite →", func(): duel_choice_requested.emit("right", ""), 58)
    _text(_column, "TECHNIQUE SPÉCIALE · " + category, 16, AQUA)
    for definition: Dictionary in _for_category(category):
        var id: String = str(definition.get("id", ""))
        var actor: IEGPlayerState = _duel_actor()
        var prepaid: bool = attack and id == str(duel.get("prepaid_technique", ""))
        var cost: String = "déjà payée" if prepaid else _cost_text(definition)
        var special: Button = _technique_card(definition, func(): duel_choice_requested.emit("special", id), cost)
        special.disabled = not prepaid and not _session.can_use_technique(actor.get_id(), id, category)
        _duel_tech_buttons.append(special)
    _text(_column, "Croix / flèches · Naviguer     A / Entrée · Valider", 12, MUTED)
    _modal_notice = _text(_column, "", 15, GOLD)
    _modal_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    first.grab_focus()

func _duel_portrait(parent: Node, state: IEGPlayerState, role: String) -> void:
    if state == null:
        return
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style: StyleBoxFlat = _style(Color("11263a"))
    style.border_color = Color(AQUA if state.team_id == _session.LOCAL_TEAM else CORAL, 0.38)
    style.shadow_size = 0
    style.content_margin_top = 7
    style.content_margin_bottom = 8
    card.add_theme_stylebox_override("panel", style)
    parent.add_child(card)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 3)
    card.add_child(contents)
    var team: Label = _text(contents, "%s · %s" % [_session.team_names[state.team_id].to_upper(), role], 10, AQUA if state.team_id == _session.LOCAL_TEAM else CORAL)
    team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    contents.add_child(center)
    var portrait = PlayerPortrait.new()
    portrait.custom_minimum_size = Vector2(128, 140)
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _duel_portraits.append(portrait)
    center.add_child(portrait)
    portrait.set_profile(state.profile, state.is_goalkeeper)
    var name_label: Label = _text(contents, "%02d · %s" % [state.profile.shirt_number, state.profile.display_name], 16, INK)
    name_label.add_theme_font_override("font", VisualTheme.bold_font())
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

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
    var home: Label = _text(_column, _session.team_names[0], 21, AQUA)
    home.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _formation_blue = _formation_selector()
    var away: Label = _text(_column, _session.team_names[1], 21, Color("ff9d9a"))
    away.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _formation_red = _formation_selector()
    var ids: Array[String] = ["balanced", "wide", "press"]
    _formation_blue.select(maxi(0, ids.find(_session.formations[0])))
    _formation_red.select(maxi(0, ids.find(_session.formations[1])))
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
    var result: Label = _text(_column, "%s  %d — %d  %s" % [_session.team_names[0], _session.team_goals[0], _session.team_goals[1], _session.team_names[1]], 32, INK)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if is_route_match:
        _show_route_result()
    var first: Button = _button(_column, "Rejouer un match", func(): rematch_requested.emit())
    if routes_available:
        _button(_column, "Retour au parcours", func(): routes_requested.emit())
    _button(_column, "Consulter et éditer les techniques", func(): editor_requested.emit())
    _button(_column, "Retour à l'entraînement", func(): training_requested.emit())
    first.grab_focus()

func set_route_result(result: Dictionary) -> void:
    _route_result = result.duplicate(true)
    if _mode == "finished":
        _show_finished()

func _show_route_result() -> void:
    var error: Variant = _route_result.get("error", "")
    var failed: bool = (error is String and not error.is_empty()) or (error is int and error != OK) or int(_route_result.get("save_error", OK)) != OK
    if failed:
        var warning: Label = _text(_column, "Progression non enregistrée : " + str(_route_result.get("error_message", error)) + "\nRéessayez avant de quitter pour conserver le résultat.", 15, CORAL)
        warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _button(_column, "Réessayer la sauvegarde", func(): result_save_requested.emit())
        return
    var rank: String = String(_route_result.get("rank", ""))
    var best: String = String(_route_result.get("best_rank", ""))
    var description: String = "Rang obtenu : " + rank if not rank.is_empty() else "Aucun rang : une victoire est nécessaire."
    if not best.is_empty():
        description += "  ·  Meilleur rang : " + best
    description += "\nProgression enregistrée."
    var label: Label = _text(_column, description, 17, GOLD)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var rewards: Array = _route_result.get("rewards", [])
    if not rewards.is_empty():
        var reward_lines: PackedStringArray = []
        for reward: Dictionary in rewards:
            reward_lines.append("%s ×%s" % [reward.get("name", reward.get("id", reward.get("type", "Récompense"))), reward.get("amount", 1)])
        var reward_label: Label = _text(_column, "Gains : " + ", ".join(reward_lines), 14, AQUA)
        reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func open_actions(category: String = "TIR", player_id: int = -1) -> void:
    if _session == null or _session.phase != _session.Phase.LIVE:
        return
    menu_opened.emit()
    _action_player_id = _session.controlled_id if player_id < 0 else player_id
    var names: Dictionary = {"TIR": "TECHNIQUES DE TIR", "TAC": "TACTIQUES", "KARMA": "Karma", "RESONANCE": "Resonance"}
    var description: String = "Le chrono est arrêté pendant ce choix."
    if category in ["KARMA", "RESONANCE"]:
        description += "\nCumul autorisé · 3 Karma et 3 Resonance par équipe."
        description += "\nActifs dans votre équipe : Karma %d/3 · Resonance %d/3" % [_session.count_active_modifiers(0, "KARMA"), _session.count_active_modifiers(0, "RESONANCE")]
    _reset_overlay("actions_" + category, str(names.get(category, category)), description)
    if category in ["KARMA", "RESONANCE"]:
        var receiver: IEGPlayerState = _session.get_player(_action_player_id)
        var receiver_row := HBoxContainer.new()
        _column.add_child(receiver_row)
        _button(receiver_row, "← Joueur", func(): _cycle_receiver(category, -1), 38)
        var receiver_name: Label = _text(receiver_row, "%02d · %s" % [receiver.profile.shirt_number, receiver.profile.display_name], 18, INK)
        receiver_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        receiver_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _button(receiver_row, "Joueur →", func(): _cycle_receiver(category, 1), 38)
        _text(_column, "Choisissez le joueur qui recevra cette transformation.", 12, MUTED)
        for active: Dictionary in _session.get_active_modifiers(_action_player_id):
            if str(active.get("category", "")) == category:
                _button(_column, "Dissiper : " + _name_for_id(str(active.get("id", ""))), func(): modifier_release_requested.emit(category, _action_player_id))
    var first: Button = null
    for definition: Dictionary in _for_category(category):
        var id: String = str(definition.get("id", ""))
        var button: Button = _technique_card(definition, func(): _activate_content(category, id))
        if category == "TIR":
            button.disabled = not _session.can_use_technique(_session.controlled_id, id, category)
        if first == null:
            first = button
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
        _: modifier_requested.emit(id, _action_player_id)
    resume_requested.emit()

func _for_category(category: String) -> Array[Dictionary]:
    if _session != null:
        if category in ["TIR", "ATT", "DEF", "GAR"]:
            var actor: IEGPlayerState = _duel_actor() if _mode == "duel" else _session.controlled()
            var available: Array[Dictionary] = _session.get_available_techniques(actor.get_id(), category)
            # Un tir prépayé traverse le blocage même si son Karma s'est épuisé.
            if _mode == "duel" and _session.duel.get("local_role", "attack") == "attack":
                var prepaid_id: String = str(_session.duel.get("prepaid_technique", ""))
                var prepaid: Dictionary = _session.catalog.get_definition(prepaid_id)
                if bool(_session.duel.get("shot_chain", false)):
                    available.clear()
                if prepaid.get("category", "") == category:
                    available.append(prepaid)
            return available
        if category in ["KARMA", "RESONANCE"]:
            return _session.get_available_modifiers(_action_player_id, category)
    var result: Array[Dictionary] = []
    for definition: Dictionary in _definitions:
        if str(definition.get("category", "")) == category:
            result.append(definition)
    return result

func _duel_actor() -> IEGPlayerState:
    var duel: Dictionary = _session.duel
    return _session.get_player(int(duel["actor_id"] if duel.get("local_role", "attack") == "attack" else duel["target_id"]))

func _cycle_receiver(category: String, direction: int) -> void:
    var allies: Array[int] = []
    for state: IEGPlayerState in _session.players:
        if state.team_id == _session.LOCAL_TEAM:
            allies.append(state.get_id())
    var index: int = allies.find(_action_player_id)
    open_actions(category, allies[posmod(index + direction, allies.size())])

func _refresh_modifiers(session, player: IEGPlayerState) -> void:
    _karma_pg_label.visible = false
    _karma_pg_bar.visible = false
    _inherited_label.visible = false
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
        if category == "KARMA" and modifier.has("pg"):
            _karma_pg_label.text = "Karma · PG %.0f / %.0f" % [modifier["pg"], modifier["pg_max"]]
            _karma_pg_label.tooltip_text = _name_for_id(id)
            _karma_pg_label.visible = true
            _karma_pg_bar.max_value = maxf(1.0, float(modifier["pg_max"]))
            _karma_pg_bar.value = float(modifier["pg"])
            _karma_pg_bar.visible = true
            label.text = "Karma · PE %.0f / %.0f" % [modifier["pe"], modifier["pe_max"]]
            if bool(modifier.get("inherited_from", false)):
                label.text += " · hérité"
        elif category == "RESONANCE" and modifier.has("techniques"):
            label.text = "Resonance · %02d:%02d" % [remaining / 60, remaining % 60]
            var inherited_names: PackedStringArray = []
            for technique: Variant in modifier["techniques"]:
                inherited_names.append(_name_for_id(str(technique)))
            _inherited_label.text = "Héritées : " + ", ".join(inherited_names)
            _inherited_label.visible = not inherited_names.is_empty()
        label.tooltip_text = _name_for_id(id)
        bar.max_value = maxf(1.0, float(modifier.get("pe_max", modifier.get("energy_max", _modifier_max_energy(id)))))
        bar.value = energy
        label.visible = true
        bar.visible = true
    var bonuses: Dictionary = session.get_stat_bonuses(player.get_id())
    var stat_names: Dictionary = {"shot": "Tir", "dribble": "Dribble", "technique": "Technique", "defense": "Défense", "keeper": "Gardien"}
    var displayed: PackedStringArray = []
    for stat: String in stat_names:
        if float(bonuses.get(stat, 0.0)) > 0.0:
            displayed.append("%s +%.0f" % [stat_names[stat], bonuses[stat]])
    _stat_label.text = " · ".join(displayed.slice(0, 3))
    if displayed.size() > 3:
        _stat_label.text += "\n" + " · ".join(displayed.slice(3))
    _stat_label.visible = not displayed.is_empty()

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
    var properties: Dictionary = definition.get("properties", {})
    if properties.has("karma_id"):
        return "%.0f PG · %.0f PE" % [properties.get("pg_cost", 0.0), properties.get("pe_cost", 0.0)]
    if properties.has("pg_max"):
        return "%.0f PG · %.0f PE" % [properties["pg_max"], properties.get("pe_max", 0.0)]
    if properties.has("inherited_techniques"):
        return "%.0f s · 2 techniques" % float(definition.get("duration", 0.0))
    var cost: float = float(definition.get("cost", definition.get("energy_cost", 0)))
    return "%d énergie" % roundi(cost) if cost > 0 else "activation"

func _description(definition: Dictionary) -> void:
    var label: Label = _text(_column, str(definition.get("description", "")), 15, MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _panel(anchor: Vector2, rectangle: Rect2) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.067, 0.105, 0.94)))
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
    column.add_theme_constant_override("separation", 4)
    panel.add_child(column)
    return column

func _style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.38, 0.50, 0.58, 0.24)
    style.set_border_width_all(1)
    style.border_width_top = 2
    style.set_corner_radius_all(4)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    style.shadow_color = Color(0, 0, 0, 0.16)
    style.shadow_size = 9
    return style

func _menu_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = _style(Color(0.045, 0.085, 0.14, 0.98))
    style.border_color = Color(0.55, 0.67, 0.73, 0.30)
    style.border_width_top = 2
    style.content_margin_left = 24
    style.content_margin_right = 24
    style.content_margin_top = 24
    style.content_margin_bottom = 24
    style.shadow_size = 30
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
    bar.custom_minimum_size = Vector2(0, 5)
    var background := StyleBoxFlat.new()
    background.bg_color = Color("28384a")
    background.set_corner_radius_all(2)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.set_corner_radius_all(2)
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _button(parent: Node, value: String, callback: Callable, height: float = 44) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, height)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 16 if height > 37 else 11)
    button.add_theme_color_override("font_color", INK)
    button.add_theme_color_override("font_hover_color", INK)
    button.add_theme_color_override("font_focus_color", GOLD)
    button.add_theme_color_override("font_disabled_color", Color("71818f"))
    var normal: StyleBoxFlat = _style(Color("172b40"))
    normal.set_border_width_all(1)
    normal.shadow_size = 0
    normal.content_margin_top = 5
    normal.content_margin_bottom = 5
    normal.content_margin_left = 10
    normal.content_margin_right = 10
    button.add_theme_stylebox_override("normal", normal)
    var hover: StyleBoxFlat = normal.duplicate()
    hover.bg_color = Color("233c51")
    hover.border_color = AQUA
    button.add_theme_stylebox_override("hover", hover)
    var pressed: StyleBoxFlat = hover.duplicate()
    pressed.bg_color = Color("30465a")
    button.add_theme_stylebox_override("pressed", pressed)
    var disabled: StyleBoxFlat = normal.duplicate()
    disabled.bg_color = Color("112235")
    button.add_theme_stylebox_override("disabled", disabled)
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color(0, 0, 0, 0)
    focus.border_color = GOLD
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(4)
    focus.expand_margin_left = 2
    focus.expand_margin_right = 2
    focus.expand_margin_top = 2
    focus.expand_margin_bottom = 2
    button.add_theme_stylebox_override("focus", focus)
    parent.add_child(button)
    button.pressed.connect(callback)
    return button

func _technique_card(definition: Dictionary, callback: Callable, cost: String = "") -> Button:
    var card := PanelContainer.new()
    var card_style: StyleBoxFlat = _style(Color("13283c"))
    card_style.shadow_size = 0
    card_style.content_margin_left = 12
    card_style.content_margin_right = 12
    card_style.content_margin_top = 8
    card_style.content_margin_bottom = 10
    card_style.border_width_left = 3
    var category: String = str(definition.get("category", "TIR"))
    card_style.border_color = Color(GOLD, 0.45) if category in ["TIR", "KARMA"] else Color(AQUA, 0.40)
    card.add_theme_stylebox_override("panel", card_style)
    _column.add_child(card)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 5)
    card.add_child(contents)
    var cost_text: String = _cost_text(definition) if cost.is_empty() else cost
    var button: Button = _button(contents, "%s  ·  %s" % [_definition_name(definition), cost_text], callback, 42)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var description: String = str(definition.get("description", ""))
    if not description.is_empty():
        var label: Label = _text(contents, description, 13, MUTED)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return button
