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
