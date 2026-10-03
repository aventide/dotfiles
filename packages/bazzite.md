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
bash scripts/apply-bazzite-keyboard.sh --check
bash scripts/apply-bazzite-keyboard.sh
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
