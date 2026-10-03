# Keyboard

Remapping and held-key repeat are separate settings. Apply either or both as
needed; each section below includes verification and rollback guidance.

## Keychron remapping

The Keychron profile maps physical Command to Control and Caps Lock to Super.
Ghostty bindings provide selection-aware copy and clipboard paste, and GNOME
gets a Caps Lock+T fullscreen launcher shortcut. The installer uses GNOME's
dconf backend.

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

The profile at `bazzite/config/keyd/keychron-link.conf` targets the original
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
bash bazzite/scripts/apply-keyboard-remap.sh --check
bash bazzite/scripts/apply-keyboard-remap.sh
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
configure and verify the [absolute-path Zellij launcher](ghostty.md).

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

## Key repeat (Wayland only)

Run explicitly from a terminal in your desktop session, as your regular user.
This command applies immediately and has no `--check` mode:

```sh
sh bazzite/scripts/apply-keyboard-repeat.sh
```

The script detects GNOME or KDE Plasma 6 and rejects X11 and unsupported
sessions before changing settings. It sets a 150 ms initial repeat delay and
approximately 67 repeats per second (GNOME: 15 ms interval; KDE: 67 Hz).
These settings change held-key repeat, not initial keypress latency. A literal
zero delay is not the default; edit `delay_ms` in the script if desired, noting
that individual clients may handle zero differently.

GNOME selects the dconf backend explicitly, including from AppImage terminals,
uses the keyboard `gsettings` schema, and prints previous values before
applying changes. To restore those values, use `gsettings set` with the printed
values and `GSETTINGS_BACKEND=dconf`; `gsettings reset` restores schema defaults
instead of your old values.
KDE uses `kwriteconfig6` to update only the repeat keys in the `[Keyboard]`
group of `kcminputrc`, preserving other settings. Existing configuration is
backed up to `kcminputrc.before-dotfiles-keyboard`; subsequent runs refuse to
overwrite that backup. Log out and back in after applying KDE settings.

No sudo, keyd changes, package installation, or automatic shell-startup execution
is involved.

Return to the [Bazzite setup guide](../README.md).
