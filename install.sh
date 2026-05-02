#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Dotfiles Installer
# ============================================================
# Features:
# - Creates backups of existing configs
# - Symlinks dotfiles into $HOME
# - Installs common package managers if available
# - Supports macOS + Linux
# - Safe, idempotent re-runs
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ------------------------------------------------------------
# Logging Helpers
# ------------------------------------------------------------
info() {
  printf "\033[1;34m[INFO]\033[0m %s\n" "$1"
}

success() {
  printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"
}

warn() {
  printf "\033[1;33m[WARN]\033[0m %s\n" "$1"
}

error() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"
}

# ------------------------------------------------------------
# OS Detection
# ------------------------------------------------------------
OS="unknown"

case "$(uname -s)" in
  Darwin)
    OS="macos"
    ;;
  Linux)
    OS="linux"
    ;;
  *)
    error "Unsupported OS"
    exit 1
    ;;
esac

info "Detected OS: $OS"

# ------------------------------------------------------------
# Create Backup Directory
# ------------------------------------------------------------
mkdir -p "$BACKUP_DIR"

# ------------------------------------------------------------
# Helper: Backup Existing File
# ------------------------------------------------------------
backup_file() {
  local target="$1"

  if [ -e "$target" ] || [ -L "$target" ]; then
    info "Backing up $target"
    mkdir -p "$BACKUP_DIR$(dirname "$target")"
    mv "$target" "$BACKUP_DIR$target"
  fi
}

# ------------------------------------------------------------
# Helper: Create Symlink
# ------------------------------------------------------------
link_file() {
  local source="$1"
  local target="$2"

  backup_file "$target"

  mkdir -p "$(dirname "$target")"

  ln -sfn "$source" "$target"
  success "Linked $target -> $source"
}

# ------------------------------------------------------------
# Package Installation
# ------------------------------------------------------------
install_packages() {
  info "Installing dependencies"

  if [ "$OS" = "macos" ]; then
    if ! command -v brew >/dev/null 2>&1; then
      warn "Homebrew not found"
      warn "Install Homebrew manually: https://brew.sh"
    else
      brew update

      packages=(
        git
        zsh
        neovim
        tmux
        fzf
        ripgrep
        bat
        eza
      )

      for pkg in "${packages[@]}"; do
        if brew list "$pkg" >/dev/null 2>&1; then
          info "$pkg already installed"
        else
          brew install "$pkg"
        fi
      done
    fi
  fi

  if [ "$OS" = "linux" ]; then
    if command -v apt >/dev/null 2>&1; then
      sudo apt update

      sudo apt install -y \
        git \
        zsh \
        neovim \
        tmux \
        fzf \
        ripgrep \
        bat \
        curl
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Syu --noconfirm \
        git \
        zsh \
        neovim \
        tmux \
        fzf \
        ripgrep \
        bat \
        curl
    else
      warn "No supported package manager found"
    fi
  fi
}

# ------------------------------------------------------------
# Copy Dotfiles
# ------------------------------------------------------------
setup_configs() {
  info "Copying config directories"

  mkdir -p "$HOME/.config"

  configs=(
    fontconfig
    hypr
    kitty
    nautilus
    nvim
    rofi
    starship
    waybar
  )

  for config in "${configs[@]}"; do
    source="$DOTFILES_DIR/$config"
    target="$HOME/.config/$config"

    if [ -d "$source" ]; then
      backup_file "$target"
      cp -r "$source" "$target"
      success "Copied $config -> $target"
    else
      warn "Missing config directory: $source"
    fi
  done
}



# ------------------------------------------------------------
# Change Default Shell
# ------------------------------------------------------------
setup_shell() {
  if command -v zsh >/dev/null 2>&1; then
    local zsh_path
    zsh_path="$(command -v zsh)"

    if [ "$SHELL" != "$zsh_path" ]; then
      info "Changing default shell to zsh"
      chsh -s "$zsh_path"
    else
      info "zsh already set as default shell"
    fi
  fi
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main() {
  info "Starting dotfiles installation"

  install_packages
  setup_configs
  setup_shell

  success "Dotfiles installation complete"
  info "Backup directory: $BACKUP_DIR"
}

main "$@"
