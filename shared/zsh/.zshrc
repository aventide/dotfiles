# Resolve the repository location even when ~/.zshrc is a symlink.
typeset -g DOTFILES_ZSH_DIR="${${(%):-%x}:A:h}"
typeset -g DOTFILES_ROOT="${DOTFILES_ZSH_DIR:h:h}"

typeset -U path fpath

# Add Homebrew's bin dirs to PATH. Set directly rather than `eval "$(brew shellenv)"`
# to avoid starting brew on every new shell.
_dotfiles_brew_prepend() {
  export HOMEBREW_PREFIX=$1
  path=($1/bin $1/sbin $path)
  fpath=($1/share/zsh/site-functions $fpath)
}
case "$OSTYPE" in
  darwin*)
    # Always prepend so Brewfile tools (git, zsh, ...) beat Apple's /usr/bin versions,
    # even if already on PATH: the .pkg installer adds it after /usr/bin.
    if [[ -x /opt/homebrew/bin/brew ]]; then
      _dotfiles_brew_prepend /opt/homebrew
    elif [[ -x /usr/local/bin/brew ]]; then
      _dotfiles_brew_prepend /usr/local
    fi
    ;;
  linux*)
    # Add only if missing; otherwise keep the distro's ordering.
    if ! (( $+commands[brew] )) && [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
      _dotfiles_brew_prepend /home/linuxbrew/.linuxbrew
    fi
    ;;
esac
unfunction _dotfiles_brew_prepend

# Personal scripts in ~/.local/bin take priority over Homebrew.
path=("$HOME/.local/bin" $path)
export PATH

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="$DOTFILES_ZSH_DIR"
ZSH_THEME="SPQR"
[[ -r "$ZSH_CUSTOM/themes/SPQR.zsh-theme" ]] || ZSH_THEME="agnoster"
plugins=(git)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit
  compinit
  PROMPT='%n@%m %~ %# '
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_IGNORE_SPACE

alias gpl='git pull'
alias gps='git push'
alias lf='npm run lint:fix'
# Preserve the existing meaning, overriding Oh My Zsh's git-commit alias.
alias gc='git checkout'

# Requires fzf >= 0.48.0; do not also source ~/.fzf.zsh.
if (( $+commands[fzf] )); then
  if _dotfiles_fzf_init=$(fzf --zsh 2>/dev/null); then
    eval "$_dotfiles_fzf_init"
  else
    print -u2 'dotfiles: fzf shell integration requires fzf >= 0.48.0; upgrade fzf to enable its keybindings.'
  fi
  unset _dotfiles_fzf_init
fi
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Private and machine-specific overrides stay outside version control.
[[ ! -r "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"
