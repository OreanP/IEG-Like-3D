#!/usr/bin/env bash
# Validation moteur, tests natifs, entrées et vraie scène de diagnostic.
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/workspace/.config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/workspace/.cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/workspace/.local/share}
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
GODOT_BIN=${GODOT_BIN:-/workspace/tools/godot-4.7/Godot_v4.7-stable_linux.x86_64}
version=$("$GODOT_BIN" --version)
if [[ "$version" != 4.7.stable.* ]]; then
    printf 'Godot standard 4.7 stable requis, version détectée : %s\n' "$version" >&2
    exit 1
fi
log_root=$(mktemp -d /tmp/ieg-validation.XXXXXX)
run_checked() {
    local name=$1
    shift
    local status=0
    timeout 60 "$GODOT_BIN" --headless --path "$repo_root" "$@" > "$log_root/$name.log" 2>&1 || status=$?
    cat "$log_root/$name.log"
    if (( status != 0 )); then
        return "$status"
    fi
    if rg -q 'SCRIPT ERROR:|ERROR:|ÉCHEC' "$log_root/$name.log"; then
        printf 'Validation échouée : %s\n' "$log_root/$name.log" >&2
        return 1
    fi
}
run_checked import --editor --import
run_checked tests --script res://tests/match/test_cli.gd
run_checked scene-input --script res://tests/development/scene_smoke.gd
run_checked training res://scenes/training_ground.tscn --quit-after 180
run_checked match-input --script res://tests/match/scene_smoke.gd
run_checked full-match res://scenes/full_match.tscn --quit-after 180 -- --smoke
run_checked content-editor res://scenes/content_editor.tscn --quit-after 120
run_checked diagnostic res://scenes/diagnostic.tscn -- --verify
printf 'Validation terminée. Journaux : %s\n' "$log_root"
