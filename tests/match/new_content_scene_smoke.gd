extends SceneTree
## Nouveaux contenus dans les vrais menus et duels. Fixtures spatiales explicites ;
## aucun vainqueur ni aucune possession de fin de duel n'est affecté directement.
const MatchScene = preload("res://scenes/full_match.tscn")
const Catalog = preload("res://core/content/technique_catalog.gd")
const Rules = preload("res://core/training_rules.gd")
var _passed: int = 0
var _total: int = 0
var ground: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + "NOUVEAUX CONTENUS SCÈNE : " + message)

func _refresh() -> void:
    ground._sync_phase()
    ground._sync_views(0)
    ground.hud.refresh(0, ground.session, ground.controls, ground._paused)

func _button_named(fragment: String) -> Button:
    for button: Button in ground.hud._duel_tech_buttons:
        if button.text.contains(fragment):
            return button
    return null

func _finish_cinematic() -> void:
    var ticks: int = 0
    while ground.session.phase == ground.session.Phase.CINEMATIC and ticks < 650:
        ground._physics_process(Rules.TICK)
        ticks += 1
    _refresh()

func _run() -> void:
    ground = MatchScene.instantiate()
    ground.auto_pause_on_focus_loss = false
    root.add_child(ground)
    ground.set_physics_process(false)
    await process_frame
    var catalog = Catalog.new("user://new_content_scene_unused.json")
    ground._catalogue = catalog
    ground.session.catalog = catalog
    ground.hud.set_catalogue(catalog.all_definitions())
    var session = ground.session
    var hud = ground.hud
    _check(catalog.all_definitions().size() == 30, "Le catalogue partagé expose les trente fiches")
    _check(session.can_use_technique(7, "seismic_strike", "TIR") and session.can_use_technique(7, "prism_ricochet", "TIR"), "Soren connaît les deux nouveaux tirs")
    _check(session.can_use_technique(1, "titan_grip", "GAR") and session.can_use_technique(1, "midnight_dial", "GAR"), "Maëlle connaît les deux nouveaux arrêts")
    _check(session.can_use_technique(8, "paper_escape", "ATT") and session.can_use_technique(8, "syncope", "ATT"), "Le n°8 connaît les deux dribbles")
    _check(session.can_use_technique(4, "bronze_rampart", "DEF") and session.can_use_technique(4, "mechanical_brambles", "DEF"), "Le n°4 connaît les deux défenses")
    _check(not session.can_use_technique(8, "ninefold_hunt", "ATT") and not session.can_use_technique(4, "antler_citadel", "DEF"), "Les signatures restent verrouillées avant invocation")
    hud.open_actions("KARMA", 8)
    hud._activate_content("KARMA", "vaelis")
    _refresh()
    _check(session.get_player(8).modifiers.get("KARMA", {}).get("id", "") == "vaelis", "Le vrai menu invoque Vaélis sur son propriétaire")
    _check(session.controlled_id == 7 and session.ball.owner_id == 7, "L'invocation n'altère ni porteur ni sélection")
    session._gain_possession(session.get_player(8))
    _refresh()
    _check(hud._karma_pg_bar.max_value == 210 and hud._modifier_bars["KARMA"].max_value == 95, "Le HUD affiche les 210 PG et 95 PE de Vaélis")
    _check(ground._views[8]._modifier_views.has("vaelis"), "Le modèle de Vaélis est présent dans la scène live")
    var attacker: IEGPlayerState = session.get_player(8)
    var defender: IEGPlayerState = session.get_player(27)
    attacker.position = Vector2.ZERO
    defender.position = Vector2(0, -1.8)
    defender.energy = 0
    attacker.possession_grace = 0
    session._duel_cooldown = 0
    _check(session.request_duel(8, 27, "field"), "Le duel de dribble démarre dans la session ordinaire")
    session.duel["ai_special"] = false
    _refresh()
    var signature: Button = _button_named("Chasse aux neuf reflets")
    _check(signature != null and not signature.disabled, "La signature ATT est proposée par le vrai menu de duel")
    var pg_before: float = attacker.modifiers["KARMA"]["pg"]
    var pe_before: float = attacker.modifiers["KARMA"]["pe"]
    var clock_before: float = session.elapsed_half
    if signature != null:
        signature.pressed.emit()
    _check(session.phase == session.Phase.CINEMATIC and ground._cinematic.active and session.duel["attack_technique"] == "ninefold_hunt", "Le bouton lance Chasse aux neuf reflets")
    _check(attacker.modifiers["KARMA"]["pg"] == pg_before - 55 and attacker.modifiers["KARMA"]["pe"] == pe_before - 10, "La signature débite ses réserves propres une seule fois")
    ground._physics_process(Rules.TICK)
    _check(session.elapsed_half == clock_before and session.ball.owner_id == 8, "Le chrono et la possession restent figés pendant la présentation")
    _finish_cinematic()
    _check(session.phase == session.Phase.LIVE and session.ball.owner_id == 8 and defender.dazed_time == 1.0, "La victoire calculée reprend le jeu et inactive le défenseur une seconde")
    _check(not ground._cinematic.active and ground.ball_view.visible, "La caméra et le ballon live sont restaurés")
    hud.open_actions("KARMA", 4)
    hud._activate_content("KARMA", "orvann")
    _refresh()
    _check(session.get_player(4).modifiers.get("KARMA", {}).get("id", "") == "orvann", "Le vrai menu invoque Orvann sur le défenseur")
    _check(ground._views[4]._modifier_views.has("orvann"), "Le modèle d'Orvann est présent dans le match")
    for state: IEGPlayerState in session.players:
        if not state.is_goalkeeper:
            state.position = Vector2(24, 0)
    var shooter: IEGPlayerState = session.get_player(27)
    var blocker: IEGPlayerState = session.get_player(4)
    shooter.position = Vector2(0, 29)
    shooter.energy = 0
    shooter.dazed_time = 0
    blocker.position = Vector2(0, 34)
    blocker.energy = 100
    session._gain_possession(shooter)
    session._duel_cooldown = 0
    session._shot_technique = ""
    session._shot_charge = 0.3
    _check(session.request_duel(27, 4, "block"), "Le tir adverse rencontre le défenseur dans un vrai duel de blocage")
    session.duel["ai_special"] = false
    _refresh()
    signature = _button_named("Citadelle des ramures")
    _check(signature != null and not signature.disabled, "La signature DEF est proposée dans le choix de blocage")
    pg_before = blocker.modifiers["KARMA"]["pg"]
    pe_before = blocker.modifiers["KARMA"]["pe"]
    if signature != null:
        signature.pressed.emit()
    _check(session.phase == session.Phase.CINEMATIC and session.duel["defend_technique"] == "antler_citadel", "Le bouton lance Citadelle des ramures en défense")
    _check(blocker.modifiers["KARMA"]["pg"] == pg_before - 65 and blocker.modifiers["KARMA"]["pe"] == pe_before - 11, "Le blocage paie les 65 PG et 11 PE prévus")
    _finish_cinematic()
    _check(session.phase == session.Phase.LIVE and session.ball.owner_id == 4 and session.controlled_id == 4, "Le blocage victorieux attribue une vraie possession et sélectionne l'allié")
    _check(not session.get_player(session.controlled_id).team_id == 1, "Aucun adversaire n'est sélectionné")
    ground._release_modifier("KARMA", 4)
    _check(not session.can_use_technique(4, "antler_citadel", "DEF"), "La dissipation retire la signature sans effacer les réserves")
    ground._open_editor()
    await process_frame
    _check(is_instance_valid(ground._editor_layer) and not ground.hud.visible, "L'atelier embarqué s'ouvre après les nouveaux duels")
    ground._close_editor()
    _check(ground.hud.visible and session.phase == session.Phase.LIVE and session.ball.owner_id == 4, "Le retour d'atelier conserve le match et sa possession")
    ground.queue_free()
    await process_frame
    print("Scène nouveaux contenus : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
