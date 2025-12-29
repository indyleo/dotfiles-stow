#!/bin/env bash
is_stow_installed() {
    command -v stow &> /dev/null
}

if ! is_stow_installed &> /dev/null; then
    echo "Stow is not installed. Please install stow."
    exit 1
fi

# Quick function to stow things with right args
stowq() {
    stow --target="$HOME" --adopt -v "$1"
}

# Stowing
stowq figletfonts
stowq shell
ln -sf  ~/.config/zsh/.zshenv ~/.zshenv
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
stowq startpage
stowq foot
