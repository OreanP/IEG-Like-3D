class_name IEGMatchArena
extends Node3D
## Parc des Équinoxes. Le décor reste indépendant des collisions de la simulation.
## Les milliers de sièges, spectateurs, feuillages et garde-corps sont instanciés.

const HALF_WIDTH: float = 30.0
const HALF_LENGTH: float = 45.0
const GOAL_HALF_WIDTH: float = 3.66
const GOAL_HEIGHT: float = 2.44
const GOAL_DEPTH: float = 2.0
const PITCH_SHADER = preload("res://assets/environment/match_pitch.gdshader")

var _white: StandardMaterial3D
var _steel: StandardMaterial3D
var _concrete: StandardMaterial3D
var _blue: StandardMaterial3D
var _red: StandardMaterial3D
var _navy: StandardMaterial3D
var _copper: StandardMaterial3D
var _cream: StandardMaterial3D
var _second_half: bool = false
var _pipe_groups: Dictionary = {}
var _seats: Array = []
var _seat_colors: Array = []
var _crowd_bodies: Array = []
var _crowd_colors: Array = []
var _crowd_heads: Array = []
var _skin_colors: Array = []
var _crowd_legs: Array = []
var _crowd_hair: Array = []
var _hair_colors: Array = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    _random.seed = 7082026
    _white = _material(Color("e9eadd"))
    _steel = _material(Color("334552"))
    _concrete = _material(Color("a0a39a"))
    _blue = _material(Color("315d78"))
    _red = _material(Color("794356"))
    _navy = _material(Color("15283a"))
    _copper = _material(Color("b88e59"))
    _cream = _material(Color("b4b5a3"))
    _build_ground()
    _build_markings()
    _build_goal(-1.0)
    _build_goal(1.0)
    _build_stands()
    _build_surroundings()
    _bake_static_boxes()
    _flush_seating()
    _flush_pipes()
    _build_lighting()

func set_second_half(value: bool) -> void:
    _second_half = value

func _material(color: Color) -> StandardMaterial3D:
    var result: StandardMaterial3D = StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.9
    return result

func _box(at: Vector3, size: Vector3, material: Material, node_name: String = "Detail") -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = at
    add_child(instance)
    return instance

func _pipe(from: Vector3, to: Vector3, radius: float, material: Material) -> void:
    # Une seule MultiMesh par matériau, y compris pour les montants des buts.
    var key: int = material.get_instance_id()
    if not _pipe_groups.has(key):
        _pipe_groups[key] = {"material": material, "transforms": []}
    var basis: Basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
    basis = basis * Basis.from_scale(Vector3(radius, from.distance_to(to), radius))
    _pipe_groups[key]["transforms"].append(Transform3D(basis, (from + to) * 0.5))

func _flush_pipes() -> void:
    var cylinder: CylinderMesh = CylinderMesh.new()
    cylinder.top_radius = 1.0
    cylinder.bottom_radius = 1.0
    cylinder.height = 1.0
    cylinder.radial_segments = 8
    cylinder.rings = 1
    for group: Dictionary in _pipe_groups.values():
        _batch_mesh(cylinder, group["transforms"], [], group["material"], "StructuralRails")
    _pipe_groups.clear()

func _batch_mesh(mesh: Mesh, transforms: Array, colors: Array, material: Material, node_name: String) -> MultiMeshInstance3D:
    var batch: MultiMesh = MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = not colors.is_empty()
    batch.mesh = mesh
    batch.instance_count = transforms.size()
    for index: int in transforms.size():
        batch.set_instance_transform(index, transforms[index])
        if batch.use_colors:
            batch.set_instance_color(index, colors[index])
    var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = batch
    instance.material_override = material
    add_child(instance)
    return instance

func _bake_static_boxes() -> void:
    # Le détail architectural ne coûte pas un draw call par marche / fenêtre.
    # Le gazon conserve son mesh de 60 × 90 m ; aucun collider n'est créé.
    var groups: Dictionary = {}
    for child: Node in get_children():
        if not child is MeshInstance3D:
            continue
        var instance: MeshInstance3D = child as MeshInstance3D
        if not instance.mesh is BoxMesh or instance.material_override == null:
            continue
        var key: String = "%d:%d" % [instance.material_override.get_instance_id(), instance.cast_shadow]
        if not groups.has(key):
            groups[key] = {"material": instance.material_override, "shadow": instance.cast_shadow, "transforms": []}
        var size: Vector3 = (instance.mesh as BoxMesh).size
        groups[key]["transforms"].append(instance.transform * Transform3D(Basis.from_scale(size), Vector3.ZERO))
        remove_child(instance)
        instance.queue_free()
    var cube: BoxMesh = BoxMesh.new()
    cube.size = Vector3.ONE
    for group: Dictionary in groups.values():
        var instance: MultiMeshInstance3D = _batch_mesh(cube, group["transforms"], [], group["material"], "BatchedStadiumArchitecture")
        instance.cast_shadow = group["shadow"]

func _build_ground() -> void:
    _box(Vector3(0.0, -0.6, 0.0), Vector3(148.0, 0.9, 174.0), _material(Color("69786c")), "LandscapePlatform")
    _box(Vector3(0.0, -0.19, 0.0), Vector3(101.0, 0.2, 133.0), _material(Color("737b77")), "StadiumConcourse")
    _box(Vector3(0.0, -0.075, 0.0), Vector3(67.0, 0.12, 101.0), _material(Color("2c4c3a")), "GrassRunoff")
    var pitch: MeshInstance3D = MeshInstance3D.new()
    pitch.name = "MatchPitch60x90"
    var plane: PlaneMesh = PlaneMesh.new()
    plane.size = Vector2(HALF_WIDTH * 2.0, HALF_LENGTH * 2.0)
    pitch.mesh = plane
    var grass: ShaderMaterial = ShaderMaterial.new()
    grass.shader = PITCH_SHADER
    grass.set_shader_parameter("grass_light", Color("315c42"))
    grass.set_shader_parameter("grass_dark", Color("2b503b"))
    pitch.material_override = grass
    add_child(pitch)
    var drain: StandardMaterial3D = _material(Color("293e3c"))
    var curb: StandardMaterial3D = _material(Color("afb2a4"))
    for side: float in [-1.0, 1.0]:
        _box(Vector3(side * 30.85, -0.003, 0.0), Vector3(0.16, 0.025, 93.0), drain, "TouchlineDrainage")
        _box(Vector3(side * 34.1, -0.012, 0.0), Vector3(0.16, 0.08, 103.0), curb, "WalkwayCurb")
        _box(Vector3(0.0, -0.003, side * 46.0), Vector3(60.0, 0.025, 0.16), drain, "GoalLineDrainage")
        _box(Vector3(0.0, -0.012, side * 51.3), Vector3(68.3, 0.08, 0.16), curb, "WalkwayCurb")
        # Joints de dilatation des allées, loin des limites jouables.
        for index: int in range(-8, 9):
            _box(Vector3(side * 34.65, -0.003, float(index) * 6.0), Vector3(1.0, 0.018, 0.035), drain, "PavingJoint")

func _line(a: Vector2, b: Vector2, width: float = 0.11) -> void:
    var span: Vector2 = b - a
    var middle: Vector2 = (a + b) * 0.5
    var line: MeshInstance3D = _box(Vector3(middle.x, 0.016, middle.y),
        Vector3(width, 0.018, span.length()), _white, "PitchMark")
    line.rotation.y = atan2(span.x, span.y)
    line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _circle(at: Vector2, radius: float, begin: float = 0.0, end: float = TAU) -> void:
    var mesh: ImmediateMesh = ImmediateMesh.new()
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.name = "PitchArc"
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    var paint: StandardMaterial3D = _white.duplicate() as StandardMaterial3D
    paint.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, paint)
    mesh.surface_set_normal(Vector3.UP)
    var segments: int = maxi(12, int(96.0 * absf(end - begin) / TAU))
    for segment: int in range(segments):
        var a: float = lerpf(begin, end, float(segment) / float(segments))
        var b: float = lerpf(begin, end, float(segment + 1) / float(segments))
        var aa: Vector3 = Vector3(at.x + cos(a) * (radius - 0.055), 0.027, at.y + sin(a) * (radius - 0.055))
        var ab: Vector3 = Vector3(at.x + cos(a) * (radius + 0.055), 0.027, at.y + sin(a) * (radius + 0.055))
        var ba: Vector3 = Vector3(at.x + cos(b) * (radius - 0.055), 0.027, at.y + sin(b) * (radius - 0.055))
        var bb: Vector3 = Vector3(at.x + cos(b) * (radius + 0.055), 0.027, at.y + sin(b) * (radius + 0.055))
        for vertex: Vector3 in [aa, ba, ab, ab, ba, bb]:
            mesh.surface_add_vertex(vertex)
    mesh.surface_end()

func _spot(at: Vector2) -> void:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.height = 0.018
    mesh.top_radius = 0.14
    mesh.bottom_radius = 0.14
    mesh.radial_segments = 16
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = _white
    instance.position = Vector3(at.x, 0.02, at.y)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _build_markings() -> void:
    _line(Vector2(-30.0, -45.0), Vector2(30.0, -45.0))
    _line(Vector2(-30.0, 45.0), Vector2(30.0, 45.0))
    _line(Vector2(-30.0, -45.0), Vector2(-30.0, 45.0))
    _line(Vector2(30.0, -45.0), Vector2(30.0, 45.0))
    _line(Vector2(-30.0, 0.0), Vector2(30.0, 0.0))
    _circle(Vector2.ZERO, 9.15)
    _spot(Vector2.ZERO)
    for side: float in [-1.0, 1.0]:
        var goal_line: float = side * HALF_LENGTH
        var area_line: float = side * (HALF_LENGTH - 16.5)
        var box_line: float = side * (HALF_LENGTH - 5.5)
        var penalty_half_width: float = GOAL_HALF_WIDTH + 16.5
        var goal_area_half_width: float = GOAL_HALF_WIDTH + 5.5
        for x: float in [-penalty_half_width, penalty_half_width]:
            _line(Vector2(x, goal_line), Vector2(x, area_line))
        _line(Vector2(-penalty_half_width, area_line), Vector2(penalty_half_width, area_line))
        for x: float in [-goal_area_half_width, goal_area_half_width]:
            _line(Vector2(x, goal_line), Vector2(x, box_line))
        _line(Vector2(-goal_area_half_width, box_line), Vector2(goal_area_half_width, box_line))
        _spot(Vector2(0.0, side * 34.0))
        if side < 0.0:
            _circle(Vector2(0.0, -34.0), 9.15, 0.646, PI - 0.646)
        else:
            _circle(Vector2(0.0, 34.0), 9.15, PI + 0.646, TAU - 0.646)
        for x: float in [-30.0, 30.0]:
            _pipe(Vector3(x, 0.0, goal_line), Vector3(x, 1.3, goal_line), 0.025, _white)
            var flag: MeshInstance3D = _box(Vector3(x + 0.23, 1.19, goal_line), Vector3(0.45, 0.28, 0.025), _red, "CornerFlag")
            flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_goal(side: float) -> void:
    var z: float = side * HALF_LENGTH
    var back: float = z + side * GOAL_DEPTH
    for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
        _pipe(Vector3(x, 0.0, z), Vector3(x, GOAL_HEIGHT, z), 0.065, _white)
        _pipe(Vector3(x, 0.0, back), Vector3(x, GOAL_HEIGHT, back), 0.035, _steel)
        _pipe(Vector3(x, GOAL_HEIGHT, z), Vector3(x, GOAL_HEIGHT, back), 0.035, _white)
        _pipe(Vector3(x, 0.035, z), Vector3(x, 0.035, back), 0.035, _white)
    _pipe(Vector3(-GOAL_HALF_WIDTH, GOAL_HEIGHT, z), Vector3(GOAL_HALF_WIDTH, GOAL_HEIGHT, z), 0.065, _white)
    _pipe(Vector3(-GOAL_HALF_WIDTH, 0.035, back), Vector3(GOAL_HALF_WIDTH, 0.035, back), 0.035, _white)
    var net: ImmediateMesh = ImmediateMesh.new()
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = "GoalNet"
    instance.mesh = net
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    var material: StandardMaterial3D = _material(Color("bdc9be"))
    net.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for index: int in range(33):
        var x: float = lerpf(-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH, float(index) / 32.0)
        net.surface_add_vertex(Vector3(x, 0.04, back))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, back))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, z))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, back))
    for index: int in range(12):
        var y: float = GOAL_HEIGHT * float(index) / 11.0
        net.surface_add_vertex(Vector3(-GOAL_HALF_WIDTH, y, back))
        net.surface_add_vertex(Vector3(GOAL_HALF_WIDTH, y, back))
        for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
            net.surface_add_vertex(Vector3(x, y, z))
            net.surface_add_vertex(Vector3(x, y, back))
    for index: int in range(10):
        var depth: float = z + side * GOAL_DEPTH * float(index) / 9.0
        net.surface_add_vertex(Vector3(-GOAL_HALF_WIDTH, GOAL_HEIGHT, depth))
        net.surface_add_vertex(Vector3(GOAL_HALF_WIDTH, GOAL_HEIGHT, depth))
        for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
            net.surface_add_vertex(Vector3(x, 0.04, depth))
            net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, depth))
    net.surface_end()

func _build_stands() -> void:
    for side: float in [-1.0, 1.0]:
        _build_long_stand(side)
        _build_end_stand(side)
        _build_advertising(side)
        _build_dugout(side)
    _build_entry_building()

func _build_long_stand(side: float) -> void:
    # Une vraie coupe de tribune : sous-bassement, gradins, promenade haute et toiture.
    _box(Vector3(side * 42.3, 0.22, 0.0), Vector3(15.0, 0.55, 84.0), _navy, "StandPlinth")
    _box(Vector3(side * 48.0, 2.85, 0.0), Vector3(0.4, 5.7, 82.0), _cream, "ConcourseRearWall")
    _box(Vector3(side * 47.4, 5.5, 0.0), Vector3(2.7, 0.22, 82.0), _concrete, "UpperPromenade")
    for row: int in range(11):
        var depth: float = 36.0 + float(row) * 0.86
        var rise: float = 0.42 + float(row) * 0.47
        _box(Vector3(side * depth, rise * 0.5, 0.0), Vector3(0.87, rise, 80.0), _concrete, "TerraceRiser")
        for seat: int in range(119):
            var z: float = (float(seat) - 59.0) * 0.66
            if absf(z) < 1.15 or absf(absf(z) - 25.1) < 0.95:
                continue
            var at: Vector3 = Vector3(side * depth, rise + 0.07, z)
            var color: Color = Color("376d87") if side < 0.0 else Color("854559")
            if row > 7:
                color = Color("253f53")
            if seat % 23 < 3:
                color = Color("c8cbbb")
            _add_seat(at, side * PI * 0.5, color, 0.77)
    # Les escaliers interrompent les sièges ; leurs rampes suivent la pente réelle.
    for aisle: float in [-25.1, 0.0, 25.1]:
        for edge: float in [-0.85, 0.85]:
            _pipe(Vector3(side * 35.9, 1.3, aisle + edge), Vector3(side * 44.8, 6.0, aisle + edge), 0.035, _steel)
        for row: int in range(11):
            var depth: float = 36.0 + float(row) * 0.86
            var rise: float = 0.42 + float(row) * 0.47
            _box(Vector3(side * (depth - 0.38), rise + 0.012, aisle), Vector3(0.08, 0.025, 1.45), _copper, "StairSafetyEdge")
    for x: float in [35.2, 47.4]:
        _pipe(Vector3(side * x, 1.0 if x < 40.0 else 6.55, -40.0), Vector3(side * x, 1.0 if x < 40.0 else 6.55, 40.0), 0.04, _steel)
        _pipe(Vector3(side * x, 0.55 if x < 40.0 else 6.1, -40.0), Vector3(side * x, 0.55 if x < 40.0 else 6.1, 40.0), 0.025, _steel)
    for z: float in [-40.0, 40.0]:
        _pipe(Vector3(side * 35.2, 1.0, z), Vector3(side * 47.4, 6.55, z), 0.04, _steel)
    for z: float in [-39.0, -26.0, -13.0, 0.0, 13.0, 26.0, 39.0]:
        _pipe(Vector3(side * 48.5, 0.0, z), Vector3(side * 48.5, 8.8, z), 0.13, _steel)
        _pipe(Vector3(side * 48.5, 8.8, z), Vector3(side * 33.5, 7.75, z), 0.085, _steel)
        _pipe(Vector3(side * 48.5, 6.4, z), Vector3(side * 39.2, 8.15, z), 0.065, _steel)
        _pipe(Vector3(side * 35.2, 0.15, z), Vector3(side * 35.2, 1.0, z), 0.035, _steel)
        _pipe(Vector3(side * 47.4, 5.5, z), Vector3(side * 47.4, 6.55, z), 0.035, _steel)
    var roof_mesh: ArrayMesh = _curved_roof_mesh()
    for panel: int in range(8):
        var z: float = (float(panel) - 3.5) * 10.1
        var roof: MeshInstance3D = MeshInstance3D.new()
        roof.name = "SculptedCantileverRoof"
        roof.mesh = roof_mesh
        roof.position = Vector3(side * 41.15, 0.0, z)
        roof.rotation.y = 0.0 if side > 0.0 else PI
        add_child(roof)
    # Nervures de couverture et gouttière : le toit garde une lecture construite.
    for rib: int in range(33):
        var z: float = (float(rib) - 16.0) * 2.5
        for segment: int in range(6):
            var a: float = float(segment) / 6.0
            var b: float = float(segment + 1) / 6.0
            _pipe(Vector3(side * (33.5 + 15.3 * a), _roof_height(a) + 0.035, z), Vector3(side * (33.5 + 15.3 * b), _roof_height(b) + 0.035, z), 0.022, _steel)
    # Treillis triangulés entre la membrure droite et la peau courbe.
    for z: float in [-39.0, -26.0, -13.0, 0.0, 13.0, 26.0, 39.0]:
        for segment: int in range(5):
            var a: float = float(segment) / 5.0
            var b: float = float(segment + 1) / 5.0
            _pipe(Vector3(side * (33.5 + 15.3 * a), _roof_height(a) - 0.12, z), Vector3(side * (33.5 + 15.3 * b), 7.75 + b * 1.05, z), 0.045, _steel)
    _pipe(Vector3(side * 33.45, 7.86, -40.5), Vector3(side * 33.45, 7.86, 40.5), 0.055, _steel)
    _box(Vector3(side * 33.4, 7.77, 0.0), Vector3(0.12, 0.4, 81.0), _navy, "CanopyFascia")
    _box(Vector3(side * 33.32, 7.98, 0.0), Vector3(0.06, 0.06, 81.0), _copper, "CanopyCopperEdge")
    _label("PARC DES ÉQUINOXES", Vector3(side * 33.31, 7.77, 0.0), side * -PI * 0.5, 0.008, Color("e6e2cd"), 56)
    # Accès latéraux et numéros de secteur visibles depuis les gradins.
    for sector: int in range(4):
        var z: float = (float(sector) - 1.5) * 19.8
        _box(Vector3(side * 48.27, 2.4, z), Vector3(0.05, 2.8, 3.5), _navy, "ConcourseOpening")
        _label("TRIBUNE %s  /  %02d" % ["AZUR" if side < 0.0 else "CARMIN", sector + 1], Vector3(side * 47.75, 4.4, z), side * -PI * 0.5, 0.006, Color("273d48"), 48)

func _roof_height(t: float) -> float:
    return 7.7 + t * 1.15 + sin(t * PI) * 0.8

func _curved_roof_mesh() -> ArrayMesh:
    # Profil continu et sous-face séparée : la couverture a une vraie épaisseur.
    var result: ArrayMesh = ArrayMesh.new()
    for layer: int in range(2):
        var surface: SurfaceTool = SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for segment: int in range(18):
            var a: float = float(segment) / 18.0
            var b: float = float(segment + 1) / 18.0
            var drop: float = 0.0 if layer == 0 else 0.12
            var vertices: Array[Vector3] = [
                Vector3(-7.65 + a * 15.3, _roof_height(a) - drop, -5.0),
                Vector3(-7.65 + a * 15.3, _roof_height(a) - drop, 5.0),
                Vector3(-7.65 + b * 15.3, _roof_height(b) - drop, 5.0),
                Vector3(-7.65 + b * 15.3, _roof_height(b) - drop, -5.0),
            ]
            var slope: float = (_roof_height(b) - _roof_height(a)) / (15.3 * (b - a))
            surface.set_normal(Vector3(-slope, 1.0, 0.0).normalized() * (1.0 if layer == 0 else -1.0))
            var order: Array = [2, 1, 0, 3, 2, 0] if layer == 0 else [0, 1, 2, 0, 2, 3]
            for index: int in order:
                surface.add_vertex(vertices[index])
        surface.set_material(_cream if layer == 0 else _navy)
        surface.commit(result)
    return result

func _build_end_stand(side: float) -> void:
    _box(Vector3(0.0, 0.2, side * 57.2), Vector3(59.0, 0.5, 10.7), _navy, "EndStandPlinth")
    for row: int in range(7):
        var z: float = side * (53.0 + float(row) * 0.82)
        var rise: float = 0.4 + float(row) * 0.45
        _box(Vector3(0.0, rise * 0.5, z), Vector3(57.5, rise, 0.83), _concrete, "EndTerraceRiser")
        for seat: int in range(85):
            var x: float = (float(seat) - 42.0) * 0.66
            if absf(x) < 1.1 or absf(absf(x) - 18.5) < 0.8:
                continue
            var color: Color = Color("376d87") if x < 0.0 else Color("854559")
            if row % 4 == 0:
                color = Color("b8bda9")
            _add_seat(Vector3(x, rise + 0.07, z), 0.0 if side > 0.0 else PI, color, 0.7)
    for x: float in [-28.5, -18.5, 0.0, 18.5, 28.5]:
        _pipe(Vector3(x, 1.2, side * 52.3), Vector3(x, 4.05, side * 58.5), 0.035, _steel)
    _pipe(Vector3(-29.0, 4.3, side * 58.9), Vector3(29.0, 4.3, side * 58.9), 0.045, _steel)
    for x: float in [-28.0, -21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0, 28.0]:
        _pipe(Vector3(x, 3.4, side * 58.9), Vector3(x, 4.3, side * 58.9), 0.035, _steel)
    # Petit bandeau de tribune, sans faux score figé qui contredirait le HUD.
    _box(Vector3(0.0, 0.72, side * 51.8), Vector3(58.0, 1.2, 0.15), _navy, "SupportersBanner")
    var yaw: float = 0.0 if side < 0.0 else PI
    _label("UN TERRAIN.  DEUX COULEURS.  LA MÊME PASSION.", Vector3(0.0, 0.75, side * 51.7), yaw, 0.012, Color("d9d5bf"), 56)
    _box(Vector3(0.0, 6.5, side * 61.0), Vector3(21.0, 4.0, 0.4), _navy, "ArenaMonumentSign")
    _box(Vector3(0.0, 8.48, side * 60.75), Vector3(21.0, 0.08, 0.08), _copper, "SignCopperEdge")
    _label("ÉQUINOXES", Vector3(0.0, 6.85, side * 60.73), yaw, 0.025, Color("e9e4ce"), 72)
    _label("PARC SPORTIF  /  AZUR × CARMIN", Vector3(0.0, 5.45, side * 60.72), yaw, 0.009, Color("95b7ba"), 56)
    for x: float in [-9.1, 9.1]:
        _pipe(Vector3(x, 0.0, side * 61.05), Vector3(x, 6.7, side * 61.05), 0.16, _steel)

func _build_advertising(side: float) -> void:
    var brands: Array[String] = ["ORBITAL", "NOVA SPORT", "RIVE ATHLETICS", "PRISME", "AURORA", "NOVA SPORT", "ORBITAL", "PRISME"]
    for index: int in range(brands.size()):
        var z: float = (float(index) - 3.5) * 10.3
        var light: bool = index % 3 == 1
        _box(Vector3(side * 31.8, 0.53, z), Vector3(0.14, 1.04, 10.0), _cream if light else _navy, "FictionalSponsorBoard")
        _box(Vector3(side * 31.7, 0.08, z), Vector3(0.12, 0.05, 10.0), _copper, "BoardAccent")
        _label(brands[index], Vector3(side * 31.69, 0.55, z), side * -PI * 0.5, 0.009, Color("263a46") if light else Color("dedbc7"), 64)
        for dz: float in [-4.5, 4.5]:
            _pipe(Vector3(side * 31.9, 0.0, z + dz), Vector3(side * 31.9, 0.65, z + dz), 0.035, _steel)
    for index: int in range(5):
        var x: float = (float(index) - 2.0) * 11.3
        _box(Vector3(x, 0.53, side * 49.8), Vector3(11.1, 1.04, 0.14), _cream if index % 2 == 0 else _navy, "EndSponsorBoard")
        _label(brands[index], Vector3(x, 0.55, side * 49.68), 0.0 if side < 0.0 else PI, 0.009, Color("263a46") if index % 2 == 0 else Color("dedbc7"), 64)

func _build_dugout(side: float) -> void:
    var z: float = side * 10.0
    var x: float = -33.6
    _box(Vector3(x, 0.1, z), Vector3(2.5, 0.18, 8.4), _steel, "TechnicalAreaPlatform")
    _box(Vector3(x - 1.1, 1.2, z), Vector3(0.08, 2.3, 8.4), _navy, "DugoutBack")
    var roof: MeshInstance3D = _box(Vector3(x, 2.45, z), Vector3(2.6, 0.12, 8.6), _cream, "DugoutCanopy")
    roof.rotation.z = 0.08
    _box(Vector3(x + 1.24, 2.3, z), Vector3(0.08, 0.3, 8.6), _blue if side < 0.0 else _red, "DugoutFascia")
    for dz: float in [-4.05, 4.05]:
        _pipe(Vector3(x + 1.1, 0.1, z + dz), Vector3(x + 1.1, 2.35, z + dz), 0.045, _steel)
    for index: int in range(10):
        _add_seat(Vector3(x - 0.4, 0.45, z + (float(index) - 4.5) * 0.69), -PI * 0.5, Color("376d87") if side < 0.0 else Color("854559"), 0.0)
    _label("AZUR" if side < 0.0 else "CARMIN", Vector3(x + 1.29, 2.3, z), PI * 0.5, 0.006, Color("eee6d0"), 48)

func _build_entry_building() -> void:
    # Pavillon au-delà du virage nord : rythme de fenêtres et terrasse de presse.
    _box(Vector3(0.0, 2.5, -66.0), Vector3(56.0, 5.0, 6.0), _cream, "NorthEntryPavilion")
    _box(Vector3(0.0, 5.05, -66.0), Vector3(57.0, 0.25, 7.0), _navy, "PavilionCornice")
    _box(Vector3(0.0, 3.4, -62.94), Vector3(54.0, 1.35, 0.05), _material(Color("46616b")), "PressBoxGlazing")
    for index: int in range(-8, 9):
        _box(Vector3(float(index) * 3.05, 3.4, -62.88), Vector3(0.09, 1.6, 0.12), _navy, "PressWindowMullion")
    for x: float in [-21.0, -14.0, 14.0, 21.0]:
        _box(Vector3(x, 1.25, -62.92), Vector3(3.4, 2.5, 0.08), _navy, "PavilionGate")
    _pipe(Vector3(-27.0, 6.0, -63.0), Vector3(27.0, 6.0, -63.0), 0.035, _steel)
    for x: float in [-27.0, -18.0, -9.0, 0.0, 9.0, 18.0, 27.0]:
        _pipe(Vector3(x, 5.1, -63.0), Vector3(x, 6.0, -63.0), 0.035, _steel)

func _add_seat(at: Vector3, yaw: float, color: Color, occupancy: float) -> void:
    var basis: Basis = Basis(Vector3.UP, yaw)
    _seats.append(Transform3D(basis, at))
    _seat_colors.append(color)
    if _random.randf() > occupancy:
        return
    var height: float = _random.randf_range(0.88, 1.13)
    var lean: float = _random.randf_range(-0.05, 0.05)
    var body_basis: Basis = basis.scaled(Vector3(1.0, height, 1.0))
    var body_at: Vector3 = at + basis * Vector3(0.0, 0.26, -0.03 + lean)
    _crowd_bodies.append(Transform3D(body_basis, body_at))
    var shirts: Array[Color] = [Color("345c76"), Color("74465a"), Color("c7c7ad"), Color("2c3f50"), Color("849e9e"), Color("b18e6e")]
    var shirt: Color = color if _random.randf() < 0.5 else shirts[_random.randi_range(0, shirts.size() - 1)]
    _crowd_colors.append(shirt)
    _crowd_heads.append(Transform3D(basis.scaled(Vector3.ONE * height), at + Vector3.UP * (0.26 + height * 0.52)))
    var skins: Array[Color] = [Color("c69573"), Color("976c50"), Color("d0ad88"), Color("704f40"), Color("ad8064")]
    _skin_colors.append(skins[_random.randi_range(0, skins.size() - 1)])
    _crowd_legs.append(Transform3D(basis, at + Vector3(0.0, 0.03, 0.0)))
    _crowd_hair.append(Transform3D(basis.scaled(Vector3.ONE * height), at + Vector3.UP * (0.26 + height * 0.61) + basis * Vector3(0.0, 0.0, 0.025)))
    var hair: Array[Color] = [Color("3b3431"), Color("514438"), Color("7e6750"), Color("a38e65"), Color("383c43")]
    _hair_colors.append(hair[_random.randi_range(0, hair.size() - 1)])

func _solid_mesh(parts: Array) -> ArrayMesh:
    # Assemblage de petits volumes dans une seule surface, utilisé par toutes les instances.
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var faces: Array = [
        [Vector3.RIGHT, [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
        [Vector3.LEFT, [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
        [Vector3.UP, [Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
        [Vector3.DOWN, [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)]],
        [Vector3.BACK, [Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)]],
        [Vector3.FORWARD, [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1)]],
    ]
    for part: Array in parts:
        var center: Vector3 = part[0]
        var size: Vector3 = part[1]
        for face: Array in faces:
            surface.set_normal(face[0])
            for index: int in [2, 1, 0, 3, 2, 0]:
                surface.add_vertex(center + (face[1][index] as Vector3) * size * 0.5)
    return surface.commit()

func _flush_seating() -> void:
    var instance_material: StandardMaterial3D = _material(Color.WHITE)
    instance_material.vertex_color_use_as_albedo = true
    var seat_mesh: ArrayMesh = _solid_mesh([
        [Vector3(0.0, 0.06, 0.0), Vector3(0.49, 0.11, 0.47)],
        [Vector3(0.0, 0.3, 0.19), Vector3(0.49, 0.41, 0.09)],
    ])
    _batch_mesh(seat_mesh, _seats, _seat_colors, instance_material, "IndividualSeats")
    var body_mesh: ArrayMesh = _solid_mesh([
        [Vector3(0.0, 0.25, 0.0), Vector3(0.28, 0.39, 0.22)],
        [Vector3(-0.18, 0.18, -0.06), Vector3(0.085, 0.28, 0.12)],
        [Vector3(0.18, 0.18, -0.06), Vector3(0.085, 0.28, 0.12)],
    ])
    _batch_mesh(body_mesh, _crowd_bodies, _crowd_colors, instance_material, "SupporterShirts")
    var head: SphereMesh = SphereMesh.new()
    head.radius = 0.125
    head.height = 0.27
    head.radial_segments = 8
    head.rings = 4
    _batch_mesh(head, _crowd_heads, _skin_colors, instance_material, "SupporterHeads")
    var hair: SphereMesh = SphereMesh.new()
    hair.radius = 0.128
    hair.height = 0.15
    hair.radial_segments = 8
    hair.rings = 3
    _batch_mesh(hair, _crowd_hair, _hair_colors, instance_material, "SupporterHair")
    var legs: ArrayMesh = _solid_mesh([
        [Vector3(-0.085, 0.13, -0.16), Vector3(0.115, 0.16, 0.38)],
        [Vector3(0.085, 0.13, -0.16), Vector3(0.115, 0.16, 0.38)],
        [Vector3(-0.085, -0.035, -0.3), Vector3(0.115, 0.27, 0.115)],
        [Vector3(0.085, -0.035, -0.3), Vector3(0.115, 0.27, 0.115)],
    ])
    _batch_mesh(legs, _crowd_legs, [], _navy, "SeatedSupporterLegs")
    # Les tribunes/toitures portent les ombres principales ; les milliers de
    # petits spectateurs n'alourdissent pas les cascades d'ombre du terrain.
    for batch_name: String in ["IndividualSeats", "SupporterShirts", "SupporterHeads", "SupporterHair", "SeatedSupporterLegs"]:
        var batch: GeometryInstance3D = get_node(batch_name) as GeometryInstance3D
        batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Les arrays CPU ne sont plus nécessaires après chargement GPU.
    _seats.clear()
    _seat_colors.clear()
    _crowd_bodies.clear()
    _crowd_colors.clear()
    _crowd_heads.clear()
    _skin_colors.clear()
    _crowd_legs.clear()
    _crowd_hair.clear()
    _hair_colors.clear()

func _label(text: String, at: Vector3, yaw: float, pixel_size: float, color: Color, font_size: int = 64) -> void:
    var label: Label3D = Label3D.new()
    label.text = text
    label.position = at
    label.rotation.y = yaw
    label.font_size = font_size
    label.pixel_size = pixel_size
    label.modulate = color
    label.outline_size = 0
    label.no_depth_test = false
    label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
    label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(label)

func _build_surroundings() -> void:
    var bark: StandardMaterial3D = _material(Color("645348"))
    var foliage_material: StandardMaterial3D = _material(Color.WHITE)
    foliage_material.vertex_color_use_as_albedo = true
    var crowns: Array = []
    var colors: Array = []
    var crown: SphereMesh = SphereMesh.new()
    crown.radius = 1.0
    crown.height = 2.0
    crown.radial_segments = 10
    crown.rings = 5
    for side: float in [-1.0, 1.0]:
        for index: int in range(11):
            var at: Vector3 = Vector3(side * _random.randf_range(55.0, 64.0), 0.0, float(index) * 13.8 - 69.0)
            var height: float = _random.randf_range(5.0, 8.4)
            _pipe(at, at + Vector3.UP * (height - 0.5), 0.2, bark)
            for lobe: int in range(4):
                var offset: Vector3 = Vector3(_random.randf_range(-1.3, 1.3), height + _random.randf_range(-0.5, 1.0), _random.randf_range(-1.3, 1.3))
                var scale: Vector3 = Vector3(_random.randf_range(1.5, 2.5), _random.randf_range(2.2, 3.2), _random.randf_range(1.5, 2.5))
                crowns.append(Transform3D(Basis.IDENTITY.scaled(scale), at + offset))
                colors.append(Color("49634b").lerp(Color("718064"), _random.randf() * 0.65))
        for z: float in [-47.0, 47.0]:
            _build_floodlight(Vector3(side * 49.5, 0.0, z))
        # Murets bas du parc et percées aux entrées.
        for z: float in [-47.0, 47.0]:
            _box(Vector3(side * 51.8, 0.45, z), Vector3(0.35, 0.9, 25.0), _cream, "GardenBoundaryWall")
    for index: int in range(19):
        var at: Vector3 = Vector3((float(index) - 9.0) * 7.6, 0.0, -76.0 - _random.randf_range(0.0, 3.0))
        var height: float = _random.randf_range(5.5, 8.0)
        _pipe(at, at + Vector3.UP * height, 0.18, bark)
        for lobe: int in range(3):
            var position: Vector3 = at + Vector3((float(lobe) - 1.0) * 1.1, height + sin(float(lobe)) * 1.0, 0.0)
            crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.0, 2.7, 2.3)), position))
            colors.append(Color("49634b").lerp(Color("718064"), _random.randf() * 0.45))
    _batch_mesh(crown, crowns, colors, foliage_material, "LayeredTreeCanopies")
    _build_skyline()
    _build_clouds()

func _build_floodlight(at: Vector3) -> void:
    _pipe(at, at + Vector3.UP * 17.5, 0.12, _steel)
    _pipe(at + Vector3(-0.75, 0.0, 0.0), at + Vector3.UP * 15.0, 0.08, _steel)
    _pipe(at + Vector3(0.75, 0.0, 0.0), at + Vector3.UP * 15.0, 0.08, _steel)
    _box(at + Vector3.UP * 17.4, Vector3(4.4, 1.7, 0.25), _navy, "FloodlightFrame")
    for row: int in range(2):
        for column: int in range(6):
            _box(at + Vector3((float(column) - 2.5) * 0.66, 17.0 + float(row) * 0.74, 0.16), Vector3(0.53, 0.57, 0.12), _cream, "DaylightFloodlightLens")

func _build_skyline() -> void:
    var facades: Array[StandardMaterial3D] = [_material(Color("8b9992")), _material(Color("939886")), _material(Color("8b8e87"))]
    var roof: StandardMaterial3D = _material(Color("526b70"))
    var glazing: StandardMaterial3D = _material(Color("547079"))
    for index: int in range(9):
        var x: float = (float(index) - 4.0) * 17.0
        var height: float = _random.randf_range(5.0, 10.0)
        var z: float = -87.0 - _random.randf_range(0.0, 9.0)
        var width: float = _random.randf_range(9.0, 13.0)
        _box(Vector3(x, height * 0.5, z), Vector3(width, height, 7.0), facades[index % 3], "DistantCampusBuilding")
        _box(Vector3(x, height + 0.15, z), Vector3(width + 0.7, 0.3, 7.7), roof, "CampusRoofline")
        for floor_index: int in range(1, int(height / 2.4) + 1):
            var y: float = float(floor_index) * 2.3 - 0.5
            _box(Vector3(x, y, z + 3.53), Vector3(width - 1.1, 0.95, 0.06), glazing, "DistantRibbonWindows")
            for mullion: int in range(1, 5):
                _box(Vector3(x - width * 0.5 + float(mullion) * width / 5.0, y, z + 3.57), Vector3(0.12, 1.05, 0.08), facades[index % 3], "DistantFacadeRhythm")
    # Courbes douces : un parc en arrière-plan, sans pics polygonaux derrière le stade.
    var mesh: ImmediateMesh = ImmediateMesh.new()
    var material: StandardMaterial3D = _material(Color("7d968d"))
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
    for index: int in range(80):
        var x: float = -200.0 + float(index) * 5.0
        var height_a: float = 14.0 + sin(x * 0.032) * 5.0 + sin(x * 0.071) * 1.6
        var nx: float = x + 5.0
        var height_b: float = 14.0 + sin(nx * 0.032) * 5.0 + sin(nx * 0.071) * 1.6
        for vertex: Vector3 in [Vector3(x, -2.0, -126.0), Vector3(x, height_a, -126.0), Vector3(nx, height_b, -126.0), Vector3(x, -2.0, -126.0), Vector3(nx, height_b, -126.0), Vector3(nx, -2.0, -126.0)]:
            mesh.surface_add_vertex(vertex)
    mesh.surface_end()
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.name = "DistantParkRidgeline"
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _build_clouds() -> void:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 16
    mesh.rings = 6
    var transforms: Array = []
    for cluster: Vector3 in [Vector3(-74.0, 31.0, -111.0), Vector3(53.0, 35.0, -125.0), Vector3(110.0, 29.0, 47.0), Vector3(-103.0, 37.0, 65.0)]:
        for lobe: int in range(5):
            var position: Vector3 = cluster + Vector3((float(lobe) - 2.0) * 6.3, sin(float(lobe)) * 1.2, 0.0)
            transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(8.0, 2.4 + sin(float(lobe)) * 0.6, 3.8)), position))
    var material: StandardMaterial3D = _material(Color("dce1d6"))
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var clouds: MultiMeshInstance3D = _batch_mesh(mesh, transforms, [], material, "AfternoonCloudBanks")
    clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_lighting() -> void:
    var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("67869e")
    sky_material.sky_horizon_color = Color("cdd6ce")
    sky_material.ground_bottom_color = Color("647867")
    sky_material.ground_horizon_color = Color("cdd6ce")
    sky_material.sky_curve = 0.16
    var sky: Sky = Sky.new()
    sky.sky_material = sky_material
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("b6c8cc")
    environment.ambient_light_energy = 0.48
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 0.85
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = environment
    add_child(world)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.name = "ArenaSun"
    sun.rotation_degrees = Vector3(-43.0, -32.0, 0.0)
    sun.light_color = Color("fce8c9")
    sun.light_energy = 0.88
    sun.light_angular_distance = 0.7
    sun.shadow_enabled = true
    sun.shadow_blur = 1.4
    sun.directional_shadow_max_distance = 165.0
    sun.directional_shadow_blend_splits = true
    add_child(sun)
