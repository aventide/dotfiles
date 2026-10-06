# Shared environment

These settings and CLI packages are used by both macOS and Bazzite.
Follow your [platform guide](../README.md) first, then install the configs
below with `./setup.sh` from the repository root.

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
version installed by Homebrew. Start a fresh Zellij session after installing it.

Clipboard copying uses the terminal's OSC 52 support, with no OS-specific
clipboard command enabled. If copying fails, check terminal support before
adding a platform-specific command such as `pbcopy`, `wl-copy`, or `xclip`.

## Install the configs

From the repository root, after installing Homebrew and, ideally, Oh My Zsh:

```sh
./setup.sh
```

The script copies these files into place, so the clone can be moved or
deleted afterwards:

| Repo file | Installed at |
| --- | --- |
| `shared/zsh/.zshrc` | `~/.zshrc` |
| `shared/zsh/themes/SPQR.zsh-theme` | `~/.oh-my-zsh/custom/themes/` (skipped without Oh My Zsh) |
| `shared/zellij/config.kdl` | `~/.config/zellij/config.kdl` |

It shows a plan and asks before changing anything. Files that already match
are left alone; anything it replaces is moved to
`~/.dotfiles-backup/<timestamp>/` first. Nothing is written until you confirm
the plan, and if setup fails or is interrupted while applying it, it undoes
that run's changes. Re-run it after pulling changes to update the installed
copies.

If `~/.zshrc` already exists with other content, setup asks what to do:

- **replace**: use the dotfiles config; yours is backed up.
- **layer**: use the dotfiles config and move your old config to
  `~/.zshrc.local`, which loads last, so your settings still apply. If your
  old config also loads Oh My Zsh, remove that part afterwards so it does not
  load twice.
- **skip**: keep yours; the dotfiles config is written to `~/.zshrc.dotfiles`
  for you (or an agent) to merge by hand.

| Option | Effect |
| --- | --- |
| `--zshrc=replace\|layer\|skip` | Answer the `~/.zshrc` question in advance |
| `--brew` / `--no-brew` | Run (or don't run) `brew bundle` with this platform's Brewfile |
| `--yes` | Don't prompt; requires `--zshrc` when `~/.zshrc` conflicts and skips `brew bundle` unless `--brew` is given |
| `--dry-run` | Show the plan without changing anything |
| `--restore` | Undo the most recent run, restoring its backups; repeat to go further back |

Setup does not install Oh My Zsh, Homebrew, or fonts, and does not change your
login shell; it warns when they are missing. Install Oh My Zsh with
`--keep-zshrc`, or its installer replaces `~/.zshrc`:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
```

If you install Oh My Zsh after running setup, run setup again to add the
SPQR theme.

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

## zsh configuration

`shared/zsh/.zshrc` is a shared interactive-shell config for macOS and Linux.
It enables the git plugin and SPQR theme through Oh My Zsh, persistent history
(50,000 entries), shared history between local sessions, your existing aliases,
fzf keybindings, and zoxide when installed. NVM, Fabric, and Zellij auto-start
are not included. Homebrew is discovered using standard macOS/Linux paths. On
macOS it is always moved ahead of `/usr/bin`, even if an installer already added
it to PATH; on Linux it is added only when missing, keeping the distro's
ordering. `~/.local/bin` comes before Homebrew.

Use a font with Powerline glyphs (such as a Nerd Font). A custom Oh My Zsh
installation can be selected by exporting `ZSH` before starting the shell.
If SPQR is absent, the config selects Oh My Zsh's bundled `agnoster` theme.
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

Put machine-specific changes in `~/.zshrc.local`, which is loaded last and is
not part of this repository. Setup never overwrites it except to add your old
config when you choose **layer** (after backing it up). Edits made directly to
`~/.zshrc` are replaced the next time setup runs, after a backup.
