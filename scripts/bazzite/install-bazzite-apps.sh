#!/usr/bin/env bash
# Native desktop packages only; run as your user, not via sudo.
set -euo pipefail
case "${1:-}" in
    '') check_only=false ;;
    --check) check_only=true ;;
    *) echo 'Usage: bash scripts/bazzite/install-bazzite-apps.sh [--check]' >&2; exit 1 ;;
esac
[[ $# -le 1 && $EUID != 0 ]] || { echo 'Run as your regular user.' >&2; exit 1; }
[[ -r /etc/os-release ]] && . /etc/os-release
[[ ${ID:-} == bazzite ]] || { echo 'This installer is for Bazzite only.' >&2; exit 1; }
repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
manifest="$repo_dir/packages/bazzite-desktop-app.txt"
packages=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%%#*}
    line=$(printf '%s' "$line" | xargs)
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] || { echo "Invalid RPM name: $line" >&2; exit 1; }
    packages+=("$line")
done < "$manifest"
[[ ${#packages[@]} -gt 0 ]] || { echo 'No desktop packages listed.'; exit 0; }
for tool in rpm rpm-ostree /usr/bin/python3; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
missing=()
for package in "${packages[@]}"; do
    if rpm -q --quiet "$package"; then
        printf 'Installed: %s\n' "$package"
    else
        missing+=("$package")
        printf 'Requested: %s\n' "$package"
    fi
done
[[ ${#missing[@]} -gt 0 ]] || { echo 'All native desktop packages are installed.'; exit 0; }
[[ -r /etc/yum.repos.d/terra.repo ]] || { echo 'Bazzite Terra repository configuration is missing; see packages/bazzite.md.' >&2; exit 1; }
if "$check_only"; then
    echo 'Would enable the existing Terra repo and layer missing packages with rpm-ostree --idempotent.'
    echo 'Check only: no repository changes, downloads, sudo, or deployment changes.'
    exit 0
fi
echo 'Enabling the third-party Terra package source (keeping signature checks intact).'
# Edit only the existing [terra] enabled flag, preserving other sections and
# comments. Back up once, and refuse an unexpected layout instead of guessing.
sudo /usr/bin/python3 - <<'PY'
import pathlib
import re
import shutil

path = pathlib.Path('/etc/yum.repos.d/terra.repo')
text = path.read_text()
section = re.search(r'(?ms)^\[terra\][ \t]*\r?\n.*?(?=^\[|\Z)', text)
if not section:
    raise SystemExit('No [terra] section; refusing to change repository configuration.')
flags = list(re.finditer(r'(?m)^[ \t]*enabled[ \t]*=[ \t]*([01])[ \t]*(?:[#;].*)?$', section[0]))
if len(flags) != 1:
    raise SystemExit('Expected exactly one enabled=0/1 flag in [terra]; no changes made.')
flag = flags[0]
if flag[1] == '0':
    backup = path.with_name(path.name + '.before-dotfiles-desktop-apps')
    if not backup.exists():
        shutil.copy2(path, backup)
    position = section.start() + flag.start(1)
    path.write_text(text[:position] + '1' + text[position + 1:])
    print('Enabled [terra]; first backup retained at', backup)
else:
    print('[terra] is already enabled.')
PY
sudo rpm-ostree install --idempotent "${missing[@]}"
echo 'Native package request completed. Reboot if a new deployment was staged, then run:'
echo '  bash scripts/bazzite/setup-bazzite-vicinae.sh'
echo 'This script does not reboot or replace an existing user-local/AppImage install.'
