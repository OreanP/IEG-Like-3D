class_name IEGPlayerPortrait
extends SubViewportContainer
## Portrait studio du modèle réel ; aucune simulation ne tourne dans ce viewport.
const PlayerScene = preload("res://scenes/characters/player_view.tscn")
var _viewport: SubViewport
var _world: Node3D
var _view: Node3D
var _source: IEGPlayerProfile
var _goalkeeper: bool = false

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if custom_minimum_size == Vector2.ZERO:
        custom_minimum_size = Vector2(128, 140)
    resized.connect(_request_redraw)
    visibility_changed.connect(_request_redraw)
    _viewport = SubViewport.new()
    _viewport.size = Vector2i(192, 210)
    _viewport.own_world_3d = true
    _viewport.transparent_bg = true
    _viewport.msaa_3d = Viewport.MSAA_2X
    _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(_viewport)
    _world = Node3D.new()
    _viewport.add_child(_world)
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("15283e")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("d5e3f3")
    environment.ambient_light_energy = 0.65
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("91b9d1")
    sky_material.sky_horizon_color = Color("e8d5af")
    var sky := Sky.new()
    sky.sky_material = sky_material
    environment.sky = sky
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    _world.add_child(world_environment)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-25, 165, 0)
    key.light_color = Color("fff0d8")
    key.light_energy = 1.15
    _world.add_child(key)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-25, -55, 0)
    rim.light_color = Color("a7d4ee")
    rim.light_energy = 0.8
    _world.add_child(rim)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 0.98
    camera.position = Vector3(0.1, 1.45, -3.0)
    _world.add_child(camera)
    camera.look_at(Vector3(0, 1.4, 0))
    camera.current = true
    if _source != null:
        _refresh_model()

func set_profile(source: IEGPlayerProfile, goalkeeper: bool = false) -> void:
    _source = source
    _goalkeeper = goalkeeper
    if _world != null:
        _refresh_model()

func _refresh_model() -> void:
    if is_instance_valid(_view):
        _world.remove_child(_view)
        _view.queue_free()
    _view = PlayerScene.instantiate()
    _view.profile = _source
    _view.is_goalkeeper = _goalkeeper
    _world.add_child(_view)
    _view.rotation.y = -0.12
    for decoration: String in ["SelectionRing", "PassTargetRing", "Number"]:
        var node: Node3D = _view.get_node_or_null(decoration)
        if node != null:
            node.visible = false
    for player: Node in _view.find_children("*", "AnimationPlayer", true, false):
        player.active = false
    _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _request_redraw() -> void:
    # Le resize efface la texture : demander une image après le layout,
    # sans laisser tourner le rendu du portrait pendant le choix de duel.
    _render_once.call_deferred()

func _render_once() -> void:
    if is_inside_tree() and _viewport != null and is_visible_in_tree():
        _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
