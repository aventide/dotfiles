# Ghostty AppImage with Homebrew Zellij

Install Ghostty separately as a Linux application; the macOS Ghostty cask
does not install it on Bazzite. Install the CLI tools with
`brew bundle --file=bazzite/packages/Brewfile` from the repository root.

When launching Ghostty from GNOME, the app may receive a PATH that excludes
Homebrew and `~/.local/bin`. A bare `command = zellij` can therefore fail even
when Zellij works in an existing terminal. Changes made in `.zshrc` cannot
help find Zellij here: Ghostty starts Zellij before Zellij starts the
interactive shell.

## Configure the launcher before the first desktop launch

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

## Verify and restart

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

Return to the [Bazzite setup guide](../README.md).
