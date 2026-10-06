#!/usr/bin/env bash
# Copy the shared shell configs (zsh, SPQR theme, Zellij) into place so the
# clone can be deleted afterwards. Run ./setup.sh --help for options.
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")" && pwd)
backup_root="$HOME/.dotfiles-backup"
omz_dir=${ZSH:-$HOME/.oh-my-zsh}
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
ours_zshrc="$repo_dir/shared/zsh/.zshrc"
zshrc="$HOME/.zshrc"
zshrc_local="$HOME/.zshrc.local"

zshrc_mode=  # replace | layer | skip
brew_bundle= # yes | no
assume_yes=0
dry_run=0
restore=0

usage() {
    cat <<'EOF'
Usage: ./setup.sh [options]

Copies the shared configs into place, backing up anything it replaces:
  ~/.zshrc, the SPQR Oh My Zsh theme, and the Zellij config.
Shows a plan and asks before changing anything.

Options:
  --zshrc=MODE  What to do when ~/.zshrc already exists with other content:
                  replace  use ours; yours is backed up
                  layer    use ours; your old config moves to ~/.zshrc.local,
                           which ours loads last
                  skip     keep yours; ours is written to ~/.zshrc.dotfiles
  --brew        Also run brew bundle with this platform's Brewfile.
  --no-brew     Don't run brew bundle (the default with --yes).
  -y, --yes     Don't prompt. Needs --zshrc if ~/.zshrc would conflict.
  -n, --dry-run Show the plan and exit without changing anything.
  --restore     Undo the most recent setup run from its backup.
  -h, --help    Show this help.

Backups go to ~/.dotfiles-backup/<timestamp>/.
EOF
}

fail() { printf 'setup: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warning: %s\n' "$*" >&2; }

# Show paths under $HOME as ~/...
tidy() {
    case $1 in
        "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
        *) printf '%s' "$1" ;;
    esac
}

for arg in "$@"; do
    case $arg in
        --zshrc=replace|--zshrc=layer|--zshrc=skip) zshrc_mode=${arg#--zshrc=} ;;
        --zshrc=*) fail "unknown --zshrc mode '${arg#--zshrc=}' (use replace, layer or skip)" ;;
        --brew) brew_bundle=yes ;;
        --no-brew) brew_bundle=no ;;
        -y|--yes) assume_yes=1 ;;
        -n|--dry-run) dry_run=1 ;;
        --restore) restore=1 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown option '$arg' (see --help)" ;;
    esac
done

interactive=0
[ "$assume_yes" = 0 ] && [ -t 0 ] && interactive=1

# Each step is described during planning and performed when applying, so the
# plan shown to the user is exactly what runs.
applying=0
steps=0
step() {
    local desc=$1
    shift
    steps=$((steps + 1))
    if [ "$applying" = 1 ]; then
        "$@"
    else
        printf '  - %s\n' "$desc"
    fi
}
note() {
    [ "$applying" = 1 ] || printf '  · %s\n' "$*"
}

# --- Backups -----------------------------------------------------------------
# A run's backups mirror absolute paths under $run_dir/files; paths that did not
# exist before are listed in $run_dir/created (folders with a trailing /).

run_dir="$backup_root/$(date +%Y%m%d-%H%M%S)"
if [ -e "$run_dir" ] || [ -e "$run_dir.restored" ]; then
    n=2
    while [ -e "$run_dir-$n" ] || [ -e "$run_dir-$n.restored" ]; do n=$((n + 1)); done
    run_dir="$run_dir-$n"
fi

# Copy (not move) into the backup, so the original stays in place until the
# new file replaces it. -RP keeps a symlink as a symlink.
back_up() {
    local dest="$run_dir/files$1"
    mkdir -p "$(dirname "$dest")"
    cp -RPp "$1" "$dest"
}
note_created() {
    mkdir -p "$run_dir"
    printf '%s\n' "$1" >>"$run_dir/created"
}

# Create the target's folder, recording the topmost new one so undoing the run
# can remove it again.
make_parent() {
    local dir top
    dir=$(dirname "$1")
    [ ! -d "$dir" ] || return 0
    top=$dir
    while [ ! -d "$(dirname "$top")" ]; do top=$(dirname "$top"); done
    note_created "$top/"
    mkdir -p "$dir"
}

# Write a file in one step: build it beside the target, then rename it over
# the target, so the target is never missing or half-written.
pending_tmp=
write_file() { # target, then a command that prints the contents
    local target=$1
    shift
    make_parent "$target"
    pending_tmp="$target.dotfiles-tmp.$$"
    "$@" >"$pending_tmp"
    mv -f "$pending_tmp" "$target"
    pending_tmp=
}
replace_file() {
    back_up "$2"
    write_file "$2" cat "$1"
}
create_file() {
    note_created "$2"
    write_file "$2" cat "$1"
}

# Install src at target unless it is already identical. A symlink always counts
# as different so it is replaced by a real file that doesn't depend on the clone.
install_file() {
    local src=$1 target=$2 label=$3
    if [ -d "$target" ] && [ ! -L "$target" ]; then
        fail "$(tidy "$target") is a directory; move it aside and re-run."
    elif [ -L "$target" ] || { [ -e "$target" ] && ! cmp -s "$src" "$target"; }; then
        step "Back up $(tidy "$target") and replace it with $label" replace_file "$src" "$target"
    elif [ -e "$target" ]; then
        note "$(tidy "$target") is already up to date"
    else
        step "Install $label at $(tidy "$target")" create_file "$src" "$target"
    fi
}

# --- Setup -------------------------------------------------------------------

# True when ~/.zshrc has content that differs from ours.
zshrc_conflicts() {
    [ -s "$zshrc" ] && ! cmp -s "$ours_zshrc" "$zshrc"
}

brewfile() {
    case $OSTYPE in
        darwin*) printf '%s' "$repo_dir/macos/packages/Brewfile" ;;
        linux*)
            if grep -qs '^ID=bazzite' /etc/os-release; then
                printf '%s' "$repo_dir/bazzite/packages/Brewfile"
            else
                printf '%s' "$repo_dir/shared/packages/Brewfile"
            fi
            ;;
        *) fail "unsupported OS '$OSTYPE'" ;;
    esac
}

layered_local() {
    printf '# Previous ~/.zshrc, moved here by dotfiles setup.sh. Loaded last by ~/.zshrc.\n\n'
    cat "$zshrc"
    if [ -e "$zshrc_local" ]; then
        printf '\n# --- Previous ~/.zshrc.local ---\n\n'
        cat "$zshrc_local"
    fi
}
layer_zshrc() {
    back_up "$zshrc"
    if [ -e "$zshrc_local" ] || [ -L "$zshrc_local" ]; then
        back_up "$zshrc_local"
    else
        note_created "$zshrc_local"
    fi
    write_file "$zshrc_local" layered_local
    write_file "$zshrc" cat "$ours_zshrc"
}

setup_steps() {
    if [ "$brew_bundle" = yes ]; then
        local file
        file=$(brewfile)
        step "Install packages with brew bundle --file=${file#"$repo_dir"/}" brew bundle --file="$file"
    fi

    if ! zshrc_conflicts; then
        install_file "$ours_zshrc" "$zshrc" "the dotfiles zsh config"
    else
        case $zshrc_mode in
            replace)
                install_file "$ours_zshrc" "$zshrc" "the dotfiles zsh config"
                ;;
            layer)
                local desc="Back up ~/.zshrc, install the dotfiles zsh config, and move your old config to ~/.zshrc.local"
                [ ! -e "$zshrc_local" ] || desc="$desc (ahead of your existing ~/.zshrc.local, which is backed up)"
                step "$desc" layer_zshrc
                ;;
            skip)
                install_file "$ours_zshrc" "$HOME/.zshrc.dotfiles" "the dotfiles zsh config"
                note "~/.zshrc is left unchanged; merge ~/.zshrc.dotfiles into it by hand"
                ;;
        esac
    fi

    if [ -d "$omz_dir" ]; then
        install_file "$repo_dir/shared/zsh/themes/SPQR.zsh-theme" \
            "${ZSH_CUSTOM:-$omz_dir/custom}/themes/SPQR.zsh-theme" "the SPQR theme"
    else
        note "Oh My Zsh not found at $(tidy "$omz_dir"); skipping the SPQR theme"
    fi

    install_file "$repo_dir/shared/zellij/config.kdl" "$config_dir/zellij/config.kdl" "the Zellij config"
}

check_prerequisites() {
    command -v zsh >/dev/null 2>&1 || warn 'zsh is not installed; the zsh config has no effect until it is.'
    if ! command -v brew >/dev/null 2>&1; then
        [ "$brew_bundle" != yes ] || fail 'Homebrew is not installed (see https://brew.sh); cannot use --brew.'
        warn 'Homebrew is not installed (see https://brew.sh); the Brewfile tools will be missing.'
        brew_bundle=no
    fi
    if [ ! -d "$omz_dir" ]; then
        warn "Oh My Zsh is not installed. Install it with --keep-zshrc (otherwise its installer replaces ~/.zshrc), then re-run setup for the SPQR theme:"
        printf '  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc\n' >&2
    fi
    case ${SHELL:-} in
        */zsh) ;;
        *) warn "your login shell is ${SHELL:-unknown}, not zsh. To switch: chsh -s \"\$(command -v zsh)\"" ;;
    esac
}

choose_zshrc_mode() {
    zshrc_conflicts || return 0
    [ -z "$zshrc_mode" ] || return 0
    [ "$interactive" = 1 ] || fail '~/.zshrc already exists with other content; pass --zshrc=replace, layer or skip.'
    cat <<'EOF'
~/.zshrc already exists with different content. What should setup do?
  1) replace  Use the dotfiles config; yours is backed up.
  2) layer    Use the dotfiles config; your old config moves to ~/.zshrc.local,
              which loads last, so your settings still apply.
  3) skip     Keep yours; the dotfiles config is saved as ~/.zshrc.dotfiles
              for you to merge by hand.
EOF
    local reply
    while :; do
        printf 'Choose 1-3: '
        read -r reply || fail 'no answer given.'
        case $reply in
            1|replace) zshrc_mode=replace; return ;;
            2|layer) zshrc_mode=layer; return ;;
            3|skip) zshrc_mode=skip; return ;;
        esac
    done
}

check_layer() {
    [ "$zshrc_mode" = layer ] && zshrc_conflicts || return 0
    if grep -q 'zshrc\.local' "$zshrc"; then
        fail '~/.zshrc already refers to ~/.zshrc.local, so layering could load it recursively. Use --zshrc=replace or skip.'
    fi
    if grep -q 'oh-my-zsh\.sh' "$zshrc"; then
        warn 'your old ~/.zshrc loads Oh My Zsh, which the dotfiles config also does. After setup, remove that part from ~/.zshrc.local so it does not load twice.'
    fi
}

choose_brew_bundle() {
    [ -z "$brew_bundle" ] || return 0
    brew_bundle=no
    [ "$interactive" = 1 ] || return 0
    local reply
    printf 'Install the Brewfile packages with brew bundle? [y/N] '
    read -r reply || reply=
    case $reply in [yY]*) brew_bundle=yes ;; esac
}

# --- Restore -----------------------------------------------------------------

latest_run=

set_aside() {
    local dest="$latest_run/replaced$1"
    mkdir -p "$(dirname "$dest")"
    mv "$1" "$dest"
}
# Remove a folder and any empty folders inside it; anything with files stays.
remove_empty_dirs() {
    find "$1" -depth -type d -exec rmdir {} \; 2>/dev/null || true
}
# Keep a copy of the current file, then rename the backup over it in one step.
restore_one() {
    local saved=$1 target=$2 dest="$latest_run/replaced$2"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -RPp "$target" "$dest"
    fi
    mkdir -p "$(dirname "$target")"
    mv -f "$saved" "$target"
}

restore_steps() {
    local saved target files=
    [ ! -d "$latest_run/files" ] || files=$(cd "$latest_run/files" && find . ! -type d)
    while IFS= read -r saved; do
        [ -n "$saved" ] || continue
        target=${saved#.}
        step "Restore $(tidy "$target") from backup" restore_one "$latest_run/files$target" "$target"
    done <<<"$files"
    if [ -f "$latest_run/created" ]; then
        while IFS= read -r target; do
            case $target in */) continue ;; esac
            if [ -e "$target" ] || [ -L "$target" ]; then
                step "Remove $(tidy "$target"), which setup created (kept in the backup folder)" set_aside "$target"
            fi
        done <"$latest_run/created"
        while IFS= read -r target; do
            case $target in */) ;; *) continue ;; esac
            [ -d "$target" ] || continue
            step "Remove $(tidy "${target%/}") if empty, which setup created" remove_empty_dirs "${target%/}"
        done <"$latest_run/created"
    fi
    [ "$steps" = 0 ] || step "Mark backup $(tidy "$latest_run") as restored" mv "$latest_run" "$latest_run.restored"
}

find_latest_run() {
    local dir
    # The glob sorts by name, so the newest timestamp comes last.
    for dir in "$backup_root"/*; do
        [ -d "$dir" ] || continue
        case $dir in *.restored) continue ;; esac
        latest_run=$dir
    done
    [ -n "$latest_run" ] || fail "no setup backups to restore in $(tidy "$backup_root")."
}

# --- Main --------------------------------------------------------------------

# Remove a half-written temp file, and if setup fails or is interrupted
# part-way, undo what this run already changed so nothing is left half-installed.
interrupted=0
on_exit() {
    local status=$?
    [ -z "$pending_tmp" ] || rm -f "$pending_tmp"
    if [ "$status" != 0 ] && [ "$applying" = 1 ] && [ "$restore" = 0 ] && [ -d "$run_dir" ]; then
        if [ "$interrupted" = 1 ]; then
            printf 'setup: interrupted; undoing the changes made so far.\n' >&2
        else
            printf 'setup: failed part-way; undoing the changes made so far.\n' >&2
        fi
        set +e
        latest_run=$run_dir
        restore_steps
        rm -rf "$run_dir" "$run_dir.restored"
        rmdir "$backup_root" 2>/dev/null
    fi
}
trap on_exit EXIT

if [ "$restore" = 1 ]; then
    find_latest_run
    plan=restore_steps
else
    check_prerequisites
    choose_zshrc_mode
    check_layer
    choose_brew_bundle
    plan=setup_steps
fi

printf '\nPlan:\n'
$plan
if [ "$steps" = 0 ]; then
    printf 'Nothing to do.\n'
    exit 0
fi
if [ "$dry_run" = 1 ]; then
    printf 'Dry run: nothing was changed.\n'
    exit 0
fi
if [ "$assume_yes" = 0 ]; then
    [ "$interactive" = 1 ] || fail 'no terminal to confirm the plan; re-run with --yes.'
    printf 'Apply these changes? [y/N] '
    read -r reply || reply=
    case $reply in [yY]*) ;; *) printf 'Cancelled; nothing was changed.\n'; exit 0 ;; esac
fi

# Don't let Ctrl-C kill the script outright while applying. If it stops the
# command that is running (brew bundle, a copy), setup fails and on_exit undoes
# the run; if it lands between commands, setup finishes first.
trap 'interrupted=1' INT TERM
applying=1
steps=0
$plan
trap - INT TERM
[ "$interrupted" = 0 ] || printf 'Interrupt received; finished applying first so nothing was left half-done.\n'
if [ "$restore" = 1 ]; then
    printf 'Restored.\n'
    [ ! -d "$latest_run.restored/replaced" ] || printf 'The files it replaced are kept in %s/replaced/.\n' "$(tidy "$latest_run.restored")"
else
    printf 'Done. Open a new terminal to use the config.\n'
    [ ! -d "$run_dir" ] || printf 'Backups are in %s; undo with ./setup.sh --restore.\n' "$(tidy "$run_dir")"
fi
