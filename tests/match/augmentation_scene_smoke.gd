extends SceneTree
## Parcours des vrais menus et des nouvelles transformations dans la scène Godot.
const MatchScene = preload("res://scenes/full_match.tscn")
const Catalog = preload("res://core/content/technique_catalog.gd")
const Session = preload("res://core/match/match_session.gd")
const Roster = preload("res://scripts/match/match_roster.gd")
const Rules = preload("res://core/training_rules.gd")
var _passed: int = 0
var _total: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    _total += 1
    _passed += 1 if ok else 0
    print(("OK " if ok else "ÉCHEC ") + "SCÈNE AUGMENTATIONS : " + description)

func _refresh(ground: Node3D) -> void:
    ground._sync_phase()
    ground._sync_views(0.0)
    ground.hud.refresh(0.0, ground.session, ground.controls, ground._paused)

func _ids(entries: Array[Dictionary]) -> PackedStringArray:
    var ids: PackedStringArray = []
    for entry: Dictionary in entries:
        ids.append(str(entry["id"]))
    return ids

func _run() -> void:
    var ground: Node3D = MatchScene.instantiate()
    ground.auto_pause_on_focus_loss = false
    root.add_child(ground)
    ground.set_physics_process(false)
    await process_frame
    # Les sauvegardes du joueur ne sont ni lues pour les règles testées ni modifiées.
    var catalog = Catalog.new("user://augmentation_scene_unused.json")
    ground._catalogue = catalog
    ground.session.catalog = catalog
    ground.hud.set_catalogue(catalog.all_definitions())
    var session = ground.session
    var hud = ground.hud
    _check(session.get_player(7).profile.display_name == "Soren Vale" and session.get_player(1).profile.display_name == "Maëlle Néris", "Les deux donneurs sont présents dans le roster 11v11")
    _check(not session.can_use_technique(7, "perihelion_hammer", "TIR"), "La signature ne peut pas être utilisée sans invocation")
    hud.open_actions("KARMA", 7)
    _check(_ids(hud._for_category("KARMA")).has("astreion"), "Astreion est proposé à son propriétaire")
    hud._activate_content("KARMA", "astreion")
    _refresh(ground)
    _check(session.get_player(7).modifiers.get("KARMA", {}).get("id", "") == "astreion", "Le vrai menu invoque Astreion")
    _check(hud._karma_pg_bar.visible and hud._karma_pg_bar.max_value == 240 and hud._karma_pg_bar.value == 240 and hud._modifier_bars["KARMA"].max_value == 80, "PG et PE du Karma affichés séparément avec les bons maxima")
    _check(session.can_use_technique(7, "perihelion_hammer", "TIR"), "L'invocation débloque sa technique propre")
    _check(not _ids(session.get_available_techniques(10, "ATT")).has("drift"), "Le receveur ne connaît pas Drift avant la Résonance")
    hud.open_actions("RESONANCE", 10)
    hud._activate_content("RESONANCE", "sovereign_orbit")
    _refresh(ground)
    var resonance: Dictionary = session.get_player(10).modifiers.get("RESONANCE", {})
    _check(resonance.get("partner_id", -1) == 7 and session.controlled_id == 7 and session.ball.owner_id == 7, "La Résonance choisit Soren sans changer porteur ni sélection")
    _check(_ids(session.get_available_techniques(10, "ATT")).has("drift") and _ids(session.get_available_techniques(10, "TIR")).has("magnus_shot"), "Les deux techniques héritées deviennent réellement accessibles")
    var bonuses: Dictionary = session.get_stat_bonuses(10)
    _check(bonuses.get("shot", 0) == 18 and bonuses.get("dribble", 0) == 16 and bonuses.get("technique", 0) == 17, "Les statistiques de base du donneur produisent les trois bonus attendus")
    hud.open_actions("KARMA", 10)
    _check(_ids(hud._for_category("KARMA")).has("astreion"), "Le Karma du donneur est proposé au receveur")
    hud._activate_content("KARMA", "astreion")
    _refresh(ground)
    _check(session.count_active_modifiers(0, "KARMA") == 2 and session.count_active_modifiers(0, "RESONANCE") == 1, "Le Karma hérité occupe sa propre place dans le quota de trois")
    hud.open_actions("KARMA", 1)
    hud._activate_content("KARMA", "thalassa")
    _refresh(ground)
    _check(session.get_player(1).modifiers.get("KARMA", {}).get("id", "") == "thalassa" and session.controlled_id == 7, "Thalassa peut être invoquée sur la gardienne sans déplacer la sélection")
    _check(session.count_active_modifiers(0, "KARMA") == 3 and session.get_player(1).modifiers["KARMA"]["pg"] == 300, "Les trois places de Karma sont utilisées avec des réserves distinctes")
    hud.open_actions("RESONANCE", 10)
    hud._cycle_receiver("RESONANCE", 1)
    _check(hud._action_player_id == 11 and session.controlled_id == 7 and session.ball.owner_id == 7, "Les boutons de choix du receveur préservent la sélection et la possession")
    session._gain_possession(session.get_player(10))
    _refresh(ground)
    _check(hud._inherited_label.visible and hud._inherited_label.text.contains("Drift") and hud._inherited_label.text.contains("Magnus") and hud._karma_pg_bar.visible, "Le porteur cumulé voit ses PG, PE et deux techniques héritées")
    _check(hud._stat_label.visible and hud._stat_label.text.contains("Technique +17"), "Les bonus du porteur sont lisibles dans le HUD")
    var reserves: Dictionary = session.get_player(10).karma_reserves["astreion"].duplicate(true)
    ground._release_modifier("RESONANCE", 10)
    _refresh(ground)
    _check(not session.get_player(10).modifiers.has("RESONANCE") and not session.get_player(10).modifiers.has("KARMA"), "Dissiper la Résonance retire aussi son Karma hérité")
    _check(session.get_player(10).karma_reserves["astreion"] == reserves and not hud._inherited_label.visible, "La dissipation conserve les réserves et nettoie l'affichage")

    # Même tir entre blocage et gardien, avec PE épuisés lors du premier duel.
    var roster: Dictionary = Roster.build()
    session = Session.new(roster.profiles, roster.starts, roster.teams, roster.keepers)
    session.catalog = catalog
    ground.session = session
    ground._observed_phase = -1
    _refresh(ground)
    session.activate_modifier(7, "astreion")
    session.get_player(7).modifiers["KARMA"]["pe"] = 12.0
    session.get_player(7).position = Vector2(0, -25)
    session.get_player(27).position = Vector2(0, -30)
    session.get_player(27).energy = 0.0
    for state: IEGPlayerState in session.players:
        if state.team_id == 1 and state.get_id() not in [21, 27]:
            state.position.x = 20.0
    session._shot_technique = "perihelion_hammer"
    session._shot_charge = 1.0
    session._duel_cooldown = 0.0
    session.request_duel(7, 27, "block")
    session.duel["ai_special"] = false
    session.choose_duel("special", "perihelion_hammer")
    _check(session.duel.get("outcome", "") == "shot_continues" and not session.get_player(7).modifiers.has("KARMA"), "Le Marteau traverse le blocage en épuisant ses PE")
    session._finish_duel()
    _refresh(ground)
    var prepaid_present: bool = false
    var prepaid_enabled: bool = false
    for button: Button in hud._duel_tech_buttons:
        if button.text.contains("Périhélie"):
            prepaid_present = true
            prepaid_enabled = not button.disabled
    _check(session.phase == session.Phase.DUEL_CHOICE and prepaid_present and prepaid_enabled, "Le tir déjà payé reste proposé dans le duel gardien malgré l'épuisement du Karma")
    session.duel["ai_special"] = false
    hud.duel_choice_requested.emit("special", "perihelion_hammer")
    _check(session.phase == session.Phase.CINEMATIC and session.duel["attack_technique"] == "perihelion_hammer", "Le vrai bouton poursuit la signature prépayée jusqu'au gardien")
    ground.queue_free()
    await process_frame
    print("Scène augmentations : %d / %d vérifications réussies." % [_passed, _total])
    quit(0 if _passed == _total else 1)
