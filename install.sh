#!/usr/bin/env bash
set -euo pipefail

# Resolve the repo root (where this script lives), following symlinks
REPO_ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)"

PACKAGES=(
    figletfonts shell xdg git yazi tmux nvim neovide ohmyposh alacritty
    wezterm fastfetch espanso xorg picom dunst qutebrowser discordo Thunar
    lf pipewire gurk twt lazygit rofi quickshell hypr mako startpage foot
    tridactyl systemd life-wallpaper btop xdg-desktop-portal
)

function is_stow_installed() { command -v stow &>/dev/null; }

if ! is_stow_installed; then
    echo "Stow is not installed. Please install stow." >&2
    exit 1
fi

function stow_pkg()   { stow --target="$HOME" --adopt -v "$1"; }
function unstow_pkg() { stow --target="$HOME" -D "$1" 2>/dev/null || true; }

function stow_all() {
    for pkg in "${PACKAGES[@]}"; do stow_pkg "$pkg"; done
    ln -sf ~/.config/zsh/.zshenv ~/.zshenv
}

function unstow_all() {
    for pkg in "${PACKAGES[@]}"; do unstow_pkg "$pkg"; done
    rm -f ~/.zshenv
}

# ---------- relocate mode ----------
# Usage: ./install.sh --relocate /new/path/to/dotfiles
if [[ "${1:-}" == "--relocate" ]]; then
    NEW_REPO="${2:?usage: $0 --relocate /new/path}"
    NEW_REPO="$(realpath -m -- "$NEW_REPO")"

    if [[ "$NEW_REPO" == "$REPO_ROOT" ]]; then
        echo "Already at $NEW_REPO, nothing to do."
        exit 0
    fi

    echo "Unstowing from $REPO_ROOT..."
    cd "$REPO_ROOT"
    unstow_all

    echo "Moving $REPO_ROOT -> $NEW_REPO"
    mkdir -p "$(dirname -- "$NEW_REPO")"
    cd /                       # step out of the dir we're about to move
    mv -- "$REPO_ROOT" "$NEW_REPO"

    echo "Re-exec from $NEW_REPO/install.sh"
    exec "$NEW_REPO/$(basename -- "$0")"
fi

# ---------- normal install ----------
cd "$REPO_ROOT"
stow_all

echo "Enabling startpage service..."
systemctl --user daemon-reload
systemctl --user enable startpage.service
loginctl enable-linger "$USER"

echo "Installing tpm..."
[[ -d ~/.tmux/plugins/tpm ]] || \
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

echo "Done! You can restart your shell or reload your config."
