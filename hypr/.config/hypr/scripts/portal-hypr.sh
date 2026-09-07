#!/usr/bin/env sh
sleep 1
killall -e xdg-desktop-portal-hyprland
killall -e xdg-desktop-portal-gtk
# NOTE: this was missing -e. Without it, killall matches on the first 15
# characters of a process name when the full name is longer (it is here:
# "xdg-desktop-portal" is 19 chars) - which is the same truncated prefix
# shared by xdg-desktop-portal-hyprland and xdg-desktop-portal-gtk above,
# so this could inadvertently also match those instead of just the plain
# dispatcher process.
killall -e xdg-desktop-portal
sleep 1
/usr/lib/xdg-desktop-portal-hyprland &
sleep 1
/usr/lib/xdg-desktop-portal-gtk &
sleep 1
/usr/lib/xdg-desktop-portal &