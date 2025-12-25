#!/usr/bin/env bash

DIR="${1:-.}"

# Valid swww transitions
TRANSITIONS=(grow fade wipe left right top bottom outer wave center)

# Pick random transition
TT="${TRANSITIONS[RANDOM % ${#TRANSITIONS[@]}]}"

# Pick random image
IMG=$(find "$DIR" -maxdepth 1 -type f \
  \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) \
  | shuf -n 1)

# Exit if no image found
[ -z "$IMG" ] && exit 1

# Base command
CMD=(swww img "$IMG"
  --transition-type "$TT"
  --transition-duration 1.3
  --transition-fps 60
)

# Random position for transitions that support it
if [[ "$TT" =~ ^(grow|center|outer)$ ]]; then
  CMD+=(--transition-pos "$(printf "0.%02d,0.%02d" $((RANDOM%80+10)) $((RANDOM%80+10)))")
fi

exec "${CMD[@]}"

