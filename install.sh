#!/bin/env bash
REPO_URL="https://github.com/indyleo/dotfiles-stow"
REPO_NAME="dotfiles-stow"

is_stow_installed() {
    dpkg -s "stow" &> /dev/null
}

if ! is_stow_installed &> /dev/null; then
    echo "Stow is not installed. Please install stow."
    exit 1
fi

cd ~/Github || exit

# Check if the repository already exists
if [[ -d "$REPO_NAME" ]]; then
    echo "Repository '$REPO_NAME' already exists. Skipping clone"
else
    git clone "$REPO_URL"
fi

# Quick function to stow things with right args
stowq() {
    stow --target="$HOME" --adopt -v "$1"
}

# Stowing
stowq figletfonts
stowq shell
stowq xdg
stowq git
stowq yazi
stowq tmux
stowq nvim
stowq neovide
stowq ohmyposh
stowq alacritty
stowq wezterm
stowq fastfetch
stowq espanso
stowq xorg
stowq picom
stowq dunst
stowq qutebrowser
stowq discordo
stowq Thunar
stowq lf
stowq pipewire
stowq gurk
stowq twt
stowq lazygit
stowq rofi
stowq quickshell
stowq hypr
stowq mako
