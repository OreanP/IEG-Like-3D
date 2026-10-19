extends Control
## Tableau de parcours : présentation uniquement. RouteRun lance le vrai match.

const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")
const Connections = preload("res://scripts/routes/route_connections.gd")
const CARD_SIZE := Vector2(190, 112)
const RANK_COLORS := {"B": Color("b79d7c"), "A": Color("c8d9e6"), "S": Color("e5af65")}
const TYPE_NAMES := {"match": "RENCONTRE", "reward": "COFFRE", "gate": "DÉBLOCAGE", "branch": "BIFURCATION"}

var route_id: String = ""
var selected_node_id: String = ""
var _runner: Node
var _routes: Array = []
var _route: Dictionary = {}
var _buttons: Dictionary = {}
var _selector: OptionButton
var _wallet: Label
var _route_summary: Label
var _route_description: Label
var _notice: Label
var _notice_panel: PanelContainer
var _map_scroll: ScrollContainer
var _map: Control
var _connections: Control
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _detail_actions: VBoxContainer
var _detail_title: Label
var _detail_action: Button
var _original_scale_size: Vector2i

func _ready() -> void:
    _runner = get_node_or_null("/root/RouteRun")
    _original_scale_size = get_window().content_scale_size
    get_window().size_changed.connect(_fit_interface)
    _fit_interface()
    _build_ui()
    if _runner == null:
        _set_notice("Le gestionnaire de parcours n’est pas disponible.", true)
        return
    _routes = _runner.catalog.routes()
    for route: Dictionary in _routes:
        _selector.add_item(String(route.get("name", route.get("id", "Parcours"))))
        _selector.set_item_metadata(_selector.item_count - 1, String(route.get("id", "")))
    var result: Dictionary = _runner.last_result
    var requested: String = String(result.get("route_id", _runner.selected_route))
    if requested.is_empty() and not _routes.is_empty():
        requested = String(_routes[0].get("id", ""))
    if not requested.is_empty():
        select_route(requested)
    if not result.is_empty():
        _show_result(result)
        if String(result.get("route_id", "")) == route_id:
            select_node(String(result.get("node_id", selected_node_id)))
    elif _runner.selected_route == route_id and not String(_runner.selected_node).is_empty():
        select_node(String(_runner.selected_node))
    if not _runner.catalog.last_errors.is_empty():
        _set_notice("Le catalogue de parcours n’a pas pu être chargé.\n" + "\n".join(_runner.catalog.last_errors), true)
    elif not _runner.progress.last_errors.is_empty():
        _set_notice("La progression n’a pas pu être chargée ou enregistrée.\n" + "\n".join(_runner.progress.last_errors), true)
    _update_wallet()
    call_deferred("_focus_selected")

func _fit_interface() -> void:
    if not is_inside_tree():
        return
    var window: Window = get_window()
    var target := Vector2i(clampi(window.size.x, 960, 1280), clampi(window.size.y, 600, 800))
    if window.content_scale_size != target:
        window.content_scale_size = target

func _exit_tree() -> void:
    var window: Window = get_window()
    if window != null and window.size_changed.is_connected(_fit_interface):
        window.size_changed.disconnect(_fit_interface)
        window.content_scale_size = _original_scale_size

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and _buttons.has(selected_node_id):
        _buttons[selected_node_id].grab_focus()
        get_viewport().set_input_as_handled()

func _build_ui() -> void:
    theme = VisualTheme.make_theme()
    var backdrop := ColorRect.new()
    backdrop.color = Color("0b1523")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    add_child(margin)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    margin.add_child(layout)
    var header := HBoxContainer.new()
    layout.add_child(header)
    var title_group := VBoxContainer.new()
    title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_group.add_theme_constant_override("separation", 0)
    header.add_child(title_group)
    _label(title_group, "IEG  /  LE CLUB PART EN TOURNÉE", 11, VisualTheme.GOLD)
    var title := _label(title_group, "LES PARCOURS", 32)
    title.add_theme_font_override("font", VisualTheme.display_font())
    _wallet = _label(header, "", 13, VisualTheme.AQUA)
    _wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var free_button := _button(header, "Match libre", _launch_free)
    free_button.tooltip_text = "Lancer un match sans enjeu de progression."
    _button(header, "Entraînement", _launch_training)
    var route_bar := HBoxContainer.new()
    layout.add_child(route_bar)
    _selector = OptionButton.new()
    _selector.name = "RouteSelector"
    _selector.custom_minimum_size.x = 270
    _selector.item_selected.connect(func(index: int) -> void: select_route(String(_selector.get_item_metadata(index))))
    route_bar.add_child(_selector)
    _route_description = _label(route_bar, "", 13, VisualTheme.MUTED)
    _route_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _route_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _route_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _route_summary = _label(route_bar, "", 12, VisualTheme.AQUA)
    _route_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _notice_panel = PanelContainer.new()
    _notice_panel.visible = false
    layout.add_child(_notice_panel)
    _notice = _label(_notice_panel, "", 13)
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    layout.add_child(content)
    var map_panel := PanelContainer.new()
    map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_panel.add_theme_stylebox_override("panel", VisualTheme.surface(Color("0e1c2d")))
    content.add_child(map_panel)
    var map_layout := VBoxContainer.new()
    map_panel.add_child(map_layout)
    var map_heading := HBoxContainer.new()
    map_layout.add_child(map_heading)
    _label(map_heading, "CHOISISSEZ VOTRE PROCHAINE RENCONTRE", 11, VisualTheme.GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(map_heading, "Faites défiler la carte", 10, VisualTheme.MUTED)
    _map_scroll = ScrollContainer.new()
    _map_scroll.name = "RouteMapScroll"
    _map_scroll.follow_focus = true
    _map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_layout.add_child(_map_scroll)
    _map = Control.new()
    _map.name = "RouteMap"
    _map_scroll.add_child(_map)
    var map_legend := HBoxContainer.new()
    map_layout.add_child(map_legend)
    _label(map_legend, "●  Disponible", 11, VisualTheme.AQUA)
    _label(map_legend, "●  Remporté", 11, VisualTheme.GOLD)
    _label(map_legend, "●  Verrouillé", 11, VisualTheme.MUTED)
    var detail_panel := PanelContainer.new()
    detail_panel.name = "MatchDetail"
    detail_panel.custom_minimum_size.x = 316
    detail_panel.size_flags_horizontal = Control.SIZE_FILL
    detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(detail_panel)
    var detail_layout := VBoxContainer.new()
    detail_panel.add_child(detail_layout)
    _detail_scroll = ScrollContainer.new()
    _detail_scroll.name = "DetailScroll"
    _detail_scroll.custom_minimum_size.x = 288
    _detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _detail_scroll.follow_focus = true
    _detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_layout.add_child(_detail_scroll)
    _detail = VBoxContainer.new()
    _detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detail.add_theme_constant_override("separation", 12)
    _detail_scroll.add_child(_detail)
    _detail_actions = VBoxContainer.new()
    _detail_actions.name = "DetailActions"
    detail_layout.add_child(_detail_actions)
    var footer := HBoxContainer.new()
    layout.add_child(footer)
    _label(footer, "Direction / croix : parcourir    ·    A / Entrée : sélectionner", 11, VisualTheme.MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(footer, "Chaque rencontre se joue sur le terrain.", 11, VisualTheme.GOLD)

func select_route(id: String) -> void:
    if _runner == null:
        return
    var candidate: Dictionary = _runner.catalog.route(id)
    if candidate.is_empty():
        return
    route_id = id
    _route = candidate
    for index: int in _selector.item_count:
        if String(_selector.get_item_metadata(index)) == id:
            _selector.select(index)
            break
    _route_description.text = String(_route.get("description", "Gagnez des matchs pour ouvrir de nouvelles voies."))
    var previous: String = selected_node_id
    _rebuild_map()
    var nodes: Array = _route.get("nodes", [])
    if _buttons.has(previous):
        select_node(previous)
    elif not nodes.is_empty():
        select_node(String(nodes[0].get("id", "")))

func select_node(id: String) -> void:
    if _runner == null or not _buttons.has(id):
        return
    var node: Dictionary = _runner.catalog.node(route_id, id)
    if node.is_empty():
        return
    selected_node_id = id
    _build_detail(node)
    for key: String in _buttons:
        _style_node(_buttons[key], _runner.catalog.node(route_id, key), key == id)
    _connections.selected_id = id
    _connections.queue_redraw()
    _wire_focus()

func _rebuild_map() -> void:
    for child: Node in _map.get_children():
        _map.remove_child(child)
        child.queue_free()
    _buttons.clear()
    _connections = Connections.new()
    _connections.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _connections.nodes = _route.get("nodes", [])
    _connections.edges = _route.get("edges", [])
    _connections.card_size = CARD_SIZE
    _map.add_child(_connections)
    var bounds := Vector2(550, 370)
    var won: int = 0
    var matches: int = 0
    for node: Dictionary in _route.get("nodes", []):
        var id: String = String(node.get("id", ""))
        var unlocked: bool = _runner.progress.is_unlocked(route_id, id)
        var rank: String = _runner.progress.best_rank(route_id, id)
        _connections.available[id] = unlocked
        var step_type: String = String(node.get("type", "match"))
        _connections.cleared[id] = not rank.is_empty() or _is_claimed(id) or (unlocked and step_type in ["gate", "branch"])
        if String(node.get("type", "match")) == "match":
            matches += 1
            if not rank.is_empty():
                won += 1
        var raw: Array = node.get("position", [40, 40])
        var position_value := Vector2(float(raw[0]), float(raw[1]))
        bounds = bounds.max(position_value + CARD_SIZE + Vector2(40, 40))
        var button := Button.new()
        button.name = "Node_" + id.validate_node_name()
        button.position = position_value
        button.size = CARD_SIZE
        button.custom_minimum_size = CARD_SIZE
        button.clip_contents = true
        button.tooltip_text = String(node.get("name", id)) + (" · Disponible" if unlocked else " · Conditions à remplir")
        button.pressed.connect(func() -> void: _activate_node(id))
        button.focus_entered.connect(func() -> void: select_node(id))
        _map.add_child(button)
        _buttons[id] = button
        _node_content(button, node, unlocked, rank)
        _style_node(button, node, false)
    _map.custom_minimum_size = bounds
    _connections.size = bounds
    _connections.queue_redraw()
    _route_summary.text = "%d / %d remportés" % [won, matches]
    _wire_focus()

func _node_content(button: Button, node: Dictionary, unlocked: bool, rank: String) -> void:
    var box := VBoxContainer.new()
    box.position = Vector2(12, 9)
    box.size = CARD_SIZE - Vector2(24, 18)
    box.add_theme_constant_override("separation", 4)
    _ignore_mouse(box)
    button.add_child(box)
    var identity := HBoxContainer.new()
    identity.add_theme_constant_override("separation", 7)
    box.add_child(identity)
    var type: String = String(node.get("type", "match"))
    var team: Dictionary = _runner.catalog.team(String(node.get("team_id", ""))) if type == "match" else {}
    if type == "match":
        _emblem(identity, team, 32)
    var top := VBoxContainer.new()
    top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_theme_constant_override("separation", 0)
    identity.add_child(top)
    _label(top, String(TYPE_NAMES.get(type, "ÉTAPE")), 9, VisualTheme.GOLD if unlocked else VisualTheme.MUTED)
    var name_label := _label(top, String(team.get("name", node.get("name", "Rencontre"))), 13)
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.clip_text = true
    var status := HBoxContainer.new()
    box.add_child(status)
    var level: String = "Niv. conseillé  %d" % int(node.get("recommended_level", team.get("level", 1))) if type == "match" else String(node.get("name", "Étape"))
    var level_label := _label(status, level, 10, VisualTheme.MUTED)
    level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    level_label.clip_text = true
    if not rank.is_empty():
        _label(status, rank, 17, RANK_COLORS.get(rank, VisualTheme.GOLD))
    var caption: String = "DISPONIBLE" if unlocked else "VERROUILLÉ"
    var caption_color: Color = VisualTheme.AQUA if unlocked else VisualTheme.MUTED
    if not rank.is_empty():
        caption = "REJOUER LIBREMENT"
        caption_color = VisualTheme.GOLD
    elif type == "reward" and _is_claimed(String(node.get("id", ""))):
        caption = "RÉCUPÉRÉ"
        caption_color = VisualTheme.GOLD
    _label(box, caption, 9, caption_color)
    var rewards: Dictionary = node.get("rewards", {})
    var candidates: Array = rewards.get("first_win", []) if type == "match" else rewards.get("claim", [])
    if candidates.is_empty():
        candidates = rewards.get("repeat", [])
    if not candidates.is_empty():
        var potential := _label(box, _reward_text(candidates[0], false), 9, VisualTheme.MUTED)
        potential.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        potential.clip_text = true
    _ignore_mouse(box)

func _style_node(button: Button, node: Dictionary, selected: bool) -> void:
    var id: String = String(node.get("id", ""))
    var unlocked: bool = _runner.progress.is_unlocked(route_id, id)
    var rank: String = _runner.progress.best_rank(route_id, id)
    var border: Color = VisualTheme.AQUA if unlocked else Color("34475a")
    if not rank.is_empty() or _is_claimed(id):
        border = VisualTheme.GOLD
    var background := Color("152c3d") if unlocked else Color("152132")
    if selected:
        border = VisualTheme.GOLD
        background = Color("253b4a")
    var style := VisualTheme.surface(background, border)
    style.set_border_width_all(2 if selected else 1)
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", VisualTheme.surface(background.lightened(0.08), border))

func _build_detail(node: Dictionary) -> void:
    for child: Node in _detail.get_children():
        _detail.remove_child(child)
        child.queue_free()
    for child: Node in _detail_actions.get_children():
        _detail_actions.remove_child(child)
        child.queue_free()
    _detail_action = null
    _detail_scroll.scroll_vertical = 0
    var type: String = String(node.get("type", "match"))
    var id: String = String(node.get("id", ""))
    var unlocked: bool = _runner.progress.is_unlocked(route_id, id)
    var team: Dictionary = _runner.catalog.team(String(node.get("team_id", ""))) if type == "match" else {}
    _label(_detail, "FICHE  /  " + String(TYPE_NAMES.get(type, "ÉTAPE")), 11, VisualTheme.GOLD)
    var identity := HBoxContainer.new()
    _detail.add_child(identity)
    if type == "match":
        _emblem(identity, team, 56)
    _detail_title = _label(identity, String(team.get("name", node.get("name", "Étape"))), 27)
    _detail_title.add_theme_font_override("font", VisualTheme.display_font())
    _detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var description: String = String(node.get("description", team.get("description", "")))
    if not description.is_empty():
        _wrapped(_detail, description, VisualTheme.MUTED)
    if type == "match":
        var formation: String = String(team.get("formation", ""))
        formation = String({"balanced": "Disposition équilibrée", "wide": "Jeu sur les ailes", "compact": "Bloc compact", "offensive": "Disposition offensive", "defensive": "Disposition défensive"}.get(formation, formation))
        _wrapped(_detail, "Niveau conseillé  %d%s" % [int(node.get("recommended_level", team.get("level", 1))), "   ·   " + formation if not formation.is_empty() else ""], VisualTheme.AQUA)
        var rank: String = _runner.progress.best_rank(route_id, id)
        if rank.is_empty():
            _wrapped(_detail, "Aucune victoire enregistrée", VisualTheme.MUTED)
        else:
            _wrapped(_detail, "Meilleur rang   " + rank + "   ·   Rencontre rejouable", RANK_COLORS.get(rank, VisualTheme.GOLD))
    _separator(_detail)
    _label(_detail, "ACCÈS", 11, VisualTheme.GOLD)
    _wrapped(_detail, "Rencontre débloquée" if unlocked and type == "match" else ("Étape accessible" if unlocked else "Conditions à remplir"), VisualTheme.AQUA if unlocked else VisualTheme.MUTED)
    _requirements(node)
    var rewards: Dictionary = node.get("rewards", {})
    if not rewards.is_empty():
        _separator(_detail)
        _reward_section("PREMIÈRE VICTOIRE", rewards.get("first_win", []))
        _reward_section("À CHAQUE VICTOIRE", rewards.get("repeat", []))
        _reward_section("CONTENU DU COFFRE", rewards.get("claim", []))
    if type == "match":
        _separator(_detail)
        _label(_detail, "RANGS DE VICTOIRE", 11, VisualTheme.GOLD)
        _wrapped(_detail, _rank_description(), VisualTheme.MUTED, 12)
        _detail_action = _button(_detail_actions, "Jouer le match" if unlocked else "Match verrouillé", _play_selected)
        _detail_action.disabled = not unlocked
        _detail_action.name = "PlayMatch"
        _detail_action.custom_minimum_size.y = 45
        _wrapped(_detail, "Victoire, nul ou défaite : le résultat vient du match. Seule une victoire attribue un rang.", VisualTheme.MUTED, 11)
    elif type == "reward":
        var claimed: bool = _is_claimed(id)
        _detail_action = _button(_detail_actions, "Récompense récupérée" if claimed else "Réclamer la récompense", _claim_selected)
        _detail_action.name = "ClaimReward"
        _detail_action.disabled = not unlocked or claimed
        _detail_action.custom_minimum_size.y = 45
    else:
        _wrapped(_detail, "Cette étape relie les rencontres suivantes. Les conditions se valident avec votre progression.", VisualTheme.MUTED, 12)

func _requirements(node: Dictionary) -> void:
    var all: Array = node.get("requires", [])
    var any: Array = node.get("requires_any", [])
    if all.is_empty() and any.is_empty():
        _wrapped(_detail, "Accès libre dès le début du parcours.", VisualTheme.MUTED, 12)
        return
    for condition: Variant in all:
        _wrapped(_detail, _condition_text(condition), VisualTheme.MUTED, 12)
    if not any.is_empty():
        _wrapped(_detail, "Remplir au moins une condition :", VisualTheme.MUTED, 12)
        for condition: Variant in any:
            _wrapped(_detail, "• " + _condition_text(condition), VisualTheme.MUTED, 12)

func _condition_text(condition: Variant) -> String:
    if not condition is Dictionary:
        return String(condition)
    if condition.has("flag"):
        return String(condition.get("name", "Condition spéciale : " + String(condition.flag)))
    var other: Dictionary = _runner.catalog.node(String(condition.get("route", route_id)), String(condition.get("node", "")))
    var other_name: String = String(other.get("name", condition.get("node", "étape précédente")))
    if String(other.get("type", "match")) != "match":
        return ("Récupérer « %s »" if String(other.get("type", "")) == "reward" else "Débloquer « %s »") % other_name
    var required: String = String(condition.get("rank", "B"))
    return "Gagner « %s »%s" % [other_name, " au rang " + required + " ou mieux" if required != "B" else ""]

func _rank_description() -> String:
    var rules: Variant = _runner.catalog.rank_rules
    var a_margin: int = 3
    var s_goals: int = 5
    if rules is Dictionary:
        a_margin = int(rules.get("a_goal_difference", 3))
        s_goals = int(rules.get("s_goals_for", 5))
    var s_against: int = int(rules.get("s_goals_against", 0)) if rules is Dictionary else 0
    var s_conceded: String = "aucun encaissé" if s_against == 0 else "au plus %d encaissé(s)" % s_against
    return "B  Victoire\nA  Au moins %d buts d’écart\nS  Au moins %d buts marqués, %s\nLe meilleur rang historique est conservé." % [a_margin, s_goals, s_conceded]

func _reward_section(title: String, rewards: Array) -> void:
    if rewards.is_empty():
        return
    _label(_detail, title, 10, VisualTheme.GOLD)
    for reward: Variant in rewards:
        _wrapped(_detail, _reward_text(reward, true), VisualTheme.INK, 12)

func _reward_text(reward: Variant, detailed: bool) -> String:
    if not reward is Dictionary:
        return String(reward)
    var type: String = String(reward.get("type", "item"))
    var fallback: String = {"currency": "Crédits", "xp": "Expérience", "technique": "Technique", "equipment": "Équipement", "recruitment": "Recrutement", "item": "Objet"}.get(type, "Récompense")
    var label: String = String(reward.get("name", reward.get("id", fallback)))
    var amount: int = int(reward.get("amount", 1))
    var result: String = "%s  ×%d" % [label, amount]
    if detailed:
        var minimum: String = String(reward.get("min_rank", ""))
        if not minimum.is_empty():
            result += "  ·  rang " + minimum + "+"
        var chance: float = float(reward.get("chance", 1.0))
        result += "  ·  %d %%" % roundi(chance * 100.0) if chance < 1.0 else "  ·  garanti"
    return result

func _is_claimed(id: String) -> bool:
    var state: Dictionary = _runner.progress.state
    var route_state: Dictionary = state.get("routes", {}).get(route_id, {})
    return bool(route_state.get("nodes", {}).get(id, {}).get("claimed", false))

func _play_selected() -> void:
    if _runner == null or selected_node_id.is_empty():
        return
    var error: Error = _runner.launch_match(route_id, selected_node_id)
    if error != OK:
        _set_notice("Impossible de lancer la rencontre : " + error_string(error), true)

func _activate_node(id: String) -> void:
    select_node(id)
    if _detail_action != null and not _detail_action.disabled:
        _detail_action.grab_focus()

func _claim_selected() -> void:
    if _runner == null:
        return
    var result: Dictionary = _runner.progress.claim_node(route_id, selected_node_id)
    var failure: Variant = _result_error(result)
    if _is_error(failure):
        _set_notice("Récompense non enregistrée : " + str(failure) + ". " + " ".join(_runner.progress.last_errors), true)
    elif not bool(result.get("ok", true)):
        _set_notice(String(result.get("message", "Cette récompense ne peut pas être récupérée.")), true)
    else:
        var lines := PackedStringArray()
        for reward: Variant in result.get("rewards", []):
            lines.append(_reward_text(reward, false))
        _set_notice("Récompense récupérée et sauvegardée." + ("  " + " · ".join(lines) if not lines.is_empty() else ""))
    var previous: String = selected_node_id
    _rebuild_map()
    select_node(previous)
    _update_wallet()

func _launch_free() -> void:
    if _runner == null:
        return
    var error: Error = _runner.launch_free_match()
    if error != OK:
        _set_notice("Impossible de lancer le match libre : " + error_string(error), true)

func _launch_training() -> void:
    if _runner == null:
        return
    var error: Error = _runner.launch_training()
    if error != OK:
        _set_notice("Impossible de lancer l’entraînement : " + error_string(error), true)

func _show_result(result: Dictionary) -> void:
    var own: int = int(result.get("goals_for", result.get("score_home", 0)))
    var opponent: int = int(result.get("goals_against", result.get("score_away", 0)))
    var title: String = "VICTOIRE" if own > opponent else ("MATCH NUL" if own == opponent else "DÉFAITE")
    var text: String = "%s  ·  %d – %d" % [title, own, opponent]
    var error: Variant = _result_error(result)
    var failed: bool = _is_error(error)
    if failed:
        text += "  ·  Progression non enregistrée : " + String(result.get("error_message", str(error))) + ". Récompenses non attribuées."
    else:
        var rank: String = String(result.get("rank", ""))
        if not rank.is_empty():
            text += "  ·  Rang " + rank + "  ·  Meilleur : " + String(result.get("best_rank", rank))
        else:
            text += "  ·  Aucun rang attribué. Vous pouvez recommencer."
        var earned := PackedStringArray()
        for reward: Variant in result.get("rewards", []):
            earned.append(_reward_text(reward, false))
        if not earned.is_empty():
            text += "\nRécompenses : " + " · ".join(earned)
    _set_notice(text, failed)

func _result_error(result: Dictionary) -> Variant:
    var save_error: Variant = result.get("save_error", OK)
    return save_error if _is_error(save_error) else result.get("error", OK)

func _is_error(value: Variant) -> bool:
    return (value is int and value != OK) or (value is String and not value.is_empty())

func _update_wallet() -> void:
    if _runner == null:
        return
    var state: Dictionary = _runner.progress.state
    _wallet.text = "%d  CRÉDITS" % int(state.get("wallet", {}).get("currency", 0))

func _set_notice(message: String, error: bool = false) -> void:
    _notice_panel.visible = true
    _notice_panel.add_theme_stylebox_override("panel", VisualTheme.surface(Color("352431") if error else Color("17393d"), VisualTheme.CARMIN if error else VisualTheme.AQUA))
    _notice.text = message

func _focus_selected() -> void:
    if _buttons.has(selected_node_id):
        _buttons[selected_node_id].grab_focus()
    else:
        _selector.grab_focus()

func _wire_focus() -> void:
    for id: String in _buttons:
        var button: Button = _buttons[id]
        for side: String in ["left", "right", "top", "bottom"]:
            var direction: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "top": Vector2.UP, "bottom": Vector2.DOWN}[side]
            var best: Button = null
            var best_score: float = INF
            for other: String in _buttons:
                if other == id:
                    continue
                var candidate: Button = _buttons[other]
                var delta: Vector2 = candidate.position - button.position
                var along: float = delta.dot(direction)
                if along <= 4.0:
                    continue
                var sideways: float = absf(delta.cross(direction))
                var score: float = along + sideways * 2.2
                if score < best_score:
                    best = candidate
                    best_score = score
            if best != null:
                button.set("focus_neighbor_" + side, button.get_path_to(best))
            elif side == "top":
                button.focus_neighbor_top = button.get_path_to(_selector)
            elif side == "right" and _detail_action != null and not _detail_action.disabled:
                button.focus_neighbor_right = button.get_path_to(_detail_action)
            else:
                button.set("focus_neighbor_" + side, button.get_path_to(button))
        button.focus_next = button.get_path_to(_detail_action) if _detail_action != null and not _detail_action.disabled else button.get_path_to(_selector)
    if _detail_action != null and _buttons.has(selected_node_id):
        var selected: Button = _buttons[selected_node_id]
        _detail_action.focus_neighbor_left = _detail_action.get_path_to(selected)
        _detail_action.focus_previous = _detail_action.get_path_to(selected)
        _detail_action.focus_neighbor_top = _detail_action.get_path_to(_selector)
        _selector.focus_neighbor_bottom = _selector.get_path_to(selected)

func _emblem(parent: Node, team: Dictionary, dimension: int) -> void:
    var texture: Texture2D = null
    var path: String = String(team.get("emblem", ""))
    if not path.is_empty() and ResourceLoader.exists(path):
        texture = load(path)
    if texture != null:
        var image := TextureRect.new()
        image.texture = texture
        image.custom_minimum_size = Vector2(dimension, dimension)
        image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        parent.add_child(image)
    else:
        var crest := PanelContainer.new()
        crest.custom_minimum_size = Vector2(dimension, dimension)
        var color := Color.from_string(String(team.get("kit_color", team.get("color", "468ee6"))), VisualTheme.AZUR)
        crest.add_theme_stylebox_override("panel", VisualTheme.surface(color.darkened(0.45), color, 5))
        var monogram := _label(crest, String(team.get("name", "FC")).substr(0, 2).to_upper(), 12)
        monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        monogram.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        parent.add_child(crest)

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _label(parent: Node, text: String, font_size: int = 14, color: Color = VisualTheme.INK) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _wrapped(parent: Node, text: String, color: Color, font_size: int = 13) -> Label:
    var label := _label(parent, text, font_size, color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label

func _separator(parent: Node) -> void:
    var line := HSeparator.new()
    line.modulate = Color("526477")
    parent.add_child(line)

func _ignore_mouse(node: Node) -> void:
    if node is Control:
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child: Node in node.get_children():
        _ignore_mouse(child)
