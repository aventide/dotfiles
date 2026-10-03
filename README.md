# dotfiles

Personal environment configuration for macOS and Bazzite Linux.

## Current contents

```text
dotfiles/
├── README.md
└── shared/
    └── zellij/
        └── config.kdl
```

The Zellij config includes the embedded SPQR theme, keybindings, and built-in
plugin aliases. It is copied from the active config, not either backup.
No separate theme file or external plugins are required. The source machine
uses Zellij 0.42.2; matching that version is the safest initial setup.

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
├── shared/
│   ├── zellij/config.kdl
│   └── ghostty/config          # If settings are genuinely shared
├── platforms/
│   ├── macos/
│   │   ├── ghostty/config
│   │   └── Brewfile
│   └── bazzite/
│       ├── ghostty/config
│       ├── keyd/default.conf
│       └── packages.md
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
