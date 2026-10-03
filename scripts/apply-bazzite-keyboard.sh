#!/usr/bin/env bash
set -euo pipefail

# AppImage terminals can export GSETTINGS_BACKEND=keyfile. GNOME's shortcut
# handler uses dconf, so always read and write the actual desktop settings.
export GSETTINGS_BACKEND=dconf

case "${1:-}" in
    "") check_only=false ;;
    --check) check_only=true ;;
    *) printf '%s\n' "Usage: bash scripts/apply-bazzite-keyboard.sh [--check]" >&2; exit 1 ;;
esac
if (( $# > 1 )); then
    printf '%s\n' "Unexpected arguments." >&2
    exit 1
fi
if [[ "$OSTYPE" != linux* || "$EUID" == 0 ]]; then
    printf '%s\n' "Run as your regular logged-in Linux desktop user, not with sudo." >&2
    exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
keyd_source="$repo_dir/platforms/bazzite/keyd/keychron-link.conf"
ghostty_source="$repo_dir/platforms/bazzite/ghostty/config"
# Keep the legacy target to avoid installing two profiles for the same device.
keyd_target=/etc/keyd/default.conf

if [[ ! -r "$keyd_source" || ! -r "$ghostty_source" ]]; then
    printf '%s\n' "The dotfiles checkout is missing the Bazzite keyd or Ghostty source config." >&2
    exit 1
fi

if ! command -v keyd >/dev/null 2>&1; then
    printf '%s\n' "keyd is not installed. On Bazzite, check rpm-ostree search keyd first, then install it and reboot before rerunning this script." >&2
    exit 1
fi

if ! command -v zellij >/dev/null 2>&1; then
    printf '%s\n' "zellij is not installed. Install zellij before applying this configuration." >&2
    exit 1
fi

# GNOME shortcuts may not inherit the interactive shell PATH. Prefer the
# user's Ghostty desktop launcher, especially for AppImage installations.
ghostty_desktop_file="${XDG_DATA_HOME:-$HOME/.local/share}/applications/ghostty.desktop"
ghostty_launcher_command=
if [[ -r "$ghostty_desktop_file" ]]; then
    ghostty_launcher_command=$(sed -n 's/^Exec=//p' "$ghostty_desktop_file" | head -n 1 | sed -E 's/ --gtk-single-instance=true//g; s/ %[A-Za-z]//g')
fi
if [[ -z "$ghostty_launcher_command" ]]; then
    ghostty_binary=$(command -v ghostty || true)
    if [[ -n "$ghostty_binary" ]]; then
        ghostty_launcher_command=$ghostty_binary
    else
        ghostty_launcher_command=ghostty
    fi
fi
ghostty_fullscreen_command="$ghostty_launcher_command --fullscreen=true"

# Validate before replacing the working system configuration.
keyd check "$keyd_source"

if "$check_only"; then
    printf 'Validated keyd profile: %s\n' "$keyd_source"
    printf 'Install target: %s\n' "$keyd_target"
    printf 'Ghostty merge target: %s/ghostty/config\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
    printf 'Fullscreen launcher: %s\n' "$ghostty_fullscreen_command"
    printf '%s\n' "Check complete. No settings changed. Confirm the profile's device ID with sudo keyd monitor."
    exit 0
fi

# Install the device-scoped keyd configuration, retaining the first backup.
if sudo test -e "$keyd_target" && ! sudo test -e "$keyd_target.before-mac-layout"; then
    sudo cp -a "$keyd_target" "$keyd_target.before-mac-layout"
fi
sudo install -D -m 0644 "$keyd_source" "$keyd_target"
sudo systemctl enable --now keyd
if ! sudo keyd reload; then
    sudo systemctl restart keyd
fi

# Append the requested bindings and startup command to the existing config.
ghostty_config="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
ghostty_dir=$(dirname -- "$ghostty_config")
mkdir -p "$ghostty_dir"
if [[ -e "$ghostty_config" && ! -e "$ghostty_config.before-mac-layout" ]]; then
    cp -a "$ghostty_config" "$ghostty_config.before-mac-layout"
fi
touch "$ghostty_config"

# Keep an existing startup command, particularly the local absolute-path
# config.ghostty override required by some GUI/AppImage launch environments.
ghostty_command_configured=false
for existing_config in "$ghostty_config" "$ghostty_dir/config.ghostty"; do
    if [[ -r "$existing_config" ]] &&
        grep -Eq '^[[:space:]]*command[[:space:]]*=' "$existing_config"; then
        ghostty_command_configured=true
        break
    fi
done
# Keep the first appended setting separate even if the existing file has no
# trailing newline.
if [[ -s "$ghostty_config" && -n "$(tail -c 1 "$ghostty_config")" ]]; then
    printf '\n' >> "$ghostty_config"
fi
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" == "command = "* ]] && "$ghostty_command_configured"; then
        continue
    fi
    grep -Fqx -- "$line" "$ghostty_config" || printf '%s\n' "$line" >> "$ghostty_config"
done < "$ghostty_source"

# Register the launcher in GNOME as a user shortcut. keyd leaves Super+T
# intact; GNOME is the correct layer for launching a GUI application.
if command -v gsettings >/dev/null 2>&1 && {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] ||
    [[ "${DESKTOP_SESSION:-}" == gnome* ]];
}; then
    gnome_media_keys=org.gnome.settings-daemon.plugins.media-keys
    gnome_custom_root=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
    gnome_custom_paths=$(gsettings get "$gnome_media_keys" custom-keybindings 2>/dev/null || true)

    gnome_shortcut_path=

    for ((gnome_index = 0; gnome_index < 100; gnome_index++)); do
        candidate_path="$gnome_custom_root/custom${gnome_index}/"
        candidate_schema="${gnome_media_keys}.custom-keybinding:${candidate_path}"
        candidate_name=$(gsettings get "$candidate_schema" name 2>/dev/null || true)
        if [[ "$candidate_name" == "'Open Ghostty fullscreen'" ]]; then
            gnome_shortcut_path=$candidate_path
            break
        fi
        if [[ -z "$gnome_shortcut_path" && "$candidate_name" == "''" &&
            "$gnome_custom_paths" != *"$candidate_path"* ]]; then
            gnome_shortcut_path=$candidate_path
        fi
    done

    if [[ -n "$gnome_shortcut_path" ]]; then
        gnome_shortcut_schema="${gnome_media_keys}.custom-keybinding:${gnome_shortcut_path}"
        if [[ -z "$gnome_custom_paths" || "$gnome_custom_paths" == "@as []" || "$gnome_custom_paths" == "[]" ]]; then
            gnome_updated_paths="['$gnome_shortcut_path']"
        elif [[ "$gnome_custom_paths" == *"$gnome_shortcut_path"* ]]; then
            gnome_updated_paths=$gnome_custom_paths
        else
            gnome_updated_paths="${gnome_custom_paths%]}, '$gnome_shortcut_path']"
        fi

        if gsettings set "$gnome_shortcut_schema" name 'Open Ghostty fullscreen' &&
            gsettings set "$gnome_shortcut_schema" command "$ghostty_fullscreen_command" &&
            gsettings set "$gnome_shortcut_schema" binding '<Super>t' &&
            gsettings set "$gnome_media_keys" custom-keybindings "$gnome_updated_paths"; then
            printf '%s\n' "Configured GNOME Super+T to open Ghostty fullscreen."
            printf 'Launcher: %s\n' "$ghostty_fullscreen_command"
            printf '%s\n' "On the remapped Keychron, hold Caps Lock and press T."
        else
            printf '%s\n' "Could not configure the GNOME Super+T shortcut; add it manually in Settings > Keyboard > View and Customize Shortcuts." >&2
        fi
    else
        printf '%s\n' "No available GNOME custom shortcut slot; add Super+T manually in Settings > Keyboard > View and Customize Shortcuts." >&2
    fi
else
    printf '%s\n' "GNOME was not detected; configure Super+T as a desktop shortcut for: $ghostty_fullscreen_command" >&2
fi

printf '%s\n' "Applied keyd and Ghostty configuration. Fully quit and reopen Ghostty, then follow packages/bazzite.md for verification and the local Zellij launcher override."
