# macOS setup

Run commands from the repository root, with Homebrew already installed.

## Install packages

```sh
brew bundle --file=macos/packages/Brewfile
```

This includes the [shared CLI packages](../shared/packages/Brewfile) and the
Ghostty and [Helium browser](https://formulae.brew.sh/cask/helium-browser)
casks. It does not remove other installed packages or apply configs.

## Configure the shell and terminal

Install Oh My Zsh with `--keep-zshrc`, then run `./setup.sh` to copy the Zsh
config, SPQR theme, and Zellij config into place. The
[shared setup guide](../shared/README.md#install-the-configs) explains its
options and what happens to an existing `~/.zshrc`. Setup does not change your
login shell.

The repo currently has no macOS-specific Ghostty configuration, keyboard
remapping, or launcher setup. Add those under `macos/config/` and
`macos/scripts/` when actual settings are available.
