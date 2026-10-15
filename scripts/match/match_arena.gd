class_name IEGMatchArena
extends Node3D
## Stade généré : dimensions réelles de la simulation, sans collision décorative.

const HALF_WIDTH: float = 30.0
const HALF_LENGTH: float = 45.0
const GOAL_HALF_WIDTH: float = 3.66
const GOAL_HEIGHT: float = 2.44
const GOAL_DEPTH: float = 2.0
const PITCH_SHADER = preload("res://assets/environment/pitch.gdshader")

var _white: StandardMaterial3D
var _steel: StandardMaterial3D
var _concrete: StandardMaterial3D
var _blue: StandardMaterial3D
var _red: StandardMaterial3D
var _second_half: bool = false

func _ready() -> void:
    _white = _material(Color("f7f1df"))
    _steel = _material(Color("33434d"))
    _concrete = _material(Color("aeb4b8"))
    _blue = _material(Color("195ca5"))
    _red = _material(Color("b62e45"))
    _build_ground()
    _build_markings()
    _build_goal(-1.0)
    _build_goal(1.0)
    _build_stands()
    _build_surroundings()
    _build_lighting()

func set_second_half(value: bool) -> void:
    _second_half = value

func _material(color: Color) -> StandardMaterial3D:
    var result: StandardMaterial3D = StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.92
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
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = from.distance_to(to)
    mesh.radial_segments = 10
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = (from + to) * 0.5
    instance.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
    add_child(instance)

func _build_ground() -> void:
    _box(Vector3(0.0, -0.5, 0.0), Vector3(116.0, 0.8, 144.0), _material(Color("3c5354")), "CampusBase")
    _box(Vector3(0.0, -0.15, 0.0), Vector3(72.0, 0.2, 104.0), _material(Color("295a38")), "PitchApron")
    var pitch: MeshInstance3D = MeshInstance3D.new()
    pitch.name = "MatchPitch60x90"
    var plane: PlaneMesh = PlaneMesh.new()
    plane.size = Vector2(HALF_WIDTH * 2.0, HALF_LENGTH * 2.0)
    pitch.mesh = plane
    var grass: ShaderMaterial = ShaderMaterial.new()
    grass.shader = PITCH_SHADER
    grass.set_shader_parameter("grass_light", Color("367448"))
    grass.set_shader_parameter("grass_dark", Color("2c653f"))
    pitch.material_override = grass
    add_child(pitch)

func _line(a: Vector2, b: Vector2, width: float = 0.11) -> void:
    var span: Vector2 = b - a
    var middle: Vector2 = (a + b) * 0.5
    var line: MeshInstance3D = _box(Vector3(middle.x, 0.016, middle.y),
        Vector3(width, 0.018, span.length()), _white, "PitchMark")
    line.rotation.y = atan2(span.x, span.y)

func _circle(at: Vector2, radius: float, begin: float = 0.0, end: float = TAU) -> void:
    var mesh: ImmediateMesh = ImmediateMesh.new()
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.name = "PitchArc"
    add_child(instance)
    var paint: StandardMaterial3D = _white.duplicate() as StandardMaterial3D
    paint.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, paint)
    mesh.surface_set_normal(Vector3.UP)
    var segments: int = maxi(12, int(72.0 * absf(end - begin) / TAU))
    for segment: int in range(segments):
        var a: float = lerpf(begin, end, float(segment) / float(segments))
        var b: float = lerpf(begin, end, float(segment + 1) / float(segments))
        var aa: Vector3 = Vector3(at.x + cos(a) * (radius - 0.055), 0.027, at.y + sin(a) * (radius - 0.055))
        var ab: Vector3 = Vector3(at.x + cos(a) * (radius + 0.055), 0.027, at.y + sin(a) * (radius + 0.055))
        var ba: Vector3 = Vector3(at.x + cos(b) * (radius - 0.055), 0.027, at.y + sin(b) * (radius - 0.055))
        var bb: Vector3 = Vector3(at.x + cos(b) * (radius + 0.055), 0.027, at.y + sin(b) * (radius + 0.055))
        # Counter-clockwise viewed from above; retain visibility from both sides.
        for vertex: Vector3 in [aa, ba, ab, ab, ba, bb]:
            mesh.surface_add_vertex(vertex)
    mesh.surface_end()

func _spot(at: Vector2) -> void:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.height = 0.018
    mesh.top_radius = 0.14
    mesh.bottom_radius = 0.14
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = _white
    instance.position = Vector3(at.x, 0.02, at.y)
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
            var flag: MeshInstance3D = _box(Vector3(x + 0.23, 1.19, goal_line), Vector3(0.45, 0.28, 0.025), _red)
            flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_goal(side: float) -> void:
    var z: float = side * HALF_LENGTH
    var back: float = z + side * GOAL_DEPTH
    for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
        _pipe(Vector3(x, 0.0, z), Vector3(x, GOAL_HEIGHT, z), 0.065, _white)
        _pipe(Vector3(x, 0.0, back), Vector3(x, GOAL_HEIGHT, back), 0.035, _steel)
        _pipe(Vector3(x, GOAL_HEIGHT, z), Vector3(x, GOAL_HEIGHT, back), 0.035, _white)
    _pipe(Vector3(-GOAL_HALF_WIDTH, GOAL_HEIGHT, z), Vector3(GOAL_HALF_WIDTH, GOAL_HEIGHT, z), 0.065, _white)
    var net: ImmediateMesh = ImmediateMesh.new()
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = "GoalNet"
    instance.mesh = net
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    var material: StandardMaterial3D = _material(Color("d8e2df"))
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    net.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for index: int in range(25):
        var x: float = lerpf(-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH, float(index) / 24.0)
        net.surface_add_vertex(Vector3(x, 0.04, back))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, back))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, z))
        net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, back))
    for index: int in range(9):
        var y: float = GOAL_HEIGHT * float(index) / 8.0
        net.surface_add_vertex(Vector3(-GOAL_HALF_WIDTH, y, back))
        net.surface_add_vertex(Vector3(GOAL_HALF_WIDTH, y, back))
        for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
            net.surface_add_vertex(Vector3(x, y, z))
            net.surface_add_vertex(Vector3(x, y, back))
    for index: int in range(8):
        var depth: float = z + side * GOAL_DEPTH * float(index) / 7.0
        for x: float in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
            net.surface_add_vertex(Vector3(x, 0.04, depth))
            net.surface_add_vertex(Vector3(x, GOAL_HEIGHT, depth))
    net.surface_end()

func _build_stands() -> void:
    for side: float in [-1.0, 1.0]:
        for block: int in range(3):
            var z: float = float(block - 1) * 24.0
            for row: int in range(5):
                var x: float = side * (36.0 + float(row) * 1.2)
                var y: float = 0.3 + float(row) * 0.6
                _box(Vector3(x, y * 0.5, z), Vector3(1.2, y, 21.0), _concrete, "StandStep")
                _box(Vector3(x, y + 0.12, z), Vector3(0.62, 0.22, 20.0), _blue if block != 1 else _red, "SeatRow")
            _box(Vector3(side * 39.0, 5.0, z), Vector3(8.5, 0.16, 22.0), _blue, "Canopy")
            for post_z: float in [-10.0, 10.0]:
                _pipe(Vector3(side * 42.0, 0.0, z + post_z), Vector3(side * 42.0, 5.0, z + post_z), 0.10, _steel)
        for block: int in range(5):
            var z: float = float(block - 2) * 17.0
            var board: MeshInstance3D = _box(Vector3(side * 32.0, 0.55, z), Vector3(0.16, 1.1, 15.5), _blue if block % 2 == 0 else _red, "SponsorBoard")
            board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var sign: Label3D = Label3D.new()
    sign.text = "IEG  /  ARENA"
    sign.font_size = 120
    sign.pixel_size = 0.014
    sign.position = Vector3(0.0, 4.0, -55.0)
    sign.modulate = Color("e1e9ec")
    sign.outline_size = 6
    add_child(sign)
    _box(Vector3(0.0, 3.8, -55.2), Vector3(19.0, 3.0, 0.35), _steel, "ArenaSign")
    for x: float in [-8.0, 8.0]:
        _pipe(Vector3(x, 0.0, -55.2), Vector3(x, 3.8, -55.2), 0.13, _steel)

func _build_surroundings() -> void:
    var trunk: StandardMaterial3D = _material(Color("705646"))
    var leaves: StandardMaterial3D = _material(Color("325c43"))
    for side: float in [-1.0, 1.0]:
        for index: int in range(6):
            var at: Vector3 = Vector3(side * 50.0, 0.0, float(index) * 21.0 - 52.5)
            _pipe(at, at + Vector3.UP * 4.0, 0.28, trunk)
            var tree: MeshInstance3D = MeshInstance3D.new()
            var crown: SphereMesh = SphereMesh.new()
            crown.radius = 2.8
            crown.height = 5.5
            crown.radial_segments = 12
            crown.rings = 6
            tree.mesh = crown
            tree.material_override = leaves
            tree.position = at + Vector3.UP * 5.0
            add_child(tree)
        for z: float in [-46.0, 46.0]:
            var at: Vector3 = Vector3(side * 35.0, 0.0, z)
            _pipe(at, at + Vector3.UP * 12.0, 0.13, _steel)
            _box(at + Vector3.UP * 12.0, Vector3(3.8, 0.5, 1.0), _steel, "Floodlight")
            _box(at + Vector3(0.0, 11.7, 0.0), Vector3(3.5, 0.08, 0.8), _white, "FloodlightLens")

func _build_lighting() -> void:
    var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("6f9bc3")
    sky_material.sky_horizon_color = Color("d5e6e5")
    sky_material.ground_bottom_color = Color("677f73")
    sky_material.ground_horizon_color = Color("d5e6e5")
    var sky: Sky = Sky.new()
    sky.sky_material = sky_material
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("c2d6e1")
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = environment
    add_child(world)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.name = "ArenaSun"
    sun.rotation_degrees = Vector3(-49.0, -30.0, 0.0)
    sun.light_color = Color("fff0d6")
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 125.0
    add_child(sun)
