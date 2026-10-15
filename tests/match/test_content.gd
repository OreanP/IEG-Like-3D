extends RefCounted
## Contrats du catalogue et persistance réelle dans un fichier user:// isolé.
const Catalog = preload("res://core/content/technique_catalog.gd")
var _path: String = "user://test_match_content_%d.json" % OS.get_process_id()

func run_all() -> Dictionary:
    var cases: Array[Callable] = [_eight_specials, _default_values_valid, _default_balanced_categories,
        _unknown_id, _deep_copy_definition, _deep_copy_list, _tactics_parameters,
        _augmentation_contracts, _keeper_branches, _roundtrip_and_default_fallback,
        _invalid_save_preserves_file, _duplicate_rejected, _custom_entry,
        _malformed_load_preserves_memory, _missing_fields, _invalid_numbers,
        _invalid_category_color_and_properties, _tactics_bounds, _reset,
        _unsupported_schema, _empty_overrides, _strict_augmentation_validation,
        _malformed_field_types, _invalid_presentation_properties, _oversized_save]
    var lines: Array[String] = []
    var passed: int = 0
    for test: Callable in cases:
        _cleanup()
        var ok: bool = test.call()
        passed += 1 if ok else 0
        lines.append(("OK   " if ok else "ÉCHEC   ") + "CONTENU : " + String(test.get_method()))
    _cleanup()
    return {"total": cases.size(), "passed": passed, "failed": cases.size() - passed, "lines": lines}

func fixture() -> IEGTechniqueCatalog:
    return Catalog.new(_path)

func _cleanup() -> void:
    for path: String in [_path, _path + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write(text: String) -> void:
    var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
    file.store_string(text)
    file.close()

func _eight_specials() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var expected: Dictionary = {"orbital_shot": "TIR", "hurricane_barrier": "DEF", "magnus_shot": "TIR", "photo_stop": "GAR", "combat_blade": "ATT", "drift": "ATT", "aquablast": "DEF", "gyroscopic_stop": "GAR"}
    for id: String in expected:
        if c.get_definition(id).get("category", "") != expected[id]:
            return false
    return true

func _default_values_valid() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    for data: Dictionary in c.all_definitions():
        if not c.validate_definition(data).is_empty():
            return false
    return c.all_definitions().size() >= 12

func _default_balanced_categories() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    for category: String in ["TIR", "ATT", "DEF", "GAR"]:
        if c.definitions_for(category).size() != 2:
            return false
    return true

func _unknown_id() -> bool:
    return fixture().get_definition("absent").is_empty()

func _deep_copy_definition() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("magnus_shot")
    data["name"] = "Changed"
    data["properties"]["curve"] = 99.0
    return c.get_definition("magnus_shot")["name"] == "Tir Magnus" and float(c.get_definition("magnus_shot")["properties"]["curve"]) == 0.8

func _deep_copy_list() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var entries: Array[Dictionary] = c.all_definitions()
    entries[0]["properties"]["spin"] = 999
    entries.clear()
    return c.all_definitions().size() == 12 and c.get_definition("orbital_shot")["properties"]["spin"] == 2.8

func _tactics_parameters() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var wings: Dictionary = c.get_definition("wide_wings")["properties"]
    var press: Dictionary = c.get_definition("compact_press")["properties"]
    return float(wings["width_factor"]) > 1.0 and float(press["width_factor"]) < 1.0 and float(press["pressure"]) > float(wings["pressure"])

func _augmentation_contracts() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var echo: Dictionary = c.get_definition("tempest_echo")["properties"]
    var resonance: Dictionary = c.get_definition("twin_resonance")["properties"]
    return echo["exclusive_group"] == resonance["exclusive_group"] and float(echo["energy_max"]) > 0.0 and float(echo["energy_drain"]) > 0.0 and resonance["profile_a"] != resonance["profile_b"]

func _keeper_branches() -> bool:
    for data: Dictionary in fixture().definitions_for("GAR"):
        var properties: Dictionary = data["properties"]
        if properties["success_animation"] == properties["failure_animation"] or float(properties["branch_at"]) != 0.58:
            return false
    return true

func _roundtrip_and_default_fallback() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["power"] = 41.5
    if c.save_overrides([data]) != OK:
        return false
    var loaded: IEGTechniqueCatalog = fixture()
    return loaded.last_errors.is_empty() and loaded.get_definition("drift")["power"] == 41.5 and loaded.get_definition("orbital_shot")["name"] == "Tir orbital" and loaded.all_definitions().size() == 12

func _invalid_save_preserves_file() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["power"] = 38.0
    if c.save_overrides([data]) != OK:
        return false
    var before: String = FileAccess.get_file_as_string(_path)
    data["power"] = -5.0
    return c.save_overrides([data]) == ERR_INVALID_DATA and FileAccess.get_file_as_string(_path) == before and c.get_definition("drift")["power"] == 38.0

func _duplicate_rejected() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    return c.save_overrides([data, data]) == ERR_INVALID_DATA and not FileAccess.file_exists(_path)

func _custom_entry() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["id"] = "custom_technique"
    data["name"] = "Essai"
    if c.save_overrides([data]) != OK:
        return false
    var loaded: IEGTechniqueCatalog = fixture()
    return loaded.get_definition("custom_technique")["name"] == "Essai" and loaded.all_definitions().size() == 13

func _malformed_load_preserves_memory() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["power"] = 42.0
    c.save_overrides([data])
    _write("{ broken JSON")
    return c.load_overrides() == ERR_PARSE_ERROR and not c.last_errors.is_empty() and c.get_definition("drift")["power"] == 42.0

func _missing_fields() -> bool:
    var errors: PackedStringArray = fixture().validate_definition({"id": "empty"})
    return errors.size() == Catalog.REQUIRED_FIELDS.size() - 1

func _invalid_numbers() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    for value: Variant in [NAN, INF, -1.0, 501.0, "twelve", true]:
        var data: Dictionary = c.get_definition("drift")
        data["power"] = value
        if c.validate_definition(data).is_empty():
            return false
    return true

func _invalid_category_color_and_properties() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["category"] = "UNKNOWN"
    data["color"] = "not-a-color"
    data["properties"] = [1, 2]
    return c.validate_definition(data).size() == 3

func _tactics_bounds() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("wide_wings")
    data["properties"]["width_factor"] = 5.0
    data["properties"]["pressure"] = -0.1
    return c.validate_definition(data).size() == 2

func _reset() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["power"] = 100.0
    c.save_overrides([data])
    return c.reset_overrides() == OK and not FileAccess.file_exists(_path) and c.get_definition("drift")["power"] == 23.0

func _unsupported_schema() -> bool:
    _write(JSON.stringify({"schema_version": 99, "entries": []}))
    var c: IEGTechniqueCatalog = fixture()
    return not c.last_errors.is_empty() and c.all_definitions().size() == 12

func _empty_overrides() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    return c.save_overrides([]) == OK and fixture().all_definitions().size() == 12

func _strict_augmentation_validation() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var echo: Dictionary = c.get_definition("tempest_echo")
    echo["properties"]["energy_max"] = -5.0
    echo["properties"]["exclusive_group"] = "different"
    var resonance: Dictionary = c.get_definition("twin_resonance")
    resonance["properties"]["blend"] = 2.0
    resonance["properties"]["profile_b"] = resonance["properties"]["profile_a"]
    return c.validate_definition(echo).size() == 2 and c.validate_definition(resonance).size() == 2

func _malformed_field_types() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["id"] = 7
    data["category"] = 4
    if c.save_overrides([data]) != ERR_INVALID_DATA or FileAccess.file_exists(_path):
        return false
    data = c.get_definition("tempest_echo")
    data["properties"]["exclusive_group"] = 7
    return not c.validate_definition(data).is_empty()

func _invalid_presentation_properties() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("photo_stop")
    data["properties"]["branch_at"] = 1.0
    data["properties"]["capture"] = "yes"
    return c.validate_definition(data).size() == 2

func _oversized_save() -> bool:
    var c: IEGTechniqueCatalog = fixture()
    var data: Dictionary = c.get_definition("drift")
    data["properties"]["too_large"] = "a".repeat(524288)
    return c.save_overrides([data]) == ERR_INVALID_DATA and not FileAccess.file_exists(_path)
