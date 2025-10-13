#!/usr/bin/env bash
# Custom status-right format with CPU, RAM, battery, and time
# This script is sourced by tmux to set status-right with proper UTF-8 arrows

# Powerline arrow character (left-pointing for right side of status bar)
ARROW=$(printf '\xee\x82\xb2')

# Set status-right with custom CPU/RAM and grey gap separators
# Colors: #44475a=grey, #6272a4=dark_purple, #ff79c6=pink, #50fa7b=green, #282a36=dark_gray, #f8f8f2=white
# Pattern: arrow-in (segment-color-fg, grey-bg) content arrow-out (grey-fg, segment-color-bg) gap
# Using $HOME instead of ~ for tmux compatibility
tmux set-option -g status-right " #[fg=#6272a4,bg=#44475a]${ARROW}#[fg=#f8f8f2,bg=#6272a4] #($HOME/.config/tmux/scripts/cpu_usage.sh) #[fg=#44475a,bg=#6272a4]${ARROW}#[bg=#44475a]#[fg=#6272a4,bg=#44475a]${ARROW}#[fg=#f8f8f2,bg=#6272a4] #($HOME/.config/tmux/scripts/ram_usage.sh) #[fg=#44475a,bg=#6272a4]${ARROW}#[bg=#44475a]#[fg=#ff79c6,bg=#44475a]${ARROW}#[fg=#6272a4,bg=#ff79c6] #($HOME/.config/tmux/plugins/tmux/scripts/battery.sh) #[fg=#44475a,bg=#ff79c6]${ARROW}#[bg=#44475a]#[fg=#50fa7b,bg=#44475a]${ARROW}#[fg=#282a36,bg=#50fa7b] %a %m/%d %I:%M %p #(date +%Z)  "
