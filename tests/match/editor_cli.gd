extends SceneTree
const Suite = preload("res://tests/match/test_editor.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var report: Dictionary = Suite.new().run_all()
    for line: String in report["lines"]:
        print(line)
    print("%d / %d tests atelier réussis." % [report["passed"], report["total"]])
    quit(0 if report["passed"] == report["total"] else 1)
