#!/bin/sh
# Run as your desktop user from a GNOME or KDE Wayland session, not with sudo.
set -eu

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

[ "${XDG_SESSION_TYPE:-}" = wayland ] || fail 'Only Wayland sessions are supported; no settings changed.'

# A short nonzero delay avoids accidental repeats. Edit to taste.
delay_ms=150
interval_ms=15
rate_hz=67

case ":${XDG_CURRENT_DESKTOP:-}:" in
    *:GNOME:*|*:gnome:*)
        # AppImage terminals may select keyfile; GNOME uses the dconf backend.
        export GSETTINGS_BACKEND=dconf
        command -v gsettings >/dev/null 2>&1 || fail 'gsettings is required.'
        schema=org.gnome.desktop.peripherals.keyboard
        # Check every setting before modifying any of them.
        for key in repeat delay repeat-interval; do
            [ "$(gsettings writable "$schema" "$key")" = true ] || fail "GNOME setting $key is not writable."
        done
        printf 'Previous GNOME settings (repeat, delay, interval):\n'
        gsettings get "$schema" repeat
        gsettings get "$schema" delay
        gsettings get "$schema" repeat-interval
        gsettings set "$schema" delay "$delay_ms"
        gsettings set "$schema" repeat-interval "$interval_ms"
        gsettings set "$schema" repeat true
        printf 'GNOME: delay %s ms, repeat interval %s ms.\n' "$delay_ms" "$interval_ms"
        ;;
    *:KDE:*|*:kde:*)
        command -v kwriteconfig6 >/dev/null 2>&1 || fail 'KDE Plasma 6 with kwriteconfig6 is required.'
        config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}
        mkdir -p "$config_dir"
        config_file="$config_dir/kcminputrc"
        if [ -e "$config_file" ]; then
            backup="$config_file.before-dotfiles-keyboard"
            [ ! -e "$backup" ] || fail "Backup already exists: $backup. Move it aside before running again."
            cp -p "$config_file" "$backup"
            printf 'Previous KDE configuration backed up to %s\n' "$backup"
        fi
        kwriteconfig6 --file "$config_file" --group Keyboard --key RepeatDelay "$delay_ms"
        kwriteconfig6 --file "$config_file" --group Keyboard --key RepeatRate "$rate_hz"
        kwriteconfig6 --file "$config_file" --group Keyboard --key KeyRepeat repeat
        printf 'KDE: delay %s ms, rate %s Hz. Log out and back in to apply reliably.\n' "$delay_ms" "$rate_hz"
        ;;
    *) fail 'Only GNOME and KDE Plasma 6 desktops are supported; no settings changed.' ;;
esac
