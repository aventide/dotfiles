# dotfiles

Personal environment configuration for macOS and Bazzite Linux.

## Current contents

```text
dotfiles/
├── README.md
├── packages/
│   ├── common-cli.Brewfile
│   ├── macos.Brewfile
│   ├── bazzite.Brewfile
│   └── bazzite.md
└── shared/
    ├── zellij/
    │   └── config.kdl
    └── zsh/
        ├── .zshrc
        └── themes/SPQR.zsh-theme
```

The Zellij config includes the embedded SPQR theme, keybindings, and built-in
plugin aliases. It is copied from the active config, not either backup.
No separate theme file or external plugins are required. The source machine
uses Zellij 0.42.2; matching that version is the safest initial setup.

## Install packages

Homebrew must already be installed on the target machine. Package installation
is separate from config installation: these manifests do not install dotfiles,
Oh My Zsh, or change your login shell.

- `packages/common-cli.Brewfile`: shared user-space CLI tools for macOS and
  Bazzite Linux: git, GitHub CLI (`gh`), zsh, zellij, zoxide, fzf, ripgrep,
  fd, and jq.
- `packages/macos.Brewfile`: includes the shared list and adds the Ghostty cask.
- `packages/bazzite.Brewfile`: includes the shared list, with a place for future
  Bazzite-specific Homebrew formulas. It currently adds no extra packages.

From the repository root, run the command for your platform:

```sh
# macOS
brew bundle --file=packages/macos.Brewfile

# Bazzite Linux
brew bundle --file=packages/bazzite.Brewfile
```

Each platform manifest loads the common file relative to its own location.
To install only the shared tools, use
`brew bundle --file=packages/common-cli.Brewfile`.

These are desired-package lists, not exact version locks; Homebrew installs
currently available versions. In particular, the Zellij version may differ
from the original config's 0.42.2. Formula support can differ by platform.
No cleanup/removal of unlisted packages is requested by these commands.

Ghostty supports Linux, but its Homebrew cask does not. Install Ghostty on
Bazzite separately using a suitable Linux installation method. Likewise, keyd
requires separate host-level installation and service setup; it is not covered
by the Brewfiles. See [Bazzite setup notes](packages/bazzite.md) for the
Ghostty AppImage + Homebrew Zellij launcher setup. Apply those steps before
the first desktop launch to avoid depending on the GUI session's PATH.

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


## Install zsh configuration

`shared/zsh/.zshrc` is a shared interactive-shell config for macOS and Linux.
It enables the git plugin and SPQR theme through Oh My Zsh, persistent history
(50,000 entries), shared history between local sessions, your existing aliases,
fzf keybindings, and zoxide when installed. NVM, Fabric, and Zellij auto-start
are not included. Homebrew is discovered using standard macOS/Linux paths when
it is not already on PATH.

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

## Structure plan

Add directories when their actual configs are available:

```text
dotfiles/
├── README.md
├── packages/
│   ├── common-cli.Brewfile
│   ├── macos.Brewfile
│   ├── bazzite.Brewfile
│   └── bazzite.md              # Ghostty AppImage + Homebrew setup notes
├── shared/
│   ├── zellij/config.kdl
│   ├── zsh/.zshrc
│   ├── zsh/themes/SPQR.zsh-theme

│   └── ghostty/config          # If settings are genuinely shared
├── platforms/
│   ├── macos/
│   │   └── ghostty/config
│   └── bazzite/
│       ├── ghostty/config
│       └── keyd/default.conf
├── machines/                  # Only for necessary machine-specific exceptions
└── scripts/                   # Add installation automation when needed
```

Keep portable settings shared, platform-specific settings under `platforms/`,
and device-specific exceptions under `machines/`. Preserve existing configs
before extracting shared settings. Config composition depends on each tool;
this directory structure alone does not merge files.

Track software installation separately from config installation. On Bazzite,
document whether each tool is installed with Homebrew, Flatpak, Distrobox, or
on the host. Installing keyd configuration under `/etc/keyd/` and managing its
service requires explicit privileged steps.

Do not commit credentials, private keys, caches, session state, or backup configs.
