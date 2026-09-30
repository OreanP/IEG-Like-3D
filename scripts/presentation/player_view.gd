class_name IEGPlayerView
extends Node3D
## L'état vient de la session. Remplacer le GLB ne change pas les règles du jeu.

@export var profile: IEGPlayerProfile
@onready var visual_model: Node3D = $VisualModel
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var target_ring: MeshInstance3D = $PassTargetRing
@onready var number_label: Label3D = $Number
var _animations: AnimationPlayer
var _clips: Dictionary = {}
var _current: String = ""
var _kick_remaining: float = 0.0

func _ready() -> void:
    if profile == null:
        profile = IEGPlayerProfile.new()
    configure(profile)

func configure(source: IEGPlayerProfile) -> void:
    profile = source
    number_label.text = "%02d" % profile.shirt_number
    _configure_tree(visual_model)
    if _animations != null:
        # Ne pas modifier la ressource d'animation partagée entre les joueurs.
        for library_name: StringName in _animations.get_animation_library_list():
            var library: AnimationLibrary = _animations.get_animation_library(library_name).duplicate(true) as AnimationLibrary
            _animations.remove_animation_library(library_name)
            _animations.add_animation_library(library_name, library)
        for animation_name: StringName in _animations.get_animation_list():
            for wanted: String in ["Idle", "Walk", "Run", "Kick"]:
                if String(animation_name).to_lower().ends_with(wanted.to_lower()):
                    _clips[wanted] = animation_name
                    var clip: Animation = _animations.get_animation(animation_name)
                    clip.loop_mode = Animation.LOOP_NONE if wanted == "Kick" else Animation.LOOP_LINEAR
        if _clips.size() < 4:
            push_warning("Le modèle de joueur n'a pas ses quatre animations S0.")
    _play("Idle")

func _configure_tree(node: Node) -> void:
    if node is AnimationPlayer:
        _animations = node
    if node is MeshInstance3D and node.mesh != null:
        for surface_index: int in range(node.mesh.get_surface_count()):
            var original: Material = node.mesh.surface_get_material(surface_index)
            if original is StandardMaterial3D:
                var material: StandardMaterial3D = original.duplicate() as StandardMaterial3D
                var material_name: String = original.resource_name.to_lower()
                if material_name.contains("jersey"):
                    material.albedo_color = profile.kit_color
                elif material_name == "skin":
                    material.albedo_color = profile.skin_color
                elif material_name == "hair":
                    material.albedo_color = profile.hair_color
                node.set_surface_override_material(surface_index, material)
    for child: Node in node.get_children():
        _configure_tree(child)

func sync_state(state: IEGPlayerState, selected: bool, pass_target: bool, delta: float) -> void:
    position = Vector3(state.position.x, 0.0, state.position.y)
    var angle: float = atan2(-state.facing.x, -state.facing.y)
    rotation.y = lerp_angle(rotation.y, angle, 1.0 - exp(-16.0 * delta))
    selection_ring.visible = selected
    target_ring.visible = pass_target
    number_label.modulate = Color("ffdd87") if selected else Color.WHITE
    _kick_remaining = maxf(0.0, _kick_remaining - delta)
    if _kick_remaining > 0.0:
        return
    var speed: float = state.velocity.length()
    var clip: String = "Idle" if speed < 0.2 else ("Walk" if speed < 3.6 else "Run")
    _play(clip)
    if _animations != null:
        if clip == "Idle":
            _animations.speed_scale = 1.0
        else:
            _animations.speed_scale = clampf(speed / (2.6 if clip == "Walk" else 6.4), 0.65, 1.4)

func kick() -> void:
    _kick_remaining = 0.26
    if _animations == null:
        return
    _animations.speed_scale = 1.0
    _current = ""
    _play("Kick")
    if _clips.has("Kick"):
        # S0 : résultat immédiat. On démarre le visuel au contact avec le ballon.
        _animations.seek(0.18, true)

func _play(clip: String) -> void:
    if clip == _current or _animations == null or not _clips.has(clip):
        return
    _animations.play(_clips[clip], 0.12)
    _current = clip
