# Bazzite setup

Run commands from the repository root in a terminal belonging to your regular
desktop user. Individual installers request sudo when required.

## Setup order

1. [Install CLI packages](#cli-packages).
2. Apply the [shared Zsh, SPQR, and Zellij setup](../shared/README.md).
3. Install Ghostty separately and [verify its Zellij launcher](docs/ghostty.md)
   before relying on a desktop launch.
4. Follow the [keyboard guide](docs/keyboard.md) for keyd prerequisites,
   device selection, Command-key remapping, and repeat settings.
5. For a new native Vicinae installation, [install desktop apps](#desktop-apps)
   and reboot if a deployment was staged. An existing user-local Vicinae
   installation can proceed directly to the next step.
6. [Configure Vicinae](docs/vicinae.md) after verifying the keyboard remap,
   so its Ctrl+Space shortcut corresponds to physical Command+Space.
7. Optionally [authenticate rbw](#rbw-authentication) for your own vault.

Vicinae setup supports GNOME on Wayland. Keyboard repeat supports GNOME and
KDE Plasma 6 on Wayland; the keyboard guide explains the remapping scope.

## CLI packages

With Homebrew already installed:

```sh
brew bundle --file=bazzite/packages/Brewfile
```

This includes the [shared CLI packages](../shared/packages/Brewfile) and adds
`rbw`. It does not install Ghostty or keyd, apply configs, or change your
login shell. Ghostty uses a separate Linux installation; keyd requires host
installation as described in the keyboard guide.

## Desktop apps

`bazzite/packages/bazzite-desktop-app.txt` tracks native desktop RPMs separately
from the CLI Brewfile. It currently lists `vicinae`. Future entries must be RPM
package names available from the enabled host repositories, not Flatpak IDs,
Homebrew formulas, URLs, or shell commands.

[Vicinae's installation documentation](https://docs.vicinae.com/install/linux)
recommends the Terra RPM on Bazzite. Terra is a third-party Fedora repository,
not Homebrew and not a separate application sandbox. Bazzite already ships
its repository configuration. The installer enables only the `[terra]` entry
in `/etc/yum.repos.d/terra.repo`, retaining signature checks and other sections.
It keeps the first original repository config at
`/etc/yum.repos.d/terra.repo.before-dotfiles-desktop-apps`.

```sh
bash bazzite/scripts/install-apps.sh --check
bash bazzite/scripts/install-apps.sh
```

The desktop installer needs sudo for the repository flag and `rpm-ostree`
request. `--check` is read-only and does not use sudo or download anything.
Repeated runs skip installed RPMs and use `--idempotent` for pending requests.
A new deployment generally needs a reboot; the script never reboots or uses
`--apply-live` automatically. Reboot when instructed, then continue with
[Vicinae setup](docs/vicinae.md).
Native RPMs are updated through the normal Bazzite deployment/update process.

To remove a deliberately layered package, use `sudo rpm-ostree uninstall NAME`
and reboot; do not use this for packages built into the base image. See the
[Vicinae guide](docs/vicinae.md#verification-and-rollback) before undoing its
integration or restoring the Terra repository configuration.

## rbw authentication

The CLI Brewfile includes `rbw`, the unofficial Bitwarden CLI. Authentication
is configured locally after installation; never put vault
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

## Script entry points

| Script under `bazzite/scripts/` | Purpose | Read-only check |
| --- | --- | --- |
| `install-apps.sh` | Request the listed native desktop RPMs | `--check` |
| `apply-keyboard-remap.sh` | Apply keyd, Ghostty bindings, and the GNOME fullscreen shortcut | `--check` |
| `apply-keyboard-repeat.sh` | Apply the held-key repeat settings | None; applies immediately |
| `setup-vicinae.sh` | Apply Vicinae preferences and desktop integration | `--check` |

Scripts resolve their config and package files relative to their own location.
The Python helper in `scripts/lib/` is called by Vicinae setup.

## Verification for repo changes

The settings helper has isolated tests that never contact live GNOME,
systemd, or vault services:

```sh
/usr/bin/python3 -B -m unittest discover -s bazzite/scripts/tests -v
```

Shell syntax can also be checked without applying settings:

```sh
bash -n bazzite/scripts/install-apps.sh
bash -n bazzite/scripts/apply-keyboard-remap.sh
bash -n bazzite/scripts/setup-vicinae.sh
sh -n bazzite/scripts/apply-keyboard-repeat.sh
```

These checks do not exercise a full fresh-machine installation. Use each
guide's verification steps after actually applying that part of the setup.
