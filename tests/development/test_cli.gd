extends SceneTree
const Baseline = preload("res://tests/test_suite.gd")
const Opposition = preload("res://tests/s1/test_suite.gd")
const Development = preload("res://tests/development/test_suite.gd")

func _initialize() -> void:
    var total: int = 0
    var passed: int = 0
    for suite: RefCounted in [Baseline.new(), Opposition.new(), Development.new()]:
        var report: Dictionary = suite.run_all()
        total += int(report["total"])
        passed += int(report["passed"])
        for line: String in report["lines"]:
            print(line)
    print("%d / %d tests réussis ; %d échec(s)." % [passed, total, total - passed])
    quit(0 if passed == total else 1)
