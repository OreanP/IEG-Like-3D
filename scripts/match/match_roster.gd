class_name IEGMatchRoster
extends RefCounted
## Le roster de démonstration reste indépendant des profils de l'entraînement.

const Profile = preload("res://core/player_profile.gd")

static func build() -> Dictionary:
    var profiles: Array[IEGPlayerProfile] = []
    var starts: Array[Vector2] = []
    var teams: Array[int] = []
    var keepers: Array[bool] = []
    # Le n°7 local reçoit l'engagement ; les autres conservent leurs couloirs.
    var positions: Array[Vector2] = [
        Vector2(0.0, 41.0),
        Vector2(-22.0, 27.0), Vector2(-7.5, 30.0),
        Vector2(7.5, 30.0), Vector2(22.0, 27.0),
        Vector2(-23.0, 11.0), Vector2(0.0, 1.0),
        Vector2(8.0, 13.0), Vector2(23.0, 11.0),
        Vector2(-8.0, 3.5), Vector2(8.0, 3.5),
    ]
    var skin_colors: Array[Color] = [Color("b77754"), Color("e8b392"),
        Color("75492f"), Color("ce9673"), Color("9f6844")]
    for team: int in range(2):
        for index: int in range(11):
            var profile: IEGPlayerProfile = Profile.new()
            var shirt: int = index + 1
            profile.player_id = shirt + team * 20
            profile.shirt_number = shirt
            profile.display_name = "%s %02d" % ["Azur" if team == 0 else "Carmin", shirt]
            profile.content_key = "%s_%02d" % ["azur" if team == 0 else "carmin", shirt]
            if index >= 5:
                profile.technique_ids = ["orbital_shot", "combat_blade"]
            else:
                profile.technique_ids = ["hurricane_barrier", "aquablast"]
            if index == 0:
                profile.technique_ids = ["photo_stop"]
            if team == 0 and shirt == 7:
                profile.display_name = "Soren Vale"
                profile.content_key = "soren_vale"
                profile.base_stats = {"shot": 90.0, "dribble": 80.0, "technique": 85.0, "defense": 45.0, "keeper": 20.0}
                profile.technique_ids = ["drift", "magnus_shot", "orbital_shot", "combat_blade", "seismic_strike", "prism_ricochet"]
                profile.karma_ids = ["astreion"]
            elif team == 0 and shirt == 1:
                profile.display_name = "Maëlle Néris"
                profile.content_key = "maelle_neris"
                profile.base_stats = {"shot": 30.0, "dribble": 45.0, "technique": 80.0, "defense": 85.0, "keeper": 95.0}
                profile.technique_ids = ["aquablast", "gyroscopic_stop", "photo_stop", "titan_grip", "midnight_dial"]
                profile.karma_ids = ["thalassa"]
            elif team == 0 and shirt == 8:
                profile.technique_ids.append_array(["paper_escape", "syncope"])
                profile.karma_ids = ["vaelis"]
            elif team == 0 and shirt == 4:
                profile.technique_ids.append_array(["bronze_rampart", "mechanical_brambles"])
                profile.karma_ids = ["orvann"]
            profile.run_speed = 5.2 + float(index % 3) * 0.12
            profile.sprint_speed = 8.2 + float(index % 3) * 0.14
            profile.kit_color = Color("1675df") if team == 0 else Color("d93b4d")
            if index == 0:
                profile.kit_color = Color("21b99b") if team == 0 else Color("f2b73c")
            profile.skin_color = skin_colors[(index + team * 2) % skin_colors.size()]
            profile.hair_color = Color("211b21") if index % 3 != 1 else Color("704526")
            profiles.append(profile)
            starts.append(positions[index] * (1.0 if team == 0 else -1.0))
            teams.append(team)
            keepers.append(index == 0)
    return {"profiles": profiles, "starts": starts, "teams": teams, "keepers": keepers}
