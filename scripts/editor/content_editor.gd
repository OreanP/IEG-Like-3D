extends Control
## Atelier autonome : edition de copies, validation puis sauvegarde locale atomique.
const Catalog = preload("res://core/content/technique_catalog.gd")
const Preview = preload("res://scripts/editor/technique_preview.gd")
const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")

signal match_requested
@export var embedded_mode: bool = false
var storage_path: String = Catalog.STORAGE_PATH

var catalog: IEGTechniqueCatalog
var _entries: Array[Dictionary] = []
var _selected: int = -1
var _loading: bool = false
var _dirty: bool = false
var _list: ItemList
var _fields: Dictionary = {}
var _status: Label
var _preview: SubViewportContainer
var _restore_dialog: ConfirmationDialog
var _reload_dialog: ConfirmationDialog
var _mechanic_fields: Dictionary = {}
var _mechanic_sections: Dictionary = {}
var _mechanic_edits: Dictionary = {}
var _stat_checks: Dictionary = {}
var _visible_indices: Array[int] = []
var _filter: OptionButton
var _search: LineEdit
var _entry_title: Label
var _entry_badge: Label
var _entry_summary: Label
var _count_label: Label
var _dirty_badge: Label
var _original_scale_size: Vector2i
const CATEGORY_LABELS: Dictionary = {"TIR": "Tirs", "ATT": "Dribbles", "DEF": "Défense", "GAR": "Gardiens", "TAC": "Tactiques", "KARMA": "Karma", "RESONANCE": "Résonances"}
const STAT_LABELS: Dictionary = {"shot": "Tir", "dribble": "Dribble", "technique": "Technique", "defense": "Défense", "keeper": "Gardien"}

func _ready() -> void:
    if not embedded_mode:
        _original_scale_size = get_window().content_scale_size
        get_window().size_changed.connect(_fit_interface)
        _fit_interface()
    catalog = Catalog.new(storage_path)
    _entries = catalog.all_definitions()
    _build_ui()
    _rebuild_list()
    if not _entries.is_empty():
        _show_entry(0)
    if not catalog.last_errors.is_empty():
        _set_status("Le fichier local n'a pas été chargé. Les contenus intégrés restent disponibles.\n" + "\n".join(catalog.last_errors), true)
    elif not catalog.last_notices.is_empty():
        _set_status("Contenus migrés en mémoire ; paramètres personnalisés conservés. Sauvegardez pour actualiser le fichier local.\n" + "\n".join(catalog.last_notices))
    else:
        _set_status("Contenus intégrés chargés. Modifiez une fiche, puis sauvegardez pour les prochains matchs.")

func _fit_interface() -> void:
    var window: Window = get_window()
    var target := Vector2i(clampi(window.size.x, 960, 1280), clampi(window.size.y, 600, 800))
    if window.content_scale_size != target:
        window.content_scale_size = target

func _exit_tree() -> void:
    var window: Window = get_window()
    if window != null and window.size_changed.is_connected(_fit_interface):
        window.size_changed.disconnect(_fit_interface)
        window.content_scale_size = _original_scale_size

func _build_ui() -> void:
    theme = VisualTheme.make_theme()
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color("0b1523")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)
    add_child(margin)
    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    margin.add_child(layout)
    var header: HBoxContainer = HBoxContainer.new()
    header.add_theme_constant_override("separation", 16)
    layout.add_child(header)
    var wordmark: VBoxContainer = VBoxContainer.new()
    wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(wordmark)
    var eyebrow: Label = Label.new()
    eyebrow.text = "IEG  /  LABORATOIRE DU CLUB"
    eyebrow.add_theme_font_size_override("font_size", 12)
    eyebrow.add_theme_color_override("font_color", Color("e5af65"))
    wordmark.add_child(eyebrow)
    var title: Label = Label.new()
    title.text = "L’ATELIER"
    title.add_theme_font_override("font", VisualTheme.display_font())
    title.add_theme_font_size_override("font_size", 34)
    wordmark.add_child(title)
    _dirty_badge = Label.new()
    _dirty_badge.text = "CATALOGUE LOCAL"
    _dirty_badge.add_theme_font_size_override("font_size", 12)
    _dirty_badge.add_theme_color_override("font_color", Color("9dafc3"))
    header.add_child(_dirty_badge)
    var return_button: Button = Button.new()
    return_button.text = "Retour au match  ·  F5" if embedded_mode else "Jouer un match  ·  F5"
    return_button.pressed.connect(_open_match)
    header.add_child(return_button)
    var content: HBoxContainer = HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    layout.add_child(content)
    var sidebar: VBoxContainer = _card(content, "Catalogue", 14)
    sidebar.get_parent().custom_minimum_size.x = 236
    sidebar.get_parent().size_flags_horizontal = Control.SIZE_FILL
    sidebar.add_theme_constant_override("separation", 10)
    var library: Label = Label.new()
    library.text = "COLLECTION"
    library.add_theme_font_size_override("font_size", 12)
    library.add_theme_color_override("font_color", Color("e5af65"))
    sidebar.add_child(library)
    _search = LineEdit.new()
    _search.name = "Search"
    _search.placeholder_text = "Rechercher une fiche…"
    _search.clear_button_enabled = true
    _search.text_changed.connect(func(_value: String) -> void: _filter_changed())
    sidebar.add_child(_search)
    _filter = OptionButton.new()
    _filter.name = "CategoryFilter"
    _filter.add_item("Toutes les catégories")
    _filter.set_item_metadata(0, "")
    for category: String in Catalog.CATEGORIES:
        _filter.add_item(String(CATEGORY_LABELS.get(category, category)))
        _filter.set_item_metadata(_filter.item_count - 1, category)
    _filter.item_selected.connect(func(_index: int) -> void: _filter_changed())
    sidebar.add_child(_filter)
    _list = ItemList.new()
    _list.name = "ContentList"
    _list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.select_mode = ItemList.SELECT_SINGLE
    _list.fixed_column_width = 194
    _list.max_columns = 1
    _list.auto_height = false
    _list.add_theme_constant_override("v_separation", 12)
    _list.add_theme_constant_override("line_separation", 6)
    _list.item_selected.connect(_select_entry)
    sidebar.add_child(_list)
    _count_label = Label.new()
    _count_label.add_theme_font_size_override("font_size", 12)
    _count_label.add_theme_color_override("font_color", Color("9dafc3"))
    sidebar.add_child(_count_label)
    _add_button(sidebar, "＋  Dupliquer la fiche", _duplicate_entry)
    var editor_scroll: ScrollContainer = ScrollContainer.new()
    editor_scroll.name = "EditorScroll"
    editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    editor_scroll.follow_focus = true
    content.add_child(editor_scroll)
    var editor: VBoxContainer = VBoxContainer.new()
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.add_theme_constant_override("separation", 14)
    editor_scroll.add_child(editor)
    var hero: VBoxContainer = _card(editor, "Presentation", 16)
    var identity: HBoxContainer = HBoxContainer.new()
    identity.add_theme_constant_override("separation", 12)
    hero.add_child(identity)
    _entry_title = Label.new()
    _entry_title.text = "Sélectionnez une fiche"
    _entry_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _entry_title.add_theme_font_override("font", VisualTheme.display_font())
    _entry_title.add_theme_font_size_override("font_size", 28)
    _entry_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _entry_title.clip_text = true
    identity.add_child(_entry_title)
    _entry_badge = Label.new()
    _entry_badge.add_theme_font_size_override("font_size", 13)
    _entry_badge.add_theme_color_override("font_color", Color("e5af65"))
    identity.add_child(_entry_badge)
    _entry_summary = Label.new()
    _entry_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _entry_summary.add_theme_font_size_override("font_size", 13)
    _entry_summary.add_theme_color_override("font_color", Color("9dafc3"))
    hero.add_child(_entry_summary)
    _preview = Preview.new()
    _preview.name = "TechniquePreview"
    _preview.custom_minimum_size = Vector2(240, 300)
    _preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero.add_child(_preview)
    var preview_controls: HFlowContainer = HFlowContainer.new()
    preview_controls.add_theme_constant_override("h_separation", 10)
    hero.add_child(preview_controls)
    _add_button(preview_controls, "↻  Rejouer", _replay_preview)
    var outcome: OptionButton = OptionButton.new()
    outcome.name = "KeeperOutcome"
    for label: String in ["Issue GAR : capture", "Issue GAR : déviation", "Issue GAR : échec"]:
        outcome.add_item(label)
    outcome.item_selected.connect(func(index: int) -> void:
        _preview.set_outcome(["capture", "deflection", "goal"][index]))
    preview_controls.add_child(outcome)
    var parameters: VBoxContainer = _card(editor, "Parameters", 16)
    _section_heading(parameters, "01", "Identité & équilibre")
    var grid: GridContainer = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 10)
    parameters.add_child(grid)
    _add_text_field(grid, "Identifiant", "id", true)
    _add_text_field(grid, "Nom affiché", "name")
    _add_label(grid, "Catégorie")
    var category: OptionButton = OptionButton.new()
    category.name = "Category"
    category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for item: String in Catalog.CATEGORIES:
        category.add_item(item)
    category.item_selected.connect(func(index: int) -> void:
        _refresh_mechanic_sections(Catalog.CATEGORIES[index])
        _mark_dirty())
    _fields["category"] = category
    grid.add_child(category)
    _add_text_field(grid, "Effet visuel", "effect")
    _add_number_field(grid, "Puissance", "power", 0.0, 500.0)
    _add_number_field(grid, "Coût en endurance", "cost", 0.0, 100.0)
    _add_number_field(grid, "Durée (secondes)", "duration", 0.1, 600.0)
    _add_number_field(grid, "Bonus de portée (m)", "range_bonus", -25.0, 100.0)
    _add_text_field(grid, "Couleur HTML", "color")
    var semantics: Label = Label.new()
    semantics.text = "Techniques : durée de la cinématique. Tactiques et Résonances : durée en jeu. Karma : maintien limité par les PE."
    semantics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    semantics.add_theme_font_size_override("font_size", 13)
    semantics.add_theme_color_override("font_color", Color("9dafc3"))
    parameters.add_child(semantics)
    _add_label(parameters, "Description")
    var description: TextEdit = TextEdit.new()
    description.name = "Description"
    description.custom_minimum_size.y = 86
    description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    description.text_changed.connect(_mark_dirty)
    _fields["description"] = description
    parameters.add_child(description)
    _build_mechanic_fields(editor)
    var advanced: VBoxContainer = _card(editor, "Advanced", 16)
    _section_heading(advanced, "03", "Propriétés avancées")
    var properties_help: Label = Label.new()
    properties_help.text = "Les propriétés personnalisées sont conservées. Les champs dédiés modifiés priment jusqu’à validation. Charger le JSON reprend les valeurs saisies ici."
    properties_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    properties_help.add_theme_font_size_override("font_size", 13)
    properties_help.add_theme_color_override("font_color", Color("9dafc3"))
    advanced.add_child(properties_help)
    var properties: TextEdit = TextEdit.new()
    properties.name = "Properties"
    properties.custom_minimum_size.y = 190
    properties.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    properties.add_theme_font_size_override("font_size", 13)
    properties.text_changed.connect(_mark_dirty)
    _fields["properties"] = properties
    advanced.add_child(properties)
    _add_button(advanced, "Charger le JSON dans les champs", _sync_from_json)
    var footer: VBoxContainer = _card(layout, "Actions", 12)
    var actions: HFlowContainer = HFlowContainer.new()
    actions.add_theme_constant_override("h_separation", 10)
    actions.add_theme_constant_override("v_separation", 6)
    footer.add_child(actions)
    var save_button: Button = Button.new()
    save_button.text = "Sauvegarder le catalogue"
    save_button.add_theme_color_override("font_color", Color("4bd9c3"))
    save_button.pressed.connect(_save)
    actions.add_child(save_button)
    _add_button(actions, "Valider & actualiser l’aperçu", _apply_preview)
    _add_button(actions, "Recharger", _request_reload)
    _add_button(actions, "Valeurs d’origine", _request_restore)
    _status = Label.new()
    _status.custom_minimum_size.y = 32
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.add_theme_font_size_override("font_size", 12)
    footer.add_child(_status)
    _restore_dialog = ConfirmationDialog.new()
    _restore_dialog.title = "Rétablir tous les contenus intégrés ?"
    _restore_dialog.dialog_text = "Les modifications locales sauvegardées et non sauvegardées seront supprimées."
    _restore_dialog.confirmed.connect(_restore)
    add_child(_restore_dialog)
    _reload_dialog = ConfirmationDialog.new()
    _reload_dialog.title = "Recharger les contenus ?"
    _reload_dialog.dialog_text = "Les modifications non sauvegardées seront abandonnées."
    _reload_dialog.confirmed.connect(_reload)
    add_child(_reload_dialog)
    _list.grab_focus()

func _card(parent: Node, node_name: String, padding: int) -> VBoxContainer:
    var panel: PanelContainer = PanelContainer.new()
    panel.name = node_name
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("132237")
    style.border_color = Color("2b4057")
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(padding)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    return box

func _section_heading(parent: Node, number: String, title: String) -> void:
    var label: Label = Label.new()
    label.text = number + "  /  " + title
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 17)
    label.add_theme_color_override("font_color", Color("e5af65"))
    parent.add_child(label)

func _build_mechanic_fields(parent: Node) -> void:
    var karma: GridContainer = _mechanic_section(parent, "KARMA", "Karma — réserves et affrontements")
    _add_property_number(karma, "PG maximum", "pg_max", 1.0, 1000.0)
    _add_property_number(karma, "PE maximum", "pe_max", 1.0, 1000.0)
    _add_property_number(karma, "PE / seconde", "pe_drain", 0.0, 100.0)
    _add_property_number(karma, "PE sprint / seconde", "sprint_pe_drain", 0.0, 100.0)
    _add_property_number(karma, "PG / duel ordinaire", "duel_pg_cost", 0.0, 1000.0)
    _add_property_number(karma, "PE / duel ordinaire", "duel_pe_cost", 0.0, 1000.0)
    _add_property_number(karma, "PG perdus si défaite", "defeat_pg_cost", 0.0, 1000.0)
    _add_property_choice(karma, "Technique exclusive", "signature_id")
    _add_property_list(karma, "Propriétaires (clés séparées par ,)", "owner_keys")
    for key: String in STAT_LABELS:
        _add_property_number(karma, "Bonus " + String(STAT_LABELS[key]), "stat_bonuses." + key, 0.0, 100.0)
    var signature: GridContainer = _mechanic_section(parent, "SIGNATURE", "Technique exclusive — réservée à son Karma")
    _add_property_choice(signature, "Karma propriétaire", "karma_id")
    _add_property_number(signature, "Coût PG", "pg_cost", 0.0, 1000.0)
    _add_property_number(signature, "Coût PE", "pe_cost", 0.0, 1000.0)
    var resonance: GridContainer = _mechanic_section(parent, "RESONANCE", "Résonance — donneur, deux techniques et héritage")
    _add_property_text(resonance, "Clé du donneur", "donor_key")
    _add_property_number(resonance, "Ratio des stats (0–1)", "blend", 0.0, 1.0, 0.01)
    _add_property_choice(resonance, "Technique héritée 1", "inherited_techniques.0")
    _add_property_choice(resonance, "Technique héritée 2", "inherited_techniques.1")
    _add_property_choice(resonance, "Karma héritable", "inherited_karma_id")
    _add_label(resonance, "Statistiques transmises")
    var stat_box: HFlowContainer = HFlowContainer.new()
    stat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resonance.add_child(stat_box)
    for key: String in STAT_LABELS:
        var check: CheckBox = CheckBox.new()
        check.name = "Inherited" + key.to_pascal_case()
        check.text = String(STAT_LABELS[key])
        check.toggled.connect(func(_value: bool) -> void: _stat_selection_changed())
        stat_box.add_child(check)
        _stat_checks[key] = check
    var appearance: GridContainer = _mechanic_section(parent, "APPEARANCE", "Apparence de la transformation")
    _add_property_text(appearance, "Style visuel (identifiant)", "appearance.style")
    _add_property_text(appearance, "Couleur principale HTML", "appearance.primary")
    _add_property_text(appearance, "Couleur secondaire HTML", "appearance.accent")
    _add_property_text(appearance, "Motif", "appearance.motif")
    _add_property_text(appearance, "Description visuelle", "appearance.description")
    var rules: Label = Label.new()
    rules.text = "Propriétaires / donneur : soren_vale (Azur n° 7), maelle_neris (Azur n° 1), azur_02 à azur_11 pour les autres profils (hors n° 7). Un Karma hérité doit appartenir au donneur. Les PG / PE ne se rechargent pas en désactivant un Karma. Le rôle gardien reste requis pour GAR. Les anciens prototypes restent éditables dans le JSON."
    rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules.add_theme_font_size_override("font_size", 14)
    parent.add_child(rules)

func _mechanic_section(parent: Node, key: String, title: String) -> GridContainer:
    var section: VBoxContainer = _card(parent, key.to_pascal_case() + "Section", 16)
    _section_heading(section, "02", title)
    var grid: GridContainer = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 10)
    section.add_child(grid)
    _mechanic_sections[key] = section.get_parent()
    return grid

func _add_property_number(parent: Node, title: String, path: String, minimum: float, maximum: float, increment: float = 0.1) -> void:
    _add_label(parent, title)
    var field: SpinBox = SpinBox.new()
    field.name = path.replace(".", "_").to_pascal_case()
    field.min_value = minimum
    field.max_value = maximum
    field.step = increment
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.value_changed.connect(func(value: float) -> void: _property_changed(path, value))
    _mechanic_fields[path] = field
    parent.add_child(field)

func _add_property_text(parent: Node, title: String, path: String) -> void:
    _add_label(parent, title)
    var field: LineEdit = LineEdit.new()
    field.name = path.replace(".", "_").to_pascal_case()
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.custom_minimum_size.x = 140
    field.text_changed.connect(func(value: String) -> void: _property_changed(path, value))
    _mechanic_fields[path] = field
    parent.add_child(field)

func _add_property_list(parent: Node, title: String, path: String) -> void:
    _add_label(parent, title)
    var field: LineEdit = LineEdit.new()
    field.name = path.replace(".", "_").to_pascal_case()
    field.set_meta("csv_list", true)
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.text_changed.connect(func(value: String) -> void:
        var values: Array[String] = []
        for raw: String in value.split(",", false):
            var key: String = raw.strip_edges()
            if not key.is_empty() and not values.has(key):
                values.append(key)
        _property_changed(path, values))
    _mechanic_fields[path] = field
    parent.add_child(field)

func _add_property_choice(parent: Node, title: String, path: String) -> void:
    _add_label(parent, title)
    var field: OptionButton = OptionButton.new()
    field.fit_to_longest_item = false
    field.clip_text = true
    field.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    field.custom_minimum_size.x = 180
    field.name = path.replace(".", "_").to_pascal_case()
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.item_selected.connect(func(index: int) -> void:
        if path.begins_with("inherited_techniques."):
            _inherited_selection_changed()
        else:
            _property_changed(path, String(field.get_item_metadata(index))))
    _mechanic_fields[path] = field
    parent.add_child(field)

func _property_changed(path: String, value: Variant) -> void:
    if _loading:
        return
    _mechanic_edits[path] = value
    _mark_dirty()

func _inherited_selection_changed() -> void:
    var inherited: Array[String] = []
    for key: String in ["inherited_techniques.0", "inherited_techniques.1"]:
        var field: OptionButton = _mechanic_fields[key]
        inherited.append(String(field.get_item_metadata(field.selected)) if field.selected >= 0 else "")
    _property_changed("inherited_techniques", inherited)

func _stat_selection_changed() -> void:
    var stats: Array[String] = []
    for key: String in _stat_checks:
        if _stat_checks[key].button_pressed:
            stats.append(key)
    _property_changed("stat_keys", stats)

func _refresh_mechanic_sections(category: String, properties: Dictionary = {}) -> void:
    _mechanic_sections["KARMA"].visible = category == "KARMA"
    _mechanic_sections["RESONANCE"].visible = category == "RESONANCE"
    _mechanic_sections["SIGNATURE"].visible = properties.has("karma_id") or properties.has("pg_cost") or properties.has("pe_cost")
    _mechanic_sections["APPEARANCE"].visible = category in ["KARMA", "RESONANCE"]

func _load_mechanic_fields(properties: Dictionary) -> void:
    var was_loading: bool = _loading
    _loading = true
    for path: String in _mechanic_fields:
        var field: Control = _mechanic_fields[path]
        var value: Variant = _property_value(properties, path)
        if field is SpinBox:
            field.value = float(value) if value is float or value is int else field.min_value
        elif field is LineEdit:
            if field.get_meta("csv_list", false):
                field.text = ", ".join(value) if value is Array else ""
            else:
                field.text = str(value) if value != null else ""
        elif field is OptionButton:
            _populate_reference(field, path, str(value) if value != null else "")
    var stat_keys: Variant = properties.get("stat_keys", [])
    for key: String in _stat_checks:
        _stat_checks[key].button_pressed = stat_keys is Array and stat_keys.has(key)
    var category: String = Catalog.CATEGORIES[_fields["category"].selected]
    _refresh_mechanic_sections(category, properties)
    _loading = was_loading

func _populate_reference(field: OptionButton, path: String, current: String) -> void:
    field.clear()
    field.add_item("— Aucun —")
    field.set_item_metadata(0, "")
    var selected: int = 0
    for entry: Dictionary in _entries:
        var category: String = str(entry["category"])
        var is_karma_field: bool = path in ["karma_id", "inherited_karma_id"]
        if is_karma_field and category != "KARMA":
            continue
        if not is_karma_field and category not in ["TIR", "ATT", "DEF", "GAR"]:
            continue
        # Les deux techniques d'une Résonance restent des techniques ordinaires.
        if path.begins_with("inherited_techniques.") and entry.get("properties", {}).has("karma_id"):
            continue
        field.add_item("%s [%s]" % [entry["name"], entry["id"]])
        var index: int = field.item_count - 1
        field.set_item_metadata(index, str(entry["id"]))
        if str(entry["id"]) == current:
            selected = index
    if not current.is_empty() and selected == 0:
        field.add_item("Référence absente : " + current)
        selected = field.item_count - 1
        field.set_item_metadata(selected, current)
    field.select(selected)

func _property_value(properties: Dictionary, path: String) -> Variant:
    var value: Variant = properties
    for segment: String in path.split("."):
        if value is Dictionary:
            value = value.get(segment)
        elif value is Array and segment.is_valid_int() and int(segment) < value.size():
            value = value[int(segment)]
        else:
            return null
    return value

func _assign_property(properties: Dictionary, path: String, value: Variant) -> void:
    var parts: PackedStringArray = path.split(".")
    var target: Dictionary = properties
    for index: int in range(parts.size() - 1):
        var key: String = parts[index]
        if not target.get(key) is Dictionary:
            target[key] = {}
        target = target[key]
    target[parts[-1]] = value

func _sync_from_json() -> void:
    var parser: JSON = JSON.new()
    if parser.parse(_fields["properties"].text) != OK or not parser.data is Dictionary:
        _set_status("Le JSON doit être un objet valide avant de charger les champs dédiés.", true)
        return
    _mechanic_edits.clear()
    _load_mechanic_fields(parser.data)
    _mark_dirty()
    _set_status("Champs dédiés actualisés depuis le JSON. Validez pour vérifier la fiche.")

func _add_label(parent: Node, title: String) -> void:
    var label: Label = Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 13)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size.x = 150
    label.add_theme_color_override("font_color", Color("b8c5d5"))
    parent.add_child(label)

func _add_text_field(parent: Node, title: String, key: String, read_only: bool = false) -> void:
    _add_label(parent, title)
    var field: LineEdit = LineEdit.new()
    field.name = key.to_pascal_case()
    field.editable = not read_only
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.custom_minimum_size.x = 140
    field.text_changed.connect(func(_value: String) -> void: _mark_dirty())
    _fields[key] = field
    parent.add_child(field)

func _add_number_field(parent: Node, title: String, key: String, minimum: float, maximum: float) -> void:
    _add_label(parent, title)
    var field: SpinBox = SpinBox.new()
    field.name = key.to_pascal_case()
    field.min_value = minimum
    field.max_value = maximum
    field.step = 0.1
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field.value_changed.connect(func(_value: float) -> void: _mark_dirty())
    _fields[key] = field
    parent.add_child(field)

func _add_button(parent: Node, title: String, callback: Callable) -> void:
    var button: Button = Button.new()
    button.text = title
    button.pressed.connect(callback)
    parent.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
        _open_match()
        get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _list.grab_focus()
        get_viewport().set_input_as_handled()

func _rebuild_list() -> void:
    _list.clear()
    _visible_indices.clear()
    var query: String = _search.text.strip_edges().to_lower() if _search != null else ""
    var selected_category: String = str(_filter.get_item_metadata(_filter.selected)) if _filter != null else ""
    for index: int in range(_entries.size()):
        var entry: Dictionary = _entries[index]
        if not selected_category.is_empty() and str(entry["category"]) != selected_category:
            continue
        if not query.is_empty() and not (str(entry["name"]) + " " + str(entry["id"])).to_lower().contains(query):
            continue
        _visible_indices.append(index)
        _list.add_item(str(entry["name"]))
        _list.set_item_tooltip(_list.item_count - 1, "[%s] %s\n%s" % [entry["category"], entry["name"], entry["description"]])
        _list.set_item_custom_fg_color(_list.item_count - 1, Color("e5af65") if str(entry["category"]) == "KARMA" else (Color("4bd9c3") if str(entry["category"]) == "RESONANCE" else Color("f4f0df")))
    if _count_label != null:
        _count_label.text = "%d / %d fiches" % [_visible_indices.size(), _entries.size()]
    var visible_index: int = _visible_indices.find(_selected)
    if visible_index >= 0:
        _list.select(visible_index)

func _filter_changed() -> void:
    if not _try_apply_edits():
        return
    _rebuild_list()

func _select_entry(index: int) -> void:
    if index < 0 or index >= _visible_indices.size():
        return
    var target: int = _visible_indices[index]
    if not _try_apply_edits():
        var previous: int = _visible_indices.find(_selected)
        if previous >= 0:
            _list.select(previous)
        return
    _show_entry(target)

func _update_identity(entry: Dictionary) -> void:
    _entry_title.text = str(entry["name"])
    _entry_badge.text = str(entry["category"])
    var props: Dictionary = entry.get("properties", {})
    match str(entry["category"]):
        "KARMA":
            var signature: Dictionary = _find_definition(str(props.get("signature_id", "")))
            _entry_summary.text = "%s PG  /  %s PE  •  %s" % [props.get("pg_max", "—"), props.get("pe_max", "—"), signature.get("name", "Technique exclusive")]
        "RESONANCE":
            var inherited: Array[String] = []
            for id: Variant in props.get("inherited_techniques", []):
                inherited.append(str(_find_definition(str(id)).get("name", id)))
            _entry_summary.text = "%s  •  %s s  •  %s" % [props.get("donor_key", "Donneur"), entry.get("duration", 0), " + ".join(inherited)]
        _:
            _entry_summary.text = "Puissance %s  •  Endurance %s  •  %s" % [entry.get("power", 0), entry.get("cost", 0), "Technique exclusive" if props.has("karma_id") else "Technique de match"]

func _show_entry(index: int) -> void:
    if index < 0 or index >= _entries.size():
        return
    _selected = index
    _loading = true
    var entry: Dictionary = _entries[index]
    for key: String in ["id", "name", "effect", "color", "description"]:
        _fields[key].text = String(entry[key])
    for key: String in ["power", "cost", "duration", "range_bonus"]:
        _fields[key].value = float(entry[key])
    _fields["category"].select(Catalog.CATEGORIES.find(String(entry["category"])))
    _fields["properties"].text = JSON.stringify(entry["properties"], "  ")
    _mechanic_edits.clear()
    _load_mechanic_fields(entry["properties"])
    _loading = false
    var visible_index: int = _visible_indices.find(index)
    if visible_index >= 0:
        _list.select(visible_index)
        _list.ensure_current_is_visible()
    _update_identity(entry)
    _preview.set_definition(entry)

func _try_apply_edits() -> bool:
    if _selected < 0:
        return true
    var entry: Dictionary = _entries[_selected].duplicate(true)
    for key: String in ["name", "effect", "color", "description"]:
        entry[key] = _fields[key].text
    for key: String in ["power", "cost", "duration", "range_bonus"]:
        entry[key] = float(_fields[key].value)
    entry["category"] = Catalog.CATEGORIES[_fields["category"].selected]
    var parser: JSON = JSON.new()
    var result: Error = parser.parse(_fields["properties"].text)
    if result != OK:
        _set_status("Propriétés JSON invalides, ligne %d : %s" % [parser.get_error_line(), parser.get_error_message()], true)
        return false
    if not parser.data is Dictionary:
        _set_status("Les propriétés JSON doivent être un objet : { ... }.", true)
        return false
    var properties: Dictionary = parser.data
    for path: String in _mechanic_edits:
        _assign_property(properties, path, _mechanic_edits[path])
    entry["properties"] = properties
    var references: Dictionary = {}
    for known: Dictionary in _entries:
        references[str(known["id"])] = known
    references[str(entry["id"])] = entry
    var errors: PackedStringArray = catalog.validate_definition(entry, references)
    if not errors.is_empty():
        _set_status("\n".join(errors), true)
        return false
    _entries[_selected] = entry
    _loading = true
    _fields["properties"].text = JSON.stringify(properties, "  ")
    _mechanic_edits.clear()
    _load_mechanic_fields(properties)
    _loading = false
    _rebuild_list()
    _update_identity(entry)
    return true

func _mark_dirty() -> void:
    if not _loading:
        _dirty = true
        if _dirty_badge != null:
            _dirty_badge.text = "●  NON SAUVEGARDÉ"
            _dirty_badge.add_theme_color_override("font_color", Color("e5af65"))
        if _status != null:
            _set_status("Modifications non sauvegardées. Validez la fiche pour actualiser l'aperçu.")

func _apply_preview() -> void:
    if _try_apply_edits():
        _preview.set_definition(_entries[_selected])
        _set_status("Fiche valide. Sauvegardez pour appliquer ces valeurs aux prochains matchs.")

func _replay_preview() -> void:
    if _try_apply_edits():
        _preview.set_definition(_entries[_selected])

func _save() -> void:
    if not _try_apply_edits():
        return
    var result: Error = catalog.save_overrides(_entries)
    if result == OK:
        _dirty = false
        _set_status("Sauvegardé : user://match_content.json. Les nouveaux matchs chargeront ces contenus ; le match en cours conserve ses règles.")
    else:
        _set_status("Sauvegarde refusée :\n" + "\n".join(catalog.last_errors), true)

func _request_reload() -> void:
    if _dirty:
        _reload_dialog.popup_centered()
    else:
        _reload()

func _reload() -> void:
    var result: Error = catalog.load_overrides()
    if result != OK:
        _set_status("Rechargement refusé, fiches actuelles conservées :\n" + "\n".join(catalog.last_errors), true)
        return
    var selected_id: String = String(_entries[_selected]["id"]) if _selected >= 0 else ""
    _entries = catalog.all_definitions()
    _dirty = false
    _rebuild_list()
    var target: int = 0
    for index: int in range(_entries.size()):
        if String(_entries[index]["id"]) == selected_id:
            target = index
    _show_entry(target)
    if not catalog.last_notices.is_empty():
        _set_status("Rechargé et migré sans écraser le fichier. " + " ".join(catalog.last_notices))
    else:
        _set_status("Contenus rechargés depuis la sauvegarde locale.")

func _request_restore() -> void:
    _restore_dialog.popup_centered()

func _restore() -> void:
    if catalog.reset_overrides() != OK:
        _set_status("\n".join(catalog.last_errors), true)
        return
    _entries = catalog.all_definitions()
    _dirty = false
    _rebuild_list()
    _show_entry(0)
    _set_status("Contenus intégrés rétablis. La sauvegarde locale a été supprimée.")

func _duplicate_entry() -> void:
    if not _try_apply_edits():
        return
    var entry: Dictionary = _entries[_selected].duplicate(true)
    var id: String = _unique_id(str(entry["id"]))
    entry["id"] = id
    entry["name"] = String(entry["name"]).left(72) + " (copie)"
    var candidates: Array[Dictionary] = _entries.duplicate(true)
    candidates.append(entry)
    var copied_signature: bool = false
    if str(entry["category"]) == "KARMA":
        var source_signature: String = str(entry["properties"].get("signature_id", ""))
        var signature: Dictionary = _find_definition(source_signature)
        if signature.is_empty():
            _set_status("Copie impossible : la technique exclusive du Karma est absente.", true)
            return
        signature = signature.duplicate(true)
        var signature_id: String = _unique_id(id.left(52) + "_signature")
        signature["id"] = signature_id
        signature["name"] = str(signature["name"]).left(72) + " (copie)"
        signature["properties"]["karma_id"] = id
        entry["properties"]["signature_id"] = signature_id
        candidates.append(signature)
        copied_signature = true
    var errors: PackedStringArray = catalog.validate_entries(candidates)
    if not errors.is_empty():
        _set_status("Copie refusée, fiches conservées :\n" + "\n".join(errors), true)
        return
    var selected_copy: int = _entries.size()
    _entries = candidates
    _dirty = true
    _rebuild_list()
    _show_entry(selected_copy)
    _set_status("Copie locale créée : " + id + (", avec sa propre technique exclusive." if copied_signature else ".") + " Sauvegardez pour la conserver.")

func _unique_id(base: String) -> String:
    var stem: String = base.left(52) + "_copy"
    var id: String = stem
    var suffix: int = 2
    while _has_id(id):
        id = stem + "_" + str(suffix)
        suffix += 1
    return id

func _find_definition(id: String) -> Dictionary:
    for entry: Dictionary in _entries:
        if str(entry["id"]) == id:
            return entry
    return {}

func _has_id(id: String) -> bool:
    for entry: Dictionary in _entries:
        if String(entry["id"]) == id:
            return true
    return false

func _open_match() -> void:
    if _dirty:
        _set_status("Sauvegardez ou rechargez vos modifications avant d'ouvrir le match.", true)
        return
    if embedded_mode:
        match_requested.emit()
        return
    if ResourceLoader.exists("res://scenes/full_match.tscn"):
        get_tree().change_scene_to_file("res://scenes/full_match.tscn")
    else:
        _set_status("Scène scenes/full_match.tscn indisponible. L'atelier fonctionne indépendamment.", true)

func _set_status(message: String, is_error: bool = false) -> void:
    _status.text = message
    if _dirty_badge != null:
        _dirty_badge.text = "●  NON SAUVEGARDÉ" if _dirty else "✓  CATALOGUE À JOUR"
        _dirty_badge.add_theme_color_override("font_color", VisualTheme.GOLD if _dirty else VisualTheme.AQUA)
    _status.add_theme_color_override("font_color", Color("ff9c9c") if is_error else Color("a9e1c2"))
