extends SceneTree
## Après import : godot --headless --path . --script res://tests/s1/test_cli.gd
const Baseline = preload("res://tests/test_suite.gd")
const Opposition = preload("res://tests/s1/test_suite.gd")

func _initialize() -> void:
    var total: int = 0
    var passed: int = 0
    var reports: Array[Dictionary] = [Baseline.new().run_all(), Opposition.new().run_all()]
    for report: Dictionary in reports:
        total += int(report["total"])
        passed += int(report["passed"])
        for line: String in report["lines"]:
            print(line)
    print("%d / %d tests réussis ; %d échec(s)." % [passed, total, total - passed])
    quit(0 if passed == total else 1)
