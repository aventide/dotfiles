# dotfiles

Personal environment configuration for macOS and Bazzite Linux.

## Current contents

```text
dotfiles/
├── README.md
├── packages/
│   ├── common-cli.Brewfile
│   ├── macos.Brewfile
│   └── bazzite.Brewfile
└── shared/
    └── zellij/
        └── config.kdl
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
  Bazzite Linux: git, zsh, zellij, zoxide, fzf, ripgrep, fd, and jq.
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
by the Brewfiles. Document non-Homebrew installation steps in
`packages/bazzite.md` when those choices are made.

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


## Structure plan

Add directories when their actual configs are available:

```text
dotfiles/
├── README.md
├── packages/
│   ├── common-cli.Brewfile
│   ├── macos.Brewfile
│   ├── bazzite.Brewfile
│   └── bazzite.md              # Future non-Homebrew installation notes
├── shared/
│   ├── zellij/config.kdl

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
