extends Control
## Ouvrir test_runner.tscn puis F6. Le jeu reste la scène principale pour F5.

const Suite = preload("res://tests/test_suite.gd")

func _ready() -> void:
    var report: Dictionary = Suite.new().run_all()
    var title: String = "%d / %d tests réussis — %d échec(s)" % [report["passed"], report["total"], report["failed"]]
    print(title)
    $Margin/Column/Title.text = title
    for line: String in report["lines"]:
        print(line)
        $Margin/Column/Results.append_text(line + "\n")
    $Margin/Column/Play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/training_ground.tscn"))
