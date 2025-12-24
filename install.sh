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

FILES_HOME=(
    .zshrc
    .zshenv
    .zprofile
    .zlogout
    .bash_logout
    .profile
    .bashrc
    .bash_profile
    .hooksrc
    .aliasrc
    .functionrc
    .Xresources
    .xinitrc
)

DIRS_CONFIG=(
    alacritty
    wezterm
    neovide
    tmux
    nvim
    ohmyposh
    fastfetch
    yazi
    git
    espanso
    picom
    dunst
    qutebrowser
    discordo
    Thunar
    lf
    shell
    zsh
    pipewire
    gurk
    twt
    lazygit
    rofi
)

FILES_CONFIG=(
    mimeapps.list
    user-dirs.dirs
    user-dirs.locale
)

echo "Removing old dotfiles..."
for file in "${FILES_HOME[@]}"; do
    if [[ -f "$HOME/$file" ]]; then
        command rm -fv "$HOME/$file"
    fi
done

for dir in "${DIRS_CONFIG[@]}"; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        command rm -rfv "$HOME/.config/$dir"
    fi
done

for file in "${FILES_CONFIG[@]}"; do
    if [[ -f "$HOME/.config/$file" ]]; then
        command rm -fv "$HOME/.config/$file"
    fi
done

if [[ -d "$HOME/.local/share/figletfonts" ]]; then
    command rm -rfv "$HOME/.local/share/figletfonts"
fi

# Quick function to stow things with right args
stowq() {
    stow --target="$HOME" -v "$1"
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
