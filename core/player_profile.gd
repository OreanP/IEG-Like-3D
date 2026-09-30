class_name IEGPlayerProfile
extends Resource
## Définition éditable et partagée. Aucun état temporaire du match ici.

@export var player_id: int = 7
@export var display_name: String = "Joueur 07"
@export_range(1, 99, 1) var shirt_number: int = 7
@export_range(1.0, 12.0, 0.1) var run_speed: float = 5.2
@export_range(1.0, 16.0, 0.1) var sprint_speed: float = 8.2
@export var kit_color: Color = Color("1268c4")
@export var skin_color: Color = Color("a9663f")
@export var hair_color: Color = Color("26180f")

func is_valid() -> bool:
    return (player_id >= 0 and not display_name.is_empty()
        and is_finite(run_speed) and is_finite(sprint_speed)
        and run_speed > 0.0 and sprint_speed >= run_speed)
