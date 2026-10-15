class_name IEGTechniqueCatalog
extends RefCounted
## Contenus de match partageables entre simulation, présentation et atelier.
## Les modifications locales sont sérialisées dans user://, jamais dans les assets.

const STORAGE_PATH: String = "user://match_content.json"
const SCHEMA_VERSION: int = 1
const CATEGORIES: PackedStringArray = ["TIR", "ATT", "DEF", "GAR", "TAC", "ECHO", "RESONANCE"]
const REQUIRED_FIELDS: PackedStringArray = ["id", "name", "category", "power", "cost", "duration", "range_bonus", "effect", "color", "description", "properties"]

var last_errors: PackedStringArray = []
var _overrides: Dictionary = {}
var _storage_path: String = STORAGE_PATH

func _init(storage_path: String = STORAGE_PATH) -> void:
    _storage_path = storage_path
    load_overrides()

func get_definition(id: String) -> Dictionary:
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

func validate_definition(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = []
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
        errors.append("Catégorie inconnue. Utiliser TIR, ATT, DEF, GAR, TAC, ECHO ou RESONANCE.")
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
        if str(data["category"]) in ["ECHO", "RESONANCE"]:
            if str(properties.get("exclusive_group", "")) != "augmentation":
                errors.append("Écho et Résonance doivent partager exclusive_group : augmentation.")
        if str(data["category"]) == "ECHO":
            if not _is_finite_number(properties.get("energy_max")) or float(properties.get("energy_max", 0.0)) <= 0.0:
                errors.append("Un Écho doit avoir une réserve energy_max positive.")
            if not _is_finite_number(properties.get("energy_drain")) or float(properties.get("energy_drain", 0.0)) <= 0.0:
                errors.append("Un Écho doit avoir une consommation energy_drain positive.")
        if str(data["category"]) == "RESONANCE":
            if not properties.has("profile_a") or not properties.has("profile_b"):
                errors.append("Une Résonance doit préciser profile_a et profile_b.")
            elif properties["profile_a"] == properties["profile_b"]:
                errors.append("Une Résonance doit réunir deux profils distincts.")
            if not _is_finite_number(properties.get("blend")) or float(properties.get("blend", -1.0)) < 0.0 or float(properties.get("blend", -1.0)) > 1.0:
                errors.append("Le mélange blend doit être compris entre 0 et 1.")
    return errors

func save_overrides(entries: Array[Dictionary]) -> Error:
    var checked: Dictionary = _checked_entries(entries)
    if not last_errors.is_empty():
        return ERR_INVALID_DATA
    var document: String = JSON.stringify({"schema_version": SCHEMA_VERSION, "entries": entries}, "  ")
    if document.to_utf8_buffer().size() > 524288:
        last_errors.append("La sauvegarde dépasserait 512 Kio ; réduisez les propriétés ou le nombre de contenus.")
        return ERR_INVALID_DATA
    var temporary: String = _storage_path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        last_errors.append("Impossible de créer le fichier local : " + error_string(FileAccess.get_open_error()))
        return FileAccess.get_open_error()
    file.store_string(document)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        last_errors.append("Impossible d'écrire les contenus : " + error_string(write_error))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return write_error
    var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(_storage_path))
    if rename_error != OK:
        last_errors.append("Impossible de remplacer la sauvegarde : " + error_string(rename_error))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return rename_error
    _overrides = checked
    return OK

func load_overrides() -> Error:
    last_errors.clear()
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
    if document.get("schema_version", -1) != SCHEMA_VERSION or not document.get("entries") is Array:
        last_errors.append("Version de contenu inconnue ou tableau entries absent.")
        return ERR_INVALID_DATA
    var checked: Dictionary = _checked_entries(document["entries"])
    if not last_errors.is_empty():
        return ERR_INVALID_DATA
    _overrides = checked
    return OK

func reset_overrides() -> Error:
    last_errors.clear()
    if FileAccess.file_exists(_storage_path):
        var result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(_storage_path))
        if result != OK:
            last_errors.append("Impossible de rétablir les contenus : " + error_string(result))
            return result
    _overrides.clear()
    return OK

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
        for error: String in validate_definition(definition):
            last_errors.append("Entrée %d : %s" % [index + 1, error])
        var id: String = str(definition.get("id", ""))
        if checked.has(id):
            last_errors.append("Identifiant en double : " + id)
        checked[id] = definition.duplicate(true)
    return checked

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
        _definition("wide_wings", "Ailes ouvertes", "TAC", 0.0, 12.0, 60.0, 0.0, "wide", "#87c7ff",
            "Les soutiens s'écartent pour créer deux couloirs de passe. Une pression mesurée conserve l'équilibre collectif.",
            {"width_factor": 1.35, "pressure": 0.35}),
        _definition("compact_press", "Étau collectif", "TAC", 0.0, 15.0, 45.0, 0.0, "press", "#ff937c",
            "Le bloc se resserre et avance sur le porteur, avec un seul poursuivant pour conserver les couvertures.",
            {"width_factor": 0.72, "pressure": 0.85}),
        _definition("tempest_echo", "Écho : Vigie des vents", "ECHO", 14.0, 0.0, 45.0, 0.0, "echo", "#c2b0ff",
            "Une silhouette de vent accompagne le joueur. Sa réserve d'énergie propre se vide avec le temps et chaque technique. Incompatible avec une Résonance.",
            {"exclusive_group": "augmentation", "energy_max": 100.0, "energy_drain": 2.2, "technique_energy_cost": 18.0}),
        _definition("twin_resonance", "Résonance : Double horizon", "RESONANCE", 12.0, 20.0, 60.0, 0.0, "resonance", "#ff9fe3",
            "Deux profils mettent leurs qualités en commun pour une fusion temporaire pondérée. Une seule augmentation peut être active.",
            {"exclusive_group": "augmentation", "profile_a": 7, "profile_b": 10, "blend": 0.5}),
    ]
