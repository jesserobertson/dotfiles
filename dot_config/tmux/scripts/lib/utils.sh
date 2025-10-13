#!/usr/bin/env bash

# get tmux option
get_tmux_option() {
  local option="$2"
  local default_value="${3:-}"
  local option_value

  option_value=$(tmux show-option "$1" "$option" 2>/dev/null | cut -d' ' -f2-)

  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

# set tmux option
set_tmux_option() {
  tmux set-option "$@" >/dev/null 2>&1
}

# add to tmux option (append)
add_tmux_option() {
  local option="$2"
  local value="$3"
  local current_value

  current_value=$(get_tmux_option "$1" "$option")

  if [ -z "$current_value" ]; then
    set_tmux_option "$1" "$option" "$value"
  else
    set_tmux_option "$1" "$option" "$current_value$value"
  fi
}

# set tmux environment variable
set_tmux_env() {
  tmux set-environment "$@" >/dev/null 2>&1
}
