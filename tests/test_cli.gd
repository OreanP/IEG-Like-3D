extends SceneTree
## Facultatif : godot --headless --path . --script res://tests/test_cli.gd
## Effectuer d'abord l'import du projet dans l'éditeur.
const Suite = preload("res://tests/test_suite.gd")

func _initialize() -> void:
    var report: Dictionary = Suite.new().run_all()
    for line: String in report["lines"]:
        print(line)
    print("%d / %d tests réussis ; %d échec(s)." % [report["passed"], report["total"], report["failed"]])
    quit(0 if int(report["failed"]) == 0 else 1)
