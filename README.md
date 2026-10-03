# dotfiles

Personal environment configuration for macOS and Bazzite Linux. Start with
your platform's guide; it includes the shared setup in the appropriate order.

- [Bazzite setup](bazzite/README.md)
- [macOS setup](macos/README.md)
- [Shared Zsh, SPQR, and Zellij setup](shared/README.md)

Run documented commands from the repository root unless stated otherwise.
Homebrew must already be installed. Cloning the repo does not apply settings.

## Organization

```text
dotfiles/
├── README.md
├── shared/
│   ├── README.md
│   ├── packages/Brewfile
│   ├── zsh/
│   │   ├── .zshrc
│   │   └── themes/SPQR.zsh-theme
│   └── zellij/config.kdl
├── bazzite/
│   ├── README.md
│   ├── packages/
│   │   ├── Brewfile
│   │   └── bazzite-desktop-app.txt
│   ├── config/
│   │   ├── ghostty/config
│   │   ├── keyd/keychron-link.conf
│   │   └── vicinae/settings.json
│   ├── scripts/
│   │   ├── install-apps.sh
│   │   ├── apply-keyboard-remap.sh
│   │   ├── apply-keyboard-repeat.sh
│   │   ├── setup-vicinae.sh
│   │   ├── lib/vicinae-settings.py
│   │   └── tests/test_vicinae_settings.py
│   └── docs/
│       ├── ghostty.md
│       ├── keyboard.md
│       └── vicinae.md
└── macos/
    ├── README.md
    └── packages/Brewfile
```

Choose the platform first, then the kind of file:

- `packages/` lists software to install and keeps each package manager separate.
- `config/` contains platform-specific application and device settings.
- `scripts/` contains commands that install packages or apply settings;
  `lib/` holds internal helpers and `tests/` holds isolated checks.
- `docs/` explains prerequisites, verification, troubleshooting, and rollback.

`shared/` holds settings and CLI packages used on both platforms. Both
platform Brewfiles include `shared/packages/Brewfile`. Shared config paths
remain stable so an existing `~/.zshrc` symlink keeps working.

Add platform folders only when they have actual content. Keep machine-specific
overrides local, such as `~/.zshrc.local`; never commit credentials, private
keys, vault data, caches, session state, or config backups. Package manifests
and config files are applied separately; the directory layout does not merge
or install them automatically.
