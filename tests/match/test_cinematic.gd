extends RefCounted
## Contrats de présentation réutilisables par la suite native, sans scène d'atelier.
## Exécuter run_all() une fois le SceneTree prêt, comme les autres tests de scène.
const ModifierVisual = preload("res://scripts/presentation/modifier_visual.gd")
const Catalog = preload("res://core/content/technique_catalog.gd")
const Preview = preload("res://scripts/editor/technique_preview.gd")
const Cinematic = preload("res://scripts/presentation/duel_cinematic.gd")
const PlayerScene = preload("res://scenes/characters/player_view.tscn")
const Match = preload("res://core/match/match_session.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")
const IDS: Array[String] = ["orbital_shot", "magnus_shot", "combat_blade", "drift",
    "hurricane_barrier", "aquablast", "photo_stop", "gyroscopic_stop", "perihelion_hammer", "abyssal_cathedral",
    "seismic_strike", "prism_ricochet", "paper_escape", "syncope", "bronze_rampart",
    "mechanical_brambles", "titan_grip", "midnight_dial", "ninefold_hunt", "antler_citadel"]
var _total: int = 0
var _passed: int = 0
var _lines: Array[String] = []
var _reveals: int = 0
var _finishes: int = 0

func run_all() -> Dictionary:
    _total = 0
    _passed = 0
    _lines.clear()
    var context: Dictionary = _fixture()
    if not context.viewport.is_inside_tree():
        _check(false, "SceneTree prêt requis pour tester caméra et poses")
        context.viewport.free()
        return _report()
    for id: String in IDS:
        _technique_lifecycle(context, id)
    for id: String in ["photo_stop", "gyroscopic_stop", "abyssal_cathedral", "titan_grip", "midnight_dial"]:
        _keeper_branches(context, id)
    _catalogue_overrides(context)
    _new_effect_clones(context)
    _cancellation(context)
    _shot_block(context)
    _simulation_contracts()
    _modifier_presentation(context)
    context.viewport.queue_free()
    return _report()

func _fixture() -> Dictionary:
    var viewport: SubViewport = SubViewport.new()
    viewport.size = Vector2i(640, 400)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    var root: Node3D = Node3D.new()
    viewport.add_child(root)
    (Engine.get_main_loop() as SceneTree).root.add_child(viewport)
    var attacker: Node3D = PlayerScene.instantiate()
    attacker.position = Vector3(0, 0, -3)
    root.add_child(attacker)
    var defender: Node3D = PlayerScene.instantiate()
    defender.position = Vector3(0, 0, 3)
    defender.rotation.y = PI
    root.add_child(defender)
    var ball: Node3D = Node3D.new()
    ball.position = Vector3(0.3, 0.17, -2.4)
    root.add_child(ball)
    var camera: Camera3D = Camera3D.new()
    root.add_child(camera)
    camera.make_current()
    var cinematic: IEGDuelCinematic = Cinematic.new()
    root.add_child(cinematic)
    cinematic.reveal.connect(func(): _reveals += 1)
    cinematic.finished.connect(func(): _finishes += 1)
    return {"viewport": viewport, "root": root, "attacker": attacker,
        "defender": defender, "ball": ball, "camera": camera, "cinematic": cinematic}

func _result(id: String, outcome: String = "") -> Dictionary:
    var catalog: IEGTechniqueCatalog = Catalog.new("user://test_cinematic_definitions_unused_%d.json" % OS.get_process_id())
    var category: String = str(catalog.get_definition(id).get("category", ""))
    var defending: bool = category in ["DEF", "GAR"]
    var keeper: bool = category in ["TIR", "GAR"]
    var attack_won: bool = not defending
    if outcome in ["capture", "deflection"]:
        attack_won = false
    elif outcome in ["goal", "dribble"]:
        attack_won = true
    return {"kind": "keeper" if keeper else "field", "actor_id": 7, "target_id": 21,
        "attack_choice": "left" if defending else "special",
        "defend_choice": "special" if defending else "right",
        "attack_technique": "" if defending else id, "defend_technique": id if defending else "",
        "attack_score": 140 if attack_won else 110, "defend_score": 110 if attack_won else 140,
        "winner_id": 7 if attack_won else 21, "attacker_won": attack_won,
        "duration": 3.2, "reveal_time": 1.4, "techniques": catalog.all_definitions(),
        "outcome": outcome if not outcome.is_empty() else ("capture" if defending and keeper else "dribble")}

func _begin(context: Dictionary, result: Dictionary) -> void:
    context.cinematic.begin(result, context.attacker, context.defender, context.ball)

func _technique_lifecycle(context: Dictionary, id: String) -> void:
    var cinematic: IEGDuelCinematic = context.cinematic
    _reveals = 0
    _finishes = 0
    var before: Array = _actors_snapshot(context)
    var roots: Array = [context.attacker.transform, context.defender.transform, context.ball.transform]
    _begin(context, _result(id))
    _check(cinematic.active and not context.ball.visible
        and context.viewport.get_camera_3d() != context.camera, id + " : caméra cinéma et ballon doublure")
    cinematic.advance(1.0)
    _check(_actors_snapshot(context) != before and roots == [context.attacker.transform,
        context.defender.transform, context.ball.transform], id + " : animation visuelle sans déplacer les racines de jeu")
    _check(_reveals == 0 and not cinematic.revealed, id + " : aucun résultat révélé pendant la préparation")
    cinematic.advance(0.41)
    _check(_reveals == 1 and cinematic.revealed and cinematic.active,
        id + " : révélation unique suivie de la réaction")
    for _tick: int in 30:
        cinematic.advance(0.1)
    _check(_finishes == 1 and not cinematic.active, id + " : durée finie et fin émise une seule fois")
    _check(_actors_snapshot(context) == before and context.ball.visible
        and context.viewport.get_camera_3d() == context.camera,
        id + " : modèles, os, matériaux, décorations, animations, ballon et caméra restaurés")

func _keeper_branches(context: Dictionary, id: String) -> void:
    var cinematic: IEGDuelCinematic = context.cinematic
    _begin(context, _result(id, "capture"))
    cinematic.advance(1.0)
    var capture_prefix: Array = _full_snapshot(context)
    cinematic.stop()
    _begin(context, _result(id, "goal"))
    cinematic.advance(1.0)
    var goal_prefix: Array = _full_snapshot(context)
    cinematic.stop()
    _begin(context, _result(id, "deflection"))
    cinematic.advance(1.0)
    _check(_full_snapshot(context) == capture_prefix and goal_prefix == capture_prefix,
        id + " : préparation strictement identique pour capture, déviation et échec")
    cinematic.advance(1.5)
    var parry_ball: Vector3 = _cinema_ball(cinematic).position
    var parry_pose: Array = _full_snapshot(context)
    cinematic.stop()
    _begin(context, _result(id, "capture"))
    cinematic.advance(2.5)
    var held_ball: Vector3 = _cinema_ball(cinematic).position
    var held_pose: Array = _full_snapshot(context)
    cinematic.stop()
    _begin(context, _result(id, "goal"))
    cinematic.advance(2.5)
    var goal_ball: Vector3 = _cinema_ball(cinematic).position
    _check(_full_snapshot(context) != held_pose and parry_pose != held_pose,
        id + " : trois réactions distinctes après les scores")
    _check(parry_ball.x - held_ball.x > 1.0 and parry_ball.z < held_ball.z - 1.0,
        id + " : une déviation éloigne la balle des mains vers le terrain")
    _check(goal_ball.z > held_ball.z + 1.0, id + " : l'échec laisse la balle dépasser le gardien")
    cinematic.stop()

func _catalogue_overrides(context: Dictionary) -> void:
    var cinematic: IEGDuelCinematic = context.cinematic
    var definition: Dictionary = {"id": "orbital_shot", "effect": "aqua", "color": "#f01090", "power": 90.0}
    var result: Dictionary = _result("orbital_shot")
    result.techniques = [definition]
    _begin(context, result)
    cinematic.advance(0.8)
    var effect: Dictionary = cinematic.get("_fx")[0]
    _check(effect.id == "aquablast", "catalogue : famille d'effet éditée appliquée au vrai duel")
    var material: StandardMaterial3D = effect.pieces[0].material_override
    _check(material.albedo_color.is_equal_approx(Color("#f01090", 0.8)),
        "catalogue : couleur éditée appliquée au matériau du duel")
    var large_scale: Vector3 = effect.root.scale
    cinematic.stop()
    definition.power = 0.0
    result.techniques = [definition]
    _begin(context, result)
    var small: Dictionary = cinematic.get("_fx")[0]
    _check(large_scale.length() > small.root.scale.length(),
        "catalogue : puissance reflétée dans l'intensité visuelle sans calcul de résultat")
    _check(cinematic.duel_data.attack_score == result.attack_score and cinematic.duel_data.winner_id == result.winner_id,
        "catalogue : les scores fournis restent l'autorité du résultat")
    cinematic.stop()

func _cancellation(context: Dictionary) -> void:
    var cinematic: IEGDuelCinematic = context.cinematic
    var before: Array = _actors_snapshot(context)
    _begin(context, _result("drift"))
    cinematic.advance(0.5)
    cinematic.stop()
    cinematic.stop()
    _check(_actors_snapshot(context) == before and context.ball.visible
        and context.viewport.get_camera_3d() == context.camera, "annulation anticipée et stop répété restaurent les vues")
    _begin(context, _result("photo_stop", "capture"))
    var source: Dictionary = _result("orbital_shot", "goal")
    _begin(context, source)
    source.attacker_won = false
    _check(cinematic.active and cinematic.duel_data.attacker_won,
        "nouveau duel remplace proprement l'ancien et conserve sa copie du résultat")
    cinematic.stop()

func _simulation_contracts() -> void:
    var roster: Dictionary = Roster.build()
    var session: IEGMatchSession = Match.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    var shooter: IEGPlayerState = session.get_player(27)
    var keeper: IEGPlayerState = session.get_player(1)
    shooter.position = Vector2(0, 31)
    keeper.keeper_stamina = 50.0
    session.ball.owner_id = 27
    session._duel_cooldown = 0.0
    session._follow_owner()
    var requested: bool = session.request_duel(27, 1, "keeper")
    _check(requested, "simulation : duel tireur/gardien réel initialisé")
    if not requested:
        return
    session.duel.ai_choice = "left"
    session.duel.ai_special = false
    session.choose_duel("left") # marge étroite : déviation, sans technique spéciale.
    _check(session.duel.outcome == "deflection", "simulation : victoire étroite du gardien produit une déviation")
    var clock: float = session.elapsed_half
    var position: Vector2 = shooter.position
    var ball_position: Vector3 = session.ball.position
    for _tick: int in 191:
        session.step(Command.new())
    _check(session.phase == Match.Phase.CINEMATIC and session.elapsed_half == clock
        and shooter.position == position and session.ball.position == ball_position and session.ball.owner_id == 27,
        "simulation : monde et chrono gelés jusqu'au dernier tick cinématique")
    var selected: int = session.controlled_id
    session.step(Command.new())
    _check(session.phase == Match.Phase.LIVE and session.duel.applied
        and session.ball.owner_id == -1 and session.controlled_id == selected,
        "simulation : déviation appliquée à la fin sans possession ni nouvelle sélection")

func _shot_block(context: Dictionary) -> void:
    var result: Dictionary = _result("orbital_shot", "goal")
    result.kind = "block"
    result.outcome = "shot_continues"
    result.defend_technique = "hurricane_barrier"
    _begin(context, result)
    context.cinematic.advance(2.5)
    var through: Vector3 = _cinema_ball(context.cinematic).position
    var shooter: Vector3 = context.cinematic.get("_actors")[0].model.global_position
    _check(through.z > 3.0, "blocage de tir : une attaque gagnante traverse la barrière")
    context.cinematic.stop()
    result.outcome = "block"
    result.attacker_won = false
    _begin(context, result)
    context.cinematic.advance(2.5)
    var blocked: Vector3 = _cinema_ball(context.cinematic).position
    _check(blocked.z < 1.5 and blocked.y < 0.7,
        "blocage de tir : une défense gagnante contrôle le ballon au sol")
    _check(context.cinematic.get("_actors")[0].model.global_position.is_equal_approx(shooter),
        "blocage de tir : le tireur ne simule pas un dribble à travers le défenseur")
    context.cinematic.stop()

func _cinema_ball(cinematic: Node) -> Node3D:
    return cinematic.find_child("CinematicBall", true, false) as Node3D

func _actors_snapshot(context: Dictionary) -> Array:
    var result: Array = []
    _snapshot(context.attacker, result)
    _snapshot(context.defender, result)
    return result

func _full_snapshot(context: Dictionary) -> Array:
    var result: Array = _actors_snapshot(context)
    _snapshot(context.cinematic, result, false)
    return result

func _snapshot(node: Node, result: Array, resource_identity: bool = true) -> void:
    if node is Node3D:
        result.append(node.transform)
        result.append(node.visible)
    if node is Skeleton3D:
        for index: int in node.get_bone_count():
            result.append(node.get_bone_pose(index))
    if node is MeshInstance3D:
        if resource_identity:
            result.append(node.material_override)
        elif node.material_override is StandardMaterial3D:
            result.append(node.material_override.albedo_color)
    if node is AnimationPlayer:
        result.append(node.active)
    for child: Node in node.get_children():
        _snapshot(child, result, resource_identity)

func _check(condition: bool, text: String) -> void:
    _total += 1
    _passed += 1 if condition else 0
    _lines.append(("OK   " if condition else "ÉCHEC   ") + "CINÉMATIQUE : " + text)

func _report() -> Dictionary:
    return {"total": _total, "passed": _passed, "failed": _total - _passed, "lines": _lines.duplicate()}

func _modifier_presentation(context: Dictionary) -> void:
    var catalog: IEGTechniqueCatalog = Catalog.new("user://cinematic_catalogue_unused.json")
    for id: String in ["astreion", "thalassa", "vaelis", "orvann", "sovereign_orbit", "deep_watch"]:
        var visual: Node3D = ModifierVisual.new()
        context.root.add_child(visual)
        var definition: Dictionary = catalog.get_definition(id)
        var before: Dictionary = definition.duplicate(true)
        visual.configure(definition)
        visual.set_presentation(1.0)
        var pose: Array = []
        _snapshot(visual, pose, false)
        visual.set_presentation(1.0)
        var same_pose: Array = []
        _snapshot(visual, same_pose, false)
        _check(visual.style == id and visual.find_children("*", "MeshInstance3D", true, false).size() >= 5,
            id + " : forme originale en géométrie 3D réelle")
        _check(pose == same_pose and definition == before, id + " : pose déterministe et définition préservée")
        visual.set_presentation(2.0)
        var animated: Array = []
        _snapshot(visual, animated, false)
        _check(animated != pose, id + " : orbites, flux ou corps animés")
        visual.queue_free()
    var palette: Node3D = ModifierVisual.new()
    context.root.add_child(palette)
    var palette_definition: Dictionary = catalog.get_definition("astreion")
    palette_definition.properties.appearance.primary = "#133355"
    palette_definition.properties.appearance.accent = "#f02090"
    palette.configure(palette_definition)
    var body: Node3D = palette.get("_body")
    _check(body.get_child(0).material_override.albedo_color.is_equal_approx(Color("#133355"))
        and palette.get("_core").material_override.albedo_color.is_equal_approx(Color("#f02090")),
        "atelier : palettes primary et accent appliquées réellement aux matériaux 3D")
    palette.configure({"id": "custom_style", "category": "KARMA", "color": "#ffffff", "properties": {"appearance": {"style": "unknown"}}})
    _check(palette.find_children("*", "MeshInstance3D", true, false).size() >= 3,
        "style personnalisé inconnu : aura de repli visible au lieu d'un aperçu vide")
    palette.queue_free()
    var view: IEGPlayerView = context.attacker
    var actor_before: Array = _actors_snapshot(context)
    var definitions: Array[Dictionary] = [catalog.get_definition("astreion"), catalog.get_definition("deep_watch")]
    view.sync_modifier_visuals(definitions, 0.25)
    _check(view.get("_modifier_views").size() == 2, "cumul : Karma et Résonance visibles sur le même joueur")
    var frozen: Array = []
    _snapshot(view, frozen)
    view.sync_modifier_visuals(definitions, 0.0)
    var frozen_after: Array = []
    _snapshot(view, frozen_after)
    _check(frozen == frozen_after, "pause : delta nul conserve toutes les poses de transformation")
    var edited: Array[Dictionary] = definitions.duplicate(true)
    edited[0].color = "#ee3377"
    view.sync_modifier_visuals(edited, 0.0)
    _check(view.get("_modifier_views")["astreion"].definition.color == "#ee3377",
        "atelier : changement de couleur répercuté sur le Karma déjà actif")
    view.sync_modifier_visuals([], 0.0)
    _check(view.get("_modifier_views").is_empty() and _actors_snapshot(context) == actor_before,
        "fin des transformations : accessoires retirés, modèle et matériaux originaux intacts")
    _invocation_time_origin(view, catalog)
    var preview: SubViewportContainer = Preview.new()
    context.viewport.add_child(preview)
    preview.set_process(false)
    for id: String in ["astreion", "thalassa", "vaelis", "orvann", "sovereign_orbit", "deep_watch", "perihelion_hammer", "abyssal_cathedral", "ninefold_hunt", "antler_citadel"]:
        preview.set_definition(catalog.get_definition(id))
        preview.set_outcome("deflection")
        preview._process(1.0)
        _check(preview.get("_modifier").visible and preview.get("_modifier").find_child("SpiritBody", true, false) != null
            if id in ["astreion", "thalassa", "vaelis", "orvann", "perihelion_hammer", "abyssal_cathedral", "ninefold_hunt", "antler_citadel"] else preview.get("_modifier").visible,
            id + " : aperçu atelier rendu et sélection de l'issue disponibles")
    preview.queue_free()

func _invocation_time_origin(view: IEGPlayerView, catalog: IEGTechniqueCatalog) -> void:
    view.sync_modifier_visuals([], 42.0)
    var entries: Array[Dictionary] = [catalog.get_definition("vaelis")]
    view.sync_modifier_visuals(entries, 0.0)
    var spirit: Node3D = view._modifier_views["vaelis"]
    _check(is_zero_approx(float(spirit._time)), "invocation tardive : Vaélis commence à zéro après 42 secondes sans aura")
    view.sync_modifier_visuals(entries, 0.3)
    var elapsed: float = float(spirit._time)
    view.sync_modifier_visuals(entries, 0.0)
    _check(is_equal_approx(elapsed, 0.3) and is_equal_approx(float(spirit._time), elapsed),
        "invocation : le delta avance la présentation et une pause conserve son temps")
    entries[0].properties.appearance.height = 4.3
    entries[0].properties.appearance.primary = "#243865"
    view.sync_modifier_visuals(entries, 0.0)
    _check(is_equal_approx(float(spirit._time), elapsed), "édition d'une invocation active : palette et hauteur ne rembobinent pas son animation")
    view.sync_modifier_visuals([], 0.0)
    view.sync_modifier_visuals(entries, 0.2)
    _check(is_zero_approx(float(view._modifier_views["vaelis"]._time)), "réinvocation : un nouveau cycle visuel commence à zéro")
    view.sync_modifier_visuals([], 0.0)

func _new_effect_clones(context: Dictionary) -> void:
    var catalog: IEGTechniqueCatalog = Catalog.new("user://test_cinematic_clone_unused_%d.json" % OS.get_process_id())
    for id: String in ["seismic_strike", "prism_ricochet", "paper_escape", "syncope", "bronze_rampart", "mechanical_brambles", "titan_grip", "midnight_dial", "ninefold_hunt", "antler_citadel"]:
        var cloned: Dictionary = catalog.get_definition(id)
        cloned.id = id + "_copy"
        cloned.color = "#e63f92"
        var result: Dictionary = _result(id)
        var defending: bool = cloned.category in ["DEF", "GAR"]
        result["defend_technique" if defending else "attack_technique"] = cloned.id
        result.techniques.append(cloned)
        _begin(context, result)
        var effects: Array = context.cinematic._fx
        var resolved: bool = not effects.is_empty() and effects[0].id == id and effects[0].technique_id == cloned.id
        _check(resolved, id + " : une copie personnalisée retrouve sa chorégraphie par effect")
        _check(resolved and effects[0].color.is_equal_approx(Color("#e63f92"))
            and _contains_color(effects[0].root, Color("#e63f92")),
            id + " : la couleur éditée de la copie apparaît dans les matériaux du vrai duel")
        context.cinematic.stop()

func _contains_color(node: Node, color: Color) -> bool:
    if node is MeshInstance3D:
        var material: Material = node.material_override
        if material is StandardMaterial3D:
            var actual: Color = material.albedo_color
            if is_equal_approx(actual.r, color.r) and is_equal_approx(actual.g, color.g) and is_equal_approx(actual.b, color.b):
                return true
    for child: Node in node.get_children():
        if _contains_color(child, color):
            return true
    return false
