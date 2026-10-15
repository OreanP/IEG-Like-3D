extends SceneTree
## Toutes les régressions du projet et les nouveaux contrats du match.
const Baseline = preload("res://tests/test_suite.gd")
const Opposition = preload("res://tests/s1/test_suite.gd")
const Development = preload("res://tests/development/test_suite.gd")
const FullMatch = preload("res://tests/match/test_match.gd")
const Content = preload("res://tests/match/test_content.gd")
const Cinematic = preload("res://tests/match/test_cinematic.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var total: int = 0
    var passed: int = 0
    for suite: RefCounted in [Baseline.new(), Opposition.new(), Development.new(), FullMatch.new(), Content.new(), Cinematic.new()]:
        var report: Dictionary = suite.run_all()
        total += int(report["total"])
        passed += int(report["passed"])
        for line: String in report["lines"]:
            print(line)
    print("%d / %d tests natifs réussis ; %d échec(s)." % [passed, total, total - passed])
    quit(0 if passed == total else 1)
