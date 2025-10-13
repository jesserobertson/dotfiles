#!/usr/bin/env bash

# tmux config directory
TMUX_DIR="${TMUX_DIR:-$HOME/.config/tmux}"

# plugins directory
PLUGINS_DIR="$TMUX_DIR/plugins"

# auto-generated plugins config
AUTO_PLUGINS_CONF="$TMUX_DIR/conf.d/auto_plugins.conf"

# tmux options
opt_tmux_theme="@tmux-theme"
opt_tmux_theme_status_enable="@tmux-theme-status-enable"
