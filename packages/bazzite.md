# Bazzite setup notes

## Ghostty AppImage with Homebrew Zellij

Install Ghostty separately as a Linux application; the macOS Ghostty cask
does not install it on Bazzite. Install the CLI tools with
`brew bundle --file=packages/bazzite.Brewfile` from the repository root.

When launching Ghostty from GNOME, the app may receive a PATH that excludes
Homebrew and `~/.local/bin`. A bare `command = zellij` can therefore fail even
when Zellij works in an existing terminal. This happened after logging out and
back in following a switch to Zsh. Changes made in `.zshrc` cannot help find
Zellij here: Ghostty starts Zellij before Zellij starts the interactive shell.

### Configure the launcher before the first desktop launch

Find the stable Homebrew executable path in a working terminal:

```sh
zellij_path="$(brew --prefix)/bin/zellij"
test -x "$zellij_path" && "$zellij_path" --version
printf 'command = %s\n' "$zellij_path"
```

Use the printed `command` line in the machine's local Ghostty configuration.
For a standard Linux Homebrew install, it looks like this:

```ini
command = /home/linuxbrew/.linuxbrew/bin/zellij
```

Use the stable `bin/zellij` link rather than a versioned `Cellar` path, so
Homebrew upgrades do not require changing the launcher. Choose the actual
prefix on the target machine; the example above is not a shared default.

On the tested Ghostty AppImage 1.3.1 setup, the portable settings live in
`~/.config/ghostty/config`, and this local `command` override lives in
`~/.config/ghostty/config.ghostty`, which that build loads afterward. Preserve
any existing settings when editing those files. If `XDG_CONFIG_HOME` is set,
use its `ghostty/` directory instead of `~/.config/ghostty/`.

Configuration filenames and loading order can vary with the Ghostty version.
For a new setup, verify which `command` wins instead of assuming that a second
file overrides the first. With a different layout, set the absolute command
in the active configuration file or use an explicit local include as described
in [Ghostty's configuration documentation](https://ghostty.org/docs/config).

### Verify and restart

Run these with the installed Ghostty AppImage path (replace the example if
the AppImage is elsewhere):

```sh
"$HOME/AppImages/ghostty.appimage" +validate-config
"$HOME/AppImages/ghostty.appimage" +show-config | rg '^command ='
```

Validation should succeed and the effective command should be the absolute
Zellij path. Fully quit Ghostty and reopen it from the desktop launcher.
Zellij should start and open the configured login shell, which loads the SPQR
theme through the linked `.zshrc`. Check both the app launcher and any desktop
shortcut used to open Ghostty.

Updating the systemd user manager or D-Bus activation PATH did not fix launches
from the already-running GNOME session in this setup. The attempted
`environment.d/80-user-path.conf` integration was removed. The working fix is
the local absolute-path command above; no session PATH override is required.

## Keychron remapping

This migrates the configuration and normal installer from the original
`keyboard-remap-config` directory. The historical `cleanup.sh` is not part of
new-machine setup: it only removed two obsolete keyfile shortcut entries from
the original machine. The new installer always uses GNOME's dconf backend.

### Device selection and prerequisites

Install keyd on the host and Ghostty separately; install Zellij through the
Bazzite Brewfile. Check whether keyd is already available before layering it:

```sh
command -v keyd
rpm-ostree search keyd
# Only if keyd is missing and the package is available:
sudo rpm-ostree install keyd
# Reboot after layering the package, before applying the remap.
```

The profile at `platforms/bazzite/keyd/keychron-link.conf` targets the original
Keychron Link keyboard ID `k:3434:d030:8f88fcbf`, not every keyboard. On another
machine or with another keyboard, identify the keyboard using:

```sh
sudo keyd monitor
```

Update the profile's `[ids]` entry if necessary, retaining keyboard-only `k:`
scoping. Do not replace it with a wildcard. The installer validates the config
syntax but cannot confirm that this ID matches the keyboard you intend to use.

### Install explicitly

From the dotfiles root, in a terminal belonging to the logged-in desktop user:

```sh
bash scripts/bazzite/apply-bazzite-keyboard.sh --check
bash scripts/bazzite/apply-bazzite-keyboard.sh
```

`--check` validates the profile and prints installation targets without writing
settings or invoking sudo. The normal run uses sudo only for the host keyd
installation and service commands. Do not wrap the whole script in sudo.

The installer writes the profile to `/etc/keyd/default.conf`, retaining the
original installer's target so an existing installation does not acquire a
second conflicting profile. It enables keyd at boot and reloads it, falling
back to a service restart if reload fails. It merges missing Ghostty lines into
`${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config`, preserving unrelated settings.
Existing `command` settings in either `config` or `config.ghostty` are retained;
the local `config.ghostty` file itself is never edited. On a fresh setup,
configure and verify the absolute-path Zellij launcher as described above.

The first existing configs are backed up to:

```text
/etc/keyd/default.conf.before-mac-layout
~/.config/ghostty/config.before-mac-layout
```

The Ghostty backup lives under `XDG_CONFIG_HOME` if that variable is set.
Repeated runs preserve those first backups. Review any existing backup from a
previous setup before relying on it for rollback.

On GNOME, the script registers `Open Ghostty fullscreen` with binding
`<Super>t`, using the user's Ghostty desktop launcher when available. It reuses
that named shortcut and retains other registered custom shortcuts. Caps Lock
is Super after the remap, so the physical shortcut is Caps Lock+T; Command+T
remains Control+T. Other desktops require adding the shortcut manually.

### Verify

Fully quit and reopen Ghostty. Check the service:

```sh
systemctl is-enabled keyd
systemctl is-active keyd
```

- In applications, test Command-C/V/Z/A/T/W.
- In a shell, Control-C still interrupts and Control-Z still suspends.
- Option remains Alt, and physical Control remains Control.
- In Ghostty, Command-C copies a selection; without a selection it interrupts.
  Command-V and Control-V both paste because keyd makes them the same modifier.
- New Ghostty surfaces start Zellij using the verified local launcher command.
- Caps Lock+T opens Ghostty fullscreen on GNOME.
- Other attached keyboards remain unaffected by the device-scoped profile.

A reboot is not required to reload an already-installed keyd. Reboot once when
checking boot persistence, or after initially layering the keyd package.

### Roll back

To disable remapping immediately and at boot:

```sh
sudo systemctl disable --now keyd
```

If a prior keyd config was backed up, restore it and re-enable the service:

```sh
sudo cp -a /etc/keyd/default.conf.before-mac-layout /etc/keyd/default.conf
sudo systemctl enable --now keyd
sudo keyd reload || sudo systemctl restart keyd
```

If no previous config existed, keep keyd disabled until you remove or replace
the installed profile. Restoring the Ghostty backup restores the main config
as it was before installation; review any later edits before replacing it:

```sh
cp -a "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.before-mac-layout" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
```

Remove the named fullscreen shortcut through GNOME Keyboard settings if no
longer wanted. Restoring the main Ghostty config leaves the local
`config.ghostty` command override in place; remove its `command` line separately
if you also want to stop launching Zellij. Restart Ghostty after editing.

## Vicinae

`packages/bazzite-desktop-app.txt` tracks native desktop RPMs separately from
the CLI Brewfile. It currently lists `vicinae`. Future entries must be RPM
package names available from the enabled host repositories, not Flatpak IDs,
Homebrew formulas, URLs, or shell commands.

### Native installation on a new machine

[Vicinae's installation documentation](https://docs.vicinae.com/install/linux)
recommends the Terra RPM on Bazzite. Terra is a third-party Fedora repository,
not Homebrew and not a separate application sandbox. Bazzite already ships
its repository configuration. The installer enables only the `[terra]` entry
in `/etc/yum.repos.d/terra.repo`, retaining signature checks and other sections.
It keeps the first original repository config at
`/etc/yum.repos.d/terra.repo.before-dotfiles-desktop-apps`.

From the checkout, as your regular user:

```sh
brew bundle --file=packages/bazzite.Brewfile
bash scripts/bazzite/install-bazzite-apps.sh --check
bash scripts/bazzite/install-bazzite-apps.sh
```

The CLI Brewfile includes `rbw`, the unofficial Bitwarden CLI. It does not
include the official `bw` CLI. Removing `bw` from the manifest does not
uninstall a copy already present; no credentials or authentication are
configured by either installer. Configure `rbw` locally; never put vault
credentials in this repo. For the official US Bitwarden cloud, leave server
URLs unset to use the correct built-in defaults. After setting your email,
run `rbw register` before `rbw login`: [rbw requires per-device registration](https://github.com/doy/rbw#usage)
with a [personal API key](https://bitwarden.com/help/personal-api-key/) to avoid
Bitwarden's bot detection. A plain login before registration may fail with
HTTP 400. Enter the client ID and secret only in the local interactive
prompts, not shell arguments, repo files, or chat. EU/self-hosted vaults need
their corresponding API and identity URLs instead of the US defaults.
The Homebrew dependency supplies pinentry; GUI extensions may require choosing
a graphical pinentry locally rather than the terminal-based default.

The desktop installer needs sudo for the repository flag and `rpm-ostree`
request. `--check` is read-only and does not use sudo or download anything.
Repeated runs skip installed RPMs and use `--idempotent` for pending requests.
A new deployment generally needs a reboot; the script never reboots or uses
`--apply-live` automatically. Reboot when instructed, then continue below.
Native RPMs are updated through the normal Bazzite deployment/update process.

An existing AppImage/user-local installation, such as the original machine's
`~/.local/bin/vicinae`, can run the user setup directly. The repo does not
silently migrate or uninstall that copy. To migrate deliberately later, first
review its systemd unit, desktop entries, and local executable; native and
user-local copies should not both be launched independently. User-local
AppImages still need updates via their original installer, not rpm-ostree.

### User preferences, startup, and shortcut

Run from a logged-in Bazzite GNOME Wayland session, not through sudo:

```sh
bash scripts/bazzite/setup-bazzite-vicinae.sh --check
bash scripts/bazzite/setup-bazzite-vicinae.sh
```

KDE and X11 are intentionally rejected by this script; they need different
launcher/shortcut integration. GNOME's Adwaita Sans font, Python 3 with
PyGObject (`Gio`), curl, jq, fontconfig, desktop-file utilities, and a running
systemd user session are prerequisites. The Bazzite image and CLI Brewfile
provide these on the tested system; `--check` reports missing prerequisites.

The tracked `platforms/bazzite/vicinae/settings.json` contains only the font
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

### Verification and rollback

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

The settings helper has isolated tests that never contact live GNOME,
systemd, or vault services:

```sh
/usr/bin/python3 -B -m unittest discover -s scripts/bazzite/tests -v
```
