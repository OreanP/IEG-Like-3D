class_name IEGDuelCinematic
extends Node3D
## La simulation fournit un résultat figé. Ce noeud ne modifie ni état ni possession.
## Seuls les modèles visuels sont mis en scène ; stop() rétablit leur état exact.

const ModifierVisual = preload("res://scripts/presentation/modifier_visual.gd")
const BallScene = preload("res://assets/ball/football.glb")
const ENERGY_SHELL = preload("res://assets/vfx/energy_shell.gdshader")

signal reveal
signal finished

@export var duration: float = 3.2
@export var reveal_time: float = 1.4
var duel_data: Dictionary = {}
var elapsed: float = 0.0
var active: bool = false
var revealed: bool = false
var _stage: Node3D
var _camera: Camera3D
var _previous_camera: Camera3D
var _actors: Array[Dictionary] = []
var _fx: Array[Dictionary] = []
var _ghost_ball: MeshInstance3D
var _ball: Node3D
var _ball_was_visible: bool = true
var _center: Vector3
var _axis: Vector3
var _side: Vector3
var _impact: MeshInstance3D
var _floor_ring: MeshInstance3D

func begin(duel: Dictionary, attacker: Node3D, defender: Node3D, ball: Node3D) -> void:
    stop()
    duel_data = duel.duplicate(true)
    duration = maxf(1.0, float(duel.get("duration", duration)))
    reveal_time = clampf(float(duel.get("reveal_time", reveal_time)), 0.2, duration - 0.2)
    elapsed = 0.0
    revealed = false
    active = true
    _previous_camera = get_viewport().get_camera_3d()
    _axis = defender.global_position - attacker.global_position
    _axis.y = 0.0
    _axis = _axis.normalized() if _axis.length_squared() > 0.01 else Vector3.BACK
    _side = Vector3.UP.cross(_axis)
    _center = (attacker.global_position + defender.global_position) * 0.5
    _center.y = maxf(attacker.global_position.y, defender.global_position.y)
    _stage = Node3D.new()
    add_child(_stage)
    _stage.global_transform = Transform3D(Basis(_side, Vector3.UP, _axis), _center)
    _capture_actor(attacker)
    _capture_actor(defender)
    _ball = ball
    if is_instance_valid(_ball):
        _ball_was_visible = _ball.visible
        _ball.visible = false
    _ghost_ball = _sphere(_stage, 0.17, Color("fff8dd"))
    _ghost_ball.name = "CinematicBall"
    _use_football_mesh(_ghost_ball)
    _impact = _sphere(_stage, 0.28, Color("fff5b8"))
    var impact_material := ShaderMaterial.new()
    impact_material.shader = ENERGY_SHELL
    _impact.material_override = impact_material
    _floor_ring = _ring(_stage, 0.8, Color("ffda89"))
    _floor_ring.position.y = 0.025
    _camera = Camera3D.new()
    _camera.fov = 48.0
    _camera.near = 0.1
    _stage.add_child(_camera)
    _camera.make_current()
    var attack: String = str(duel_data.get("attack_technique", ""))
    var defend: String = str(duel_data.get("defend_technique", ""))
    if not attack.is_empty():
        _create_technique(attack, 0)
    if not defend.is_empty():
        _create_technique(defend, 1)
    if attack.is_empty() and defend.is_empty() and not str(duel_data.get("effect", "")).is_empty():
        _create_technique(str(duel_data.effect), 0)
    _render()

func advance(delta: float) -> void:
    if not active:
        return
    elapsed = minf(duration, elapsed + maxf(0.0, delta))
    if not revealed and elapsed >= reveal_time:
        revealed = true
        reveal.emit()
    _render()
    if elapsed >= duration:
        stop()
        finished.emit()

func stop() -> void:
    active = false
    for actor: Dictionary in _actors:
        var model: Node3D = actor.model
        if not is_instance_valid(model):
            continue
        model.transform = actor.transform
        for decoration: Dictionary in actor.decorations:
            if is_instance_valid(decoration.node):
                decoration.node.visible = decoration.visible
        for animation: Dictionary in actor.animations:
            if is_instance_valid(animation.node):
                animation.node.active = animation.active
        for bone: Dictionary in actor.bones:
            var skeleton: Skeleton3D = bone.skeleton
            if is_instance_valid(skeleton):
                skeleton.set_bone_pose_position(bone.index, bone.position)
                skeleton.set_bone_pose_rotation(bone.index, bone.rotation)
                skeleton.set_bone_pose_scale(bone.index, bone.scale)
    _actors.clear()
    if is_instance_valid(_ball):
        _ball.visible = _ball_was_visible
    _ball = null
    if is_instance_valid(_camera):
        _camera.current = false
    if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
        _previous_camera.make_current()
    _previous_camera = null
    if is_instance_valid(_stage):
        remove_child(_stage)
        _stage.queue_free()
    _stage = null
    _camera = null
    _fx.clear()

func _exit_tree() -> void:
    stop()

func _capture_actor(view: Node3D) -> void:
    var model: Node3D = view.get_node_or_null("VisualModel") as Node3D
    if model == null:
        # Les fixtures sans modèle sont acceptées, sans déplacer leur racine.
        _actors.append({"model": null, "bones": [], "animations": [], "decorations": []})
        return
    var data: Dictionary = {"model": model, "transform": model.transform,
        "scale": model.global_basis.get_scale(), "bones": [], "animations": [], "skeleton": null,
        "decorations": []}
    for child: Node in view.get_children():
        if child is Node3D and child != model:
            data.decorations.append({"node": child, "visible": child.visible})
            child.visible = false
    _capture_tree(model, data)
    _actors.append(data)

func _capture_tree(node: Node, data: Dictionary) -> void:
    if node is AnimationPlayer:
        data.animations.append({"node": node, "active": node.active})
        node.active = false
    if node is Skeleton3D:
        data.skeleton = node
        for index: int in node.get_bone_count():
            data.bones.append({"skeleton": node, "index": index,
                "position": node.get_bone_pose_position(index),
                "rotation": node.get_bone_pose_rotation(index), "scale": node.get_bone_pose_scale(index)})
            node.set_bone_pose_rotation(index, Quaternion.IDENTITY)
    for child: Node in node.get_children():
        _capture_tree(child, data)

func _render() -> void:
    var windup: float = clampf(elapsed / reveal_time, 0.0, 1.0)
    var aftermath: float = clampf((elapsed - reveal_time) / (duration - reveal_time), 0.0, 1.0)
    var won: bool = bool(duel_data.get("attacker_won", false))
    var keeper: bool = str(duel_data.get("kind", "field")) == "keeper"
    var block: bool = str(duel_data.get("kind", "field")) == "block"
    var parried: bool = keeper and not won and str(duel_data.get("outcome", duel_data.get("result", ""))) in ["deflection", "parry"]
    var contact: float = smoothstep(0.30, 0.92, windup)
    var attacker_pos: Vector3 = Vector3(0.0, 0.0, -2.4 + contact * 1.5)
    var defender_pos: Vector3 = Vector3(0.0, 0.0, 2.3 - contact * (0.0 if keeper else 1.45))
    if revealed:
        if keeper:
            defender_pos.x = (0.85 if won else 0.25) * sin(aftermath * PI * 0.55)
            defender_pos.y = sin(aftermath * PI) * (0.65 if won else 0.18)
        elif block:
            attacker_pos.z -= aftermath * 0.25
            defender_pos.x += sin(aftermath * PI) * (0.4 if won else 0.0)
        elif won:
            attacker_pos += Vector3(sin(aftermath * PI) * 0.95, 0.0, aftermath * 3.4)
            defender_pos += Vector3(-aftermath * 0.6, 0.0, aftermath * 0.25)
        else:
            attacker_pos += Vector3(aftermath * 0.4, 0.0, -aftermath * 0.5)
            defender_pos += Vector3(0.0, 0.0, -aftermath * 0.4)
    _position_actor(0, attacker_pos, Vector3.BACK, 0.0, -0.12 * sin(windup * PI))
    _position_actor(1, defender_pos, Vector3.FORWARD,
        (-0.75 if won and keeper and revealed else 0.0) * sin(aftermath * PI * 0.75),
        0.13 * sin(windup * PI))
    var kick: float = sin(clampf((windup - 0.35) / 0.65, 0.0, 1.0) * PI)
    var strike: float = smoothstep(0.52, 1.0, windup)
    var preparation: float = smoothstep(0.08, 0.4, windup)
    var leg_angle: float = lerpf(-0.85, 1.25, strike) * preparation
    if revealed:
        leg_angle = 1.25 * (1.0 - smoothstep(0.0, 0.75, aftermath))
    _bone(0, "UpperLegR", Vector3(leg_angle, 0.0, 0.12 * kick))
    _bone(0, "LowerLegR", Vector3(1.25 * preparation * (1.0 - strike), 0.0, 0.0))
    _bone(0, "Chest", Vector3(-0.18 * kick, -0.38 * kick, 0.0))
    _bone(0, "UpperArmL", Vector3(-0.28, 0.0, -0.6 * kick))
    _bone(0, "UpperArmR", Vector3(0.28, 0.0, 0.5 * kick))
    var hands: float = smoothstep(0.12, 0.9, windup)
    _bone(1, "UpperArmL", Vector3(hands * 1.0, 0.0, -hands * 0.2))
    _bone(1, "UpperArmR", Vector3(hands * 1.0, 0.0, hands * 0.2))
    _bone(1, "LowerArmL", Vector3(hands * 0.5, 0.0, 0.0))
    _bone(1, "LowerArmR", Vector3(hands * 0.5, 0.0, 0.0))
    _bone(1, "UpperLegL", Vector3(0.10, 0.0, -hands * 0.18))
    _bone(1, "UpperLegR", Vector3(-0.10, 0.0, hands * 0.18))
    if revealed and keeper:
        var held: float = (0.0 if won or parried else 1.0) * sin(aftermath * PI * 0.5)
        _bone(1, "LowerArmL", Vector3(0.5 + held * 0.45, 0.0, 0.0))
        _bone(1, "LowerArmR", Vector3(0.5 + held * 0.45, 0.0, 0.0))
        _bone(1, "Chest", Vector3(0.2 * held if not won else -0.6 * aftermath, 0.0, 0.0))
        if parried:
            _bone(1, "UpperArmR", Vector3(1.0, -aftermath * 0.7, aftermath * 0.6))
            _bone(1, "LowerArmR", Vector3(0.5 - aftermath * 0.4, 0.0, 0.0))
            _bone(1, "Chest", Vector3(0.0, -aftermath * 0.35, aftermath * 0.12))
    if keeper or block:
        var travel: float = smoothstep(0.36, 1.0, windup)
        var impact_z: float = 1.95 if keeper else 0.65
        _ghost_ball.position = Vector3(0.0, 0.22 + sin(travel * PI * 0.5) * 0.95,
            lerpf(-1.8, impact_z, travel))
        if revealed:
            _ghost_ball.position = Vector3(lerpf(0.0, 0.8, aftermath) if won else defender_pos.x,
                1.2 + (sin(aftermath * PI) * 0.35 if won else -0.2 * aftermath),
                1.95 + (aftermath * 5.0 if won else -0.2 * aftermath))
            if parried:
                # La balle quitte les mains vers le côté et revient dans le terrain.
                # Ni cette trajectoire de cinéma ni le geste n'attribuent de possession.
                _ghost_ball.position = Vector3(aftermath * 3.6,
                    1.2 + sin(aftermath * PI) * 0.7, 1.95 - aftermath * 3.0)
            if block:
                _ghost_ball.position = Vector3(0.0, 1.2, impact_z + aftermath * 5.0) if won else Vector3(
                    defender_pos.x + aftermath * 0.25, lerpf(1.2, 0.2, aftermath),
                    lerpf(impact_z, defender_pos.z - 0.4, aftermath))
    else:
        _ghost_ball.position = (attacker_pos if not revealed or won else defender_pos) + Vector3(0.3, 0.2, 0.5)
    _ghost_ball.rotation = Vector3(13.0, 8.0, 3.0) * elapsed
    var burst: float = maxf(0.0, 1.0 - absf(elapsed - reveal_time) * 4.0)
    _impact.position = Vector3(0.0, 1.0, 1.9 if keeper else 0.0)
    _impact.scale = Vector3.ONE * maxf(0.001, burst * 1.9)
    _floor_ring.scale = Vector3.ONE * (1.0 + windup * 0.9 + aftermath * 3.0)
    _floor_ring.position.z = 0.0
    for effect: Dictionary in _fx:
        _animate_technique(effect, windup, aftermath)
    # Contre-plongée qui s'ouvre sur l'impact, puis laisse voir l'issue.
    var side_orbit: float = lerpf(6.4, 4.8, windup) + aftermath * 1.3
    _camera.position = Vector3(side_orbit, 2.5 + windup * 0.35, -4.8 + windup * 2.8)
    if keeper:
        _camera.position.z += aftermath * 3.0
    _camera.look_at(_stage.to_global(Vector3(0.0, 1.0, 0.3 + aftermath * (1.5 if keeper else 0.4))), Vector3.UP)
    _camera.fov = 48.0 - windup * 4.0 + burst * 4.0
    for effect: Dictionary in _fx:
        if effect.id in ["perihelion_hammer", "abyssal_cathedral"]:
            _camera.position = Vector3(9.2 - windup * 0.7, 4.0,
                4.2 - windup * 1.5 if effect.id == "perihelion_hammer" else -5.0 + windup * 2.0)
            _camera.look_at(_stage.to_global(Vector3(0, 1.8, 0.4)), Vector3.UP)
            _camera.fov = 49.0

func _position_actor(index: int, point: Vector3, facing: Vector3, roll: float, pitch: float) -> void:
    if index >= _actors.size() or not is_instance_valid(_actors[index].model):
        return
    var model: Node3D = _actors[index].model
    var forward: Vector3 = _stage.global_basis * facing
    var basis: Basis = Basis.looking_at(forward, Vector3.UP)
    basis = basis * Basis.from_euler(Vector3(pitch, 0.0, roll))
    model.global_transform = Transform3D(basis.scaled(_actors[index].scale), _stage.to_global(point))

func _bone(actor_index: int, bone_name: String, euler: Vector3) -> void:
    if actor_index >= _actors.size():
        return
    var skeleton: Skeleton3D = _actors[actor_index].get("skeleton") as Skeleton3D
    if skeleton == null:
        return
    var index: int = skeleton.find_bone(bone_name)
    if index >= 0:
        skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(euler))

func _create_technique(id: String, actor_index: int) -> void:
    var definition: Dictionary = _technique_definition(id)
    var signature: String = _effect_signature(str(definition.get("effect", id)), id)
    var root: Node3D = Node3D.new()
    root.name = "FX_" + id
    _stage.add_child(root)
    var effect: Dictionary = {"id": signature, "technique_id": id,
        "root": root, "actor": actor_index, "pieces": []}
    var colors: Dictionary = {"orbital_shot": Color("bca0ff"), "magnus_shot": Color("ffc45c"),
        "hurricane_barrier": Color("a3ffc0"), "aquablast": Color("50d9ff"),
        "combat_blade": Color("ff5b83"), "drift": Color("71ffe0"),
        "photo_stop": Color("fff7bd"), "gyroscopic_stop": Color("77b3ff"),
        "perihelion_hammer": Color("eaa266"), "abyssal_cathedral": Color("5fe3df")}
    effect.color = colors.get(signature, Color("eee6cb"))
    if definition.get("color") is String and Color.html_is_valid(definition.color):
        effect.color = Color.html(definition.color)
    var power: float = float(definition.get("power", 30.0))
    var intensity: float = clampf(0.8 + power / 150.0, 0.8, 1.65) if is_finite(power) else 1.0
    root.scale = Vector3.ONE * intensity
    match signature:
        "perihelion_hammer", "abyssal_cathedral":
            var spirit: Node3D = ModifierVisual.new()
            root.add_child(spirit)
            var visual_definition: Dictionary = definition.duplicate(true)
            visual_definition.id = id
            visual_definition.effect = "perihelion" if signature == "perihelion_hammer" else "abyssal"
            spirit.configure(visual_definition)
            effect.spirit = spirit
            if signature == "perihelion_hammer":
                var projectile: Node3D = Node3D.new()
                projectile.name = "PerihelionMeteor"
                _stage.add_child(projectile)
                effect.projectile = projectile
                for index: int in 3:
                    effect.pieces.append(_ring(projectile, 0.28 + index * 0.12, effect.color))
                for index: int in 12:
                    effect.pieces.append(_sphere(projectile, 0.045 + (index % 3) * 0.02, effect.color))
        "orbital_shot", "gyroscopic_stop":
            for i: int in 3:
                effect.pieces.append(_ring(root, 0.75 + float(i) * 0.22, effect.color))
            if signature == "orbital_shot":
                for i: int in 8:
                    effect.pieces.append(_sphere(root, 0.07, effect.color))
        "magnus_shot", "aquablast", "combat_blade":
            for i: int in (3 if signature != "combat_blade" else 2):
                effect.pieces.append(_ribbon(root, effect.color))
            for i: int in 9:
                effect.pieces.append(_sphere(root, 0.045 if signature != "aquablast" else 0.10, effect.color))
        "hurricane_barrier":
            for i: int in 11:
                effect.pieces.append(_ring(root, 0.7 + sin(float(i) * 0.35) * 0.45, effect.color))
        "photo_stop":
            for i: int in 4:
                var bar: MeshInstance3D = MeshInstance3D.new()
                var box: BoxMesh = BoxMesh.new()
                box.size = Vector3(1.8, 0.07, 0.07)
                bar.mesh = box
                bar.material_override = _material(effect.color)
                root.add_child(bar)
                effect.pieces.append(bar)
            effect.pieces.append(_sphere(root, 0.55, effect.color))
        "drift":
            if _actors.size() > actor_index and is_instance_valid(_actors[actor_index].model):
                for i: int in 3:
                    var ghost: Node3D = _actors[actor_index].model.duplicate() as Node3D
                    root.add_child(ghost)
                    _ghost_material(ghost, effect.color, 0.22 - float(i) * 0.04)
                    effect.pieces.append(ghost)
    _fx.append(effect)

func _technique_definition(id: String) -> Dictionary:
    var definitions: Variant = duel_data.get("techniques", [])
    if definitions is Array:
        for definition: Variant in definitions:
            if definition is Dictionary and str(definition.get("id", "")) == id:
                return definition
    return {}

func _effect_signature(effect: String, fallback: String) -> String:
    var aliases: Dictionary = {"orbital": "orbital_shot", "magnus": "magnus_shot",
        "hurricane": "hurricane_barrier", "aqua": "aquablast", "blade": "combat_blade",
        "drift": "drift", "photo": "photo_stop", "gyro": "gyroscopic_stop",
        "perihelion": "perihelion_hammer", "abyssal": "abyssal_cathedral"}
    if aliases.has(effect):
        return aliases[effect]
    if effect in aliases.values():
        return effect
    return fallback

func _animate_technique(effect: Dictionary, charge: float, after: float) -> void:
    var root: Node3D = effect.root
    var pieces: Array = effect.pieces
    var id: String = effect.id
    var owner_index: int = int(effect.actor)
    var won: bool = bool(duel_data.get("attacker_won", false))
    var owner_won: bool = won if int(effect.actor) == 0 else not won
    var parried: bool = not won and str(duel_data.get("outcome", duel_data.get("result", ""))) in ["deflection", "parry"]
    var energy: float = sin(charge * PI * 0.5)
    var rupture: float = after if revealed and not owner_won else 0.0
    var time: float = elapsed
    match id:
        "perihelion_hammer", "abyssal_cathedral":
            var spirit: Node3D = effect.spirit
            root.position = Vector3(0, 0, -2.0 if owner_index == 0 else 2.85)
            root.rotation.y = PI if owner_index == 0 else 0.0
            spirit.set_presentation(time)
            spirit.set_signature_progress(charge, after if revealed else 0.0,
                str(duel_data.get("outcome", "goal" if won else "capture")) if revealed else "")
            if id == "perihelion_hammer":
                effect.projectile.position = _ghost_ball.position
                for index: int in mini(3, pieces.size()):
                    pieces[index].rotation = Vector3(time * (2 + index), index * PI / 3, time * 1.5)
                    pieces[index].scale = Vector3.ONE * (0.55 + energy * 0.6)
                for index: int in range(3, pieces.size()):
                    var angle: float = index * 2.4 + time * 8
                    var distance: float = (index - 2) * 0.1
                    pieces[index].position = Vector3(cos(angle) * 0.3, sin(angle) * 0.3,
                        -distance * (0.3 + after * 2))
                _bone(owner_index, "UpperArmL", Vector3(-0.6 * energy, 0, -0.8 * energy))
                _bone(owner_index, "Chest", Vector3(-sin(charge * PI) * 0.2, -sin(charge * PI) * 0.6, 0))
                if not revealed:
                    _ghost_ball.position.y += sin(charge * PI) * 1.3
            else:
                _bone(owner_index, "UpperArmL", Vector3(1.0 * energy, 0, -0.5 * energy))
                _bone(owner_index, "UpperArmR", Vector3(1.0 * energy, 0, 0.5 * energy))
        "orbital_shot":
            root.position = _ghost_ball.position
            for i: int in mini(3, pieces.size()):
                pieces[i].rotation = Vector3(time * (1.1 + i * 0.4), float(i) * 1.05, time * 0.8)
                pieces[i].scale = Vector3.ONE * (0.35 + energy * 0.6) * (1.0 + rupture * 2.0)
            for i: int in range(3, pieces.size()):
                var angle: float = time * 7.0 + float(i) * TAU / 8.0
                pieces[i].position = Vector3(cos(angle), sin(angle * 1.3) * 0.7, sin(angle)) * (0.8 + rupture * 2.0)
            var swing: float = sin(charge * PI) if not revealed else -sin(after * PI) * 0.35
            var strike_angle: float = lerpf(-0.9, 1.3, smoothstep(0.5, 1.0, charge)) * smoothstep(0.0, 0.3, charge)
            if revealed:
                strike_angle = 1.3 * (1.0 - smoothstep(0.0, 0.8, after))
            _bone(owner_index, "UpperLegR", Vector3(strike_angle, charge * 0.3 * (1.0 - after), 0.0))
            _bone(owner_index, "Chest", Vector3(-0.25 * swing, swing * 0.9, 0.0))
            if is_instance_valid(_actors[owner_index].model):
                _actors[owner_index].model.global_position += Vector3.UP * sin(charge * PI) * 0.55
        "magnus_shot":
            root.position = Vector3.ZERO
            var tip: Vector3 = _ghost_ball.position
            if not revealed:
                tip.x += sin(charge * PI) * 1.4
                _ghost_ball.position = tip
            for i: int in mini(3, pieces.size()):
                var path: Array[Vector3] = []
                for j: int in 22:
                    var f: float = float(j) / 21.0
                    path.append(tip - Vector3(sin(f * PI + i * 0.3) * 0.7, -sin(f * PI) * 0.25 + i * 0.05, f * 2.8 * energy))
                _update_ribbon(pieces[i], path, 0.035 + i * 0.02)
            for i: int in range(3, pieces.size()):
                var angle: float = time * 12.0 + i
                pieces[i].position = tip + Vector3(cos(angle), sin(angle), -float(i - 3) * 0.18) * 0.45
            var swing: float = sin(charge * PI) if not revealed else -sin(after * PI) * 0.35
            _bone(owner_index, "Chest", Vector3(-0.1, -swing * 0.65, 0.0))
            var strike_angle: float = lerpf(-0.8, 1.15, smoothstep(0.5, 1.0, charge)) * smoothstep(0.0, 0.3, charge)
            if revealed:
                strike_angle = 1.15 * (1.0 - smoothstep(0.0, 0.8, after))
            _bone(owner_index, "UpperLegR", Vector3(strike_angle, -swing * 0.7, -0.25 * (1.0 - after)))
        "hurricane_barrier":
            root.position = Vector3(0.0, 0.1, 0.75)
            for i: int in pieces.size():
                var height: float = float(i) * 0.20
                var angle: float = time * 4.0 + i * 0.55
                pieces[i].position = Vector3(sin(angle) * 0.16 + sin(i * 3.0) * rupture * 2.5,
                    height + rupture * i * 0.10, cos(angle) * 0.1 + rupture * i * 0.12)
                pieces[i].rotation = Vector3(sin(angle) * 0.12 + rupture, angle, cos(angle) * 0.12)
                pieces[i].scale = Vector3.ONE * maxf(0.01, energy * (1.0 - after * 0.45))
        "aquablast":
            root.position = Vector3(0.0, 0.05, 1.0)
            for i: int in mini(3, pieces.size()):
                var wave: Array[Vector3] = []
                for j: int in 30:
                    var f: float = float(j) / 29.0
                    var x: float = (f - 0.5) * 3.4
                    wave.append(Vector3(x + rupture * sin(j) * 0.5,
                        sin(f * PI) * energy * (1.35 + i * 0.3) + sin(f * 9.0 - time * 6.0) * 0.09,
                        -sin(f * PI) * 0.4 - float(i) * 0.2 - after * (2.0 if owner_won else -1.0)))
                _update_ribbon(pieces[i], wave, 0.10 + i * 0.07)
            for i: int in range(3, pieces.size()):
                var angle: float = float(i) * 1.7
                pieces[i].position = Vector3(sin(angle) * 1.7, fmod(time * 1.8 + i * 0.25, 2.1), cos(angle) * 0.6 - after)
                pieces[i].scale = Vector3(0.7, 1.5, 0.7) * energy
        "combat_blade":
            root.position = Vector3(0.0, 0.8, -0.9 + charge * 0.7)
            for i: int in mini(2, pieces.size()):
                var blade: Array[Vector3] = []
                for j: int in 25:
                    var a: float = -1.2 + float(j) / 24.0 * 2.3 + time * 3.2 + i * 0.8
                    blade.append(Vector3(cos(a) * (1.5 + i * 0.2), sin(a) * 0.65,
                        sin(a) * 0.7 + after * 1.8))
                _update_ribbon(pieces[i], blade, 0.04 + sin(charge * PI) * 0.13)
            for i: int in range(2, pieces.size()):
                pieces[i].position = Vector3(sin(i * 2.4 + time * 8.0), cos(i + time * 5.0) * 0.5,
                    sin(i * 3.0) + after * 2.0) * energy
            _bone(owner_index, "UpperArmR", Vector3(-1.1 * energy, -energy, 0.4 * sin(time * 6.0)))
            _bone(owner_index, "Chest", Vector3(-0.1, sin(time * 5.0) * 0.5, 0.0))
        "drift":
            root.position = Vector3.ZERO
            for i: int in pieces.size():
                var model: Node3D = pieces[i]
                var phase: float = time * 3.0 - i * 0.28
                model.position = Vector3(sin(phase) * (0.55 + i * 0.3), 0.0,
                    -1.7 + energy * 1.5 - i * 0.35 + after * (3.0 if owner_won else -0.5))
                model.rotation.y = PI + sin(phase) * 0.35
                for skeleton: Node in model.find_children("*", "Skeleton3D", true, false):
                    for bone_name: String in ["UpperLegL", "UpperLegR"]:
                        var bone_index: int = skeleton.find_bone(bone_name)
                        if bone_index >= 0:
                            var step: float = sin(time * 9.0 - i * 0.4) * (0.8 if bone_name.ends_with("L") else -0.8)
                            skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(Vector3(step, 0.0, 0.0)))
            var drift_roll: float = sin(time * 5.0) * 0.24
            _bone(owner_index, "Chest", Vector3(0.0, sin(time * 5.0) * 0.4, drift_roll))
            _bone(owner_index, "UpperLegL", Vector3(sin(time * 9.0) * 0.8, 0.0, -0.1))
            _bone(owner_index, "UpperLegR", Vector3(-sin(time * 9.0) * 0.8, 0.0, 0.1))
        "photo_stop":
            root.position = Vector3(0.0, 1.25, 1.8)
            for i: int in mini(4, pieces.size()):
                var angle: float = float(i) * PI * 0.5
                pieces[i].position = Vector3(cos(angle), sin(angle), 0.0) * (0.95 - energy * 0.25 + rupture * 2.0)
                pieces[i].rotation = Vector3(0.0, rupture * float(i), angle + PI * 0.5 + rupture * 1.7)
                pieces[i].scale = Vector3.ONE * (0.4 + energy * 0.6)
            if pieces.size() > 4:
                var flash: float = maxf(0.0, 1.0 - absf(elapsed - reveal_time) * 7.0)
                pieces[4].scale = Vector3.ONE * maxf(0.001, flash * 3.0)
            if revealed and owner_won:
                # La pose et le cadre se figent après le même flash que l'échec.
                _bone(owner_index, "Head", Vector3(0.0, -0.18, 0.0))
                if parried:
                    root.position.x += after * 0.6
                    root.rotation.z = after * 0.5
        "gyroscopic_stop":
            root.position = Vector3(0.0, 1.2, 1.9)
            for i: int in mini(3, pieces.size()):
                var phase: float = time * (2.0 + i * 0.7)
                var lock: float = after if revealed and owner_won and not parried else 0.0
                pieces[i].rotation = Vector3(lerp_angle(phase, PI * 0.5, lock),
                    float(i) * PI / 3.0 + phase * (1.0 - lock), phase * 0.5)
                pieces[i].position = Vector3(sin(i * 3.0), cos(i * 2.0), 1.0) * rupture * 2.0
                if revealed and parried:
                    pieces[i].position += Vector3(after * 0.8, 0.0, -after * 0.4)
                pieces[i].scale = Vector3.ONE * maxf(0.01, 0.4 + energy * 0.6 - lock * 0.3)
            _bone(owner_index, "UpperArmL", Vector3(1.3 * energy, 0.0, -0.2))
            _bone(owner_index, "UpperArmR", Vector3(1.3 * energy, 0.0, 0.2))

func _material(color: Color, opacity: float = 1.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(color, opacity)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.25
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if opacity < 1.0:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return material

func _sphere(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 12
    sphere.rings = 6
    node.mesh = sphere
    node.material_override = _material(color)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _use_football_mesh(target: MeshInstance3D) -> void:
    # Même ballon détaillé que le jeu live, avec ses panneaux et son cuir.
    var source: Node3D = BallScene.instantiate()
    var mesh: MeshInstance3D = source as MeshInstance3D
    if mesh == null:
        var parts: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
        if not parts.is_empty():
            mesh = parts[0] as MeshInstance3D
    if mesh != null:
        target.mesh = mesh.mesh
        target.material_override = null
        target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    source.free()

func _ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var torus: TorusMesh = TorusMesh.new()
    torus.inner_radius = radius - 0.025
    torus.outer_radius = radius + 0.025
    torus.rings = 40
    torus.ring_segments = 6
    node.mesh = torus
    node.material_override = _material(color)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _ribbon(parent: Node3D, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.mesh = ImmediateMesh.new()
    node.material_override = _material(color, 0.8)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _update_ribbon(node: MeshInstance3D, path: Array[Vector3], width: float) -> void:
    var mesh: ImmediateMesh = node.mesh as ImmediateMesh
    mesh.clear_surfaces()
    if path.size() < 2:
        return
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i: int in range(path.size() - 1):
        var normal: Vector3 = (path[i + 1] - path[i]).cross(Vector3.FORWARD).normalized() * width
        if normal.length_squared() < 0.00001:
            normal = Vector3.RIGHT * width
        for vertex: Vector3 in [path[i] - normal, path[i] + normal, path[i + 1] + normal,
                path[i] - normal, path[i + 1] + normal, path[i + 1] - normal]:
            mesh.surface_add_vertex(vertex)
    mesh.surface_end()

func _ghost_material(node: Node, color: Color, opacity: float) -> void:
    if node is AnimationPlayer:
        node.active = false
    if node is MeshInstance3D:
        node.material_override = _material(color, opacity)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child: Node in node.get_children():
        _ghost_material(child, color, opacity)
