extends Node
## Fixtures de diagnostic visibles, réutilisant la vraie scène et sa simulation.
## F2 / clic sur Suivant : scénario. -- --verify : vérification automatisée.
const Command = preload("res://core/game_command.gd")
const Session = preload("res://core/training_session.gd")
const Suite = preload("res://tests/development/test_suite.gd")
const SCENARIOS: Array[String] = ["Capture bleue", "Capture rouge", "Déviation bleue",
    "Déviation rouge", "Passe lobée ciblée", "Tacle allié", "Placement collectif"]
var _ground: Node3D
var _label: Label
var _scenario: int = 0
var _ticks: int = 0
var _observed: bool = false
var _verify: bool = false
var _failures: int = 0

func _ready() -> void:
    _ground = get_parent()
    _verify = OS.get_cmdline_user_args().has("--verify")
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.layer = 20
    add_child(canvas)
    var panel: VBoxContainer = VBoxContainer.new()
    panel.position = Vector2(390, 245)
    canvas.add_child(panel)
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 16)
    _label.add_theme_color_override("font_color", Color("ffdc8b"))
    _label.add_theme_color_override("font_shadow_color", Color.BLACK)
    _label.add_theme_constant_override("shadow_offset_x", 2)
    _label.add_theme_constant_override("shadow_offset_y", 2)
    panel.add_child(_label)
    var next: Button = Button.new()
    next.text = "Scénario suivant (F2 / pavé directionnel gauche)"
    next.pressed.connect(_next)
    panel.add_child(next)
    call_deferred("_initialize_diagnostic")

func _initialize_diagnostic() -> void:
    var report: Dictionary = Suite.new().run_all()
    print("Diagnostic : %d / %d régressions DEV réussies" % [report["passed"], report["total"]])
    _failures += int(report["failed"])
    _load_scenario()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("diagnostic_next"):
        _next()
        get_viewport().set_input_as_handled()

func _next() -> void:
    _scenario = (_scenario + 1) % SCENARIOS.size()
    _load_scenario()

func _load_scenario() -> void:
    if _ground.session == null:
        return
    var s: IEGTrainingSession = _ground.session
    var reset: IEGGameCommand = Command.new()
    reset.reset_drill = true
    s.step(reset)
    _ground.controls.cancel_charge()
    _ground.controls.pass_target_id = -1
    _ticks = 0
    _observed = false
    if _scenario < 4:
        var side: float = 1.0 if _scenario % 2 == 0 else -1.0
        s.ball.owner_id = -1
        s.ball.position = Vector3(0, 0.8, side * 15.0)
        s.ball.velocity = Vector3(0, 0, side * (12.0 if _scenario < 2 else 30.0))
    elif _scenario == 4:
        var pass_command: IEGGameCommand = Command.new()
        pass_command.pass_ball = true
        pass_command.lob_pass = true
        pass_command.pass_target_id = 8
        s.step(pass_command)
    elif _scenario == 5:
        s.get_player(8).position = Vector2(0, -4)
        s.get_player(21).position = Vector2(0, -5)
        s.ball.owner_id = 21
        var tackle: IEGGameCommand = Command.new()
        tackle.tackle = true
        s.step(Command.new(), {8: tackle})
        _observed = s.ball.owner_id == 8 and s.controlled_id == 8
    _ground._sync_views(1.0 / 60.0)
    print("Diagnostic : " + SCENARIOS[_scenario])

func _physics_process(_delta: float) -> void:
    if _ground.session == null:
        return
    var s: IEGTrainingSession = _ground.session
    _ticks += 1
    for event: Dictionary in s.events:
        var kind: int = int(event["kind"])
        var actor: int = int(event["actor_id"])
        match _scenario:
            0:
                _observed = _observed or (kind == Session.EventKind.KEEPER_CAPTURE and actor == 1 and s.controlled_id == 1)
            1:
                _observed = _observed or (kind == Session.EventKind.KEEPER_CAPTURE and actor == 31 and s.controlled().team_id == 0)
            2, 3:
                var expected_actor: int = 1 if _scenario == 2 else 31
                _observed = _observed or (kind == Session.EventKind.KEEPER_DEFLECTION and actor == expected_actor and s.ball.owner_id < 0 and s.controlled_id == 7)
    if _scenario == 4:
        _observed = _observed or s.ball.position.y > 0.95
    elif _scenario == 6 and _ticks >= 90:
        _observed = s.get_player(8).position.distance_to(s.get_player(10).position) > 6.0
    _label.text = "DIAGNOSTIC %d / %d : %s\nTick %d | possession %d | sélection %d\nBallon y=%.2f | vitesse %.2f | score %s\nRésultat attendu observé : %s" % [
        _scenario + 1, SCENARIOS.size(), SCENARIOS[_scenario], s.tick_number,
        s.ball.owner_id, s.controlled_id, s.ball.position.y, s.ball.velocity.length(),
        str(s.team_goals), "oui" if _observed else "en attente"]
    if _verify and _ticks >= 120:
        if not _observed:
            _failures += 1
            push_error("Diagnostic non validé : " + SCENARIOS[_scenario])
        if _scenario == SCENARIOS.size() - 1:
            print("Diagnostic : 7 scénarios exécutés ; %d échec(s)." % _failures)
            get_tree().quit(0 if _failures == 0 else 1)
        else:
            _next()
