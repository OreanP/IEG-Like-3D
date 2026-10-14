#!/usr/bin/env bash
# Installation reproductible de Godot standard 4.7, sans modifier les sources.
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_root=/workspace/tools/godot-4.7
mkdir -p "$install_root" /workspace/.config /workspace/.cache /workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
asset=Godot_v4.7-stable_linux.x86_64.zip
release=https://github.com/godotengine/godot-builds/releases/download/4.7-stable
if [[ ! -f "$install_root/SHA512-SUMS.txt" ]]; then
    curl -fsSL --retry 2 "$release/SHA512-SUMS.txt" -o "$install_root/SHA512-SUMS.txt"
fi
if [[ ! -f "$install_root/$asset" ]]; then
    curl -fsSL --retry 2 "$release/$asset" -o "$install_root/$asset"
fi
python3 - <<'PY'
from pathlib import Path
import hashlib
import zipfile
root = Path('/workspace/tools/godot-4.7')
name = 'Godot_v4.7-stable_linux.x86_64.zip'
rows = [line.split() for line in (root / 'SHA512-SUMS.txt').read_text().splitlines()]
expected = next(row[0] for row in rows if row[-1].lstrip('*') == name)
if hashlib.sha512((root / name).read_bytes()).hexdigest() != expected:
    raise SystemExit('Official SHA512 mismatch; remove the corrupt archive and retry. Verification is required.')
with zipfile.ZipFile(root / name) as archive:
    binary = 'Godot_v4.7-stable_linux.x86_64'
    (root / binary).write_bytes(archive.read(binary))
(root / binary).chmod(0o755)
print('Godot archive: official SHA512 verified.')
PY
export GODOT_BIN="$install_root/Godot_v4.7-stable_linux.x86_64"
cd "$repo_root"
"$GODOT_BIN" --version
# Import metadata may be rewritten by the editor; preserve pre-existing files.
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
root = Path.cwd()
tracked = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
backup = {root / p: (root / p).read_bytes() for p in tracked if p.endswith('.import')}
uids = set(root.rglob('*.gd.uid'))
try:
    result = subprocess.run([os.environ['GODOT_BIN'], '--headless', '--path', str(root), '--editor', '--import'],
                            capture_output=True, text=True, timeout=120)
    output = result.stdout + result.stderr
    print(output)
    Path('/tmp/ieg-import.log').write_text(output)
finally:
    for path, content in backup.items():
        path.write_bytes(content)
    for path in set(root.rglob('*.gd.uid')) - uids:
        path.unlink()
if result.returncode:
    raise SystemExit(result.returncode)
if 'SCRIPT ERROR:' in output or 'ERROR:' in output:
    raise SystemExit('Import/compilation failed; see /tmp/ieg-import.log.')
PY
