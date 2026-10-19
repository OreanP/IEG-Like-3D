extends RefCounted
## Chorégraphies visuelles déterministes : aucun accès à la session de jeu.
## charge est commune à toutes les issues ; après les scores, after révèle le résultat.

const ModifierVisual = preload("res://scripts/presentation/modifier_visual.gd")
const STYLES: Array[String] = ["seismic_strike", "prism_ricochet", "paper_escape", "syncope",
    "bronze_rampart", "mechanical_brambles", "titan_grip", "midnight_dial", "ninefold_hunt", "antler_citadel"]

var host: Node3D

func handles(style: String) -> bool:
    return style in STYLES

func build(effect: Dictionary, definition: Dictionary) -> void:
    var root: Node3D = effect.root
    var color: Color = effect.color
    effect.parts = {}
    effect.root.scale = Vector3.ONE # Les dimensions gardent un rapport humain lisible.
    match str(effect.id):
        "seismic_strike":
            effect.parts.slabs = []
            for i: int in 7:
                var slab: MeshInstance3D = _prism(root, 5, Color("514854").lerp(color, 0.16), false)
                slab.name = "RocheSoulevee%d" % i
                slab.scale = Vector3(0.45, 0.15 + i % 3 * 0.12, 0.65)
                effect.parts.slabs.append(slab)
            effect.parts.shards = []
            for i: int in 15:
                effect.parts.shards.append(_prism(root, 3, color.lerp(Color("493539"), 0.55), false))
            effect.parts.trails = [_ribbon(root, color), _ribbon(root, color.lightened(0.2))]
        "prism_ricochet":
            effect.parts.prisms = []
            effect.parts.frames = []
            effect.parts.echoes = []
            effect.parts.trails = []
            for i: int in 3:
                var prism: MeshInstance3D = _prism(root, 3, color, true)
                prism.scale = Vector3(0.45, 0.85, 0.45)
                effect.parts.prisms.append(prism)
                var rim: Node3D = _prism_frame(root, color.lightened(0.4))
                effect.parts.frames.append(rim)
                var echo: MeshInstance3D = host._sphere(root, 0.16, color)
                host._use_football_mesh(echo)
                echo.material_override = _material(color, true, 0.36)
                effect.parts.echoes.append(echo)
                effect.parts.trails.append(_ribbon(root, color))
        "paper_escape":
            effect.parts.ghosts = []
            if int(effect.actor) < host._actors.size() and is_instance_valid(host._actors[int(effect.actor)].model):
                for i: int in 2:
                    var ghost: Node3D = host._actors[int(effect.actor)].model.duplicate() as Node3D
                    root.add_child(ghost)
                    host._ghost_material(ghost, color, 0.34 - i * 0.07)
                    effect.parts.ghosts.append(ghost)
            effect.parts.leaves = []
            for i: int in 30:
                var leaf: MeshInstance3D = _leaf(root, color.lerp(Color("fff8e1"), float(i % 4) / 4.0))
                effect.parts.leaves.append(leaf)
        "syncope":
            effect.parts.beats = []
            effect.parts.ticks = []
            for i: int in 3:
                var beat: MeshInstance3D = host._ring(root, 0.36 + i * 0.08, color)
                effect.parts.beats.append(beat)
                var ticks: Array = []
                for j: int in 8:
                    ticks.append(_box(root, Vector3(0.065, 0.03, 0.18), color, true))
                effect.parts.ticks.append(ticks)
            effect.parts.trails = [_ribbon(root, color), _ribbon(root, color.lightened(0.3))]
        "bronze_rampart":
            effect.parts.shields = []
            for i: int in 3:
                effect.parts.shields.append(_shield(root, color, i))
            effect.parts.fragments = []
            for i: int in 15:
                var fragment: MeshInstance3D = _prism(root, 3, color, false)
                effect.parts.fragments.append(fragment)
        "mechanical_brambles":
            effect.parts.stems = []
            effect.parts.joints = []
            effect.parts.thorns = []
            for i: int in 6:
                var chain: Array = []
                var joints: Array = []
                var thorns: Array = []
                for j: int in 6:
                    chain.append(_rod(root, 0.065, Color("3d5761")))
                    joints.append(_joint(root, 0.10, color))
                    thorns.append(_cone(root, 0.085, 0.32, color))
                effect.parts.stems.append(chain)
                effect.parts.joints.append(joints)
                effect.parts.thorns.append(thorns)
        "titan_grip":
            effect.parts.hands = [_stone_hand(root, -1, color), _stone_hand(root, 1, color)]
            effect.parts.chips = []
            for i: int in 18:
                effect.parts.chips.append(_prism(root, 3, Color("b9b8af").lerp(color, 0.12), false))
        "midnight_dial":
            var dial: Node3D = Node3D.new()
            root.add_child(dial)
            effect.parts.dial = dial
            effect.parts.rim = host._ring(dial, 1.18, color)
            effect.parts.rim.rotation.x = PI * 0.5
            effect.parts.inner = host._ring(dial, 0.99, color.darkened(0.2))
            effect.parts.inner.rotation.x = PI * 0.5
            var face: MeshInstance3D = _disc(dial, 1.13, Color("101d3d"), 0.46)
            face.position.z = 0.06
            effect.parts.face = face
            effect.parts.hours = []
            for i: int in 12:
                var mark: MeshInstance3D = _box(dial, Vector3(0.045 if i % 3 else 0.075, 0.18, 0.045), color, true)
                effect.parts.hours.append(mark)
            effect.parts.hands = []
            for i: int in 2:
                var pivot: Node3D = Node3D.new()
                dial.add_child(pivot)
                var hand: MeshInstance3D = _box(pivot, Vector3(0.07, 0.76 + i * 0.22, 0.04), color.lightened(0.25), true)
                hand.position.y = 0.31 + i * 0.10
                var tip: MeshInstance3D = _cone(pivot, 0.095, 0.20, color.lightened(0.25))
                tip.position.y = 0.78 + i * 0.22
                effect.parts.hands.append(pivot)
            effect.parts.arcs = [_ribbon(root, color), _ribbon(root, color.lightened(0.3))]
        "ninefold_hunt":
            _build_spirit(effect, definition, "vaelis")
            effect.parts.foxes = []
            effect.parts.trails = []
            for i: int in 9:
                effect.parts.foxes.append(_fox_echo(root, color, i))
                effect.parts.trails.append(_ribbon(root, color))
        "antler_citadel":
            _build_spirit(effect, definition, "orvann")
            effect.parts.branches = []
            effect.parts.crowns = []
            effect.parts.keystones = []
            for i: int in 5:
                var arch: Array = []
                var crown: Array = []
                for j: int in 12:
                    arch.append(_rod(root, 0.075 if j % 3 else 0.115, Color("e4e0ca").lerp(color, 0.14)))
                    if j % 2 == 0:
                        crown.append(_rod(root, 0.045, color))
                effect.parts.branches.append(arch)
                effect.parts.crowns.append(crown)
                var key: Node3D = _shield(root, color, i)
                key.scale = Vector3.ONE * 0.32
                effect.parts.keystones.append(key)

func animate(effect: Dictionary, charge: float, after: float) -> void:
    var root: Node3D = effect.root
    var p: Dictionary = effect.parts
    var owner: int = int(effect.actor)
    var revealed: bool = host.revealed
    var won: bool = bool(host.duel_data.get("attacker_won", false))
    var owner_won: bool = won if owner == 0 else not won
    var parry: bool = revealed and not won and str(host.duel_data.get("outcome", host.duel_data.get("result", ""))) in ["deflection", "parry"]
    var failure: float = after if revealed and not owner_won else 0.0
    var success: float = after if revealed and owner_won else 0.0
    var energy: float = smoothstep(0.05, 0.7, charge)
    var t: float = host.elapsed
    var ball: Vector3 = host._ghost_ball.position
    var actor: Vector3 = _actor_position(owner)
    root.position = Vector3.ZERO
    match str(effect.id):
        "seismic_strike":
            var stomp: float = smoothstep(0.08, 0.28, charge)
            var launch: float = smoothstep(0.49, 0.88, charge)
            for i: int in p.slabs.size():
                var slab: Node3D = p.slabs[i]
                var angle: float = i * TAU / p.slabs.size()
                slab.position = Vector3(cos(angle) * (0.65 + launch * 0.25),
                    -0.1 + stomp * (0.20 + i % 3 * 0.18) - launch * 0.26, actor.z + 0.7 + sin(angle) * 0.55)
                slab.rotation = Vector3(launch * cos(angle) * 0.65, angle, stomp * sin(angle) * 0.32)
                slab.visible = not revealed or after < 0.28
            for i: int in p.shards.size():
                var fragment: Node3D = p.shards[i]
                var phase: float = i * 2.4 + t * 4.2
                var scatter: float = 0.16 + (i % 4) * 0.07 + after * 1.6
                fragment.position = ball + Vector3(cos(phase), sin(phase) * 0.7, sin(phase * 0.7)) * scatter
                fragment.rotation = Vector3(t + i, t * 1.7, phase)
                fragment.scale = Vector3(0.07, 0.04 + i % 3 * 0.035, 0.12) * launch
            for i: int in 2:
                var path: Array[Vector3] = []
                for j: int in 16:
                    var f: float = j / 15.0
                    path.append(ball - Vector3(sin(f * 5 + i * PI) * 0.12, sin(f * PI) * 0.13, f * (0.5 + launch * 2.2)))
                host._update_ribbon(p.trails[i], path, 0.025 + launch * 0.025)
            host._bone(owner, "UpperLegL", Vector3(-0.9 * sin(stomp * PI), 0, -0.08))
            host._bone(owner, "LowerLegL", Vector3(0.6 * (1 - stomp), 0, 0))
            host._bone(owner, "UpperLegR", Vector3(lerpf(-1.0, 1.35, launch) * energy * (1 - after), 0.05, 0.16))
            host._bone(owner, "Chest", Vector3(-0.32 * sin(charge * PI), -0.4 * launch * (1 - after), 0))
        "prism_ricochet":
            var launch: float = smoothstep(0.34, 0.84, charge)
            for i: int in 3:
                var prism_position: Vector3 = Vector3((-1 if i % 2 == 0 else 1) * (0.75 + i * 0.16), 1.0 + i * 0.26, -0.7 + i * 0.75)
                p.prisms[i].position = prism_position
                p.frames[i].position = prism_position
                var rotation: Vector3 = Vector3(0.18 * sin(t * 2 + i), t * 0.6 + i, 0.2)
                p.prisms[i].rotation = rotation
                p.frames[i].rotation = rotation
                p.prisms[i].visible = not revealed or after < 0.12
                p.frames[i].visible = p.prisms[i].visible
                var convergence: float = smoothstep(0.74, 1.0, charge)
                var echo: Vector3 = ball + Vector3(sin(i * TAU / 3 + t * 2) * 0.9, cos(i * TAU / 3) * 0.5, -0.3) * (1 - convergence)
                p.echoes[i].position = echo
                p.echoes[i].rotation = Vector3(t * 9, t * 7, i)
                p.echoes[i].visible = charge > 0.28 and not revealed and charge < 0.97
                var path: Array[Vector3] = []
                for j: int in 16:
                    var f: float = j / 15.0
                    path.append(prism_position.lerp(echo, f) + Vector3.UP * sin(f * PI) * 0.12)
                host._update_ribbon(p.trails[i], path, 0.018 * launch * (1 - after))
            host._bone(owner, "UpperLegR", Vector3(lerpf(-0.55, 1.0, launch) * energy * (1 - after), -0.8 * sin(charge * PI), -0.3))
            host._bone(owner, "LowerLegR", Vector3(0.85 * (1 - launch) * energy, 0, 0))
            host._bone(owner, "Chest", Vector3(-0.1, sin(charge * PI) * 0.9, -0.15))
            host._bone(owner, "UpperArmL", Vector3(0.1, 0, -0.85 * energy))
        "paper_escape":
            var pivot: float = smoothstep(0.28, 0.76, charge)
            var slip: float = sin(pivot * PI) * 0.72 * (1 - after)
            host._position_actor(owner, actor + Vector3(slip, 0, 0), Vector3.BACK, -slip * 0.15, -0.1)
            host._bone(owner, "Chest", Vector3(-0.13, -sin(pivot * PI) * 0.9, -slip * 0.28))
            host._bone(owner, "UpperLegL", Vector3(sin(pivot * TAU) * 0.65, -0.2, -0.14))
            host._bone(owner, "UpperLegR", Vector3(-sin(pivot * TAU) * 0.65, 0.25, 0.14))
            host._bone(owner, "LowerLegR", Vector3(0.5 * sin(pivot * PI), 0, 0))
            host._bone(owner, "UpperArmL", Vector3(0.15, 0, -0.45))
            for i: int in p.ghosts.size():
                var ghost: Node3D = p.ghosts[i]
                ghost.position = Vector3(-slip * (0.7 + i * 0.5), 0, -2.3 + pivot * 2.1 + i * 0.4 + success * 1.7)
                ghost.rotation.y = PI - pivot * 0.45
                ghost.visible = charge > 0.17 and (not revealed or after < (0.2 if not owner_won else 0.42))
                _ghost_stride(ghost, t * 7 + i)
            for i: int in p.leaves.size():
                var leaf: Node3D = p.leaves[i]
                var angle: float = i * 2.4 + t * 3
                var distance: float = 0.35 + i % 4 * 0.13 + after * (2.3 if not owner_won else 0.7)
                leaf.position = Vector3(cos(angle) * distance, 0.25 + fposmod(i * 0.16 + t * 0.55, 1.7), actor.z + sin(angle) * distance)
                leaf.rotation = Vector3(angle, i + t * 2, t * 1.7)
                leaf.scale = Vector3.ONE * energy * (1 - after * 0.8)
            if not revealed:
                host._ghost_ball.position.x += slip
        "syncope":
            var beat_positions: Array[Vector3] = [Vector3(-0.38, 0.03, -1.95), Vector3(0.35, 0.035, -1.35), Vector3(-0.25, 0.04, -0.25)]
            var phases: Array[float] = [0.18, 0.48, 0.73]
            for i: int in 3:
                var beat: Node3D = p.beats[i]
                var pulse: float = clampf((charge - phases[i]) * (7.0 if i < 2 else 12.0), 0, 1)
                beat.position = beat_positions[i]
                beat.scale = Vector3.ONE * maxf(0.001, pulse * (1 + after * 0.6))
                beat.visible = failure < 0.08
                for j: int in 8:
                    var tick: Node3D = p.ticks[i][j]
                    var a: float = j * TAU / 8
                    tick.position = beat_positions[i] + Vector3(cos(a), after * failure * (1 + j % 3), sin(a)) * (0.45 + failure * 1.6)
                    tick.rotation = Vector3(failure * j, a, failure * j * 0.4)
                    tick.scale = Vector3.ONE * pulse * (1 - after * 0.7)
            var steps: float = sin(charge * TAU * 1.5) * (0.25 if charge < 0.66 else 0.75)
            host._bone(owner, "UpperLegL", Vector3(steps * (1 - after), 0, -0.08))
            host._bone(owner, "UpperLegR", Vector3(-steps * (1 - after), 0, 0.08))
            host._bone(owner, "LowerLegL", Vector3(maxf(0, -steps) * 1.4, 0, 0))
            host._bone(owner, "LowerLegR", Vector3(maxf(0, steps) * 1.4, 0, 0))
            host._bone(owner, "Chest", Vector3(-0.1 - smoothstep(0.67, 0.9, charge) * 0.28 * (1 - after), 0, steps * 0.15))
            host._bone(owner, "UpperArmL", Vector3(-steps * 0.65, 0, -0.15))
            host._bone(owner, "UpperArmR", Vector3(steps * 0.65, 0, 0.15))
            for i: int in 2:
                var path: Array[Vector3] = []
                for j: int in 15:
                    var f: float = j / 14.0
                    path.append(actor + Vector3((-0.25 if i == 0 else 0.25), 0.4 + i * 0.4, -f * 1.8))
                host._update_ribbon(p.trails[i], path, 0.025 * smoothstep(0.67, 0.9, charge) * (1 - after))
        "bronze_rampart":
            for i: int in 3:
                var shield: Node3D = p.shields[i]
                var side: float = i - 1.0
                shield.position = Vector3(side * (0.73 - success * 0.3 + failure * 1.4), 1.05 + (0.12 if i == 1 else 0) - failure * 0.5, 0.55 + absf(side) * 0.24 + success * 0.28)
                shield.rotation = Vector3(failure * (i - 0.6), -side * (0.28 + success * 0.6) + failure * i, side * failure * 1.2)
                shield.scale = Vector3.ONE * energy * (1 - failure * 0.7)
            for i: int in p.fragments.size():
                var frag: Node3D = p.fragments[i]
                frag.position = Vector3(sin(i * 2.4) * failure * 2.8, 1.1 + cos(i * 1.4) * failure * 1.3 - after * after * 0.8, 0.6 + cos(i * 2.4) * failure * 1.4)
                frag.rotation = Vector3(i + t * 3, i * 2.4, t * 4)
                frag.scale = Vector3(0.08, 0.16, 0.05) * minf(1, failure * 8)
            _defensive_pose(owner, charge, after, -0.2, 0.55)
            host._bone(owner, "UpperArmL", Vector3(0.6 * energy, 0, -0.7 * energy))
            host._bone(owner, "UpperArmR", Vector3(0.6 * energy, 0, 0.7 * energy))
        "mechanical_brambles":
            var grow: float = smoothstep(0.08, 0.86, charge)
            var cage_center: Vector3 = Vector3(0, 0.8, 0.3)
            for i: int in 6:
                var a: float = i * TAU / 6
                for j: int in 6:
                    var f: float = j / 6.0
                    var g: float = (j + 1) / 6.0
                    var first: Vector3 = _bramble_point(a, f, grow, success, failure, cage_center)
                    var second: Vector3 = _bramble_point(a, g, grow, success, failure, cage_center)
                    # Les attaches cèdent réellement : les maillons se séparent,
                    # plutôt qu'une cage intacte qui se contente de s'agrandir.
                    var broken_link: Vector3 = Vector3(sin(i * 2.4 + j) * 0.5,
                        cos(j * 2.1) * 0.35 - failure * 0.6,
                        cos(i + j * 2.4) * 0.5) * failure
                    first += broken_link
                    second += broken_link
                    _between(p.stems[i][j], first, second)
                    p.joints[i][j].position = first
                    p.joints[i][j].rotation = Vector3(t * 1.5, a, j * 0.4)
                    p.joints[i][j].scale = Vector3.ONE * maxf(0.01, grow)
                    p.thorns[i][j].position = first + Vector3(cos(a), 0, sin(a)) * 0.10
                    p.thorns[i][j].rotation = Vector3(0, 0, -PI * 0.4)
                    p.thorns[i][j].scale = Vector3.ONE * grow
            _defensive_pose(owner, charge, after, 0.25, 0.2)
            host._bone(owner, "UpperLegR", Vector3(-0.85 * sin(charge * PI) * (1 - after), 0.55 * energy, 0.15))
            host._bone(owner, "LowerLegR", Vector3(0.2 * energy, 0, 0))
        "titan_grip":
            root.position = Vector3(0, 0.2, 1.85)
            for i: int in 2:
                var side: float = -1 if i == 0 else 1
                var hand: Node3D = p.hands[i]
                var close: float = success if not parry else 0
                hand.position = Vector3(side * (0.80 - energy * 0.29 - close * 0.24 + failure * 1.0) + (after * 1.1 if parry else 0), 0.40 + energy * 0.10 + failure * 0.15, failure * 0.25 - close * 0.12)
                hand.rotation = Vector3(-0.15 + energy * 0.10 + close * 0.18, side * (-0.23 - close * 0.36 + failure * 0.45), side * (0.25 + failure * 0.7) + (after * 0.6 if parry else 0))
                hand.scale = Vector3.ONE * (0.35 + energy * 0.65) * (1 - smoothstep(0.55, 1.0, close) * 0.9)
                for finger: Node3D in hand.get_meta("fingers"):
                    var index: int = int(finger.get_meta("ordinal"))
                    finger.rotation.x = -close * (0.8 if index < 4 else 0.4) + failure * (0.45 + index * 0.18)
                    finger.position.z = -failure * (index + 1) * 0.06
            for i: int in p.chips.size():
                var chip: Node3D = p.chips[i]
                var crumble: float = smoothstep(0.45, 1.0, success) if not parry else 0
                chip.position = Vector3(sin(i * 2.4) * (0.55 + failure * 1.5 + crumble * 0.5), 1.1 + cos(i * 3.0) * failure * 1.8 - after * after * 1.4, sin(i) * 0.4 + failure * i * 0.025)
                chip.scale = Vector3(0.065, 0.11, 0.05) * (failure if failure > 0 else success * 0.25)
                chip.rotation = Vector3(i + failure * 5, i * 2.3, failure * 4)
            _keeper_pose(owner, charge, after, failure, success, parry)
        "midnight_dial":
            var dial: Node3D = p.dial
            dial.position = Vector3(0, 1.25, 2.35)
            dial.scale = Vector3.ONE * (0.45 + energy * 0.55)
            dial.rotation = Vector3(0, 0, failure * 0.25 + (after * 0.25 if parry else 0))
            p.face.visible = failure < 0.32
            for i: int in 12:
                var a: float = i * TAU / 12
                var mark: Node3D = p.hours[i]
                mark.position = Vector3(sin(a), cos(a), 0) * (1.04 + failure * (0.7 + i % 3 * 0.3))
                mark.position.y -= failure * failure * 0.7
                mark.rotation = Vector3(failure * i * 0.3, failure * sin(i) * 1.4, -a + failure * sin(i) * 0.7)
            for i: int in 2:
                var hand: Node3D = p.hands[i]
                var running: float = (-t * (3.4 if i == 0 else 0.6))
                var caught: float = lerp_angle(running, (-0.8 if i == 0 else 0.8), success)
                hand.rotation = Vector3(failure * (i + 1) * 0.7, failure * (i - 0.5), caught - (after * 2.2 if parry else 0))
                hand.position = Vector3((i - 0.5) * failure, -failure * 0.45, -0.07)
            for i: int in 2:
                var path: Array[Vector3] = []
                for j: int in 26:
                    var a: float = j / 25.0 * TAU * energy + i * PI - t
                    var radius: float = 0.46 - success * 0.22 + failure * 0.8
                    path.append(ball + Vector3(cos(a), sin(a), sin(a * 0.5) * 0.35) * radius)
                host._update_ribbon(p.arcs[i], path, 0.018 * energy * (1 - failure))
            _keeper_pose(owner, charge, after, failure, success, parry)
            host._bone(owner, "UpperArmL", Vector3(1.15 * energy, -sin(charge * PI) * 0.30, -0.18))
            host._bone(owner, "UpperArmR", Vector3(1.15 * energy, sin(charge * PI) * 0.30 + (after * 0.7 if parry else 0), 0.18))
        "ninefold_hunt":
            _animate_spirit(effect, charge, after, revealed)
            var orbit: float = smoothstep(0.08, 0.88, charge)
            for i: int in 9:
                var fox: Node3D = p.foxes[i]
                var a: float = i * TAU / 9 + t * 2.1
                var converge: float = smoothstep(0.84, 1, charge)
                var radius: float = (1.0 + i % 3 * 0.38) * (1 - converge * 0.75)
                fox.position = Vector3(cos(a) * radius, 0.05 + sin(a * 2) * 0.12, -1.25 + sin(a) * radius + success * 3)
                fox.rotation = Vector3(0, -a + PI * 0.5, sin(t * 5 + i) * 0.08)
                fox.scale = Vector3.ONE * (0.5 + orbit * 0.5) * (1 - failure * 0.9)
                fox.visible = charge > 0.1 and (not revealed or (i == 4 and owner_won) or after < 0.18)
                var path: Array[Vector3] = []
                for j: int in 14:
                    var f: float = j / 13.0
                    var old: float = a - f * 0.8
                    path.append(Vector3(cos(old) * radius, 0.45 + i % 2 * 0.2, -1.25 + sin(old) * radius + success * 3))
                host._update_ribbon(p.trails[i], path, 0.017 * energy * (1 - after))
            var feint: float = sin(charge * TAU * 1.5) * (1 - after)
            host._bone(owner, "Chest", Vector3(-0.3, feint * 0.55, feint * 0.18))
            host._bone(owner, "UpperLegL", Vector3(feint * 0.75, 0, -0.1))
            host._bone(owner, "UpperLegR", Vector3(-feint * 0.75, 0, 0.1))
            host._bone(owner, "LowerLegL", Vector3(maxf(0, -feint) * 0.7, 0, 0))
            host._bone(owner, "LowerLegR", Vector3(maxf(0, feint) * 0.7, 0, 0))
            host._bone(owner, "UpperArmL", Vector3(-0.4, -0.2, -0.7 * energy))
            host._bone(owner, "UpperArmR", Vector3(-0.2, 0.2, 0.7 * energy))
        "antler_citadel":
            _animate_spirit(effect, charge, after, revealed)
            var grow: float = smoothstep(0.12, 0.9, charge)
            for i: int in 5:
                var depth: float = 0.35 + i * 0.28
                var width: float = 1.6 - i * 0.13 - success * 0.25
                var height: float = 2.35 - i * 0.08 - success * 0.35
                for j: int in 12:
                    var f: float = j / 12.0
                    var g: float = (j + 1) / 12.0
                    var a: Vector3 = _arch_point(f, width, height, depth, grow, failure, i)
                    var b: Vector3 = _arch_point(g, width, height, depth, grow, failure, i)
                    _between(p.branches[i][j], a, b)
                    if j % 2 == 0:
                        var tip: Vector3 = a + Vector3((-0.25 if f < 0.5 else 0.25), 0.3, -0.16) * grow
                        _between(p.crowns[i][j / 2], a, tip)
                var key: Node3D = p.keystones[i]
                key.position = Vector3(sin(i * 2.3) * failure * 2.2, height * grow - failure * i * 0.15, depth + failure * i * 0.3)
                key.rotation = Vector3(failure * i * 0.6, failure * i * 0.2, failure * i)
                key.scale = Vector3.ONE * 0.32 * grow
            _defensive_pose(owner, charge, after, 0.0, 0.7)
            host._bone(owner, "Head", Vector3(0.35 * sin(charge * PI), 0, 0))
            host._bone(owner, "UpperArmL", Vector3(0.75 * energy, 0, -0.8 * energy))
            host._bone(owner, "UpperArmR", Vector3(0.75 * energy, 0, 0.8 * energy))

func camera(effect: Dictionary, charge: float, after: float) -> Dictionary:
    # Focale et point visé propres à chaque geste ; GAR ne dépend pas de son issue.
    match str(effect.id):
        "seismic_strike": return {"position": Vector3(5.4, lerpf(0.95, 2.25, charge), -3.7 + charge * 1.6), "target": Vector3(0, 0.75 + charge * 0.3, -0.2), "fov": 48.0}
        "prism_ricochet": return {"position": Vector3(5.6, 2.1, -3.1 + charge), "target": Vector3(0, 1.1, -0.1), "fov": 51.0}
        "paper_escape": return {"position": Vector3(5.2 - charge * 0.5, 1.8, -3.6 + charge * 1.5), "target": Vector3(0, 0.9, -0.4 + after), "fov": 46.0}
        "syncope": return {"position": Vector3(4.8, lerpf(0.75, 2.15, smoothstep(0.5, 0.9, charge)), -3.1 + charge), "target": Vector3(0, 0.35 + charge * 0.5, -0.8 + after), "fov": 47.0}
        "bronze_rampart": return {"position": Vector3(5.8, 1.9, -3.4 + charge), "target": Vector3(0, 1.05, 0.5), "fov": 46.0}
        "mechanical_brambles": return {"position": Vector3(5.2, 2.5, -3.7 + charge * 1.2), "target": Vector3(0, 0.75, 0.5), "fov": 48.0}
        "titan_grip": return {"position": Vector3(5.6, 1.65, -2.6 + charge * 0.8), "target": Vector3(0, 1.1, 1.5), "fov": 47.0}
        "midnight_dial": return {"position": Vector3(5.2, 2.15, -2.8 + charge * 0.7), "target": Vector3(0, 1.2, 1.6), "fov": 49.0}
        "ninefold_hunt": return {"position": Vector3(8.0 - charge * 0.6, 3.3, 4.4 - charge * 1.2), "target": Vector3(0, 1.6, -0.6 + after * 0.5), "fov": 53.0}
        "antler_citadel": return {"position": Vector3(8.4 - charge * 0.4, 3.4, -4.7 + charge), "target": Vector3(0, 1.8, 1.25), "fov": 52.0}
    return {}

func _actor_position(owner: int) -> Vector3:
    if owner < host._actors.size() and is_instance_valid(host._actors[owner].model):
        return host._stage.to_local(host._actors[owner].model.global_position)
    return Vector3(0, 0, -1.2 if owner == 0 else 1.1)

func _build_spirit(effect: Dictionary, definition: Dictionary, style: String) -> void:
    var spirit: Node3D = ModifierVisual.new()
    effect.root.add_child(spirit)
    # La signature conserve le vrai Karma associé, y compris les palettes,
    # la hauteur et les clones modifiés dans l'atelier.
    var owner_id: String = str(definition.get("properties", {}).get("karma_id", ""))
    var owner: Dictionary = host._technique_definition(owner_id)
    var visual: Dictionary = owner.duplicate(true) if not owner.is_empty() else definition.duplicate(true)
    var properties: Dictionary = visual.get("properties", {}).duplicate(true)
    var appearance: Dictionary = properties.get("appearance", {}).duplicate(true)
    if not appearance.has("style"):
        appearance.style = style
    if not appearance.has("height"):
        appearance.height = 4.0
    properties.appearance = appearance
    visual.properties = properties
    if owner.is_empty():
        visual.effect = style
    spirit.configure(visual)
    effect.parts.spirit = spirit

func _animate_spirit(effect: Dictionary, charge: float, after: float, revealed: bool) -> void:
    var spirit: Node3D = effect.parts.spirit
    spirit.position = Vector3(0, 0, -2.65 if int(effect.actor) == 0 else 3.0)
    spirit.rotation.y = PI if int(effect.actor) == 0 else 0
    spirit.set_presentation(host.elapsed, 0.68 + smoothstep(0, 0.2, charge) * 0.32)
    # Les issues terrain (dribble/tackle/block) sont décrites du point de vue
    # du duel ; le Karma reçoit explicitement la réussite de son propriétaire.
    var outcome: String = ("success" if bool(host.duel_data.get("attacker_won", false)) == (int(effect.actor) == 0) else "failure") if revealed else ""
    spirit.set_signature_progress(charge, after if revealed else 0.0, outcome)

func _defensive_pose(owner: int, charge: float, after: float, twist: float, depth: float) -> void:
    var weight: float = smoothstep(0.05, 0.7, charge) * (1 - after * 0.7)
    host._bone(owner, "UpperLegL", Vector3(-depth * weight, 0, -0.23 * weight))
    host._bone(owner, "UpperLegR", Vector3(-depth * weight, 0, 0.23 * weight))
    host._bone(owner, "LowerLegL", Vector3(depth * 1.4 * weight, 0, 0))
    host._bone(owner, "LowerLegR", Vector3(depth * 1.4 * weight, 0, 0))
    host._bone(owner, "Chest", Vector3(-0.15 * weight, twist * weight, 0))

func _keeper_pose(owner: int, charge: float, after: float, failure: float, success: float, parry: bool) -> void:
    var energy: float = smoothstep(0.05, 0.8, charge)
    host._bone(owner, "UpperArmL", Vector3(1.1 * energy + success * 0.15, 0, -0.32 * energy - failure * 0.6))
    host._bone(owner, "UpperArmR", Vector3(1.1 * energy + success * 0.15, after * 0.7 if parry else 0, 0.32 * energy + failure * 0.6))
    host._bone(owner, "LowerArmL", Vector3(0.35 * energy + success * 0.6, 0, 0))
    host._bone(owner, "LowerArmR", Vector3(0.35 * energy + success * 0.6, 0, 0))
    host._bone(owner, "Chest", Vector3(0.12 * success - failure * 0.5, -after * 0.4 if parry else 0, 0))
    host._bone(owner, "UpperLegL", Vector3(-0.15 * energy, 0, -0.18))
    host._bone(owner, "UpperLegR", Vector3(-0.15 * energy, 0, 0.18))
    host._bone(owner, "LowerLegL", Vector3(0.3 * energy, 0, 0))
    host._bone(owner, "LowerLegR", Vector3(0.3 * energy, 0, 0))

func _ghost_stride(model: Node3D, phase: float) -> void:
    for skeleton: Node in model.find_children("*", "Skeleton3D", true, false):
        for bone_name: String in ["UpperLegL", "UpperLegR", "UpperArmL", "UpperArmR"]:
            var index: int = skeleton.find_bone(bone_name)
            if index >= 0:
                var angle: float = sin(phase) * (0.6 if bone_name.ends_with("L") else -0.6)
                skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(Vector3(angle, 0, 0)))

func _bramble_point(angle: float, f: float, grow: float, success: float, failure: float, center: Vector3) -> Vector3:
    var radius: float = (0.85 - sin(f * PI) * 0.20 - success * 0.28 + failure * f * 1.35)
    var twist: float = angle + f * 1.2 * grow
    return center + Vector3(cos(twist) * radius, (-0.72 + sin(f * PI * 0.9) * 1.50) * grow - failure * f * 0.5, sin(twist) * radius)

func _arch_point(f: float, width: float, height: float, depth: float, grow: float, failure: float, index: int) -> Vector3:
    var a: float = f * PI
    return Vector3(-cos(a) * width * (1 + failure * 0.8), sin(a) * height * grow - failure * sin(f * 17 + index) * 0.55, depth + failure * sin(f * 12 + index) * 0.85)

func _material(color: Color, glowing: bool = false, opacity: float = 1.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(color, opacity)
    material.roughness = 0.7 if not glowing else 0.4
    material.metallic = 0.22 if not glowing else 0.05
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if glowing:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 0.5
    if opacity < 1:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    return material

func _instance(parent: Node3D, mesh: Mesh, color: Color, glowing: bool = false, opacity: float = 1.0) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _material(color, glowing, opacity)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _box(parent: Node3D, size: Vector3, color: Color, glowing: bool = false) -> MeshInstance3D:
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    return _instance(parent, mesh, color, glowing)

func _rod(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius * 0.82
    mesh.bottom_radius = radius
    mesh.height = 1
    mesh.radial_segments = 8
    return _instance(parent, mesh, color)

func _cone(parent: Node3D, radius: float, height: float, color: Color) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = 0
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 5
    return _instance(parent, mesh, color, true)

func _disc(parent: Node3D, radius: float, color: Color, opacity: float) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 0.025
    mesh.radial_segments = 48
    var node: MeshInstance3D = _instance(parent, mesh, color, false, opacity)
    node.rotation.x = PI * 0.5
    return node

func _prism(parent: Node3D, sides: int, color: Color, translucent: bool) -> MeshInstance3D:
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i: int in sides:
        var a: float = i * TAU / sides
        var b: float = (i + 1) * TAU / sides
        var first: Vector3 = Vector3(cos(a), 0, sin(a))
        var second: Vector3 = Vector3(cos(b), 0, sin(b))
        for vertex: Vector3 in [Vector3.UP, first, second, Vector3.DOWN * 0.55, second, first]:
            surface.add_vertex(vertex)
    surface.generate_normals()
    return _instance(parent, surface.commit(), color, translucent, 0.48 if translucent else 1)

func _prism_frame(parent: Node3D, color: Color) -> Node3D:
    var root: Node3D = Node3D.new()
    parent.add_child(root)
    for i: int in 3:
        var a: float = i * TAU / 3
        var b: float = (i + 1) * TAU / 3
        var first: Vector3 = Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
        var second: Vector3 = Vector3(cos(b) * 0.45, 0, sin(b) * 0.45)
        for pair: Array in [[Vector3.UP * 0.85, first], [Vector3.DOWN * 0.4675, first], [first, second]]:
            _between(_rod(root, 0.012, color), pair[0], pair[1])
    return root

func _leaf(parent: Node3D, color: Color) -> MeshInstance3D:
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for vertex: Vector3 in [Vector3(-0.08, 0, -0.13), Vector3(0.08, 0, -0.13), Vector3(0.05, 0.04, 0.13), Vector3(-0.08, 0, -0.13), Vector3(0.05, 0.04, 0.13), Vector3(-0.08, 0.04, 0.13)]:
        surface.add_vertex(vertex)
    surface.generate_normals()
    return _instance(parent, surface.commit(), color)

func _shield(parent: Node3D, color: Color, ordinal: int) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "Bouclier%d" % ordinal
    parent.add_child(root)
    var edge: Array[Vector3] = [Vector3(-0.48, 0.68, 0), Vector3(0.48, 0.68, 0), Vector3(0.52, -0.22, 0), Vector3(0, -0.8, 0), Vector3(-0.52, -0.22, 0)]
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i: int in edge.size():
        for vertex: Vector3 in [Vector3(0, 0, -0.17), edge[i], edge[(i + 1) % edge.size()]]:
            surface.add_vertex(vertex)
    surface.generate_normals()
    _instance(root, surface.commit(), color)
    for i: int in edge.size():
        _between(_rod(root, 0.035, color.lightened(0.25)), edge[i], edge[(i + 1) % edge.size()])
    var spine: MeshInstance3D = _box(root, Vector3(0.055, 1.0, 0.06), color.lightened(0.4), true)
    spine.position = Vector3(0, 0.12, -0.20)
    for side: float in [-1.0, 1.0]:
        for i: int in 3:
            var glyph: MeshInstance3D = _box(root, Vector3(0.17, 0.025, 0.035), color.lightened(0.25), true)
            glyph.position = Vector3(side * 0.17, 0.34 - i * 0.21, -0.18)
            glyph.rotation.z = side * 0.38
    return root

func _joint(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = radius * 0.8
    mesh.radial_segments = 8
    return _instance(parent, mesh, color, true)

func _stone_hand(parent: Node3D, side: float, color: Color) -> Node3D:
    var root: Node3D = Node3D.new()
    parent.add_child(root)
    var stone: Color = Color("626c70").lerp(color, 0.05)
    var forearm: MeshInstance3D = _stone_block(root, Vector3(0.5, 0.75, 0.43), stone.darkened(0.17))
    forearm.position = Vector3(0, -0.45, 0.04)
    forearm.rotation.z = side * 0.06
    var palm: MeshInstance3D = _stone_block(root, Vector3(0.62, 0.57, 0.28), stone)
    palm.position.y = 0.12
    var wrist: MeshInstance3D = _box(root, Vector3(0.57, 0.08, 0.47), color, true)
    wrist.position.y = -0.18
    var fingers: Array[Node3D] = []
    for i: int in 5:
        var finger: Node3D = Node3D.new()
        root.add_child(finger)
        finger.position = Vector3(-0.23 + i * 0.15 if i < 4 else side * 0.37, 0.36 if i < 4 else 0.03, 0)
        finger.set_meta("ordinal", i)
        var length: float = (0.5 if i in [1, 2] else 0.39) if i < 4 else 0.32
        for j: int in 2:
            var segment: MeshInstance3D = _stone_block(finger, Vector3(0.12 if i < 4 else 0.17, length * 0.47, 0.23), stone.lightened(j * 0.04))
            segment.position.y = length * (0.25 + j * 0.5)
            segment.position.z = -j * 0.04
        fingers.append(finger)
    root.set_meta("fingers", fingers)
    for i: int in 3:
        var seam: MeshInstance3D = _box(root, Vector3(0.025, 0.45, 0.02), color, true)
        seam.position = Vector3(-0.17 + i * 0.17, 0.06, -0.15)
        seam.rotation.z = (i - 1) * 0.22
    for i: int in 4:
        var crack: MeshInstance3D = _box(root, Vector3(0.018, 0.17, 0.012), stone.darkened(0.55))
        crack.position = Vector3(side * (0.05 + i % 2 * 0.14), 0.20 - i * 0.09, -0.15)
        crack.rotation.z = (-0.4 if i % 2 else 0.5)
    return root

func _stone_block(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
    # Octogone extrudé : vraies arêtes chanfreinées, lisibles sous le soleil
    # comme dans le studio, sans reflet métallique sur la roche.
    var x: float = size.x * 0.5
    var y: float = size.y * 0.5
    var z: float = size.z * 0.5
    var cut: float = minf(x, z) * 0.30
    var outline: Array[Vector2] = [Vector2(-x + cut, -z), Vector2(x - cut, -z),
        Vector2(x, -z + cut), Vector2(x, z - cut), Vector2(x - cut, z),
        Vector2(-x + cut, z), Vector2(-x, z - cut), Vector2(-x, -z + cut)]
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i: int in 8:
        var a: Vector2 = outline[i]
        var b: Vector2 = outline[(i + 1) % 8]
        var top_a: Vector3 = Vector3(a.x, y, a.y)
        var top_b: Vector3 = Vector3(b.x, y, b.y)
        var bottom_a: Vector3 = Vector3(a.x, -y, a.y)
        var bottom_b: Vector3 = Vector3(b.x, -y, b.y)
        for vertex: Vector3 in [Vector3(0, y, 0), top_b, top_a,
                Vector3(0, -y, 0), bottom_a, bottom_b,
                top_a, top_b, bottom_b, top_a, bottom_b, bottom_a]:
            surface.add_vertex(vertex)
    surface.generate_normals()
    var node: MeshInstance3D = _instance(parent, surface.commit(), color)
    var material: StandardMaterial3D = node.material_override as StandardMaterial3D
    material.metallic = 0.0
    material.metallic_specular = 0.15
    material.roughness = 1.0
    return node

func _fox_echo(parent: Node3D, color: Color, ordinal: int) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "RefletRenard%d" % ordinal
    parent.add_child(root)
    var indigo: Color = Color("303657").lerp(color, 0.08)
    var body: MeshInstance3D = _prism(root, 5, indigo, false)
    body.scale = Vector3(0.17, 0.30, 0.43)
    body.position.y = 0.43
    body.rotation.x = PI * 0.5
    var head: MeshInstance3D = _prism(root, 3, Color("bac1cb"), false)
    head.scale = Vector3(0.18, 0.23, 0.14)
    head.position = Vector3(0, 0.64, -0.43)
    head.rotation.x = -PI * 0.5
    for side: float in [-1.0, 1.0]:
        var ear: MeshInstance3D = _cone(root, 0.085, 0.30, indigo)
        ear.material_override = _material(indigo)
        ear.position = Vector3(side * 0.14, 0.82, -0.38)
        ear.rotation.z = -side * 0.22
        var eye: MeshInstance3D = _box(root, Vector3(0.065, 0.025, 0.035), color, true)
        eye.position = Vector3(side * 0.09, 0.66, -0.57)
        for rear: bool in [false, true]:
            var leg: MeshInstance3D = _rod(root, 0.045, indigo)
            _between(leg, Vector3(side * 0.14, 0.4, 0.25 if rear else -0.22), Vector3(side * 0.22, 0.06, 0.4 if rear else -0.37))
    for i: int in 3:
        var tail: MeshInstance3D = _cone(root, 0.12, 0.8, indigo.lightened(i * 0.035))
        tail.material_override = _material(indigo.lightened(i * 0.035), false, 0.82)
        tail.position = Vector3((i - 1) * 0.15, 0.56, 0.62)
        tail.rotation = Vector3(1.1, 0, (i - 1) * 0.35)
    return root

func _ribbon(parent: Node3D, color: Color) -> MeshInstance3D:
    return host._ribbon(parent, color)

func _between(node: Node3D, first: Vector3, second: Vector3) -> void:
    var delta: Vector3 = second - first
    node.position = (first + second) * 0.5
    node.scale = Vector3(1, maxf(0.001, delta.length()), 1)
    var direction: Vector3 = delta.normalized()
    if direction.length_squared() > 0.01:
        node.quaternion = Quaternion(Vector3.UP, direction)
