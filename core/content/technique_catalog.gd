class_name IEGTechniqueCatalog
extends RefCounted
## Contenus de match partageables entre simulation, présentation et atelier.
## Les modifications locales sont sérialisées dans user://, jamais dans les assets.

const STORAGE_PATH: String = "user://match_content.json"
const JsonStore = preload("res://core/persistence/json_store.gd")
const SCHEMA_VERSION: int = 3
const STAT_KEYS: PackedStringArray = ["shot", "dribble", "technique", "keeper", "defense"]
const MAX_KARMA_OWNERS: int = 32
const MAX_ACTIVE_PER_TEAM: int = 3
const CATEGORIES: PackedStringArray = ["TIR", "ATT", "DEF", "GAR", "TAC", "KARMA", "RESONANCE"]
const REQUIRED_FIELDS: PackedStringArray = ["id", "name", "category", "power", "cost", "duration", "range_bonus", "effect", "color", "description", "properties"]

var last_errors: PackedStringArray = []
var last_notices: PackedStringArray = []
var _overrides: Dictionary = {}
var _storage_path: String = STORAGE_PATH

func _init(storage_path: String = STORAGE_PATH) -> void:
    _storage_path = storage_path
    load_overrides()

func get_definition(id: String) -> Dictionary:
    if id == "tempest_echo":
        id = "tempest_karma"
    if _overrides.has(id):
        return _overrides[id].duplicate(true)
    for definition: Dictionary in _defaults():
        if String(definition["id"]) == id:
            return definition
    return {}

func all_definitions() -> Array[Dictionary]:
    var result: Array[Dictionary] = _defaults()
    var known: Dictionary = {}
    for index: int in range(result.size()):
        var id: String = String(result[index]["id"])
        known[id] = true
        if _overrides.has(id):
            result[index] = _overrides[id].duplicate(true)
    for id: String in _overrides:
        if not known.has(id):
            result.append(_overrides[id].duplicate(true))
    return result

func definitions_for(category: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for definition: Dictionary in all_definitions():
        if String(definition["category"]) == category:
            result.append(definition)
    return result

static func cinematic_timing(attack: Dictionary, defense: Dictionary = {}) -> Dictionary:
    # Le match et les deux ateliers emploient le même moment de révélation.
    # Une défense spéciale choisit son point de bifurcation avant l'attaque.
    var longest: float = 0.0
    for definition: Dictionary in [attack, defense]:
        if not definition.is_empty():
            longest = maxf(longest, float(definition.get("duration", 3.2)))
    var seconds: float = clampf(longest if longest > 0.0 else 3.2, 1.8, 10.0)
    var reveal_seconds: float = clampf(1.4, 0.7, seconds - 0.4)
    for definition: Dictionary in [defense, attack]:
        var properties: Dictionary = definition.get("properties", {})
        if properties.has("branch_at"):
            reveal_seconds = clampf(seconds * float(properties["branch_at"]), 0.7, seconds - 0.4)
            break
    return {"duration": seconds, "reveal_time": reveal_seconds}

func validate_definition(data: Dictionary, references: Dictionary = {}) -> PackedStringArray:
    var errors: PackedStringArray = []
    if references.is_empty():
        references = _definition_graph(_overrides)
        references[str(data.get("id", ""))] = data
    for key: String in REQUIRED_FIELDS:
        if not data.has(key):
            errors.append("Champ requis absent : " + key)
    if not errors.is_empty():
        return errors
    if not data["id"] is String or not _valid_id(String(data["id"])):
        errors.append("L'identifiant doit commencer par une lettre minuscule et contenir uniquement a-z, 0-9 et _. (64 caractères maximum)")
    if not data["name"] is String or String(data["name"]).strip_edges().is_empty() or String(data["name"]).length() > 80:
        errors.append("Le nom doit contenir entre 1 et 80 caractères.")
    if not data["category"] is String or not CATEGORIES.has(String(data["category"])):
        errors.append("Catégorie inconnue. Utiliser TIR, ATT, DEF, GAR, TAC, KARMA ou RESONANCE.")
    _validate_number(data, "power", 0.0, 500.0, errors)
    _validate_number(data, "cost", 0.0, 100.0, errors)
    _validate_number(data, "duration", 0.1, 600.0, errors)
    _validate_number(data, "range_bonus", -25.0, 100.0, errors)
    if not data["effect"] is String or not _valid_id(String(data["effect"])):
        errors.append("L'effet doit être un identifiant a-z, 0-9, _. (64 caractères maximum)")
    if not data["color"] is String or not Color.html_is_valid(String(data["color"])):
        errors.append("La couleur doit être HTML, par exemple #6bdfff.")
    if not data["description"] is String or String(data["description"]).length() > 1200:
        errors.append("La description doit être un texte de 1 200 caractères maximum.")
    if not data["properties"] is Dictionary:
        errors.append("Les propriétés doivent être un objet JSON.")
    elif not _json_safe(data["properties"]):
        errors.append("Les propriétés contiennent une valeur non JSON, non finie ou trop profondément imbriquée.")
    else:
        var properties: Dictionary = data["properties"]
        for key: String in ["width_factor", "pressure", "energy_max", "energy_drain", "profile_a", "profile_b", "blend", "branch_at", "dash", "flight_arc", "spin", "curve", "pushback", "technique_energy_cost"]:
            if properties.has(key) and not _is_finite_number(properties[key]):
                errors.append("La propriété %s doit être un nombre fini." % key)
        if properties.has("branch_at") and _is_finite_number(properties["branch_at"]) and (float(properties["branch_at"]) < 0.1 or float(properties["branch_at"]) > 0.9):
            errors.append("branch_at doit être compris entre 0.1 et 0.9 pour séparer préparation et résultat.")
        for key: String in ["block", "capture", "long_range"]:
            if properties.has(key) and not properties[key] is bool:
                errors.append("La propriété %s doit être true ou false." % key)
        if str(data["category"]) == "TAC":
            for key: String in ["width_factor", "pressure"]:
                if not properties.has(key):
                    errors.append("Une tactique doit définir " + key + ".")
            if _is_finite_number(properties.get("width_factor")) and (float(properties["width_factor"]) < 0.5 or float(properties["width_factor"]) > 1.6):
                errors.append("width_factor doit être compris entre 0.5 et 1.6.")
            if _is_finite_number(properties.get("pressure")) and (float(properties["pressure"]) < 0.0 or float(properties["pressure"]) > 1.0):
                errors.append("pressure doit être compris entre 0 et 1.")
        if str(data["category"]) in ["KARMA", "RESONANCE"]:
            var category_name: String = "Karma" if str(data["category"]) == "KARMA" else "Resonance"
            if not _is_finite_number(properties.get("max_active_per_team")) or float(properties.get("max_active_per_team", 0.0)) != MAX_ACTIVE_PER_TEAM:
                errors.append("%s impose max_active_per_team : 3. Cette limite ne peut pas être modifiée." % category_name)
            if not _is_finite_number(properties.get("energy_max")) or float(properties.get("energy_max", 0.0)) <= 0.0 or float(properties.get("energy_max", 0.0)) > 1000.0:
                errors.append("%s doit avoir une réserve energy_max strictement positive, de 1 000 maximum." % category_name)
            if not _is_finite_number(properties.get("energy_drain")) or float(properties.get("energy_drain", 0.0)) <= 0.0 or float(properties.get("energy_drain", 0.0)) > 1000.0:
                errors.append("%s doit avoir une consommation energy_drain strictement positive, de 1 000 maximum." % category_name)
            if not _is_finite_number(properties.get("technique_energy_cost")) or float(properties.get("technique_energy_cost", -1.0)) < 0.0:
                errors.append("%s doit définir un coût technique_energy_cost positif ou nul." % category_name)
            elif _is_finite_number(properties.get("energy_max")) and float(properties["technique_energy_cost"]) > float(properties["energy_max"]):
                errors.append("technique_energy_cost ne peut pas dépasser la réserve propre energy_max.")
        if str(data["category"]) == "RESONANCE":
            if not properties.has("donor_key"):
                if not properties.has("profile_a") or not properties.has("profile_b"):
                    errors.append("Une Resonance doit préciser donor_key ou les anciens profile_a et profile_b.")
                elif typeof(properties["profile_a"]) == typeof(properties["profile_b"]) and properties["profile_a"] == properties["profile_b"]:
                    errors.append("Une Resonance doit réunir deux profils distincts.")
            if not _is_finite_number(properties.get("blend")) or float(properties.get("blend", -1.0)) < 0.0 or float(properties.get("blend", -1.0)) > 1.0:
                errors.append("Le mélange blend doit être compris entre 0 et 1.")
        _validate_extended_properties(str(data["id"]), str(data["category"]), properties, references, errors)
    return errors

func validate_entries(entries: Array[Dictionary]) -> PackedStringArray:
    # Validation atomique du catalogue proposé ; aucun fichier ni override n'est modifié.
    _checked_entries(entries)
    return last_errors.duplicate()

func save_overrides(entries: Array[Dictionary]) -> Error:
    last_notices.clear()
    var canonical: Array = _migrate_entries(entries, false)
    var checked: Dictionary = _checked_entries(canonical)
    if not last_errors.is_empty():
        return ERR_INVALID_DATA
    var document: String = JSON.stringify({"schema_version": SCHEMA_VERSION, "entries": canonical}, "  ")
    if document.to_utf8_buffer().size() > 524288:
        last_errors.append("La sauvegarde dépasserait 512 Kio ; réduisez les propriétés ou le nombre de contenus.")
        return ERR_INVALID_DATA
    var write_error: Error = JsonStore.write_document(_storage_path, document, last_errors)
    if write_error != OK:
        return write_error
    _overrides = checked
    return OK

func load_overrides() -> Error:
    last_errors.clear()
    last_notices.clear()
    if not FileAccess.file_exists(_storage_path):
        _overrides.clear()
        return OK
    var file: FileAccess = FileAccess.open(_storage_path, FileAccess.READ)
    if file == null:
        last_errors.append("Impossible de lire les contenus : " + error_string(FileAccess.get_open_error()))
        return FileAccess.get_open_error()
    if file.get_length() > 524288:
        file.close()
        last_errors.append("Le fichier de contenus dépasse 512 Kio.")
        return ERR_INVALID_DATA
    var json: JSON = JSON.new()
    var parse_error: Error = json.parse(file.get_as_text())
    file.close()
    if parse_error != OK:
        last_errors.append("JSON invalide, ligne %d : %s" % [json.get_error_line(), json.get_error_message()])
        return ERR_PARSE_ERROR
    if not json.data is Dictionary:
        last_errors.append("Le fichier doit contenir un objet avec schema_version et entries.")
        return ERR_INVALID_DATA
    var document: Dictionary = json.data
    var version: Variant = document.get("schema_version", -1)
    if not _is_finite_number(version) or (float(version) not in [1.0, 2.0, float(SCHEMA_VERSION)]) or not document.get("entries") is Array:
        last_errors.append("Version de contenu inconnue ou tableau entries absent.")
        return ERR_INVALID_DATA
    var legacy: bool = document["schema_version"] == 1
    var checked: Dictionary = _checked_entries(_migrate_entries(document["entries"], legacy))
    if not last_errors.is_empty():
        return ERR_INVALID_DATA
    _overrides = checked
    if float(version) < float(SCHEMA_VERSION):
        last_notices.append("Fichier version %d chargé sans écrasement. La prochaine sauvegarde utilisera le format version %d." % [int(version), SCHEMA_VERSION])
    return OK

func reset_overrides() -> Error:
    last_errors.clear()
    last_notices.clear()
    if FileAccess.file_exists(_storage_path):
        var result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(_storage_path))
        if result != OK:
            last_errors.append("Impossible de rétablir les contenus : " + error_string(result))
            return result
    _overrides.clear()
    return OK

func _migrate_entries(entries: Array, legacy_schema: bool) -> Array:
    var result: Array = []
    for raw: Variant in entries:
        if not raw is Dictionary:
            result.append(raw)
            continue
        var data: Dictionary = raw.duplicate(true)
        var legacy: bool = str(data.get("category", "")) == "ECHO" or str(data.get("id", "")) == "tempest_echo" or str(data.get("effect", "")) == "echo"
        if str(data.get("category", "")) == "ECHO":
            data["category"] = "KARMA"
        if str(data.get("id", "")) == "tempest_echo":
            data["id"] = "tempest_karma"
        if str(data.get("effect", "")) == "echo":
            data["effect"] = "karma"
        if str(data.get("name", "")) == "Écho : Vigie des vents":
            data["name"] = "Karma : Vigie des vents"
        if str(data.get("name", "")) == "Résonance : Double horizon":
            data["name"] = "Resonance : Double horizon"
        if str(data.get("description", "")) == "Une silhouette de vent accompagne le joueur. Sa réserve d'énergie propre se vide avec le temps et chaque technique. Incompatible avec une Résonance.":
            data["description"] = "Une silhouette de vent accompagne le joueur. Sa réserve d'énergie propre se vide avec le temps et chaque technique. Cumulable avec Resonance ; trois Karma maximum par équipe."
        if str(data.get("description", "")) == "Deux profils mettent leurs qualités en commun pour une fusion temporaire pondérée. Une seule augmentation peut être active.":
            data["description"] = "Deux profils mettent leurs qualités en commun pour une fusion temporaire pondérée. Cumulable avec Karma ; trois Resonance maximum par équipe."
        var category: String = str(data.get("category", ""))
        if data.get("properties") is Dictionary and category in ["KARMA", "RESONANCE"]:
            var properties: Dictionary = data["properties"]
            var had_exclusive_group: bool = properties.has("exclusive_group")
            properties.erase("exclusive_group")
            if legacy or legacy_schema or had_exclusive_group:
                if not properties.has("max_active_per_team"):
                    properties["max_active_per_team"] = MAX_ACTIVE_PER_TEAM
                if not properties.has("energy_max"):
                    properties["energy_max"] = 100.0
                if not properties.has("energy_drain"):
                    properties["energy_drain"] = 2.2 if category == "KARMA" else 1.0
                if not properties.has("technique_energy_cost"):
                    properties["technique_energy_cost"] = 18.0 if category == "KARMA" else 0.0
                last_notices.append("%s : %s et Resonance sont cumulables ; limite fixe de trois actifs de chaque type par équipe. Budgets personnalisés conservés." % [str(data.get("id", "contenu")), "Karma"])
        result.append(data)
    return result

func _checked_entries(entries: Array) -> Dictionary:
    last_errors.clear()
    var checked: Dictionary = {}
    if entries.size() > 256:
        last_errors.append("Maximum : 256 contenus locaux.")
        return checked
    for index: int in range(entries.size()):
        if not entries[index] is Dictionary:
            last_errors.append("L'entrée %d doit être un objet JSON." % (index + 1))
            continue
        var definition: Dictionary = entries[index]
        var id: String = str(definition.get("id", ""))
        if checked.has(id):
            last_errors.append("Identifiant en double : " + id)
        checked[id] = definition.duplicate(true)
    # Vérifier le graphe final d'un seul bloc : l'ordre des entrées ne compte pas.
    # Une modification locale ne doit pas invalider un lien d'un contenu de base.
    var references: Dictionary = _definition_graph(checked)
    for id: String in references:
        for error: String in validate_definition(references[id], references):
            last_errors.append("Contenu %s : %s" % [id, error])
    return checked

func _definition_graph(overrides: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for definition: Dictionary in _defaults():
        result[str(definition["id"])] = definition
    for id: String in overrides:
        result[id] = overrides[id]
    return result

func _validate_extended_properties(data_id: String, category: String, properties: Dictionary, references: Dictionary, errors: PackedStringArray) -> void:
    var has_karma_budget: bool = category == "KARMA" and (properties.has("pg_max") or properties.has("pe_max") or properties.has("signature_id"))
    if has_karma_budget:
        for key: String in ["pg_max", "pe_max"]:
            _validate_property_number(properties, key, 1.0, 1000.0, errors)
        for key: String in ["pe_drain", "sprint_pe_drain", "duel_pg_cost", "duel_pe_cost", "defeat_pg_cost"]:
            _validate_property_number(properties, key, 0.0, 1000.0, errors)
        for key: String in ["duel_pg_cost", "defeat_pg_cost"]:
            if _is_finite_number(properties.get(key)) and _is_finite_number(properties.get("pg_max")) and float(properties[key]) > float(properties["pg_max"]):
                errors.append("%s ne peut pas dépasser pg_max." % key)
        if _is_finite_number(properties.get("duel_pe_cost")) and _is_finite_number(properties.get("pe_max")) and float(properties["duel_pe_cost"]) > float(properties["pe_max"]):
            errors.append("duel_pe_cost ne peut pas dépasser pe_max.")
        if not properties.get("stat_bonuses") is Dictionary or properties.get("stat_bonuses", {}).is_empty():
            errors.append("Un Karma à PG/PE doit définir stat_bonuses.")
        else:
            for key: Variant in properties["stat_bonuses"]:
                if not key is String or not STAT_KEYS.has(str(key)):
                    errors.append("Caractéristique de Karma inconnue : %s." % str(key))
                _validate_property_number(properties["stat_bonuses"], str(key), 0.0, 100.0, errors)
        _validate_reference(properties, "signature_id", ["TIR", "ATT", "DEF", "GAR"], references, errors)
        var signature: Dictionary = references.get(str(properties.get("signature_id", "")), {})
        if not signature.is_empty() and signature.get("properties") is Dictionary:
            var source: String = str(signature["properties"].get("karma_id", ""))
            if source != data_id:
                errors.append("La signature propre doit définir karma_id vers ce Karma (%s)." % data_id)
    if properties.has("appearance"):
        if not properties["appearance"] is Dictionary:
            errors.append("appearance doit être un objet JSON.")
        else:
            var appearance: Dictionary = properties["appearance"]
            if not appearance.get("style") is String or not _valid_id(str(appearance.get("style", ""))):
                errors.append("appearance.style doit être un identifiant valide.")
            for key: String in ["primary", "accent"]:
                if appearance.has(key) and (not appearance[key] is String or not Color.html_is_valid(str(appearance[key]))):
                    errors.append("appearance.%s doit être une couleur HTML valide." % key)
            for key: String in ["motif", "description", "sound"]:
                if appearance.has(key) and (not appearance[key] is String or str(appearance[key]).length() > 1200):
                    errors.append("appearance.%s doit être un texte de 1 200 caractères maximum." % key)
            if appearance.has("height"):
                _validate_property_number(appearance, "height", 0.1, 20.0, errors)
    if properties.has("owner_keys"):
        if not properties["owner_keys"] is Array or properties.get("owner_keys", []).size() > MAX_KARMA_OWNERS:
            errors.append("owner_keys doit être un tableau de %d identifiants de propriétaires maximum." % MAX_KARMA_OWNERS)
        else:
            var owners_seen: Array = []
            for owner_key: Variant in properties["owner_keys"]:
                if not owner_key is String or not _valid_id(str(owner_key)) or owners_seen.has(owner_key):
                    errors.append("owner_keys doit contenir des identifiants uniques, valides et non vides.")
                owners_seen.append(owner_key)
    if properties.has("karma_id") or properties.has("pg_cost") or properties.has("pe_cost"):
        if category not in ["TIR", "ATT", "DEF", "GAR"]:
            errors.append("Une signature de Karma doit être une technique TIR, ATT, DEF ou GAR.")
        _validate_reference(properties, "karma_id", ["KARMA"], references, errors)
        _validate_property_number(properties, "pg_cost", 0.0, 1000.0, errors)
        _validate_property_number(properties, "pe_cost", 0.0, 1000.0, errors)
        var owner: Dictionary = references.get(str(properties.get("karma_id", "")), {})
        var budget: Dictionary = owner.get("properties", {}) if owner.get("properties") is Dictionary else {}
        for pair: Array in [["pg_cost", "pg_max"], ["pe_cost", "pe_max"]]:
            if _is_finite_number(properties.get(pair[0])) and _is_finite_number(budget.get(pair[1])) and float(properties[pair[0]]) > float(budget[pair[1]]):
                errors.append("%s ne peut pas dépasser %s du Karma." % [pair[0], pair[1]])
    if properties.has("optimal_min") or properties.has("optimal_max") or properties.has("distance_falloff"):
        _validate_property_number(properties, "optimal_min", 0.0, 150.0, errors)
        _validate_property_number(properties, "optimal_max", 0.0, 150.0, errors)
        _validate_property_number(properties, "distance_falloff", 0.0, 20.0, errors)
        if _is_finite_number(properties.get("optimal_min")) and _is_finite_number(properties.get("optimal_max")) and float(properties["optimal_min"]) > float(properties["optimal_max"]):
            errors.append("optimal_min ne peut pas dépasser optimal_max.")
    if category == "RESONANCE" and properties.has("donor_key"):
        if not properties["donor_key"] is String or not _valid_id(str(properties["donor_key"])):
            errors.append("donor_key doit être l'identifiant d'un donneur.")
        if not properties.get("inherited_techniques") is Array or properties.get("inherited_techniques", []).size() != 2:
            errors.append("Une Resonance doit transmettre exactement deux techniques.")
        else:
            var inherited: Array = properties["inherited_techniques"]
            if inherited[0] is String and inherited[1] is String and inherited[0] == inherited[1]:
                errors.append("Les deux techniques héritées doivent être distinctes.")
            for id: Variant in inherited:
                _validate_reference({"technique": id}, "technique", ["TIR", "ATT", "DEF", "GAR"], references, errors)
                var source_properties: Variant = references.get(id, {}).get("properties", {}) if id is String else {}
                if source_properties is Dictionary and source_properties.has("karma_id"):
                    errors.append("Une signature de Karma ne peut pas occuper un emplacement de technique héritée.")
        if properties.has("inherited_karma_id") and not (properties["inherited_karma_id"] is String and properties["inherited_karma_id"] == ""):
            _validate_reference(properties, "inherited_karma_id", ["KARMA"], references, errors)
        if not properties.get("stat_keys") is Array or properties.get("stat_keys", []).is_empty() or properties.get("stat_keys", []).size() > STAT_KEYS.size():
            errors.append("stat_keys doit contenir les caractéristiques à transmettre.")
        else:
            var seen: Array = []
            for key: Variant in properties["stat_keys"]:
                if not key is String or not STAT_KEYS.has(str(key)) or seen.has(key):
                    errors.append("Caractéristique de Resonance inconnue ou répétée : %s." % str(key))
                seen.append(key)

func _validate_reference(properties: Dictionary, key: String, categories: Array, references: Dictionary, errors: PackedStringArray) -> void:
    var id: Variant = properties.get(key)
    if not id is String or not _valid_id(str(id)):
        errors.append("%s doit être un identifiant valide." % key)
    elif not references.has(id) or not references[id].get("category") in categories:
        errors.append("%s doit référencer un contenu existant de catégorie %s." % [key, "/".join(categories)])

func _validate_property_number(properties: Dictionary, key: String, minimum: float, maximum: float, errors: PackedStringArray) -> void:
    if not _is_finite_number(properties.get(key)) or float(properties.get(key, -1.0)) < minimum or float(properties.get(key, -1.0)) > maximum:
        errors.append("La propriété %s doit être un nombre fini entre %s et %s." % [key, minimum, maximum])

func _validate_number(data: Dictionary, key: String, minimum: float, maximum: float, errors: PackedStringArray) -> void:
    if not _is_finite_number(data[key]) or float(data[key]) < minimum or float(data[key]) > maximum:
        errors.append("%s doit être un nombre fini entre %s et %s." % [key, minimum, maximum])

func _is_finite_number(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))

func _valid_id(value: String) -> bool:
    if value.is_empty() or value.length() > 64 or value[0] < "a" or value[0] > "z":
        return false
    for character: String in value:
        if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
            return false
    return true

func _json_safe(value: Variant, depth: int = 0) -> bool:
    if depth > 8:
        return false
    if value == null or value is bool or value is String:
        return true
    if value is int or value is float:
        return is_finite(float(value))
    if value is Array:
        for item: Variant in value:
            if not _json_safe(item, depth + 1):
                return false
        return true
    if value is Dictionary:
        for key: Variant in value:
            if not key is String or not _json_safe(value[key], depth + 1):
                return false
        return true
    return false

func _definition(id: String, title: String, category: String, power: float, cost: float, duration: float, range_bonus: float, effect: String, color: String, description: String, properties: Dictionary = {}) -> Dictionary:
    return {"id": id, "name": title, "category": category, "power": power, "cost": cost,
        "duration": duration, "range_bonus": range_bonus, "effect": effect, "color": color,
        "description": description, "properties": properties}

func _defaults() -> Array[Dictionary]:
    return [
        _definition("orbital_shot", "Tir orbital", "TIR", 34.0, 26.0, 3.8, 4.0, "orbital", "#a99aff",
            "Le ballon décrit trois orbites lumineuses avant de plonger vers la cage. Un tir puissant à portée moyenne.",
            {"flight_arc": 3.8, "spin": 2.8, "preview": "orbital"}),
        _definition("hurricane_barrier", "Barrage ouragan", "DEF", 29.0, 22.0, 3.5, 0.0, "hurricane", "#89e8d4",
            "Deux appuis ancrent un rempart de vents croisés. Une défense de blocage qui repousse le ballon.",
            {"block": true, "pushback": 2.0, "preview": "hurricane"}),
        _definition("magnus_shot", "Tir Magnus", "TIR", 27.0, 20.0, 3.7, 18.0, "magnus", "#ffb969",
            "Une rotation latérale tend une courbe immense. Sa portée supplémentaire récompense les tirs de loin.",
            {"long_range": true, "curve": 0.8, "preview": "magnus"}),
        _definition("photo_stop", "Arrêt photo", "GAR", 31.0, 24.0, 4.0, 0.0, "photo", "#e7efff",
            "Le gardien cadre le ballon de ses mains : un flash suspend l'instant. Réussite : le cadre se referme. Échec : il se fissure.",
            {"capture": true, "success_animation": "photo_capture", "failure_animation": "photo_shatter", "branch_at": 0.58, "preview": "photo"}),
        _definition("combat_blade", "Lame de combat", "ATT", 30.0, 23.0, 3.4, 0.0, "blade", "#ff738f",
            "Une feinte d'épaule trace deux arcs de lumière, puis l'accélération tranche l'espace libre.",
            {"dash": 2.6, "preview": "blade"}),
        _definition("drift", "Drift", "ATT", 23.0, 15.0, 3.2, 0.0, "drift", "#6bdfff",
            "Le joueur glisse de côté, semelle sur le ballon, puis reprend sa course dans une traînée turquoise.",
            {"dash": 2.2, "preview": "drift"}),
        _definition("aquablast", "Aquablast", "DEF", 26.0, 18.0, 3.5, 0.0, "aqua", "#45baff",
            "Un cercle d'eau se comprime autour de l'appui avant de jaillir en vague pour intercepter le porteur.",
            {"block": false, "pushback": 1.4, "preview": "aqua"}),
        _definition("gyroscopic_stop", "Arrêt Gyroscopique", "GAR", 28.0, 19.0, 4.1, 0.0, "gyro", "#ffd76f",
            "Des anneaux stabilisent les bras du gardien. Réussite : ils absorbent la rotation. Échec : ils s'écartent sous l'impact.",
            {"capture": true, "success_animation": "gyro_lock", "failure_animation": "gyro_break", "branch_at": 0.58, "preview": "gyro"}),
        _definition("seismic_strike", "Frappe sismique", "TIR", 36.0, 28.0, 3.8, 3.0, "seismic", "#ef9855",
            "Un coup de talon soulève des plaques de roche autour du ballon. La frappe les pulvérise et propulse un noyau incandescent ; une onde circulaire accompagne l'impact.",
            {"flight_arc": 2.0, "spin": 1.4, "preview": "seismic"}),
        _definition("prism_ricochet", "Ricochet prismatique", "TIR", 29.0, 23.0, 3.9, 12.0, "prism", "#bb9cff",
            "Trois prismes réfléchissent le ballon en trajectoires apparentes. Les reflets convergent vers le véritable tir avant l'affrontement avec le gardien. Une frappe technique de longue distance.",
            {"long_range": true, "curve": 0.55, "flight_arc": 2.5, "preview": "prism"}),
        _definition("paper_escape", "Échappée de papier", "ATT", 27.0, 19.0, 3.5, 0.0, "paper", "#f2e8c7",
            "Des feuilles composent un leurre qui continue tout droit tandis que le porteur pivote et repart. En cas d'échec, le défenseur déchire la silhouette et récupère le ballon.",
            {"dash": 2.4, "branch_at": 0.58, "preview": "paper"}),
        _definition("syncope", "Syncope", "ATT", 31.0, 24.0, 3.4, 0.0, "syncope", "#f57cad",
            "Deux appuis lents précèdent une accélération brutale. Trois impulsions lumineuses marquent le rythme ; elles se brisent si le défenseur anticipe le dernier départ.",
            {"dash": 2.8, "branch_at": 0.58, "preview": "syncope"}),
        _definition("bronze_rampart", "Rempart d’airain", "DEF", 33.0, 26.0, 3.8, 0.0, "bronze", "#d5a362",
            "Trois boucliers de bronze s'imbriquent devant le défenseur. Les gravures s'illuminent puis la prise bloque le ballon ; un tir victorieux déforme et brise les boucliers.",
            {"block": true, "pushback": 1.8, "branch_at": 0.58, "preview": "bronze"}),
        _definition("mechanical_brambles", "Ronces mécaniques", "DEF", 28.0, 21.0, 3.6, 0.0, "brambles", "#a8d98b",
            "Des segments métalliques articulés encadrent le ballon pendant l'intervention du pied. La cage se referme sur une récupération ; un dribble réussi fait sauter ses attaches.",
            {"block": false, "pushback": 1.2, "branch_at": 0.58, "preview": "brambles"}),
        _definition("titan_grip", "Poigne du titan", "GAR", 35.0, 28.0, 4.0, 0.0, "titan", "#d2b99a",
            "Deux avant-bras de pierre reproduisent la prise du gardien. Après les scores, les mains amortissent une capture, une paume dévie le ballon ou les doigts se fissurent sous un tir victorieux.",
            {"capture": true, "branch_at": 0.58, "success_animation": "titan_capture", "parry_animation": "titan_parry", "failure_animation": "titan_fracture", "preview": "titan"}),
        _definition("midnight_dial", "Cadran de minuit", "GAR", 30.0, 22.0, 3.9, 0.0, "midnight", "#9cafff",
            "Un cadran sombre à douze repères se forme derrière le gardien. Après les scores, ses aiguilles guident la capture, dévient le ballon ou cèdent avec le cadran. La préparation est commune aux trois issues.",
            {"capture": true, "branch_at": 0.58, "success_animation": "midnight_capture", "parry_animation": "midnight_parry", "failure_animation": "midnight_shatter", "preview": "midnight"}),
        _definition("wide_wings", "Ailes ouvertes", "TAC", 0.0, 12.0, 60.0, 0.0, "wide", "#87c7ff",
            "Les soutiens s'écartent pour créer deux couloirs de passe. Une pression mesurée conserve l'équilibre collectif.",
            {"width_factor": 1.35, "pressure": 0.35}),
        _definition("compact_press", "Étau collectif", "TAC", 0.0, 15.0, 45.0, 0.0, "press", "#ff937c",
            "Le bloc se resserre et avance sur le porteur, avec un seul poursuivant pour conserver les couvertures.",
            {"width_factor": 0.72, "pressure": 0.85}),
        _definition("tempest_karma", "Karma : Vigie des vents", "KARMA", 14.0, 0.0, 45.0, 0.0, "karma", "#c2b0ff",
            "Une silhouette de vent accompagne le joueur. Sa réserve d'énergie propre se vide avec le temps et chaque technique. Cumulable avec Resonance ; trois Karma maximum par équipe.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 100.0, "energy_drain": 2.2, "technique_energy_cost": 18.0}),
        _definition("twin_resonance", "Resonance : Double horizon", "RESONANCE", 12.0, 20.0, 60.0, 0.0, "resonance", "#ff9fe3",
            "Deux profils mettent leurs qualités en commun pour une fusion temporaire pondérée. Cumulable avec Karma ; trois Resonance maximum par équipe.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 100.0, "energy_drain": 1.0, "technique_energy_cost": 0.0, "profile_a": 7, "profile_b": 10, "blend": 0.5}),
        _definition("astreion", "Astreion, le Forgeron orbital", "KARMA", 0.0, 0.0, 600.0, 0.0, "karma", "#eaa266",
            "Un colosse de métal bleu nuit et de cuivre incandescent ; une étoile tourne dans sa poitrine et trois anneaux gravitent autour de ses épaules. Calme et cérémonieux, il accompagne les gestes d'un finisseur.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 80.0, "energy_drain": 1.0, "technique_energy_cost": 0.0,
            "pg_max": 240.0, "pe_max": 80.0, "pe_drain": 1.0, "sprint_pe_drain": 1.0, "duel_pg_cost": 10.0, "duel_pe_cost": 4.0, "defeat_pg_cost": 20.0,
            "signature_id": "perihelion_hammer", "owner_keys": ["soren_vale"], "stat_bonuses": {"shot": 18.0, "dribble": 8.0},
            "appearance": {"style": "astreion", "height": 4.0, "primary": "#152345", "accent": "#eaa266", "sound": "Trois coups de forge et une étoile qui s'allume.", "motif": "Casque-éclipse, marteau de forge et orbites de cuivre."}}),
        _definition("thalassa", "Thalassa, la Sentinelle des marées", "KARMA", 0.0, 0.0, 600.0, 0.0, "karma", "#5fe3df",
            "Une gardienne monumentale en verre marin ; son manteau évoque une raie manta et deux turbines tournent derrière ses épaules. Elle émerge d'un cercle d'eau avec patience et précision.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 100.0, "energy_drain": 1.0, "technique_energy_cost": 0.0,
            "pg_max": 300.0, "pe_max": 100.0, "pe_drain": 1.0, "sprint_pe_drain": 1.0, "duel_pg_cost": 10.0, "duel_pe_cost": 4.0, "defeat_pg_cost": 20.0,
            "signature_id": "abyssal_cathedral", "owner_keys": ["maelle_neris"], "stat_bonuses": {"keeper": 18.0, "defense": 10.0},
            "appearance": {"style": "thalassa", "height": 4.0, "primary": "#165064", "accent": "#5fe3df", "sound": "Grondement sous-marin, turbines et tintements de verre.", "motif": "Ailes de raie, armure d'eau et boucliers transparents."}}),
        _definition("vaelis", "Vaélis, le Renard aux neuf éclats", "KARMA", 0.0, 0.0, 600.0, 0.0, "karma", "#f5cd7c",
            "Un renard humanoïde au masque blanc, armure indigo et neuf queues translucides aux pointes dorées. Souple et imprévisible, il accompagne les changements d'appui du porteur.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 95.0, "energy_drain": 0.9, "technique_energy_cost": 0.0,
            "pg_max": 210.0, "pe_max": 95.0, "pe_drain": 0.9, "sprint_pe_drain": 1.0, "duel_pg_cost": 9.0, "duel_pe_cost": 4.0, "defeat_pg_cost": 18.0,
            "signature_id": "ninefold_hunt", "owner_keys": ["azur_08"], "stat_bonuses": {"dribble": 16.0, "technique": 12.0},
            "appearance": {"style": "vaelis", "height": 3.8, "primary": "#272653", "accent": "#f5cd7c", "sound": "Neuf tintements cristallins et un souffle de soie.", "motif": "Masque blanc de renard, armure indigo et neuf queues à pointes dorées."}}),
        _definition("orvann", "Orvann, le Cerf des remparts", "KARMA", 0.0, 0.0, 600.0, 0.0, "karma", "#92d69d",
            "Un cerf cuirassé de pierre blanche et de cuivre, aux bois géométriques et épaules de forteresse. Une lumière verte circule dans ses gravures ; ses gestes sont lourds et protecteurs.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 80.0, "energy_drain": 0.8, "technique_energy_cost": 0.0,
            "pg_max": 260.0, "pe_max": 80.0, "pe_drain": 0.8, "sprint_pe_drain": 1.0, "duel_pg_cost": 10.0, "duel_pe_cost": 4.0, "defeat_pg_cost": 20.0,
            "signature_id": "antler_citadel", "owner_keys": ["azur_04"], "stat_bonuses": {"defense": 18.0, "technique": 8.0},
            "appearance": {"style": "orvann", "height": 4.2, "primary": "#e3ddc8", "accent": "#92d69d", "sound": "Branches de cuivre, pierres qui s'assemblent et vibration grave.", "motif": "Bois géométriques, armure de pierre blanche, cuivre et gravures vertes."}}),
        _definition("perihelion_hammer", "Marteau du Périhélie", "TIR", 45.0, 0.0, 4.5, 5.0, "perihelion", "#eaa266",
            "Trois anneaux compriment le ballon en un disque incandescent. La frappe du joueur rejoint le marteau d'Astreion et projette un météore dans un tunnel de lumière. Idéal de 10 à 28 mètres ; la puissance diminue ensuite.",
            {"karma_id": "astreion", "pg_cost": 70.0, "pe_cost": 12.0, "preview": "perihelion", "branch_at": 0.58, "flight_arc": 3.0, "spin": 2.4, "optimal_min": 10.0, "optimal_max": 28.0, "distance_falloff": 1.2}),
        _definition("abyssal_cathedral", "Cathédrale abyssale", "GAR", 45.0, 0.0, 4.8, 0.0, "abyssal", "#5fe3df",
            "Thalassa ferme ses ailes et érige une voûte de colonnes d'eau. Après révélation des scores : la voûte ramène le ballon pour une capture, une colonne le dévie, ou les fissures la font éclater. La préparation reste identique.",
            {"karma_id": "thalassa", "pg_cost": 80.0, "pe_cost": 14.0, "preview": "abyssal", "branch_at": 0.58, "capture": true,
            "success_animation": "abyssal_capture", "parry_animation": "abyssal_parry", "failure_animation": "abyssal_shatter"}),
        _definition("ninefold_hunt", "Chasse aux neuf reflets", "ATT", 43.0, 0.0, 5.0, 0.0, "ninefold", "#f5cd7c",
            "Les neuf queues de Vaélis deviennent des silhouettes qui croisent leurs courses autour du défenseur. Après les scores, un seul reflet accompagne le porteur victorieux ; un échec révèle la récupération adverse.",
            {"karma_id": "vaelis", "pg_cost": 55.0, "pe_cost": 10.0, "dash": 3.1, "preview": "ninefold", "branch_at": 0.58}),
        _definition("antler_citadel", "Citadelle des ramures", "DEF", 45.0, 0.0, 5.0, 0.0, "citadel", "#92d69d",
            "Orvann abaisse ses bois et déploie une voûte de remparts entrelacés. Après les scores, une victoire immobilise le ballon au centre ; une défaite fracture la voûte et laisse le tir poursuivre sa route.",
            {"karma_id": "orvann", "pg_cost": 65.0, "pe_cost": 11.0, "block": true, "pushback": 2.0, "preview": "citadel", "branch_at": 0.58}),
        _definition("sovereign_orbit", "Résonance : Orbite souveraine", "RESONANCE", 0.0, 0.0, 75.0, 0.0, "resonance", "#eaa266",
            "Soren Vale, attaquant stratège, synchronise ses appuis avec le receveur. Mèches cuivrées, yeux ambrés et constellations accompagnent Drift et Tir Magnus. Astreion devient invocable si le donneur le possède.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 75.0, "energy_drain": 1.0, "technique_energy_cost": 0.0,
            "donor_key": "soren_vale", "inherited_techniques": ["drift", "magnus_shot"], "inherited_karma_id": "astreion", "stat_keys": ["shot", "dribble", "technique"], "blend": 0.2,
            "appearance": {"style": "sovereign_orbit", "primary": "#eaa266", "accent": "#fff1d5", "motif": "Mèche cuivre et blanche, yeux ambrés, constellations et anneaux de chevilles."}}),
        _definition("deep_watch", "Résonance : Vigie des profondeurs", "RESONANCE", 0.0, 0.0, 90.0, 0.0, "resonance", "#5fe3df",
            "Maëlle Néris, gardienne observatrice, accorde deux courants autour des poignets du receveur. Aquablast et Arrêt Gyroscopique sont transmis ; Thalassa devient invocable si la donneuse la possède. Les gestes GAR restent réservés au gardien.",
            {"max_active_per_team": MAX_ACTIVE_PER_TEAM, "energy_max": 90.0, "energy_drain": 1.0, "technique_energy_cost": 0.0,
            "donor_key": "maelle_neris", "inherited_techniques": ["aquablast", "gyroscopic_stop"], "inherited_karma_id": "thalassa", "stat_keys": ["keeper", "defense", "technique"], "blend": 0.2,
            "appearance": {"style": "deep_watch", "primary": "#5fe3df", "accent": "#e2fff8", "motif": "Mèche écume, yeux turquoise, courants sur les manches et anneaux aux poignets."}}),
    ]
