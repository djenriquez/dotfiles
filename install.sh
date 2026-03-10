#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Helper functions ---

info() { printf '\033[1m>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }
error() { printf '\033[31mx %s\033[0m\n' "$*" >&2; }

has() { command -v "$1" &>/dev/null; }

link_file() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -f "$dst" ]; then
    info "Backing up existing $dst to ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  ln -s "$src" "$dst"
  info "Linked $(basename "$src") -> $dst"
}

# --- Install Homebrew ---

install_homebrew() {
  if has brew; then
    info "Homebrew already installed"
    return
  fi

  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Load brew into current session
  if [ -d /home/linuxbrew/.linuxbrew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -d /opt/homebrew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

# --- Install Brew packages ---

install_brew_packages() {
  if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    info "Installing packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock
  else
    warn "No Brewfile found, skipping package install"
  fi
}

# --- Install Mise (not available via brew) ---

install_mise() {
  if has mise; then
    info "Mise already installed"
    return
  fi

  info "Installing mise..."
  curl -fsSL https://mise.run | sh
}

# --- Symlink dotfiles ---

link_dotfiles() {
  info "Linking dotfiles..."

  # Shell configs
  link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
  link_file "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
  link_file "$DOTFILES_DIR/.profile" "$HOME/.profile"
  link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

  # XDG config files
  mkdir -p "$HOME/.config/atuin"
  link_file "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
  link_file "$DOTFILES_DIR/.config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
}

# --- Main ---

main() {
  info "Dotfiles installer starting..."
  echo ""

  # Ensure basic deps exist (git, curl)
  for cmd in git curl; do
    if ! has "$cmd"; then
      error "$cmd is required but not found. Install it first (e.g. sudo apt install $cmd)"
      exit 1
    fi
  done

  if ! has zsh; then
    warn "zsh not found, installing via apt..."
    sudo apt-get update -qq && sudo apt-get install -y -qq zsh
  fi

  install_homebrew
  install_brew_packages
  install_mise
  link_dotfiles

  echo ""
  info "Done! To finish setup:"
  info "  1. Restart your shell or run: exec zsh"
  info "  2. Run 'gh auth login' to set up GitHub credentials"
  info "  3. Run 'atuin register' or 'atuin login' for shell history sync"
}

main "$@"
