# Shared environment

These settings and CLI packages are used by both macOS and Bazzite.
Follow your [platform guide](../README.md) first, then apply the configs below
from the repository root.

## CLI packages

`shared/packages/Brewfile` contains git, GitHub CLI (`gh`), zsh, zellij,
zoxide, fzf, ripgrep, fd, jq, yazi, Neovim (`nvim`), Codex CLI (the `codex`
cask), and Claude Code (the `claude-code` cask). Both platform Brewfiles
include this list.
To install only the shared tools, with Homebrew already installed:

```sh
brew bundle --file=shared/packages/Brewfile
```

These are desired-package lists, not exact version locks. Homebrew installs
currently available versions, and formula support can differ by platform.
The command does not remove unlisted packages, install Oh My Zsh, or change
your login shell.

The Zellij config includes the embedded SPQR theme, keybindings, and built-in
plugin aliases. No separate theme file or external plugins are required.
It was originally used with Zellij 0.42.2; check compatibility with the
version installed by Homebrew.

## Install Zellij config

From the repository root, after installing Zellij:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/zellij"
cp -i shared/zellij/config.kdl "${XDG_CONFIG_HOME:-$HOME/.config}/zellij/config.kdl"
```

Back up an existing config first. `cp -i` asks before overwriting it.
Start a fresh Zellij session after installation.

Clipboard copying uses the terminal's OSC 52 support, with no OS-specific
clipboard command enabled. If copying fails, check terminal support before
adding a platform-specific command such as `pbcopy`, `wl-copy`, or `xclip`.


## Install Claude Code settings

`shared/claude/settings.json` is the user-level Claude Code config. It turns
off attribution: no `Co-Authored-By` trailer on commits and no "Generated with
Claude Code" line in pull request descriptions. `attribution` is the current
setting; `includeCoAuthoredBy` covers older Claude Code versions.

From the repository root:

```sh
mkdir -p ~/.claude
cp -i shared/claude/settings.json ~/.claude/settings.json
```

If `~/.claude/settings.json` already exists, merge the keys by hand instead
of overwriting it. The file is copied rather than symlinked because Claude
Code writes its own changes to it. It applies to every project on the machine;
a repository's `.claude/settings.json` can still override it. Start a new
Claude Code session to pick it up.

## Install zsh configuration

`shared/zsh/.zshrc` is a shared interactive-shell config for macOS and Linux.
It enables the git plugin and SPQR theme through Oh My Zsh, persistent history
(50,000 entries), shared history between local sessions, your existing aliases,
fzf keybindings, and zoxide when installed. NVM, Fabric, and Zellij auto-start
are not included. Homebrew is discovered using standard macOS/Linux paths. On
macOS it is always moved ahead of `/usr/bin`, even if an installer already added
it to PATH; on Linux it is added only when missing, keeping the distro's
ordering. `~/.local/bin` comes before Homebrew.

Install Oh My Zsh separately, normally at `~/.oh-my-zsh`, and use a font with
Powerline glyphs (such as a Nerd Font). A custom Oh My Zsh installation can be
selected by exporting `ZSH` before starting the shell.

From the repository root, back up an existing `~/.zshrc`, then symlink the config:

```sh
# Run this only when ~/.zshrc exists; choose an unused backup name.
mv ~/.zshrc ~/.zshrc.before-dotfiles
ln -s "$PWD/shared/zsh/.zshrc" "$HOME/.zshrc"
```

If there is no existing `.zshrc`, skip the `mv` command. Keep the checkout in
place and open a new zsh session. No active shell files are changed just by
cloning the repo or installing its packages.

The config resolves the symlink to locate the adjacent `themes/` directory,
so the SPQR theme needs no separate copy. Do not copy `.zshrc` out of the repo
on its own. If SPQR is absent, it selects Oh My Zsh's bundled `agnoster` theme.
If Oh My Zsh itself is absent, it uses a basic zsh prompt and completion instead.
Both SPQR and agnoster need Powerline glyphs for their intended appearance.
The SPQR file is an exact copy of the original active theme; its glyph setup
uses the `en_US.UTF-8` locale, which should be available on the target machine.

fzf 0.48.0 or newer provides Ctrl-R (history search), Ctrl-T (file selection),
and Alt-C (directory navigation). The config uses `fzf --zsh`, not the older
`~/.fzf.zsh` integration. Missing fzf or zoxide is simply skipped.

History is saved locally at `~/.zsh_history`, never in the repo. History sharing
is between sessions on the same machine, not between computers. Commands
starting with a space are excluded from saved history, but this is not a
security mechanism for secrets. The `gc` alias deliberately means
`git checkout`, overriding the git plugin's `git commit` alias.

Optional machine-specific overrides can live in `~/.zshrc.local`, which is
loaded last and is not part of this repository. No platform override files
are required yet.
