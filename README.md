# dotfiles

Personal environment configuration for macOS and Bazzite Linux. Start with
your platform's guide; it includes the shared setup in the appropriate order.

- [Bazzite setup](bazzite/README.md)
- [macOS setup](macos/README.md)
- [Shared Zsh, SPQR, Zellij, and Claude Code setup](shared/README.md)

Run documented commands from the repository root unless stated otherwise.
Homebrew must already be installed. Cloning the repo does not apply settings;
`./setup.sh` copies the shared configs into place (see `./setup.sh --help`),
after which the clone is no longer needed.

## Organization

```text
dotfiles/
├── README.md
├── setup.sh
├── shared/
│   ├── README.md
│   ├── packages/Brewfile
│   ├── claude/settings.json
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
platform Brewfiles include `shared/packages/Brewfile`. `setup.sh` copies the
shared configs into your home directory, backing up anything it replaces.

Add platform folders only when they have actual content. Keep machine-specific
overrides local, such as `~/.zshrc.local`; never commit credentials, private
keys, vault data, caches, session state, or config backups. Package manifests
and platform configs are applied separately by their own commands; `setup.sh`
installs only the shared configs (and runs `brew bundle` when asked).
