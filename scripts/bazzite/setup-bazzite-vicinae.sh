#!/usr/bin/env bash
# GNOME user setup. Native install is separate; existing user-local installs work.
set -euo pipefail
export GSETTINGS_BACKEND=dconf
case "${1:-}" in
    '') check_only=false ;;
    --check) check_only=true ;;
    *) echo 'Usage: bash scripts/bazzite/setup-bazzite-vicinae.sh [--check]' >&2; exit 1 ;;
esac
[[ $# -le 1 && $EUID != 0 ]] || { echo 'Run in your desktop session as your regular user.' >&2; exit 1; }
. /etc/os-release
[[ ${ID:-} == bazzite && ${XDG_SESSION_TYPE:-} == wayland && ":${XDG_CURRENT_DESKTOP:-}:" == *:GNOME:* ]] || {
    echo 'This setup currently supports Bazzite GNOME on Wayland only.' >&2; exit 1;
}
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
for tool in /usr/bin/python3 gsettings systemctl gnome-shell gnome-extensions fc-match curl jq update-desktop-database xdg-mime; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
vicinae_binary=
# Prefer native packaging on new installs; do not uninstall an existing local app.
for candidate in /usr/bin/vicinae "$(command -v vicinae || true)" "$HOME/.local/bin/vicinae"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then vicinae_binary=$candidate; break; fi
done
[[ -n "$vicinae_binary" ]] || {
    echo 'Install Vicinae first: bash scripts/bazzite/install-bazzite-apps.sh (then reboot if needed).' >&2; exit 1;
}
[[ "$(fc-match -f '%{family}' 'Adwaita Sans')" == *'Adwaita Sans'* ]] || {
    echo 'Adwaita Sans is not installed; install the GNOME font before applying.' >&2; exit 1;
}
# Preflight JSONC, shortcut conflicts, settings writability, and target paths
# before downloading/installing an extension or modifying user preferences.
/usr/bin/python3 "$script_dir/vicinae-settings.py" "$repo_dir/platforms/bazzite/vicinae/settings.json" "$vicinae_binary" --check
if "$check_only"; then
    echo 'Check only: no settings changes, service changes, downloads, or sudo.'
    exit 0
fi
extension_uuid=vicinae@dagimg-dot
extension_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$extension_uuid"
shell_version=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
[[ "$shell_version" =~ ^[0-9]+$ ]] || { echo 'Cannot detect GNOME version.' >&2; exit 1; }
extension_metadata="$extension_dir/metadata.json"
if [[ ! -f "$extension_metadata" && -f "/usr/share/gnome-shell/extensions/$extension_uuid/metadata.json" ]]; then
    extension_metadata="/usr/share/gnome-shell/extensions/$extension_uuid/metadata.json"
fi
if [[ ! -f "$extension_metadata" ]] || ! jq -e --arg version "$shell_version" '.uuid == "vicinae@dagimg-dot" and (."shell-version" | index($version) != null)' "$extension_metadata" >/dev/null; then
    temp_dir=$(mktemp -d)
    trap 'rm -f "$temp_dir/extension-info.json" "$temp_dir/vicinae.zip"; rmdir "$temp_dir"' EXIT
    curl --fail --silent --show-error --location --max-time 60 \
        "https://extensions.gnome.org/extension-info/?pk=8594&shell_version=$shell_version" -o "$temp_dir/extension-info.json"
    version_tag=$(jq -er --arg version "$shell_version" '.shell_version_map[$version].pk' "$temp_dir/extension-info.json")
    [[ "$version_tag" =~ ^[0-9]+$ ]] || { echo 'No compatible official GNOME extension available.' >&2; exit 1; }
    curl --fail --silent --show-error --location --max-time 60 \
        "https://extensions.gnome.org/download-extension/$extension_uuid.shell-extension.zip?version_tag=$version_tag" -o "$temp_dir/vicinae.zip"
    if [[ -d "$extension_dir" ]]; then
        backup="$extension_dir.before-dotfiles-vicinae"
        [[ ! -e "$backup" ]] || { echo "Extension backup already exists: $backup; review before upgrading." >&2; exit 1; }
        cp -a "$extension_dir" "$backup"
        gnome-extensions install --force "$temp_dir/vicinae.zip"
    else
        gnome-extensions install "$temp_dir/vicinae.zip"
    fi
fi
/usr/bin/python3 "$script_dir/vicinae-settings.py" "$repo_dir/platforms/bazzite/vicinae/settings.json" "$vicinae_binary"
update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
for scheme in vicinae raycast com.raycast; do
    xdg-mime default vicinae-url-handler.desktop "x-scheme-handler/$scheme"
done
systemctl --user daemon-reload
systemctl --user enable vicinae.service
if gnome-extensions info "$extension_uuid" >/dev/null 2>&1; then
    gnome-extensions enable "$extension_uuid"
else
    echo 'The installed GNOME extension will load after logout/login; it is already queued to enable.'
fi
systemctl --user restart vicinae.service
ready=false
for attempt in {1..15}; do
    if "$vicinae_binary" ping >/dev/null 2>&1; then ready=true; break; fi
    sleep 1
done
"$ready" || { echo 'Vicinae failed to start; inspect journalctl --user -u vicinae.service.' >&2; exit 1; }
echo 'Vicinae ready: physical Command+Space (with keyd remap), Adwaita Sans 11, login startup.'
echo 'Automatic paste/snippets may need additional host permissions; none were granted here.'
