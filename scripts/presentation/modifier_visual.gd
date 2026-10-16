class_name IEGModifierVisual
extends Node3D
## Modèles originaux GLB, palettes et articulation en Godot standard.
## Aucun résultat ni budget n'est calculé ici.
## configure(definition), puis set_presentation(secondes,intensité,issue).
## set_signature_progress(charge,après_scores,issue) anime une signature déjà résolue.

const ASTREION_MODEL: PackedScene = preload("res://assets/karma/astreion.glb")
const THALASSA_MODEL: PackedScene = preload("res://assets/karma/thalassa.glb")

var style: String = ""
var definition: Dictionary = {}
var _body: Node3D
var _arms: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _mist: Array[MeshInstance3D] = []
var _wings: Array[MeshInstance3D] = []
var _turbines: Array[Node3D] = []
var _pillars: Array[MeshInstance3D] = []
var _arches: Array[MeshInstance3D] = []
var _core: MeshInstance3D
var _hammer: Node3D
var _primary: Color
var _color: Color
var _time: float = 0.0
var _signature: bool = false
var _height_scale: float = 1.0
var _palette: Dictionary = {}

func configure(source: Dictionary) -> void:
    definition = source.duplicate(true)
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()
    _arms.clear()
    _rings.clear()
    _mist.clear()
    _wings.clear()
    _turbines.clear()
    _pillars.clear()
    _arches.clear()
    _core = null
    _hammer = null
    _palette.clear()
    var props: Dictionary = definition.get("properties", {})
    var appearance: Dictionary = props.get("appearance", {})
    style = str(appearance.get("style", props.get("preview", definition.get("id", ""))))
    var effect: String = str(definition.get("effect", ""))
    _signature = effect in ["perihelion", "abyssal"] or str(definition.get("id", "")) in ["perihelion_hammer", "abyssal_cathedral"]
    if effect == "perihelion" or style == "perihelion_hammer":
        style = "astreion"
    elif effect == "abyssal" or style == "abyssal_cathedral":
        style = "thalassa"
    if style in ["soren", "soren_vale", "orbite_souveraine"]:
        style = "sovereign_orbit"
    elif style in ["maelle", "maelle_neris", "vigie_des_profondeurs"]:
        style = "deep_watch"
    _color = Color("f5a251") if style in ["astreion", "sovereign_orbit"] else Color("56e5dc")
    if Color.html_is_valid(str(definition.get("color", ""))):
        _color = Color.html(str(definition.color))
    # La palette d'apparence prime ; la couleur générale reste le repli des anciens contenus.
    if Color.html_is_valid(str(appearance.get("accent", ""))):
        _color = Color.html(str(appearance.accent))
    _primary = Color("17263f") if style == "astreion" else Color("163c5b")
    if Color.html_is_valid(str(appearance.get("primary", ""))):
        _primary = Color.html(str(appearance.primary))
    var height: Variant = appearance.get("height", 4.0)
    var safe_height: float = float(height) if height is float or height is int else 4.0
    _height_scale = clampf(safe_height / 4.0, 0.25, 3.0) if style in ["astreion", "thalassa"] and is_finite(safe_height) else 1.0
    _body = Node3D.new()
    _body.name = "SpiritBody" if style in ["astreion", "thalassa"] else "ResonanceMarks"
    add_child(_body)
    match style:
        "astreion": _build_astreion()
        "thalassa": _build_thalassa()
        "sovereign_orbit", "deep_watch": _build_resonance()
        _: _build_fallback()
    set_presentation(0.0)

func set_presentation(time: float, intensity: float = 1.0, _outcome: String = "") -> void:
    _time = time
    if _body == null:
        return
    _body.position.y = sin(time * 1.6) * 0.055
    _body.rotation = Vector3.ZERO
    _body.scale = Vector3.ONE * maxf(0.001, intensity) * _height_scale
    for index: int in _rings.size():
        _rings[index].rotation = Vector3(0.25 + index * 0.5, time * (0.5 + index * 0.16), index * 0.7)
        _rings[index].scale = Vector3.ONE
    for index: int in _mist.size():
        var phase: float = time * 0.7 + index * TAU / maxf(1, _mist.size())
        _mist[index].position = Vector3(cos(phase) * (0.3 + index % 3 * 0.12),
            0.25 + fposmod(time * 0.32 + index * 0.13, 1.2), sin(phase) * 0.32)
        _mist[index].scale = Vector3(1, 0.5 + sin(phase) * 0.15, 1)
    for index: int in _arms.size():
        _arms[index].rotation = Vector3(0.03 * sin(time * 1.5), 0, (-1 if index == 0 else 1) * 0.14)
    for turbine: Node3D in _turbines:
        turbine.rotation.z = time * 2.3
    for index: int in _wings.size():
        _wings[index].rotation.z = (-1.0 if index == 0 else 1.0) * (0.07 + sin(time * 1.6) * 0.035)
    if _core != null:
        _core.rotation = Vector3(sin(time * 0.8) * 0.12, sin(time * 0.55) * 0.16, time * 0.28)
        _core.scale = Vector3.ONE * (1 + sin(time * 3.4) * 0.08)
    for pillar: MeshInstance3D in _pillars:
        pillar.visible = false
    for arch: MeshInstance3D in _arches:
        arch.visible = false

func set_signature_progress(charge: float, after: float, outcome: String = "") -> void:
    # L'issue ne sert qu'après charge=1, donc préparation commune aux trois fins.
    var charge_amount: float = clampf(charge, 0, 1)
    var after_amount: float = clampf(after, 0, 1)
    if style == "astreion":
        var strike: float = smoothstep(0.64, 1.0, charge_amount)
        _body.rotation.y = -sin(charge_amount * PI) * 0.22
        if _arms.size() > 1:
            _arms[1].rotation = Vector3(lerpf(-2.45, 0.45, strike) * (1 - after_amount * 0.7), 0, 0.2)
            _arms[0].rotation = Vector3(-0.55 * charge_amount, 0, -0.7 * charge_amount)
        for index: int in _rings.size():
            _rings[index].scale = Vector3.ONE * (1.2 - charge_amount * 0.34 + after_amount * 0.8)
    elif style == "thalassa":
        var failure: float = after_amount if outcome in ["goal", "failure"] else 0.0
        var parry: float = after_amount if outcome in ["deflection", "parry"] else 0.0
        var capture: float = after_amount if outcome in ["capture", "success"] else 0.0
        for index: int in _arms.size():
            var side: float = -1.0 if index == 0 else 1.0
            _arms[index].rotation = Vector3(-charge_amount * 0.55 + capture * 0.22, 0,
                side * (0.75 * charge_amount - capture * 0.46 + failure * 0.6) + parry * 0.55)
        for index: int in _pillars.size():
            var pillar: MeshInstance3D = _pillars[index]
            var side: float = -1 if index < 3 else 1
            var ordinal: int = index % 3
            pillar.visible = charge_amount > 0.1
            pillar.position = Vector3(side * (0.9 + ordinal * 0.5 + failure * 2.2),
                1.45 + failure * sin(index * 2.0) * 1.6, -0.9 - ordinal * 0.2)
            pillar.scale = Vector3(1 - capture * 0.35, maxf(0.02, charge_amount), 1)
            pillar.rotation = Vector3(failure * (ordinal + 1) * 0.5, parry * 0.7, side * failure * 0.8)
        for index: int in _arches.size():
            var arch: MeshInstance3D = _arches[index]
            arch.visible = charge_amount > 0.4
            arch.position = Vector3(failure * sin(index + 1.0) * 1.4 + parry * 0.9,
                1.4 + failure * index * 0.3, -0.9 - index * 0.22)
            arch.scale = Vector3.ONE * (charge_amount * (1 - capture * 0.44) + failure * 0.4)
            arch.rotation = Vector3(PI * 0.5 + failure * index * 0.4, failure * index * 0.3, parry * 0.4)
        _body.rotation.x = -failure * 0.18

func _build_astreion() -> void:
    _create_palette()
    var model: Node3D = ASTREION_MODEL.instantiate()
    _take_part(model, "BodyArmor", _body)
    _take_part(model, "BodyDetails", _body)
    _core = _take_part(model, "Core", _body) as MeshInstance3D
    for part_name: String in ["ArmLeft", "ArmRight"]:
        _arms.append(_take_part(model, part_name, _body))
    _hammer = _take_part(model, "Hammer", _arms[1])
    for index: int in 3:
        _rings.append(_take_part(model, "Orbit%d" % index, _body) as MeshInstance3D)
    # Petits éclats effilés, jamais des sphères de brouillard masquant le modèle.
    for index: int in 9:
        _mist.append(_shard(_body, 0.035 + (index % 3) * 0.012, _palette.Light))
    model.free()

func _build_thalassa() -> void:
    _create_palette()
    var model: Node3D = THALASSA_MODEL.instantiate()
    _take_part(model, "BodyArmor", _body)
    _take_part(model, "BodyDetails", _body)
    _core = _take_part(model, "Core", _body) as MeshInstance3D
    for part_name: String in ["ArmLeft", "ArmRight"]:
        _arms.append(_take_part(model, part_name, _body))
    for part_name: String in ["WingLeft", "WingRight"]:
        _wings.append(_take_part(model, part_name, _body) as MeshInstance3D)
    for part_name: String in ["TurbineLeft", "TurbineRight"]:
        _turbines.append(_take_part(model, part_name, _body))
    model.free()
    for index: int in 9:
        _mist.append(_shard(_body, 0.026 + (index % 3) * 0.01, _palette.Light))
    # Éléments de signature indépendants des panneaux sculptés du personnage.
    var water: StandardMaterial3D = _material(_color.darkened(0.12), true, 0.42)
    for index: int in 6:
        _pillars.append(_fluted_pillar(_body, water))
    for index: int in 3:
        _arches.append(_ring(_body, Vector3.ZERO, 1.45 + index * 0.08, _palette.Light))

func _create_palette() -> void:
    var armor: StandardMaterial3D = _material(_primary, false)
    armor.metallic = 0.20
    armor.roughness = 0.43
    armor.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
    armor.rim_enabled = true
    armor.rim = 0.22
    armor.rim_tint = 0.5
    var trim: StandardMaterial3D = _material(_color.darkened(0.24), false)
    trim.metallic = 0.40
    trim.roughness = 0.35
    var light: StandardMaterial3D = _material(_color, true)
    light.emission_energy_multiplier = 0.55
    var dark: StandardMaterial3D = _material(_primary.darkened(0.6), false)
    dark.metallic = 0.2
    dark.roughness = 0.5
    # Opaque coloured sea glass: silhouettes stay readable in Compatibility and
    # in the editor; the magical water pillars carry the actual transparency.
    var glass: StandardMaterial3D = _material(_color.darkened(0.48), false)
    glass.metallic = 0.15
    glass.roughness = 0.24
    glass.rim_enabled = true
    glass.rim = 0.32
    glass.rim_tint = 0.7
    if style == "astreion":
        glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        glass.albedo_color = Color(_color, 0.24)
        glass.metallic = 0.0
        glass.emission_enabled = true
        glass.emission = _color
        glass.emission_energy_multiplier = 0.55
    _palette = {"Primary": armor, "Trim": trim, "Light": light, "Dark": dark, "Glass": glass}

func _take_part(model: Node3D, part_name: String, parent: Node3D) -> Node3D:
    var part: Node3D = model.find_child(part_name, true, false) as Node3D
    assert(part != null, "Pièce du modèle Karma absente : " + part_name)
    _clear_part_owners(part)
    part.get_parent().remove_child(part)
    parent.add_child(part)
    _apply_model_palette(part)
    return part

func _clear_part_owners(node: Node) -> void:
    node.owner = null
    for child: Node in node.get_children():
        _clear_part_owners(child)

func _apply_model_palette(node: Node) -> void:
    if node is MeshInstance3D:
        var instance: MeshInstance3D = node as MeshInstance3D
        for surface: int in instance.mesh.get_surface_count():
            var original: Material = instance.mesh.surface_get_material(surface)
            var material_name: String = original.resource_name if original != null else "Primary"
            for key: String in _palette:
                if material_name.begins_with(key):
                    if instance.mesh.get_surface_count() == 1:
                        instance.material_override = _palette[key]
                    else:
                        instance.set_surface_override_material(surface, _palette[key])
                    break
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for child: Node in node.get_children():
        _apply_model_palette(child)

func _build_resonance() -> void:
    var material: StandardMaterial3D = _material(_color, true)
    material.emission_energy_multiplier = 0.6
    var pale: StandardMaterial3D = _material(_color.lightened(0.52), true)
    pale.emission_energy_multiplier = 0.3
    if style == "sovereign_orbit":
        for side: int in [-1, 1]:
            # Des rubans à section aiguisée épousent les chevilles.
            var ribbon: MeshInstance3D = _ribbon(_body, Vector3(side * 0.16, 0.20, 0), 0.19, 0.025, material)
            _rings.append(ribbon)
        # Mèche effilée et coutures de constellation, aux proportions du visage.
        _hair_lock(_body, Vector3(0.07, 1.79, -0.105), pale, 1)
        var points: Array[Vector3] = [Vector3(-0.13, 1.40, -0.17), Vector3(-0.06, 1.37, -0.205),
            Vector3(0.01, 1.40, -0.215), Vector3(0.08, 1.35, -0.205), Vector3(0.15, 1.38, -0.17)]
        for index: int in points.size() - 1:
            _line(_body, points[index], points[index + 1], 0.004, material)
        for point: Vector3 in points:
            var mark: MeshInstance3D = _shard(_body, 0.012, pale)
            mark.position = point
            mark.scale = Vector3(0.7, 1, 0.2)
    else:
        for side: int in [-1, 1]:
            var ribbon: MeshInstance3D = _ribbon(_body, Vector3(side * 0.43, 0.96, 0), 0.12, 0.019, material)
            _rings.append(ribbon)
            for index: int in 2:
                var a: Vector3 = Vector3(side * (0.30 + index * 0.027), 1.41, -0.10)
                var b: Vector3 = Vector3(side * (0.37 + index * 0.027), 1.21, -0.11)
                _line(_body, a, b, 0.007, material)
        _hair_lock(_body, Vector3(-0.06, 1.79, -0.105), pale, -1)
    # De minces facettes remplacent les anciennes billes devant les yeux.
    for side: int in [-1, 1]:
        _line(_body, Vector3(side * 0.045, 1.67, -0.165), Vector3(side * 0.088, 1.678, -0.153), 0.004, pale)

func _hair_lock(parent: Node3D, point: Vector3, material: Material, side: int) -> void:
    var vertices: Array[Vector3] = [Vector3(-0.035, 0.02, 0.015), Vector3(0.025, 0.035, 0.02),
        Vector3(side * 0.025, -0.17, -0.015), Vector3(0, -0.025, -0.035)]
    _facets(parent, vertices, [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 2, 1], point, material)

func _shard(parent: Node3D, size: float, material: Material) -> MeshInstance3D:
    var vertices: Array[Vector3] = [Vector3(0, size * 2.5, 0), Vector3(-size, 0, 0),
        Vector3(0, 0, -size * 0.6), Vector3(size, 0, 0), Vector3(0, 0, size * 0.6), Vector3(0, -size * 2, 0)]
    return _facets(parent, vertices, [0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 1,
        5, 2, 1, 5, 3, 2, 5, 4, 3, 5, 1, 4], Vector3.ZERO, material)

func _facets(parent: Node3D, vertices: Array[Vector3], indices: Array[int], point: Vector3, material: Material) -> MeshInstance3D:
    var mesh: ImmediateMesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for triangle: int in indices.size() / 3:
        var a: Vector3 = vertices[indices[triangle * 3]]
        var b: Vector3 = vertices[indices[triangle * 3 + 1]]
        var c: Vector3 = vertices[indices[triangle * 3 + 2]]
        mesh.surface_set_normal((b - a).cross(c - a).normalized())
        mesh.surface_add_vertex(a)
        mesh.surface_add_vertex(b)
        mesh.surface_add_vertex(c)
    mesh.surface_end()
    return _mesh(parent, mesh, point, material)

func _ribbon(parent: Node3D, point: Vector3, radius: float, width: float, material: Material) -> MeshInstance3D:
    var mesh: ImmediateMesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for segment: int in 48:
        var angle_a: float = segment * TAU / 48
        var angle_b: float = (segment + 1) * TAU / 48
        var taper_a: float = width * (0.4 + 0.6 * sin(angle_a * 0.5))
        var taper_b: float = width * (0.4 + 0.6 * sin(angle_b * 0.5))
        var a: Vector3 = Vector3(cos(angle_a) * (radius - taper_a), sin(angle_a * 2) * 0.014, sin(angle_a) * (radius - taper_a))
        var b: Vector3 = Vector3(cos(angle_a) * (radius + taper_a), 0.01 + sin(angle_a * 2) * 0.014, sin(angle_a) * (radius + taper_a))
        var c: Vector3 = Vector3(cos(angle_b) * (radius - taper_b), sin(angle_b * 2) * 0.014, sin(angle_b) * (radius - taper_b))
        var d: Vector3 = Vector3(cos(angle_b) * (radius + taper_b), 0.01 + sin(angle_b * 2) * 0.014, sin(angle_b) * (radius + taper_b))
        mesh.surface_set_normal(Vector3.UP)
        for vertex: Vector3 in [a, b, c, b, d, c]:
            mesh.surface_add_vertex(vertex)
    mesh.surface_end()
    return _mesh(parent, mesh, point, material)

func _line(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
    var instance: MeshInstance3D = _cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), material)
    var direction: Vector3 = (b - a).normalized()
    instance.quaternion = Quaternion(Vector3.UP, direction)

func _fluted_pillar(parent: Node3D, material: Material) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 0.075
    mesh.bottom_radius = 0.16
    mesh.height = 2.9
    mesh.radial_segments = 10
    return _mesh(parent, mesh, Vector3.ZERO, material)

func _build_fallback() -> void:
    # Contenus historiques et nouveaux styles personnalisés restent visibles dans l'atelier.
    var material: StandardMaterial3D = _material(_color, true)
    for index: int in 3:
        _rings.append(_ring(_body, Vector3(0, 0.4 + index * 0.45, 0), 0.6 + index * 0.12, material))
    for index: int in 6:
        _mist.append(_sphere(_body, Vector3.ZERO, 0.06, material))

func _material(color: Color, emissive: bool, opacity: float = 1) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(color, opacity)
    material.metallic = 0.65 if not emissive else 0.1
    material.roughness = 0.38
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.2
    if opacity < 1:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

func _mesh(parent: Node3D, mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = point
    parent.add_child(instance)
    return instance

func _sphere(parent: Node3D, point: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2
    mesh.radial_segments = 12
    mesh.rings = 6
    return _mesh(parent, mesh, point, material)

func _box(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    return _mesh(parent, mesh, point, material)

func _cylinder(parent: Node3D, point: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    return _mesh(parent, mesh, point, material)

func _cone(parent: Node3D, point: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 0
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 8
    return _mesh(parent, mesh, point, material)

func _ring(parent: Node3D, point: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var mesh: TorusMesh = TorusMesh.new()
    mesh.inner_radius = radius - 0.025
    mesh.outer_radius = radius + 0.025
    mesh.rings = 36
    mesh.ring_segments = 6
    return _mesh(parent, mesh, point, material)
