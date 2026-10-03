# Resolve the repository location even when ~/.zshrc is a symlink.
typeset -g DOTFILES_ZSH_DIR="${${(%):-%x}:A:h}"
typeset -g DOTFILES_ROOT="${DOTFILES_ZSH_DIR:h:h}"

typeset -U path
path=("$HOME/.local/bin" $path)
export PATH

# Discover Homebrew only when it is not already on PATH.
if ! (( $+commands[brew] )); then
  case "$OSTYPE" in
    darwin*)
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      ;;
    linux*)
      if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
      fi
      ;;
  esac
fi

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
