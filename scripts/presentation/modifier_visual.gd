class_name IEGModifierVisual
extends Node3D
## Géométrie originale, Godot standard. Aucun résultat ni budget n'est calculé ici.
## configure(definition), puis set_presentation(secondes,intensité,issue).
## set_signature_progress(charge,après_scores,issue) anime une signature déjà résolue.

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
        _core.rotation = Vector3(time * 0.55, time * 0.7, time * 0.25)
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
    var armor: StandardMaterial3D = _material(_primary, false)
    var copper: StandardMaterial3D = _material(_color.darkened(0.16), false)
    var light: StandardMaterial3D = _material(_color, true)
    var haze: StandardMaterial3D = _material(_color, true, 0.18)
    _box(_body, Vector3(0, 1.8, 0), Vector3(0.8, 0.36, 0.48), armor)
    _box(_body, Vector3(0, 2.55, 0.05), Vector3(1.12, 1.0, 0.5), armor)
    # Deux pectoraux laissent réellement ouverte la cage centrale de l'étoile.
    _box(_body, Vector3(-0.36, 2.75, -0.32), Vector3(0.31, 0.8, 0.2), copper)
    _box(_body, Vector3(0.36, 2.75, -0.32), Vector3(0.31, 0.8, 0.2), copper)
    _core = _sphere(_body, Vector3(0, 2.67, -0.4), 0.26, light)
    for index: int in 3:
        var ring: MeshInstance3D = _ring(_body, Vector3(0, 2.67, -0.42), 0.36 + index * 0.055, light)
        ring.rotation.x = PI * 0.5
    _sphere(_body, Vector3(0, 3.43, 0), 0.37, armor).scale = Vector3(0.82, 1.15, 0.85)
    _ring(_body, Vector3(0, 3.45, -0.27), 0.3, copper).rotation.x = PI * 0.5
    _box(_body, Vector3(0, 3.45, -0.32), Vector3(0.32, 0.045, 0.035), light)
    _cone(_body, Vector3(0, 3.88, 0), 0.26, 0.42, copper)
    for side: int in [-1, 1]:
        _sphere(_body, Vector3(side * 0.85, 2.95, 0), 0.39, copper).scale = Vector3(1.2, 0.8, 1.0)
        var arm: Node3D = Node3D.new()
        arm.position = Vector3(side * 0.82, 2.86, 0)
        _body.add_child(arm)
        _arms.append(arm)
        _cylinder(arm, Vector3(0, -0.45, 0), 0.2, 0.85, armor)
        _box(arm, Vector3(0, -0.97, 0), Vector3(0.4, 0.5, 0.42), copper)
        _sphere(arm, Vector3(0, -1.31, -0.04), 0.23, armor)
    for index: int in 3:
        var orbit: MeshInstance3D = _ring(_body, Vector3(0, 2.7, 0.3), 1.22 + index * 0.2, light)
        _rings.append(orbit)
    for index: int in 12:
        _mist.append(_sphere(_body, Vector3.ZERO, 0.2 + (index % 3) * 0.055, haze))
    _hammer = Node3D.new()
    _hammer.position = Vector3(0, -1.24, 0)
    _arms[1].add_child(_hammer)
    _cylinder(_hammer, Vector3(0, -0.5, 0), 0.055, 1.6, copper)
    _box(_hammer, Vector3(0, -1.25, 0), Vector3(1.0, 0.56, 0.56), armor)
    _box(_hammer, Vector3(0, -1.25, -0.31), Vector3(0.75, 0.34, 0.055), light)
    for side: int in [-1, 1]:
        _box(_hammer, Vector3(side * 0.48, -1.25, 0), Vector3(0.15, 0.62, 0.62), copper)

func _build_thalassa() -> void:
    var armor: StandardMaterial3D = _material(_primary, false)
    var glass: StandardMaterial3D = _material(_color, false, 0.62)
    var light: StandardMaterial3D = _material(_color.lightened(0.18), true)
    _sphere(_body, Vector3(0, 2.25, 0), 0.64, glass).scale = Vector3(0.8, 1.2, 0.65)
    _box(_body, Vector3(0, 2.65, -0.25), Vector3(0.65, 0.66, 0.2), armor)
    _sphere(_body, Vector3(0, 3.24, 0), 0.3, glass)
    _box(_body, Vector3(0, 3.27, -0.28), Vector3(0.34, 0.055, 0.04), light)
    _cone(_body, Vector3(0, 3.64, 0.08), 0.24, 0.44, armor)
    for side: int in [-1, 1]:
        var arm: Node3D = Node3D.new()
        arm.position = Vector3(side * 0.53, 2.7, -0.12)
        _body.add_child(arm)
        _arms.append(arm)
        _cylinder(arm, Vector3(side * 0.23, -0.4, 0), 0.15, 0.85, armor).rotation.z = side * 0.45
        _sphere(arm, Vector3(side * 0.42, -0.94, -0.08), 0.27, glass).scale = Vector3(0.9, 1.4, 0.6)
        var shield: MeshInstance3D = _ring(arm, Vector3(side * 0.43, -0.95, -0.24), 0.39, light)
        shield.rotation.x = PI * 0.5
        var wing: MeshInstance3D = _wing(_body, side, glass)
        _wings.append(wing)
        var turbine: Node3D = Node3D.new()
        turbine.position = Vector3(side * 0.86, 2.9, 0.42)
        _body.add_child(turbine)
        _turbines.append(turbine)
        _ring(turbine, Vector3.ZERO, 0.4, armor).rotation.x = PI * 0.5
        for blade: int in 5:
            var angle: float = blade * TAU / 5
            var vane: MeshInstance3D = _box(turbine, Vector3(cos(angle), sin(angle), 0) * 0.2, Vector3(0.3, 0.09, 0.04), light)
            vane.rotation.z = angle + 0.4
    for index: int in 9:
        _mist.append(_sphere(_body, Vector3.ZERO, 0.17, _material(_color, true, 0.2)))
    for index: int in 6:
        _pillars.append(_cylinder(_body, Vector3.ZERO, 0.12, 2.9, glass))
    for index: int in 3:
        _arches.append(_ring(_body, Vector3.ZERO, 1.45 + index * 0.08, light))

func _build_resonance() -> void:
    var material: StandardMaterial3D = _material(_color, true)
    var primary_material: StandardMaterial3D = _material(_primary, true)
    if style == "sovereign_orbit":
        for side: int in [-1, 1]:
            var ring: MeshInstance3D = _ring(_body, Vector3(side * 0.16, 0.22, 0), 0.22, material)
            _rings.append(ring)
        # Mèche et constellation : éléments amovibles, aucun asset partagé modifié.
        var lock: MeshInstance3D = _cone(_body, Vector3(0.1, 1.79, -0.16), 0.045, 0.18, primary_material)
        lock.rotation = Vector3(PI, 0, -0.35)
        for index: int in 5:
            _sphere(_body, Vector3(-0.19 + index * 0.08, 1.38 - sin(index) * 0.06, -0.23), 0.025, material)
    else:
        for side: int in [-1, 1]:
            var ring: MeshInstance3D = _ring(_body, Vector3(side * 0.48, 0.95, 0), 0.19, material)
            _rings.append(ring)
        _cone(_body, Vector3(-0.11, 1.79, -0.17), 0.045, 0.17, primary_material).rotation = Vector3(PI, 0, 0.35)
        for side: int in [-1, 1]:
            _box(_body, Vector3(side * 0.34, 1.28, -0.12), Vector3(0.08, 0.34, 0.04), primary_material).rotation.z = side * 0.3
    for side: int in [-1, 1]:
        _sphere(_body, Vector3(side * 0.075, 1.67, -0.19), 0.022, primary_material)

func _build_fallback() -> void:
    # Contenus historiques et nouveaux styles personnalisés restent visibles dans l'atelier.
    var material: StandardMaterial3D = _material(_color, true)
    for index: int in 3:
        _rings.append(_ring(_body, Vector3(0, 0.4 + index * 0.45, 0), 0.6 + index * 0.12, material))
    for index: int in 6:
        _mist.append(_sphere(_body, Vector3.ZERO, 0.06, material))

func _wing(parent: Node3D, side: int, material: Material) -> MeshInstance3D:
    var mesh: ImmediateMesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    var vertices: Array[Vector3] = [Vector3(side * 0.3, 2.8, 0.15), Vector3(side * 2.0, 2.55, 0.3),
        Vector3(side * 1.15, 1.75, 0.6), Vector3(side * 0.3, 2.8, 0.15),
        Vector3(side * 1.15, 1.75, 0.6), Vector3(side * 0.35, 1.25, 0.42)]
    for vertex: Vector3 in vertices:
        mesh.surface_set_normal(Vector3.FORWARD)
        mesh.surface_add_vertex(vertex)
    mesh.surface_end()
    return _mesh(parent, mesh, Vector3.ZERO, material)

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
