extends Node3D
## Atelier visuel autonome. Le catalogue fournit les techniques et leurs variantes.
## Les résultats d'aperçu illustrent la mise en scène ; aucun match n'est simulé ici.
## -- --verify contrôle chaque technique, les trois issues GAR et la restauration.

const Cinematic = preload("res://scripts/presentation/duel_cinematic.gd")
const PlayerScene = preload("res://scenes/characters/player_view.tscn")
const Catalog = preload("res://core/content/technique_catalog.gd")
const Arena = preload("res://scripts/match/match_arena.gd")
const VisualTheme = preload("res://scripts/presentation/visual_theme.gd")
# Ces listes publiques restent disponibles aux outils de capture, mais viennent
# du catalogue : une nouvelle fiche apparaît sans modifier cette scène.
var IDS: Array[String] = []
var NAMES: Array[String] = []
var cinematic: IEGDuelCinematic
var attacker: Node3D
var defender: Node3D
var ball: MeshInstance3D
var _camera: Camera3D
var _picker: OptionButton
var _outcome: CheckButton
var _keeper_outcome: OptionButton
var _automatic: CheckButton
var _status: Label
var _scores: Label
var _index: int = 0
var _wait: float = 0.0
var _verify: bool = false
var _checks: int = 0
var _failures: int = 0
var _verify_index: int = 0
var _verify_cases: Array[Dictionary] = []
var _baseline: Array[Transform3D] = []
var _saved_models: Array[Node3D] = []
var _restore_checked: bool = false
var _catalog: IEGTechniqueCatalog

func _ready() -> void:
    _verify = OS.get_cmdline_user_args().has("--verify")
    _catalog = Catalog.new("user://duel_preview_verify_unused.json") if _verify else Catalog.new()
    for definition: Dictionary in _catalog.all_definitions():
        var category: String = str(definition.get("category", ""))
        if category not in ["TIR", "ATT", "DEF", "GAR"]:
            continue
        IDS.append(str(definition["id"]))
        NAMES.append("%s · %s%s" % [definition["name"], category, " · signature" if definition.get("properties", {}).has("karma_id") else ""])
        _verify_cases.append({"id": str(definition["id"]), "success": true, "outcome": "capture" if category == "GAR" else ""})
    for keeper_id: String in _keeper_ids():
        for ending: String in ["deflection", "goal"]:
            _verify_cases.append({"id": keeper_id, "success": ending != "goal", "outcome": ending})
    var environment: Node3D = Arena.new()
    add_child(environment)
    attacker = PlayerScene.instantiate()
    attacker.position = Vector3(0.0, 0.0, -3.0)
    add_child(attacker)
    defender = PlayerScene.instantiate()
    defender.position = Vector3(0.0, 0.0, 3.0)
    defender.rotation.y = PI
    var profile: IEGPlayerProfile = IEGPlayerProfile.new()
    profile.kit_color = Color("d34d53")
    profile.shirt_number = 1
    defender.profile = profile
    add_child(defender)
    ball = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.17
    sphere.height = 0.34
    ball.mesh = sphere
    ball.position = Vector3(0.3, 0.17, -2.4)
    add_child(ball)
    _camera = Camera3D.new()
    add_child(_camera)
    _camera.position = Vector3(9.0, 5.0, -8.0)
    _camera.look_at(Vector3.UP)
    _camera.make_current()
    cinematic = Cinematic.new()
    add_child(cinematic)
    cinematic.reveal.connect(_show_scores)
    cinematic.finished.connect(_on_finished)
    _build_ui()
    for view: Node3D in [attacker, defender]:
        var model: Node3D = view.get_node("VisualModel")
        _saved_models.append(model)
        _baseline.append(model.transform)
    if _verify:
        _verify_keeper_prefix()
    if not IDS.is_empty():
        call_deferred("play_technique", IDS[0], true)

func _build_ui() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var panel: PanelContainer = PanelContainer.new()
    panel.theme = VisualTheme.make_theme()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -444.0
    panel.offset_right = -24.0
    panel.offset_top = 12.0
    panel.offset_bottom = 12.0
    panel.custom_minimum_size = Vector2(420.0, 0.0)
    layer.add_child(panel)
    var margin: MarginContainer = MarginContainer.new()
    for edge: String in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 14)
    panel.add_child(margin)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    margin.add_child(column)
    var title: Label = Label.new()
    title.text = "ATELIER · TECHNIQUES"
    title.add_theme_font_override("font", VisualTheme.display_font())
    title.add_theme_font_size_override("font_size", 22)
    column.add_child(title)
    var description: Label = Label.new()
    description.text = "Aperçu visuel · %d techniques du catalogue" % IDS.size()
    description.add_theme_font_size_override("font_size", 14)
    column.add_child(description)
    _picker = OptionButton.new()
    _picker.fit_to_longest_item = false
    _picker.clip_text = true
    for name_text: String in NAMES:
        _picker.add_item(name_text)
    _picker.item_selected.connect(func(index: int) -> void:
        _index = index
        _play_selection())
    column.add_child(_picker)
    var actions: HFlowContainer = HFlowContainer.new()
    column.add_child(actions)
    _outcome = CheckButton.new()
    _outcome.text = "Réussite de la technique"
    _outcome.button_pressed = true
    _outcome.toggled.connect(func(_value: bool) -> void: _play_selection())
    actions.add_child(_outcome)
    _keeper_outcome = OptionButton.new()
    _keeper_outcome.name = "KeeperOutcome"
    for label: String in ["GAR · Capture", "GAR · Déviation", "GAR · Échec"]:
        _keeper_outcome.add_item(label)
    _keeper_outcome.item_selected.connect(func(_index_selected: int) -> void: _play_selection())
    actions.add_child(_keeper_outcome)
    var replay: Button = Button.new()
    replay.text = "Rejouer · A"
    replay.pressed.connect(_play_selection)
    actions.add_child(replay)
    _automatic = CheckButton.new()
    _automatic.text = "Parcourir les techniques automatiquement"
    _automatic.button_pressed = _verify
    column.add_child(_automatic)
    _status = Label.new()
    _status.text = "Préparation"
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_status)
    _scores = Label.new()
    _scores.anchor_left = 0.5
    _scores.anchor_right = 0.5
    _scores.anchor_top = 1.0
    _scores.anchor_bottom = 1.0
    _scores.offset_left = -300.0
    _scores.offset_right = 300.0
    _scores.offset_top = -150.0
    _scores.offset_bottom = -32.0
    _scores.custom_minimum_size = Vector2(600.0, 110.0)
    _scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _scores.add_theme_font_size_override("font_size", 32)
    _scores.add_theme_font_override("font", VisualTheme.display_font())
    _scores.add_theme_color_override("font_color", Color("fff2ba"))
    _scores.add_theme_color_override("font_shadow_color", Color.BLACK)
    _scores.add_theme_constant_override("shadow_offset_x", 3)
    _scores.add_theme_constant_override("shadow_offset_y", 3)
    layer.add_child(_scores)
    replay.grab_focus()

func _play_selection() -> void:
    if IDS.is_empty():
        return
    var category: String = str(_catalog.get_definition(IDS[_index]).get("category", ""))
    var ending: String = ["capture", "deflection", "goal"][_keeper_outcome.selected] if category == "GAR" else ""
    play_technique(IDS[_index], ending != "goal" if category == "GAR" else _outcome.button_pressed, ending)

func play_technique(id: String, success: bool = true, outcome: String = "") -> void:
    var selected_index: int = IDS.find(id)
    if selected_index >= 0:
        _index = selected_index
        _picker.select(selected_index)
    var definition: Dictionary = _catalog.get_definition(id)
    if definition.is_empty():
        return
    var category: String = str(definition.get("category", ""))
    var properties: Dictionary = definition.get("properties", {})
    var ending: String = outcome if outcome in ["capture", "deflection", "goal"] else ("capture" if success else "goal")
    if category == "GAR":
        success = ending != "goal"
        _keeper_outcome.select(["capture", "deflection", "goal"].find(ending))
    _outcome.set_pressed_no_signal(success)
    _outcome.visible = category != "GAR"
    _keeper_outcome.visible = category == "GAR"
    var is_defender: bool = category in ["DEF", "GAR"]
    var is_keeper: bool = category in ["TIR", "GAR"]
    var is_block: bool = category == "DEF" and bool(properties.get("block", false))
    var attacker_won: bool = not success if is_defender else success
    var resolved_outcome: String = "dribble" if attacker_won else "tackle"
    if is_keeper:
        resolved_outcome = ending if category == "GAR" else ("goal" if attacker_won else "capture")
    elif is_block:
        resolved_outcome = "shot_continues" if attacker_won else "block"
    var timing: Dictionary = Catalog.cinematic_timing({} if is_defender else definition, definition if is_defender else {})
    _scores.text = ""
    _wait = 0.0
    _restore_checked = false
    var result: Dictionary = {"kind": "keeper" if is_keeper else ("block" if is_block else "field"), "actor_id": 7, "target_id": 1,
        "attack_choice": "special" if not is_defender else "left",
        "defend_choice": "special" if is_defender else "right",
        "attack_technique": "" if is_defender else id, "defend_technique": id if is_defender else "",
        "attack_score": 145 if attacker_won else 112, "defend_score": (119 if resolved_outcome == "deflection" else 145) if not attacker_won else 112,
        "winner_id": 7 if attacker_won else 1, "attacker_won": attacker_won,
        "outcome": resolved_outcome, "result": "parry" if resolved_outcome == "deflection" else resolved_outcome,
        "duration": timing["duration"], "reveal_time": timing["reveal_time"],
        "techniques": _catalog.all_definitions()}
    cinematic.begin(result, attacker, defender, ball)
    _status.text = "Charge · %s · le temps du match est suspendu" % str(definition.get("name", id))

func _process(delta: float) -> void:
    if cinematic == null or IDS.is_empty():
        return
    if cinematic.active:
        cinematic.advance(0.10 if _verify else delta)
        return
    _wait += delta
    if _verify and not _restore_checked:
        _restore_checked = true
        _check(not cinematic.active, "durée finie")
        _check(ball.visible, "ballon original restauré")
        _check(get_viewport().get_camera_3d() == _camera, "caméra précédente restaurée")
        for i: int in _saved_models.size():
            _check(_saved_models[i].transform.is_equal_approx(_baseline[i]), "transform modèle restaurée")
        _verify_index += 1
        if _verify_index >= _verify_cases.size():
            print("Duel preview: %d contrôles, %d échecs / %d techniques, %d séquences, 3 issues par GAR" % [_checks, _failures, IDS.size(), _verify_cases.size()])
            get_tree().quit(0 if _failures == 0 else 1)
            return
        var next_case: Dictionary = _verify_cases[_verify_index]
        play_technique(str(next_case["id"]), bool(next_case["success"]), str(next_case["outcome"]))
    elif not _verify and _automatic.button_pressed and _wait >= 0.75:
        _index = (_index + 1) % IDS.size()
        _picker.select(_index)
        _play_selection()

func _show_scores() -> void:
    var ending: String = str(cinematic.duel_data.get("outcome", ""))
    var verdict: String = "ATTAQUE RÉUSSIE" if bool(cinematic.duel_data.attacker_won) else "DÉFENSE RÉUSSIE"
    if str(_catalog.get_definition(IDS[_index]).get("category", "")) == "GAR":
        verdict = {"capture": "CAPTURE · POSSESSION", "deflection": "DÉVIATION · BALLON LIBRE", "goal": "ÉCHEC · BUT"}.get(ending, verdict)
    _scores.text = "%d    CONTRE    %d\n%s" % [int(cinematic.duel_data.attack_score), int(cinematic.duel_data.defend_score), verdict]
    _status.text = "Résultat révélé · reprise après la réaction"
    if _verify:
        _check(cinematic.revealed and cinematic.elapsed >= cinematic.reveal_time, "scores au point de révélation")

func _on_finished() -> void:
    _status.text = "Terminé · les modèles et la caméra sont restaurés"
    _wait = 0.0

func _check(condition: bool, label: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error("Duel preview: " + label)

func _verify_keeper_prefix() -> void:
    for id: String in _keeper_ids():
        var reference: Array = []
        for ending: String in ["capture", "deflection", "goal"]:
            play_technique(id, ending != "goal", ending)
            cinematic.advance(minf(1.0, cinematic.reveal_time * 0.45))
            var snapshot: Array = []
            _snapshot(cinematic, snapshot)
            for model: Node3D in _saved_models:
                _snapshot(model, snapshot)
            if ending == "capture":
                reference = snapshot
            else:
                _check(reference == snapshot, "GAR : début identique avant révélation pour %s / %s" % [id, ending])
            cinematic.stop()

func _keeper_ids() -> Array[String]:
    var result: Array[String] = []
    for id: String in IDS:
        if _catalog.get_definition(id).get("category", "") == "GAR":
            result.append(id)
    return result

func _snapshot(node: Node, result: Array) -> void:
    if node is Node3D:
        result.append(node.transform)
    if node is Skeleton3D:
        for index: int in node.get_bone_count():
            result.append(node.get_bone_pose_rotation(index))
    for child: Node in node.get_children():
        _snapshot(child, result)
