extends SubViewportContainer
## Aperçu 3D autonome : aucune règle de simulation n'est résolue ici.
## Les techniques utilisent la même mise en scène que les duels du match.
## Les gardiens partagent leur préparation avant les trois issues révélées.

const Cinematic = preload("res://scripts/presentation/duel_cinematic.gd")
const Catalog = preload("res://core/content/technique_catalog.gd")
const ModifierVisual = preload("res://scripts/presentation/modifier_visual.gd")
const PlayerScene = preload("res://scenes/characters/player_view.tscn")
const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")
var _skeleton: Skeleton3D
var _rig_poses: Dictionary = {}
var _modifier: Node3D
var _camera: Camera3D
var _world: Node3D
var _outcome: String = "capture"
var _definition: Dictionary = {}
var _time: float = 0.0
var _failure: bool = false
var _actor: Node3D
var _ball: MeshInstance3D
var _arms: Array[MeshInstance3D] = []
var _legs: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _frame: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _label: Label
var _cinematic: IEGDuelCinematic
var _preview_defender: Node3D
var _modifier_mount: Node3D
var _catalog_definitions: Array[Dictionary] = []
var _uses_cinematic: bool = false
var _replay_wait: float = 0.0
# Les stages détachés par stop() peuvent encore attendre la fin de la frame.
# Ils doivent disparaître avant les matériaux du studio lors d'un free() direct.
var _owned_stages: Array[Node3D] = []

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var viewport: SubViewport = SubViewport.new()
    viewport.size = Vector2i(760, 380)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_4X
    viewport.positional_shadow_atlas_size = 2048
    add_child(viewport)
    var world: Node3D = Node3D.new()
    _world = world
    viewport.add_child(world)
    var environment_node: WorldEnvironment = WorldEnvironment.new()
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("0a1423")
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("102038")
    sky_material.sky_horizon_color = Color("728b9e")
    sky_material.ground_bottom_color = Color("102038")
    sky_material.ground_horizon_color = Color("8c9faa")
    sky_material.sky_curve = 0.15
    sky_material.ground_curve = 0.15
    var studio_sky: Sky = Sky.new()
    studio_sky.sky_material = sky_material
    studio_sky.radiance_size = Sky.RADIANCE_SIZE_256
    environment.sky = studio_sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("a6bdd7")
    environment.ambient_light_energy = 0.38
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.15
    environment_node.environment = environment
    world.add_child(environment_node)
    var camera: Camera3D = Camera3D.new()
    _camera = camera
    camera.position = Vector3(4.3, 2.8, -6.2)
    camera.fov = 39.0
    world.add_child(camera)
    camera.look_at(Vector3(0, 1.0, 0))
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-25, 150, 0)
    light.light_color = Color("fff0d2")
    light.light_energy = 1.8
    light.shadow_enabled = true
    light.directional_shadow_max_distance = 20
    world.add_child(light)
    var softbox: DirectionalLight3D = DirectionalLight3D.new()
    softbox.rotation_degrees = Vector3(-18, 65, 0)
    softbox.light_color = Color("a1bfe8")
    softbox.light_energy = 0.75
    world.add_child(softbox)
    var rim: OmniLight3D = OmniLight3D.new()
    rim.position = Vector3(-3, 3.5, 2.0)
    rim.light_color = Color("4bd9c3")
    rim.light_energy = 3.5
    rim.omni_range = 9
    world.add_child(rim)
    var fill: OmniLight3D = OmniLight3D.new()
    fill.position = Vector3(3.5, 2.5, -3)
    fill.light_color = Color("e5af65")
    fill.light_energy = 1.4
    fill.omni_range = 8
    world.add_child(fill)
    var ground: PlaneMesh = PlaneMesh.new()
    ground.size = Vector2(50, 50)
    var ground_material: StandardMaterial3D = StandardMaterial3D.new()
    ground_material.albedo_color = Color("0d1928")
    ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ground_material.roughness = 0.75
    _mesh(world, ground, Vector3(0, -0.14, 0), ground_material)
    var dais_material: StandardMaterial3D = StandardMaterial3D.new()
    dais_material.albedo_color = Color("1b3043")
    dais_material.metallic = 0.5
    dais_material.roughness = 0.35
    var dais: CylinderMesh = CylinderMesh.new()
    dais.top_radius = 3.3
    dais.bottom_radius = 3.3
    dais.height = 0.12
    dais.radial_segments = 96
    _mesh(world, dais, Vector3(0, -0.08, 0), dais_material)
    var edge_material: StandardMaterial3D = StandardMaterial3D.new()
    edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_material.albedo_color = Color("e5af65")
    for radius: float in [3.2, 2.94]:
        var edge: TorusMesh = TorusMesh.new()
        edge.inner_radius = radius
        edge.outer_radius = radius + 0.014
        edge.rings = 96
        edge.ring_segments = 6
        _mesh(world, edge, Vector3(0, -0.008, 0), edge_material)
    for index: int in range(32):
        var angle: float = index * TAU / 32
        var tick_mesh: BoxMesh = BoxMesh.new()
        tick_mesh.size = Vector3(0.012, 0.006, 0.11 if index % 4 else 0.22)
        var tick: MeshInstance3D = _mesh(world, tick_mesh, Vector3(sin(angle) * 3.07, -0.005, cos(angle) * 3.07), edge_material)
        tick.rotation.y = angle
    _material = StandardMaterial3D.new()
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.albedo_color = Color("a99aff")
    _material.emission_enabled = true
    _material.emission = _material.albedo_color
    _actor = PlayerScene.instantiate()
    _actor.name = "PreviewFootballer"
    world.add_child(_actor)
    _actor.selection_ring.visible = false
    _actor.target_ring.visible = false
    _actor.number_label.visible = false
    _find_rig(_actor)
    # Hidden controls drive bone poses, preserving the preview's animation contract.
    for side: int in [-1, 1]:
        var arm: MeshInstance3D = MeshInstance3D.new()
        arm.position = Vector3(side * 0.43, 1.03, 0)
        arm.rotation.z = side * 0.25
        _actor.add_child(arm)
        _arms.append(arm)
        var leg: MeshInstance3D = MeshInstance3D.new()
        leg.position = Vector3(side * 0.16, 0.42, 0)
        _actor.add_child(leg)
        _legs.append(leg)
    var ball_material: StandardMaterial3D = StandardMaterial3D.new()
    ball_material.albedo_color = Color("f4f0df")
    ball_material.roughness = 0.4
    ball_material.emission_enabled = true
    ball_material.emission = Color("172a3d")
    _ball = _sphere(world, Vector3(0, 0.2, 0.4), 0.17, ball_material)
    for index: int in range(7):
        var torus: TorusMesh = TorusMesh.new()
        torus.inner_radius = 0.96
        torus.outer_radius = 1.0
        torus.rings = 36
        torus.ring_segments = 8
        _rings.append(_mesh(world, torus, Vector3.ZERO, _material))
    for index: int in range(16):
        _sparks.append(_sphere(world, Vector3.ZERO, 0.06, _material))
    for index: int in range(4):
        var beam: BoxMesh = BoxMesh.new()
        beam.size = Vector3(1.6 if index < 2 else 0.055, 0.055 if index < 2 else 1.5, 0.055)
        _frame.append(_mesh(world, beam, Vector3.ZERO, _material))
    var canvas: CanvasLayer = CanvasLayer.new()
    viewport.add_child(canvas)
    _label = Label.new()
    _label.position = Vector2(16, 16)
    _label.add_theme_font_override("font", VisualTheme.font())
    _label.add_theme_color_override("font_color", Color("f4f0df"))
    _label.add_theme_font_size_override("font_size", 13)
    _label.add_theme_color_override("font_shadow_color", Color.BLACK)
    _label.add_theme_constant_override("shadow_offset_x", 2)
    _label.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(_label)
    _modifier_mount = Node3D.new()
    world.add_child(_modifier_mount)
    _modifier = ModifierVisual.new()
    _modifier_mount.add_child(_modifier)
    _modifier.visible = false
    _preview_defender = PlayerScene.instantiate()
    _preview_defender.name = "PreviewOpponent"
    var opponent_profile := IEGPlayerProfile.new()
    opponent_profile.kit_color = Color("c05a69")
    opponent_profile.shirt_number = 1
    _preview_defender.profile = opponent_profile
    world.add_child(_preview_defender)
    _preview_defender.visible = false
    _cinematic = Cinematic.new()
    world.add_child(_cinematic)
    _cinematic.reveal.connect(_show_cinematic_result)
    _cinematic.finished.connect(func() -> void: _replay_wait = 0.0)
    if _catalog_definitions.is_empty():
        _catalog_definitions = Catalog.new().all_definitions()
    if not _definition.is_empty():
        set_definition(_definition)

func set_catalog_definitions(definitions: Array[Dictionary]) -> void:
    # Utiliser aussi les fiches locales non sauvegardées et leurs liens édités.
    _catalog_definitions = definitions.duplicate(true)

func set_definition(definition: Dictionary) -> void:
    if _cinematic != null:
        _cinematic.stop()
    _definition = definition.duplicate(true)
    _time = 0.0
    _replay_wait = 0.0
    _uses_cinematic = str(_definition.get("category", "")) in ["TIR", "ATT", "DEF", "GAR"]
    if _modifier != null:
        _modifier.configure(_definition)
        _modifier.visible = str(_definition.get("category", "")) in ["KARMA", "RESONANCE"] or _definition.get("properties", {}).has("karma_id") or _modifier.style in ["astreion", "thalassa", "sovereign_orbit", "deep_watch", "vaelis", "orvann"]
        var is_spirit: bool = str(_definition.get("category", "")) == "KARMA" or _modifier.style in ["astreion", "thalassa", "vaelis", "orvann"]
        _modifier.position = Vector3(0, 0, 0.7) if is_spirit else Vector3.ZERO
        _modifier_mount.visible = not _uses_cinematic
        _camera.position = Vector3(5.6, 3.5, -8.0) if is_spirit else Vector3(4.3, 2.8, -6.2)
        _camera.look_at(Vector3(0, 1.8 if is_spirit else 1.0, 0))
        _camera.make_current()
        _preview_defender.visible = _uses_cinematic
        _actor.position = Vector3(0, 0, -3) if _uses_cinematic else Vector3.ZERO
        _actor.rotation = Vector3.ZERO
        _preview_defender.position = Vector3(0, 0, 3)
        _preview_defender.rotation = Vector3(0, PI, 0)
        if _skeleton != null:
            for index: int in _rig_poses:
                _skeleton.set_bone_pose_rotation(index, _rig_poses[index])
        if _uses_cinematic:
            _start_cinematic()
    if _material != null:
        _material.albedo_color = Color(String(_definition.get("color", "#a99aff")))
        _material.emission = _material.albedo_color

func set_failure(value: bool) -> void:
    _failure = value
    _outcome = "goal" if value else "capture"
    _time = 0.0
    if _cinematic != null and _uses_cinematic:
        _start_cinematic()

func set_outcome(value: String) -> void:
    _outcome = value if value in ["capture", "deflection", "goal"] else "capture"
    _failure = _outcome == "goal"
    _time = 0.0
    if _cinematic != null and _uses_cinematic:
        _start_cinematic()

func _start_cinematic() -> void:
    _cinematic.stop()
    _replay_wait = 0.0
    for mesh: MeshInstance3D in _rings + _sparks + _frame:
        mesh.visible = false
    var category: String = str(_definition.get("category", ""))
    var defending: bool = category in ["DEF", "GAR"]
    var keeper: bool = category in ["TIR", "GAR"]
    var block: bool = category == "DEF" and bool(_definition.get("properties", {}).get("block", false))
    var attacker_won: bool = _failure if defending else not _failure
    var definitions: Array[Dictionary] = _catalog_definitions.duplicate(true)
    var selected_id: String = str(_definition.get("id", ""))
    var found: bool = false
    for index: int in definitions.size():
        if str(definitions[index].get("id", "")) == selected_id:
            definitions[index] = _definition.duplicate(true)
            found = true
            break
    if not found:
        definitions.append(_definition.duplicate(true))
    var timing: Dictionary = Catalog.cinematic_timing({} if defending else _definition, _definition if defending else {})
    var ending: String = "dribble" if attacker_won else "tackle"
    if keeper:
        ending = _outcome if category == "GAR" else ("goal" if attacker_won else "capture")
    elif block:
        ending = "shot_continues" if attacker_won else "block"
    var result: Dictionary = {
        "kind": "keeper" if keeper else ("block" if block else "field"),
        "actor_id": 7, "target_id": 1,
        "attack_choice": "left" if defending else "special",
        "defend_choice": "special" if defending else "right",
        "attack_technique": "" if defending else selected_id,
        "defend_technique": selected_id if defending else "",
        "attack_score": 145 if attacker_won else 112,
        "defend_score": (119 if ending == "deflection" else 145) if not attacker_won else 112,
        "winner_id": 7 if attacker_won else 1,
        "attacker_won": attacker_won,
        "outcome": ending, "result": "parry" if ending == "deflection" else ending,
        "duration": timing["duration"], "reveal_time": timing["reveal_time"],
        "techniques": definitions}
    _ball.position = Vector3(0.3, 0.17, -2.4)
    _cinematic.begin(result, _actor, _preview_defender, _ball)
    for index: int in range(_owned_stages.size() - 1, -1, -1):
        if not is_instance_valid(_owned_stages[index]):
            _owned_stages.remove_at(index)
    _owned_stages.append(_cinematic._stage)
    _label.text = str(_definition.get("name", "")) + " / préparation commune" if category == "GAR" else str(_definition.get("name", "")) + " / préparation"

func _show_cinematic_result() -> void:
    var outcome_text: String = "TECHNIQUE RÉUSSIE" if not _failure else "TECHNIQUE CONTRÉE"
    if str(_definition.get("category", "")) == "GAR":
        outcome_text = {"capture": "CAPTURE / ballon maîtrisé", "deflection": "DÉVIATION / ballon libre", "goal": "ÉCHEC / la garde cède"}.get(_outcome, "")
    _label.text = "%d CONTRE %d / %s" % [int(_cinematic.duel_data.attack_score), int(_cinematic.duel_data.defend_score), outcome_text]

func _exit_tree() -> void:
    if is_instance_valid(_cinematic):
        _cinematic.stop()
    # Les modèles fantômes empruntent les matériaux des deux joueurs. Libérer
    # leurs stages détachés pendant que ces joueurs existent encore évite des
    # RID de matériaux invalides si l'atelier est détruit avant la frame suivante.
    for stage: Node3D in _owned_stages:
        if is_instance_valid(stage) and not stage.is_inside_tree():
            stage.free()
    _owned_stages.clear()

func _process(delta: float) -> void:
    if _actor == null or _definition.is_empty():
        return
    if _uses_cinematic:
        if _cinematic.active:
            _cinematic.advance(delta)
        else:
            _replay_wait += delta
            if _replay_wait >= 0.8:
                _start_cinematic()
        return
    _material.albedo_color = Color(String(_definition.get("color", "#a99aff")))
    _material.emission = _material.albedo_color
    var duration: float = clampf(float(_definition.get("duration", 3.8)), 2.4, 6.0)
    _time = fmod(_time + delta, duration + 0.8)
    var t: float = clampf(_time / duration, 0.0, 1.0)
    var branch: float = float(_definition.get("properties", {}).get("branch_at", 0.58))
    var release: float = clampf((t - branch) / (1.0 - branch), 0.0, 1.0)
    var effect: String = String(_definition.get("effect", "orbital"))
    var is_keeper: bool = String(_definition.get("category", "")) == "GAR"
    _label.text = ("ÉCHEC / la garde cède" if _failure else ("DÉVIATION / ballon libre" if _outcome == "deflection" else "CAPTURE / ballon maîtrisé")) if is_keeper and t >= branch else ("GAR / préparation commune" if is_keeper else "APERÇU 3D / animation de la technique")
    _actor.position = Vector3.ZERO
    _actor.rotation = Vector3.ZERO
    for index: int in range(_arms.size()):
        var side: float = -1.0 if index == 0 else 1.0
        _arms[index].position = Vector3(side * 0.43, 1.03, 0)
        _arms[index].rotation = Vector3(0, 0, side * 0.25)
        _legs[index].rotation = Vector3(0, 0, 0)
    for ring: MeshInstance3D in _rings:
        ring.visible = true
        ring.scale = Vector3.ONE
        ring.rotation = Vector3.ZERO
    for beam: MeshInstance3D in _frame:
        beam.visible = effect == "photo"
    _ball.visible = true
    for spark: MeshInstance3D in _sparks:
        spark.visible = true
    _ball.position = Vector3(0.25, 0.25, 0.5)
    if _modifier != null and _modifier.visible:
        _render_modifier_preview(t, branch, release, effect)
        _apply_rig_pose()
        return
    match effect:
        "orbital":
            _actor.rotation.y = -t * TAU * (1.0 - release)
            _arms[0].rotation.z = -1.3
            var radius: float = 0.9 * (1.0 - release)
            _ball.position = Vector3(cos(t * TAU * 3) * radius, 0.5 + t * 1.9, sin(t * TAU * 3) * radius - release * 6)
            for index: int in range(_rings.size()):
                var ring: MeshInstance3D = _rings[index]
                ring.position = Vector3(0, 0.7 + index * 0.22, -release * 4)
                ring.rotation = Vector3(index * 0.3, t * TAU + index, 0.7)
                ring.scale = Vector3.ONE * (0.5 + index * 0.1) * (1.0 - release * 0.65)
        "magnus":
            _legs[1].rotation.x = -sin(t * PI) * 1.4
            _actor.rotation.y = sin(t * PI) * 0.8
            _ball.position = Vector3(sin(release * PI) * 2.6, 0.25 + release * 1.4, 0.4 - release * 7)
            for index: int in range(_rings.size()):
                var local_t: float = maxf(0.0, release - index * 0.035)
                _rings[index].position = Vector3(sin(local_t * PI) * 2.6, 0.25 + local_t * 1.4, 0.4 - local_t * 7)
                _rings[index].rotation.x = PI * 0.5
                _rings[index].scale = Vector3.ONE * (0.22 + index * 0.035)
        "hurricane", "aqua":
            _arms[0].rotation.z = -1.3
            _arms[1].rotation.z = 1.3
            _actor.position.y = sin(t * PI) * 0.1
            _ball.position = Vector3(0, 0.7, 3.8 * (1.0 - t) + release * 5)
            for index: int in range(_rings.size()):
                var ring: MeshInstance3D = _rings[index]
                ring.position = Vector3(0, 0.2 + index * 0.24 if effect == "hurricane" else 0.12, 0)
                ring.rotation = Vector3(sin(t * TAU + index) * 0.12, t * 8 + index, 0)
                ring.scale = Vector3.ONE * (0.4 + index * 0.18 + (release * 2.0 if effect == "aqua" else 0.0))
        "photo", "gyro":
            _arms[0].rotation.z = -1.0
            _arms[1].rotation.z = 1.0
            _arms[0].rotation.x = -0.7
            _arms[1].rotation.x = -0.7
            _actor.position.z = -release * 0.5 if _failure else 0.0
            _actor.rotation.x = -release * 0.3 if _failure else 0.0
            _ball.position = Vector3(0, 1.1, 3.5 * (1.0 - minf(t / branch, 1.0)) + 0.55 - (release * 5 if _failure else 0.0))
            for index: int in range(_rings.size()):
                var ring: MeshInstance3D = _rings[index]
                ring.visible = effect == "gyro" or index < 2
                ring.position = Vector3(0, 1.1, 0.55)
                ring.rotation = Vector3(t * 5 + index * PI / 3, t * 2 + index, release * index if _failure else 0.0)
                ring.scale = Vector3.ONE * (0.7 + index * 0.07) * (1.0 + release * 2 if _failure else 1.0 - release * 0.48)
            for index: int in range(_frame.size()):
                var beam: MeshInstance3D = _frame[index]
                var offset: Vector3 = Vector3(0, -0.75 if index == 0 else 0.75, 0) if index < 2 else Vector3(-0.8 if index == 2 else 0.8, 0, 0)
                beam.position = Vector3(0, 1.1, 0.55) + offset * (1.0 + release * 2 if _failure else 1.0 - release * 0.4)
                beam.rotation.z = release * 2.0 * (index - 1.5) if _failure else 0.0
        "blade", "drift":
            _actor.position = Vector3(sin(t * PI) * (1.5 if effect == "drift" else -1.0), sin(t * PI) * 0.14, -release * 2.3)
            _actor.rotation.y = sin(t * PI) * (1.2 if effect == "drift" else -1.7)
            _ball.position = _actor.position + Vector3(0.3, 0.22, 0.4)
            _legs[0].rotation.x = sin(t * TAU * 2) * 0.7
            _legs[1].rotation.x = -sin(t * TAU * 2) * 0.7
            for index: int in range(_rings.size()):
                _rings[index].position = _actor.position + Vector3(0, 0.2 if effect == "drift" else 1.0, index * 0.14)
                _rings[index].rotation = Vector3(0.8 if effect == "blade" else 0.0, index + t * 5, 0.7 if effect == "blade" else 0.0)
                _rings[index].scale = Vector3.ONE * (0.65 + index * 0.08)
        _:
            _actor.position.y = sin(t * PI) * 0.3
            _arms[0].rotation.z = -sin(t * PI) * 1.3
            _arms[1].rotation.z = sin(t * PI) * 1.3
            for index: int in range(_rings.size()):
                _rings[index].position = Vector3(0, index * 0.22, 0)
                _rings[index].scale = Vector3.ONE * (0.65 + sin(t * PI) * 0.2)
                _rings[index].rotation.z = index * 0.3
    for index: int in range(_sparks.size()):
        var angle: float = t * 8.0 + index * TAU / _sparks.size()
        var radius: float = 1.05 + sin(t * PI) * 0.5
        _sparks[index].position = _actor.position + Vector3(cos(angle) * radius, 0.25 + float(index % 5) * 0.35, sin(angle) * radius)
        _sparks[index].scale = Vector3.ONE * (0.6 + sin(t * PI) * 0.8)
    _apply_rig_pose()

func _find_rig(node: Node) -> void:
    if node is AnimationPlayer:
        node.stop()
    if node is Skeleton3D:
        _skeleton = node
        for index: int in range(_skeleton.get_bone_count()):
            _rig_poses[index] = _skeleton.get_bone_pose_rotation(index)
    for child: Node in node.get_children():
        _find_rig(child)

func _pose_bone(bone_name: String, angles: Vector3) -> void:
    if _skeleton == null:
        return
    var index: int = _skeleton.find_bone(bone_name)
    if index >= 0:
        _skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(angles))

func _apply_rig_pose() -> void:
    if _skeleton == null:
        return
    for index: int in _rig_poses:
        _skeleton.set_bone_pose_rotation(index, _rig_poses[index])
    _pose_bone("UpperArmL", Vector3(_arms[0].rotation.x, 0, _arms[0].rotation.z))
    _pose_bone("UpperArmR", Vector3(_arms[1].rotation.x, 0, _arms[1].rotation.z))
    _pose_bone("UpperLegL", _legs[0].rotation)
    _pose_bone("UpperLegR", _legs[1].rotation)
    _pose_bone("LowerArmL", Vector3(-0.25, 0, 0))
    _pose_bone("LowerArmR", Vector3(-0.25, 0, 0))
    _pose_bone("Chest", Vector3(-absf(_legs[1].rotation.x) * 0.12, 0, 0))

func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = position
    parent.add_child(instance)
    return instance

func _sphere(parent: Node3D, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2
    mesh.radial_segments = 24
    mesh.rings = 16
    return _mesh(parent, mesh, position, material)

func _cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    return _mesh(parent, mesh, position, material)

func _render_modifier_preview(t: float, branch: float, release: float, effect: String) -> void:
    for ring: MeshInstance3D in _rings:
        ring.visible = false
    for spark: MeshInstance3D in _sparks:
        spark.visible = false
    for beam: MeshInstance3D in _frame:
        beam.visible = false
    _actor.position = Vector3.ZERO
    _actor.rotation = Vector3.ZERO
    _ball.visible = effect in ["perihelion", "abyssal"]
    _modifier.set_presentation(_time)
    if effect == "perihelion":
        _modifier.set_signature_progress(minf(1, t / branch), release, _outcome)
        _ball.position = Vector3(0, 0.4 + minf(t / branch, 1) * 1.3, -0.35 - release * 5)
        _legs[1].rotation.x = lerpf(-0.8, 1.2, smoothstep(0.2, branch, t)) * (1 - release)
        _arms[0].rotation.z = -0.8
        _label.text = "SIGNATURE / préparation, frappe et météore"
    elif effect == "abyssal":
        _modifier.set_signature_progress(minf(1, t / branch), release, _outcome if t >= branch else "")
        _arms[0].rotation.z = -0.9 + release * 0.4
        _arms[1].rotation.z = 0.9 - release * 0.4
        _ball.position = Vector3(0, 1.1, -3.5 * (1 - minf(t / branch, 1)) - 0.45)
        if t >= branch:
            if _outcome == "goal":
                _ball.position.z += release * 5
                _actor.rotation.x = -release * 0.3
            elif _outcome == "deflection":
                _ball.position += Vector3(release * 3.4, sin(release * PI) * 0.9, -release * 3)
            else:
                _ball.position = Vector3(0, 1.1 - release * 0.1, -0.45 + release * 0.15)
        var ending: String = {"capture": "CAPTURE — voûte refermée", "deflection": "DÉVIATION — ballon libre", "goal": "ÉCHEC — voûte brisée"}.get(_outcome, "")
        _label.text = ending if t >= branch else "SIGNATURE / préparation commune"
    elif str(_definition.get("category", "")) == "KARMA":
        _label.text = "KARMA / forme invoquée"
    else:
        _label.text = "RÉSONANCE / marques du donneur"
