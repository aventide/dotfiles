# macOS setup

Run commands from the repository root, with Homebrew already installed.

## Install packages

```sh
brew bundle --file=macos/packages/Brewfile
```

This includes the [shared CLI packages](../shared/packages/Brewfile) and the
Ghostty cask. It does not remove other installed packages or apply configs.

## Configure the shell and terminal

Follow the [shared setup guide](../shared/README.md) to install Oh My Zsh,
link the Zsh config and SPQR theme, and copy the Zellij config. These steps
do not change your login shell.

The repo currently has no macOS-specific Ghostty configuration, keyboard
remapping, or launcher setup. Add those under `macos/config/` and
`macos/scripts/` when actual settings are available.
