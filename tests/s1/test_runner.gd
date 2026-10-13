extends Control
## Ouvrir cette scène puis F6 : 30 tests S0 + 24 tests S1.
const Baseline = preload("res://tests/test_suite.gd")
const Opposition = preload("res://tests/s1/test_suite.gd")

func _ready() -> void:
    var total: int = 0
    var passed: int = 0
    var lines: Array[String] = []
    var reports: Array[Dictionary] = [Baseline.new().run_all(), Opposition.new().run_all()]
    for report: Dictionary in reports:
        total += int(report["total"])
        passed += int(report["passed"])
        lines.append_array(report["lines"])
    var title: String = "%d / %d tests réussis — %d échec(s)" % [passed, total, total - passed]
    $Margin/Column/Title.text = title
    print(title)
    for line: String in lines:
        print(line)
        $Margin/Column/Results.append_text(line + "\n")
    $Margin/Column/Play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/training_ground.tscn"))
