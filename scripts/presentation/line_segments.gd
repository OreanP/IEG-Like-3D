@tool
extends Node3D
## Géométrie groupée des filets/clôtures, visible aussi dans l'éditeur.
## Aucun téléchargement et aucun script de génération à lancer par l'utilisateur.

@export var points: PackedVector3Array = PackedVector3Array():
    set(value):
        points = value
        if is_inside_tree():
            _rebuild()
@export var line_color: Color = Color("809399"):
    set(value):
        line_color = value
        if is_inside_tree():
            _rebuild()
var _view: MeshInstance3D

func _ready() -> void:
    _rebuild()

func _rebuild() -> void:
    if not is_instance_valid(_view):
        _view = MeshInstance3D.new()
        _view.name = "WireMesh"
        _view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_view)
    var lines: ImmediateMesh = ImmediateMesh.new()
    if points.size() < 2 or points.size() % 2 != 0:
        _view.mesh = lines
        return
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = line_color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    lines.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for point: Vector3 in points:
        lines.surface_add_vertex(point)
    lines.surface_end()
    _view.mesh = lines
