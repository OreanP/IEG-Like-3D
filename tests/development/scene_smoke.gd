extends SceneTree
## Contrat réel scène/entrées/simulation. N'exige ni écran ni manette physique.
const Command = preload("res://core/game_command.gd")
const Training = preload("res://scenes/training_ground.tscn")
var _passed: int = 0
var _total: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + description)

func _run() -> void:
    var ground: Node3D = Training.instantiate()
    root.add_child(ground)
    ground.auto_pause_on_focus_loss = false
    ground.set_physics_process(false)
    await process_frame
    var controls: IEGLocalPlayerInput = ground.controls
    var camera: IEGOrbitCamera = ground.camera_rig
    var session: IEGTrainingSession = ground.session
    _check(session.players.size() == 7, "Scène assemblée : sept joueurs")
    Input.action_press("move_right", 0.6)
    var c: IEGGameCommand = controls.read_command(camera, true, session)
    _check(c.move.x > 0.0 and c.move.length() < 1.0, "Amplitude analogique de déplacement conservée")
    Input.action_release("move_right")
    Input.action_press("tackle")
    c = controls.read_command(camera, true, session)
    _check(c.tackle, "Action de tacle transmise à la simulation")
    Input.action_release("tackle")
    Input.action_press("pass_target_next")
    c = controls.read_command(camera, true, session)
    _check(c.pass_target_id == 8, "Cycle de cible transmis à la commande")
    Input.action_release("pass_target_next")
    await process_frame
    Input.action_press("lob_pass")
    c = controls.read_command(camera, true, session)
    _check(c.pass_ball and c.lob_pass and c.pass_target_id == 8, "Passe lobée ciblée transmise")
    Input.action_release("lob_pass")
    await process_frame
    Input.action_press("shoot")
    controls.read_command(camera, true, session)
    _check(controls.charge > 0.0, "Charge du tir pendant la pression")
    Input.action_release("shoot")
    c = controls.read_command(camera, true, session)
    _check(c.shoot and c.shot_charge > 0.0 and controls.charge == 0.0, "Tir au relâchement")
    Input.action_press("shoot")
    controls.read_command(camera, true, session)
    controls.cancel_charge()
    Input.action_release("shoot")
    c = controls.read_command(camera, true, session)
    _check(not c.shoot, "Annulation de charge sans tir fantôme")
    controls.set_enabled(false)
    Input.action_press("pass_ball")
    c = controls.read_command(camera, true, session)
    _check(not c.pass_ball and c.move == Vector2.ZERO, "Pause neutralise les entrées")
    Input.action_release("pass_ball")
    controls.set_enabled(true)
    session.ball.owner_id = -1
    session.ball.position = Vector3(0, 0.8, 15.0)
    session.ball.velocity = Vector3(0, 0, 12)
    ground.set_physics_process(true)
    for _tick: int in range(4):
        await physics_frame
    _check(session.ball.owner_id == 1 and session.controlled_id == 1, "Capture et sélection dans la vraie boucle physique")
    _check(ground.get_node("Players/KeeperBlue/SelectionRing").visible, "Présentation du gardien sélectionné")
    _check(ground.ball_view.position.is_equal_approx(session.ball.position), "Ballon visuel synchronisé avec la simulation")
    ground.queue_free()
    await process_frame
    print("Scène/entrées : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
