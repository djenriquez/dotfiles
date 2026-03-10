# ${HOME}/.zshrc: user profile for zsh (zsh(1))

# =============================================================================
# PATH and package managers (must come first so tools are available below)
# =============================================================================

# Load Nix (multi-user install)
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Homebrew
if [ -d /home/linuxbrew/.linuxbrew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d /opt/homebrew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Core PATH setup
export GOPATH=$HOME/go
export PATH="$HOME/.local/bin:$GOPATH/bin:/usr/local/bin:$PATH"

# =============================================================================
# Environment variables
# =============================================================================

export GPG_TTY=$TTY
export DOTFILES_ZSH_DEBUG="${DOTFILES_ZSH_DEBUG:-0}"
export DOTFILES_ZSH_CACHE=$XDG_CACHE_HOME/zsh

BIN_DIR=~/.local/bin
[[ ! -d $BIN_DIR ]] && mkdir -p $BIN_DIR

CACHE_DIR=${XDG_CACHE_HOME:-~/.cache}
[[ ! -d $CACHE_DIR ]] && mkdir -p $CACHE_DIR

MAN_DIR=~/.local/man
[[ ! -d $MAN_DIR ]] && mkdir -p $MAN_DIR

COMP_DIR=~/.local/share/zsh/completions
[[ ! -d $COMP_DIR ]] && mkdir -p $COMP_DIR

# Extend PATH.
path+=${BIN_DIR}
fpath+=${COMP_DIR}
manpath+=${MAN_DIR}

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $dotfiles_win_home ]] || hash -d w=$dotfiles_win_home

# =============================================================================
# Helper functions
# =============================================================================

BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

pinfo() {
  printf '%s\n' "${BOLD}${GREY}>${NO_COLOR} $*"
}

pwarn() {
  printf '%s\n' "${YELLOW}! $*${NO_COLOR}"
}

pdebug() {
 if (( ${DOTFILES_ZSH_DEBUG} > 0 )); then
  printf '%s\n' "${BLUE}# $*${NO_COLOR}"
 fi
}

perror() {
  printf '%s\n' "${RED}x $*${NO_COLOR}" >&2
}

pcompleted() {
  printf '%s\n' "${GREEN}✓${NO_COLOR} $*"
}

has() {
  command -v -- "$1" 1>/dev/null 2>&1
}

readable() {
  [[ -r "$1" ]]
}

detect_arch() {
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  printf '%s' "${arch}"
}

detect_os() {
  platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
  printf '%s' "${platform}"
}

dedent() {
    local -n reference="$1"
    reference="$(echo "$reference" | sed 's/^[[:space:]]*//')"
}

download() {
  url="$1"
  base=$(basename "$url")
  file="${2-$base}"
  if has curl; then
    curl -fsSL -o $file $url && return 0 || rc=$?
    perror "Command failed (exit code $rc): ${BLUE}$@${NO_COLOR}"
    return $rc
  else
    perror "curl not found, please install curl."
    return 1
  fi
  perror "Command failed (exit code $rc): ${BLUE}${cmd}${NO_COLOR}"
  return $rc
}

unpack() {
  local archive=$1
  local bin_dir=$2
  local sudo=${3-}

  case "$archive" in
    *.tar.gz)
      mkdir -p "${bin_dir}"
      flags=$(test -n "${VERBOSE-}" && echo "-xzvf" || echo "-xzf")
      ${sudo} tar "${flags}" "${archive}" -C "${bin_dir}" --strip-components=1
      return 0
      ;;
    *.zip)
      flags=$(test -z "${VERBOSE-}" && echo "-qq" || echo "")
      UNZIP="${flags}" ${sudo} unzip "${archive}" -d "${bin_dir}"
      return 0
      ;;
  esac

  perror "Unknown package extension."
  printf "\n"
  return 1
}

# =============================================================================
# Plugin system
# =============================================================================

# 'bare-metal' plugin system inspired by
# https://github.com/mattmc3/zsh_unplugged#question-how-do-i-load-my-plugins-with-hypersonic-speed-rocket

plugin-load() {
  local repo plugin_name plugin_dir initfile initfiles
  ZPLUGINDIR=${ZPLUGINDIR:-$DOTFILES_ZSH_CACHE/plugins}
  for repo in $@; do
    plugin_name=${repo:t}
    plugin_dir=$ZPLUGINDIR/$plugin_name
    initfile=$plugin_dir/$plugin_name.plugin.zsh
    if [[ ! -d $plugin_dir ]]; then
      pinfo "Cloning $repo"
      # try ssh first, fall back to https
      command git clone -q --depth 1 --recursive --shallow-submodules git@github.com:$repo.git $plugin_dir 2>/dev/null || \
      command git clone -q --depth 1 --recursive --shallow-submodules https://github.com/$repo $plugin_dir 2>/dev/null
    fi
    if [[ ! -e $initfile ]]; then
      initfiles=($plugin_dir/*.plugin.{z,}sh(N) $plugin_dir/*.{z,}sh{-theme,}(N))
      [[ ${#initfiles[@]} -gt 0 ]] || { pwarn>&2 "Plugin has no init file '$repo'." && continue }
      ln -s "${initfiles[1]}" "$initfile"
    fi
    fpath+=$plugin_dir
    (( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
  done
}

plugin-compile() {
  ZPLUGINDIR=${ZPLUGINDIR:-$DOTFILES_ZSH_CACHE/plugins}
  autoload -U zrecompile
  local f
  for f in $ZPLUGINDIR/**/*.zsh{,-theme}(N); do
    pinfo "compiling $f"
    zrecompile -pq "$f"
  done
}

plugin-update () {
  ZPLUGINDIR=${ZPLUGINDIR:-$DOTFILES_ZSH_CACHE/plugins}
  for d in $ZPLUGINDIR/*/.git(/); do
    pinfo "Updating ${d:h:t}..."
    command git -C "${d:h}" pull --ff --recurse-submodules --depth 1 --rebase --autostash
  done
}

plugin-clean () {
  ZPLUGINDIR=${ZPLUGINDIR:-$DOTFILES_ZSH_CACHE/plugins}
  rm -rf $ZPLUGINDIR
}

plugin-list () {
  if ! [[ -d $ZPLUGINDIR ]]; then
    pinfo "no plugins installed."
  fi

  for d in $ZPLUGINDIR/*/.git; do
    command git -C "${d:h}" remote get-url origin
  done
}

plugin-help () {
  pinfo "Usage: ${BOLD}${GREEN}plugin${NO_COLOR} load|clean|list|update|compile"
}

_plugin() {
    local line state
    _arguments -C \
               "1: :->cmds" \
               "*::arg:->args"
    case "$state" in
        cmds)
            _values "plugin command" \
                    "load[Load a whitespace seperated list of plugins.]" \
                    "clean[Nuke your plugin cache.]" \
		    "list[List all registered plugins.]" \
		    "update[Update all plugins.]" \
		    "compile[compile existing plugins for rapid load.]"
            ;;
    esac
}

plugin () {
  subcommand=$1
  case $subcommand in
    "" | "-h" | "--help")
      plugin-help
      ;;
    *)
      shift
      plugin-${subcommand} $@
      if [ $? = 127 ]; then
        perror "$subcommand is not a known subcommand."
	      pinfo "  run plugin --help for a list of known commands."
	      exit 1
      fi
      ;;
  esac
}
compdef _plugin plugin

plugins+=(
    FFKL/s3cmd-zsh-plugin
    # anything loaded after this plugin gets deffered to background async execution
    romkatv/zsh-defer
    Aloxaf/fzf-tab
    zsh-users/zsh-autosuggestions
    zdharma-continuum/fast-syntax-highlighting
)

plugin load $plugins
unset plugins

# =============================================================================
# Shell options
# =============================================================================

# http://zsh.sourceforge.net/Doc/Release/Options.html
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu
setopt no_beep
setopt prompt_subst
setopt inc_append_history
setopt share_history
setopt hist_ignore_space
setopt no_nomatch
setopt interactive_comments
setopt hash_list_all
setopt complete_in_word
setopt noflowcontrol

# drop dot and dash from the word-char list
WORDCHARS=${WORDCHARS//./}    # remove "."
WORDCHARS=${WORDCHARS//-/}    # remove "-"

# Autoload functions.
autoload -Uz zmv

# Interactive Shell Environment Variables:
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=$XDG_CACHE_HOME/zsh-history
export CLICOLOR_FORCE=1la
export KEYTIMEOUT=1
export LIBRARY_LOG_TIMESTAMP=1
export PAGER="less -RF"

# =============================================================================
# Editor detection
# =============================================================================

if has code; then
  VSCODE_BIN="$(which code)"
  export EDITOR="$VSCODE_BIN"
  export KUBE_EDITOR="$VSCODE_BIN -w"
  export GIT_EDITOR="$VSCODE_BIN -w"
  sucode() {
    EDITOR="$VSCODE_BIN -w" command -- sudo -e "$@"
  }
elif has nvim; then
  export EDITOR=nvim
elif has vim; then
  export EDITOR=vim
elif has emacs; then
  export EDITOR=emacs
elif has nano; then
  printf "${RED}WARNING:${NO_COLOR} setting nano as editor. Install a better editor.\n"
  export EDITOR=nano
fi

# =============================================================================
# Completions
# =============================================================================

has kubectl && . <(kubectl completion zsh) && compdef k=kubectl
has gh && . <(gh completion -s zsh) && compdef _gh gh
has glab && . <(glab completion -s zsh) && compdef _glab glab
has chezmoi && . <(chezmoi completion zsh) && compdef _chezmoi chezmoi
has op && . <(op completion zsh) && compdef _op op

# =============================================================================
# Aliases
# =============================================================================

alias sudo='/usr/bin/sudo'
alias grep='grep --color=auto'

if has s3cmd; then
	compdef s3="s3cmd"
	alias s3="s3cmd"
fi

alias ls="ls --color=always"
alias ll="ls -l"

eza_list_flags='--color-scale --links --icons --git --group --changed'
alias list="$(has eza && printf "eza $eza_list_flags" || printf 'ls') --all -l --classify --group-directories-first --color=auto --time-style iso"
alias tree="$(has eza && printf 'eza --tree' || printf 'tree -C')"

# Kubernetes
alias k='kubectl'

# =============================================================================
# Tool initialization (after PATH is fully set up)
# =============================================================================

# Atuin - shell history
if [ -f "$HOME/.atuin/bin/env" ]; then
  . "$HOME/.atuin/bin/env"
  eval "$(atuin init zsh)"
fi

# Mise - runtime version manager
if has mise; then
  eval "$(mise activate zsh)"
fi

# Starship prompt (keep last for best results)
has starship && eval "$(starship init zsh)"

# =============================================================================
# User-local overrides
# =============================================================================

if [ -f "${HOME}/.zshrc-${USER}" ]; then
  source "${HOME}/.zshrc-${USER}"
fi
