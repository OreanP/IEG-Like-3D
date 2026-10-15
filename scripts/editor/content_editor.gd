extends Control
## Atelier autonome : edition de copies, validation puis sauvegarde locale atomique.
const Catalog = preload("res://core/content/technique_catalog.gd")
const Preview = preload("res://scripts/editor/technique_preview.gd")

signal match_requested
@export var embedded_mode: bool = false

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

func _ready() -> void:
    catalog = Catalog.new()
    _entries = catalog.all_definitions()
    _build_ui()
    _rebuild_list()
    if not _entries.is_empty():
        _show_entry(0)
    if not catalog.last_errors.is_empty():
        _set_status("Le fichier local n'a pas été chargé. Les contenus intégrés restent disponibles.\n" + "\n".join(catalog.last_errors), true)
    else:
        _set_status("Contenus intégrés chargés. Modifiez une fiche, puis sauvegardez pour les prochains matchs.")

func _build_ui() -> void:
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color("111b2d")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 18)
    add_child(margin)
    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 10)
    margin.add_child(layout)
    var title: Label = Label.new()
    title.text = "ATELIER DU MATCH — Techniques, tactiques et augmentations"
    title.add_theme_font_size_override("font_size", 24)
    layout.add_child(title)
    var help: Label = Label.new()
    help.text = "Manette : croix / stick = navigation, A = valider, B = quitter un champ. Clavier : Tab, flèches, Entrée. Souris : clic. F5 : retour au match."
    help.add_theme_font_size_override("font_size", 14)
    layout.add_child(help)
    var content: HBoxContainer = HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 18)
    layout.add_child(content)
    var sidebar: VBoxContainer = VBoxContainer.new()
    sidebar.custom_minimum_size.x = 265
    content.add_child(sidebar)
    _list = ItemList.new()
    _list.name = "ContentList"
    _list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _list.select_mode = ItemList.SELECT_SINGLE
    _list.item_selected.connect(_select_entry)
    sidebar.add_child(_list)
    _add_button(sidebar, "Dupliquer la fiche", _duplicate_entry)
    _add_button(sidebar, "Retour au match (F5)" if embedded_mode else "Ouvrir le match (F5)", _open_match)
    var editor_scroll: ScrollContainer = ScrollContainer.new()
    editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor_scroll.follow_focus = true
    content.add_child(editor_scroll)
    var editor: VBoxContainer = VBoxContainer.new()
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.add_theme_constant_override("separation", 8)
    editor_scroll.add_child(editor)
    var preview_row: HBoxContainer = HBoxContainer.new()
    editor.add_child(preview_row)
    _preview = Preview.new()
    _preview.custom_minimum_size = Vector2(440, 215)
    _preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_row.add_child(_preview)
    var preview_controls: VBoxContainer = VBoxContainer.new()
    preview_row.add_child(preview_controls)
    _add_button(preview_controls, "Rejouer", _replay_preview)
    var failure: CheckButton = CheckButton.new()
    failure.text = "Échec gardien"
    failure.toggled.connect(func(value: bool) -> void:
        _preview.set_failure(value))
    preview_controls.add_child(failure)
    var note: Label = Label.new()
    note.text = "Aperçu 3D procédural.\nLes deux issues GAR\npartagent la préparation."
    preview_controls.add_child(note)
    var grid: GridContainer = GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 8)
    editor.add_child(grid)
    _add_text_field(grid, "Identifiant", "id", true)
    _add_text_field(grid, "Nom", "name")
    _add_label(grid, "Catégorie")
    var category: OptionButton = OptionButton.new()
    category.name = "Category"
    category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for item: String in Catalog.CATEGORIES:
        category.add_item(item)
    category.item_selected.connect(func(_index: int) -> void: _mark_dirty())
    _fields["category"] = category
    grid.add_child(category)
    _add_text_field(grid, "Effet visuel", "effect")
    _add_number_field(grid, "Puissance", "power", 0.0, 500.0)
    _add_number_field(grid, "Coût endurance", "cost", 0.0, 100.0)
    _add_number_field(grid, "Durée (s)", "duration", 0.1, 600.0)
    _add_number_field(grid, "Bonus portée (m)", "range_bonus", -25.0, 100.0)
    _add_text_field(grid, "Couleur HTML", "color")
    var semantics: Label = Label.new()
    semantics.text = "Durée = cinématique pour une technique ; effet en jeu pour TAC / Écho / Résonance."
    semantics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    editor.add_child(semantics)
    _add_label(editor, "Description")
    var description: TextEdit = TextEdit.new()
    description.name = "Description"
    description.custom_minimum_size.y = 78
    description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    description.text_changed.connect(_mark_dirty)
    _fields["description"] = description
    editor.add_child(description)
    _add_label(editor, "Propriétés JSON — TAC : width_factor / pressure ; Écho : energy_max / energy_drain ; Résonance : profile_a / profile_b / blend")
    var properties: TextEdit = TextEdit.new()
    properties.name = "Properties"
    properties.custom_minimum_size.y = 160
    properties.text_changed.connect(_mark_dirty)
    _fields["properties"] = properties
    editor.add_child(properties)
    var actions: HBoxContainer = HBoxContainer.new()
    layout.add_child(actions)
    _add_button(actions, "Valider / aperçu", _apply_preview)
    _add_button(actions, "Sauvegarder", _save)
    _add_button(actions, "Recharger", _request_reload)
    _add_button(actions, "Rétablir les valeurs intégrées", _request_restore)
    _status = Label.new()
    _status.custom_minimum_size.y = 56
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(_status)
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

func _add_label(parent: Node, title: String) -> void:
    var label: Label = Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 14)
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
    for entry: Dictionary in _entries:
        _list.add_item("[%s] %s" % [entry["category"], entry["name"]])
        _list.set_item_tooltip(_list.item_count - 1, String(entry["description"]))

func _select_entry(index: int) -> void:
    if not _try_apply_edits():
        _list.select(_selected)
        return
    _show_entry(index)

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
    _loading = false
    _list.select(index)
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
    entry["properties"] = parser.data
    var errors: PackedStringArray = catalog.validate_definition(entry)
    if not errors.is_empty():
        _set_status("\n".join(errors), true)
        return false
    _entries[_selected] = entry
    _list.set_item_text(_selected, "[%s] %s" % [entry["category"], entry["name"]])
    _list.set_item_tooltip(_selected, String(entry["description"]))
    return true

func _mark_dirty() -> void:
    if not _loading:
        _dirty = true
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
    var suffix: int = 1
    var id: String = "custom_" + str(suffix)
    while _has_id(id):
        suffix += 1
        id = "custom_" + str(suffix)
    entry["id"] = id
    entry["name"] = String(entry["name"]).left(72) + " (copie)"
    _entries.append(entry)
    _dirty = true
    _rebuild_list()
    _show_entry(_entries.size() - 1)
    _set_status("Copie locale créée : " + id + ". Sauvegardez pour la conserver.")

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
    _status.add_theme_color_override("font_color", Color("ff9c9c") if is_error else Color("a9e1c2"))
