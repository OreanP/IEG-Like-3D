extends RefCounted
## Contrats de l'atelier réel : champs, liens, copies et sauvegarde isolée.
const Editor = preload("res://scripts/editor/content_editor.gd")
const Catalog = preload("res://core/content/technique_catalog.gd")
var _path: String = "user://test_editor_%d.json" % OS.get_process_id()
var _editor: Control

func run_all() -> Dictionary:
    var cases: Array[Callable] = [_karma_fields_loaded, _resonance_fields_loaded,
        _contextual_sections, _dedicated_edit_preserves_custom_json,
        _advanced_json_preserved, _invalid_json_preserves_entry,
        _invalid_resource_preserves_entry, _explicit_json_sync,
        _inheritance_controls, _stat_selection, _owner_keys_editing, _appearance_palette_editing,
        _duplicate_karma_clones_signature, _duplicate_karma_save_roundtrip, _duplicate_twice_keeps_unique_ids,
        _duplicate_signature_remains_linked, _duplicate_resonance_is_independent,
        _save_reload_restore, _invalid_graph_preserves_saved_file,
        _embedded_return, _unsaved_edits_block_return]
    var lines: Array[String] = []
    var passed: int = 0
    for test: Callable in cases:
        _cleanup()
        _editor = Editor.new()
        _editor.storage_path = _path
        _editor.embedded_mode = true
        (Engine.get_main_loop() as SceneTree).root.add_child(_editor)
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "ATELIER : " + String(test.get_method()))
        _editor.free()
        _editor = null
    _cleanup()
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func _cleanup() -> void:
    for path: String in [_path, _path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _select(id: String) -> bool:
    for index: int in range(_editor._entries.size()):
        if str(_editor._entries[index]["id"]) == id:
            _editor._show_entry(index)
            return true
    return false

func _entry() -> Dictionary:
    return _editor._entries[_editor._selected]

func _choose(path: String, id: String) -> bool:
    var field: OptionButton = _editor._mechanic_fields[path]
    for index: int in range(field.item_count):
        if str(field.get_item_metadata(index)) == id:
            field.select(index)
            field.item_selected.emit(index)
            return true
    return false

func _karma_fields_loaded() -> bool:
    if not _select("astreion"):
        return false
    return _editor._mechanic_fields["pg_max"].value == 240.0 and _editor._mechanic_fields["pe_max"].value == 80.0 and _editor._mechanic_fields["duel_pg_cost"].value == 10.0 and _editor._mechanic_edits.is_empty() and not _editor._dirty

func _resonance_fields_loaded() -> bool:
    if not _select("sovereign_orbit"):
        return false
    var field: OptionButton = _editor._mechanic_fields["inherited_karma_id"]
    return _editor._mechanic_fields["donor_key"].text == "soren_vale" and is_equal_approx(_editor._mechanic_fields["blend"].value, 0.2) and str(field.get_item_metadata(field.selected)) == "astreion" and _editor._stat_checks["shot"].button_pressed and not _editor._stat_checks["keeper"].button_pressed

func _contextual_sections() -> bool:
    if not _select("astreion") or not _editor._mechanic_sections["KARMA"].visible or _editor._mechanic_sections["RESONANCE"].visible:
        return false
    if not _select("deep_watch") or _editor._mechanic_sections["KARMA"].visible or not _editor._mechanic_sections["RESONANCE"].visible:
        return false
    return _select("abyssal_cathedral") and _editor._mechanic_sections["SIGNATURE"].visible and not _editor._mechanic_sections["APPEARANCE"].visible

func _dedicated_edit_preserves_custom_json() -> bool:
    if not _select("astreion"):
        return false
    var properties: Dictionary = _entry()["properties"].duplicate(true)
    properties["custom_rule"] = {"nested": [1, "keep", true]}
    properties["appearance"]["artist_note"] = "Conserver ce détail"
    _editor._fields["properties"].text = JSON.stringify(properties)
    _editor._mechanic_fields["pg_max"].value = 260.0
    _editor._mechanic_fields["appearance.description"].text = "Forge et anneaux de cuivre"
    _editor._mechanic_fields["appearance.description"].text_changed.emit("Forge et anneaux de cuivre")
    return _editor._try_apply_edits() and _entry()["properties"]["pg_max"] == 260.0 and _entry()["properties"]["custom_rule"]["nested"][1] == "keep" and _entry()["properties"]["appearance"]["artist_note"] == "Conserver ce détail" and _entry()["properties"]["appearance"]["description"] == "Forge et anneaux de cuivre"

func _advanced_json_preserved() -> bool:
    if not _select("sovereign_orbit"):
        return false
    var properties: Dictionary = _entry()["properties"].duplicate(true)
    properties["blend"] = 0.25
    properties["custom"] = {"enabled": true}
    _editor._fields["properties"].text = JSON.stringify(properties)
    return _editor._try_apply_edits() and _entry()["properties"]["blend"] == 0.25 and _entry()["properties"]["custom"]["enabled"] and _editor._mechanic_fields["blend"].value == 0.25

func _invalid_json_preserves_entry() -> bool:
    if not _select("astreion"):
        return false
    var before: Dictionary = _entry().duplicate(true)
    _editor._fields["properties"].text = "{invalide"
    if _editor._try_apply_edits() or _entry() != before:
        return false
    _editor._fields["properties"].text = "[]"
    return not _editor._try_apply_edits() and _entry() == before

func _invalid_resource_preserves_entry() -> bool:
    if not _select("astreion"):
        return false
    var before: Dictionary = _entry().duplicate(true)
    var properties: Dictionary = before["properties"].duplicate(true)
    properties["pg_max"] = -5.0
    _editor._fields["properties"].text = JSON.stringify(properties)
    return not _editor._try_apply_edits() and _entry() == before

func _explicit_json_sync() -> bool:
    if not _select("astreion"):
        return false
    _editor._mechanic_fields["pg_max"].value = 260.0
    var properties: Dictionary = _entry()["properties"].duplicate(true)
    properties["pg_max"] = 280.0
    _editor._fields["properties"].text = JSON.stringify(properties)
    _editor._sync_from_json()
    return _editor._mechanic_edits.is_empty() and _editor._mechanic_fields["pg_max"].value == 280.0 and _editor._try_apply_edits() and _entry()["properties"]["pg_max"] == 280.0

func _inheritance_controls() -> bool:
    if not _select("sovereign_orbit") or not _choose("inherited_techniques.0", "combat_blade") or not _choose("inherited_techniques.1", "orbital_shot"):
        return false
    if not _editor._try_apply_edits():
        return false
    return _entry()["properties"]["inherited_techniques"] == ["combat_blade", "orbital_shot"] and _editor.catalog.validate_entries(_editor._entries).is_empty()

func _stat_selection() -> bool:
    if not _select("deep_watch"):
        return false
    _editor._stat_checks["keeper"].button_pressed = false
    _editor._stat_checks["shot"].button_pressed = true
    return _editor._try_apply_edits() and not _entry()["properties"]["stat_keys"].has("keeper") and _entry()["properties"]["stat_keys"].has("shot")

func _owner_keys_editing() -> bool:
    if not _select("astreion"):
        return false
    var field: LineEdit = _editor._mechanic_fields["owner_keys"]
    field.text = "soren_vale, azur_03, soren_vale, , azur_09"
    field.text_changed.emit(field.text)
    if not _editor._try_apply_edits():
        return false
    _editor._duplicate_entry()
    _editor._save()
    return not _editor._dirty and _entry()["properties"]["owner_keys"] == ["soren_vale", "azur_03", "azur_09"] and field.text == "soren_vale, azur_03, azur_09"

func _appearance_palette_editing() -> bool:
    if not _select("thalassa"):
        return false
    for path: String in ["appearance.primary", "appearance.accent"]:
        var field: LineEdit = _editor._mechanic_fields[path]
        field.text = "#44bbcc" if path.ends_with("primary") else "#f0ffe0"
        field.text_changed.emit(field.text)
    return _editor._try_apply_edits() and _entry()["properties"]["appearance"]["primary"] == "#44bbcc" and _entry()["properties"]["appearance"]["accent"] == "#f0ffe0" and _entry()["properties"]["appearance"].has("motif")

func _duplicate_karma_clones_signature() -> bool:
    if not _select("astreion"):
        return false
    var count: int = _editor._entries.size()
    _editor._duplicate_entry()
    var karma: Dictionary = _entry()
    var signature: Dictionary = _editor._find_definition(str(karma["properties"]["signature_id"]))
    return _editor._entries.size() == count + 2 and karma["id"] != "astreion" and not signature.is_empty() and signature["id"] != "perihelion_hammer" and signature["properties"]["karma_id"] == karma["id"] and _editor._find_definition("astreion")["properties"]["signature_id"] == "perihelion_hammer" and _editor.catalog.validate_entries(_editor._entries).is_empty()

func _duplicate_twice_keeps_unique_ids() -> bool:
    if not _select("thalassa"):
        return false
    _editor._duplicate_entry()
    var first: String = str(_entry()["id"])
    _select("thalassa")
    _editor._duplicate_entry()
    return first != str(_entry()["id"]) and _editor.catalog.validate_entries(_editor._entries).is_empty()

func _duplicate_karma_save_roundtrip() -> bool:
    if not _select("astreion"):
        return false
    _editor._duplicate_entry()
    var id: String = str(_entry()["id"])
    _editor._mechanic_fields["pg_max"].value = 275.0
    _editor._save()
    if _editor._dirty:
        return false
    _editor._reload()
    return _entry()["id"] == id and _editor._mechanic_fields["pg_max"].value == 275.0 and _editor.catalog.validate_entries(_editor._entries).is_empty()

func _duplicate_signature_remains_linked() -> bool:
    if not _select("perihelion_hammer"):
        return false
    _editor._duplicate_entry()
    return _entry()["id"] != "perihelion_hammer" and _entry()["properties"]["karma_id"] == "astreion" and _editor.catalog.validate_entries(_editor._entries).is_empty()

func _duplicate_resonance_is_independent() -> bool:
    if not _select("sovereign_orbit"):
        return false
    _editor._duplicate_entry()
    if not _choose("inherited_techniques.0", "combat_blade") or not _editor._try_apply_edits():
        return false
    return _editor._find_definition("sovereign_orbit")["properties"]["inherited_techniques"] == ["drift", "magnus_shot"] and _entry()["properties"]["inherited_techniques"][0] == "combat_blade"

func _save_reload_restore() -> bool:
    if not _select("astreion"):
        return false
    _editor._mechanic_fields["pg_max"].value = 270.0
    _editor._save()
    if _editor._dirty or not FileAccess.file_exists(_path):
        return false
    _editor._mechanic_fields["pg_max"].value = 280.0
    _editor._reload()
    if _editor._mechanic_fields["pg_max"].value != 270.0 or _editor._dirty:
        return false
    _editor._restore()
    _select("astreion")
    return not FileAccess.file_exists(_path) and _editor._mechanic_fields["pg_max"].value == 240.0

func _invalid_graph_preserves_saved_file() -> bool:
    if not _select("perihelion_hammer"):
        return false
    _editor._save()
    var before: String = FileAccess.get_file_as_string(_path)
    if not _choose("karma_id", "thalassa"):
        return false
    _editor._save()
    return _editor._dirty and FileAccess.get_file_as_string(_path) == before and not _editor.catalog.last_errors.is_empty()

func _embedded_return() -> bool:
    var result: Dictionary = {"called": false}
    _editor.match_requested.connect(func() -> void: result["called"] = true)
    _editor._open_match()
    return result["called"]

func _unsaved_edits_block_return() -> bool:
    var result: Dictionary = {"called": false}
    _editor.match_requested.connect(func() -> void: result["called"] = true)
    _editor._fields["name"].text_changed.emit("Essai")
    _editor._open_match()
    return _editor._dirty and not result["called"]
