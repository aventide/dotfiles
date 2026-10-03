# Vicinae

For a new native install, follow the [desktop package steps](../README.md#desktop-apps)
first and reboot if needed. Then apply the user setup below.

An existing AppImage/user-local installation, such as the original machine's
`~/.local/bin/vicinae`, can run the user setup directly. The repo does not
silently migrate or uninstall that copy. To migrate deliberately later, first
review its systemd unit, desktop entries, and local executable; native and
user-local copies should not both be launched independently. User-local
AppImages still need updates via their original installer, not rpm-ostree.

## User preferences, startup, and shortcut

Run from a logged-in Bazzite GNOME Wayland session, not through sudo:

```sh
bash bazzite/scripts/setup-vicinae.sh --check
bash bazzite/scripts/setup-vicinae.sh
```

KDE and X11 are intentionally rejected by this script; they need different
launcher/shortcut integration. GNOME's Adwaita Sans font, Python 3 with
PyGObject (`Gio`), curl, jq, fontconfig, desktop-file utilities, and a running
systemd user session are prerequisites. The Bazzite image and CLI Brewfile
provide these on the tested system; `--check` reports missing prerequisites.

The tracked `bazzite/config/vicinae/settings.json` contains only the font
preference: Adwaita Sans at 11 points, matching the original GNOME interface.
It is a fixed preference, not a font downloaded by this script. Adjust this
fragment if you want a different font on a future image. Existing theme,
extension preferences, and other settings are retained. The helper accepts
JSONC comments and trailing commas, backs up existing settings once, and
writes valid JSON; original comments/formatting remain in the backup.

The setup chooses `/usr/bin/vicinae` when installed, otherwise the available
or user-local binary. Generated desktop entries, the shortcut, and the
`vicinae.service.d/dotfiles.conf` override use the current user's absolute
paths. A service-local PATH includes available Linux Homebrew tools so
extensions can find CLI dependencies such as `rbw`; no desktop-wide PATH or
interactive-shell startup changes are needed. The unit starts on graphical
login, and the script restarts it and verifies it answers a ping.

The shortcut is named `Toggle Vicinae`. GNOME gets `<Control>space` because
the device-scoped keyd profile turns physical Command into Control. Apply
and verify that profile on your intended keyboard first; without it the
shortcut is physical Ctrl+Space. Other keyboards are not remapped. Caps Lock
still acts as Super. The helper retains other shortcuts and refuses an
existing Ctrl+Space assignment rather than overwriting it. It removes only
IBus's `Control+space` legacy trigger, preserving other input-method bindings.
GSettings always uses dconf, even from an AppImage terminal.

The [official GNOME companion extension](https://github.com/vicinaehq/gnome-extension)
provides window management and clipboard integration. The script requests a
release compatible with the installed GNOME major version from
extensions.gnome.org, retaining an already-compatible installation. If it
must replace an incompatible local extension, it keeps the first backup and
refuses to overwrite that backup on a later upgrade. A newly installed
extension may require logout/login; the script queues it to be enabled at
the next login without restarting GNOME or logging you out. A previous
explicit disable of this extension is cleared; other extensions' disabled
entries are left alone.

Bitwarden is added to the extension's blocked clipboard applications without
removing existing exclusions. This is a focused-application filter, not a
guarantee that secrets copied from a browser, terminal, or another app will
be excluded. Clipboard history is sensitive local data: review the clipboard
settings before copying secrets. Automatic paste and snippet expansion may
require extra input permissions. This script does not grant device groups,
Linux capabilities, or root privileges to Vicinae.

## Verification and rollback

```sh
systemctl --user is-enabled vicinae.service
systemctl --user status vicinae.service
```

Press physical Command+Space on the remapped Keychron: Vicinae should open
and a second press should close it. Confirm the Adwaita Sans font, existing
theme, and existing shortcuts. After logout/login, check:

```sh
gnome-extensions info vicinae@dagimg-dot
# Use /usr/bin/vicinae, or ~/.local/bin/vicinae for a user-local install:
vicinae ping
```

Rerunning setup reapplies only the tracked preferences and integration;
it does not duplicate the named shortcut or reset other settings. First
backups are retained beside changed files as `.before-dotfiles-vicinae`.
Original shortcut/IBus/extension values (including disabled extensions) and
the previous default handlers for `vicinae://`, `raycast://`, and
`com.raycast://` are saved once, locally, at
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/vicinae-before.json`.
Neither backups nor extension state belong in git.
URI defaults are captured before registering our desktop entries; an empty
value means there was no previous handler. Reruns preserve the saved values.
If upgrading from a setup version with an older snapshot, only missing
fields are added using the current state. Defaults already replaced by an
older version cannot be reconstructed.

To roll back, stop/disable `vicinae.service`, remove the named shortcut in
GNOME Keyboard settings, and review/restore the saved IBus trigger if desired.
Restore backed-up settings, desktop entries, and the service drop-in only
after checking for newer personal edits; remove generated files that had no
preexisting counterpart if you no longer want them. Disable the companion
extension with `gnome-extensions disable vicinae@dagimg-dot` (or in Extensions).
Reload the systemd user daemon after restoring/removing its override. Avoid
restoring an entire old dconf/extension list over unrelated later changes.

Before removing the generated URL-handler desktop entry, inspect the saved
URI defaults:

```sh
jq '."uri-handler-defaults"' "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/vicinae-before.json"
# Example: substitute the actual saved desktop ID and scheme:
xdg-mime default previous-raycast.desktop x-scheme-handler/raycast
```

For each nonempty saved value, use `xdg-mime default` as above to restore it,
unless you have deliberately chosen a different handler since setup. For an
empty saved value, remove only that scheme's
`x-scheme-handler/SCHEME=vicinae-url-handler.desktop` entry under
`[Default Applications]` in
`${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list`, if it still points to our
handler. Keep other associations and sections intact; do not restore the
whole file over newer changes. After removing the generated desktop entry,
run `update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"`
and verify each scheme with `xdg-mime query default x-scheme-handler/SCHEME`.

For a deliberately layered native install, `sudo rpm-ostree uninstall vicinae`
stages its removal; reboot to use that deployment. Do not use this to remove a
package built into a future base image. Restore the Terra configuration only
if no other installed applications need it, and review the old backup against
any intervening repository changes. Nothing here removes a user-local
AppImage, logs into Bitwarden, or commits local vault data.

Return to the [Bazzite setup guide](../README.md).
