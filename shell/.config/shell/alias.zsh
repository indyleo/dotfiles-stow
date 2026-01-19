# Making ls Better
alias ls='eza --group-directories-first --color=auto --icons' # Basic eza But with Some Nice Flags
alias la='eza -a --group-directories-first --color=auto --icons' # Show Hidden Files
alias ll='eza -lF --group-directories-first --color=auto --icons' # Show In Listing Form
alias l='eza -alF --group-directories-first --color=auto --icons' # My Favourite
alias lt='eza -a --tree --group-directories-first --color=always --icons' # Tree Listing
alias l.='eza -a | egrep "^\."' # Show Only Hidden File

# Duf Aliases
alias df='duf'

# Cat to Bat Alias
alias cat='bat -pn --pager=""'

# Colorize grep output (good for log files)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# PS Aliases
alias psa="ps auxf"
alias psgrep='ps aux | grep -v grep | grep -i -e VSZ -e'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Confirm Before Doing Something Or The Output Being Verbose Or Both
alias rm='trash-put -iv'
alias trashl='trash-list'
alias trashr='trash-restore'
alias trashe='trash-empty'
alias cp='cp -irv'
alias mv='mv -iv'
alias ln='ln -i'
alias mkdir='mkdir -pv'

# Nice Aliases To Have
alias wq='exit'
alias ping='ping -c 10'
alias mimetype='file --mime-type'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias userx='pkill -u $USER'
alias sizedirs="du -sh * | sort -hr"
alias sizefiles="find . -type f -exec du -h {} + | sort -hr | head -n 10"
alias mpv="command mpv --fs"
alias getxinfo="xprop | grep -E 'WM_CLASS|_NET_WM_WINDOW_TYPE|WM_NAME'"
alias fd="fdfind"

# Suckless
alias cpc="sudo cp config.def.h config.h"
alias clin="sudo make clean install"

# find dirs and files
alias ff="find . | grep "

# Get Error Messages From Journalctl
alias jctl='journalctl -p 3 -xb'

# Yt-dlp Aliases
alias yta-aac='yt-dlp --extract-audio --audio-format aac '
alias yta-best='yt-dlp --extract-audio --audio-format best '
alias yta-flac='yt-dlp --extract-audio --audio-format flac '
alias yta-m4a='yt-dlp --extract-audio --audio-format m4a '
alias yta-mp3='yt-dlp --extract-audio --audio-format mp3 '
alias yta-opus='yt-dlp --extract-audio --audio-format opus '
alias yta-vorbis='yt-dlp --extract-audio --audio-format vorbis '
alias yta-wav='yt-dlp --extract-audio --audio-format wav '
alias ytv-best='yt-dlp -f bestvideo+bestaudio '

# CD Aliases
alias home='cd ~'
alias down='cd ~/Downloads'
alias docs='cd ~/Documents'
alias desk='cd ~/Desktop'
alias conf='cd ~/.config'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias bd='cd "$OLDPWD"'

# Neovim Aliases
alias v='nvim'
alias sv='sudo nvim'
alias nv='neovide'
alias snv='sudo neovide'

# GPG encryption
alias gpg-check='gpg --keyserver-options auto-key-retrieve --verify'
alias gpg-retrieve='gpg --keyserver-options auto-key-retrieve --receive-keys'

# Git Aliases
alias addup='git add -u'
alias addall='git add .'
alias branch='git branch'
alias checkout='git checkout'
alias clone='git clone'
alias commit='git commit -m'
alias fetch='git fetch'
alias pull='git pull origin'
alias push='git push origin'
alias stat='git status'
alias tag='git tag'
alias newtag='git tag -a'
alias lg="lazygit"

# Shell Aliases
alias srcz='source ~/.zshrc'
alias srcze='source ~/.zshenv'
alias src='source'
alias rs='reset'
alias cl='clear'
alias tozsh='chsh -s "$(which zsh)" "$USER"'
alias tobash='chsh -s "$(which bash)" "$USER"'

# Chmod Aliases
alias mxp='chmod a+x'
alias mxm='chmod a-x'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Pkg Manager Aliases
if [[ -f /usr/bin/apt ]]; then
    alias aptin='sudo apt install'
    alias aptup='sudo apt update && sudo apt upgrade'
    alias aptrm='sudo apt remove'
    alias aptpu='sudo apt purge'
    alias aptse='apt search'
elif [[ -f /usr/bin/dnf ]]; then
    alias dnfin='sudo dnf install'
    alias dnfup='sudo dnf update'
    alias dnfrm='sudo dnf remove'
    alias dnfse='dnf search'
elif [[ -f /usr/bin/pacman ]]; then
    alias pacin='sudo pacman -S'
    alias pacup='sudo pacman -Syu'
    alias pacrm='sudo pacman -R'
    alias pacpu='sudo pacman -Rns'
    alias pacse='pacman -Qs'
fi

if command -v pacseek >/dev/null; then
    alias pcs='pacseek'
fi

# Random Aliases
alias fusee="sudo fusee-nano ~/Bin/hekate_ctcaer_*.bin"
alias ns="sudo java -jar ~/Code/ns-usbloader-*.jar"
alias clox="tty-clock -tcxBbC 4"
alias matrix="cmatrix -abC cyan"
alias oops='oops $(fc -ln -1)'

# For Vim Users
# vim:ft=sh
