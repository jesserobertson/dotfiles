#!/usr/bin/env bash
# Automatically set up layout for Developer project sessions
# This script is triggered by tmux hook when a new session is created

SESSION_NAME="${1:-$(tmux display-message -p '#S')}"
SESSION_PATH=$(tmux display-message -p -t "$SESSION_NAME" '#{session_path}')

# Check if this is a Developer project
if [[ "$SESSION_PATH" == "$HOME/Developer/"* ]]; then
    # Only set up layout if this is the first window and it has only one pane
    PANE_COUNT=$(tmux list-panes -t "$SESSION_NAME" | wc -l)

    if [ "$PANE_COUNT" -eq 1 ]; then
        # Split the window vertically (left/right) with right pane 50%
        tmux split-window -t "$SESSION_NAME" -h -p 50

        # Select the right pane and split it horizontally (top/bottom) with bottom pane 50%
        tmux select-pane -t "$SESSION_NAME:0.1"
        tmux split-window -t "$SESSION_NAME:0.1" -v -p 50

        # Set up left pane (pane 0) - Neovim
        tmux select-pane -t "$SESSION_NAME:0.0"
        tmux send-keys -t "$SESSION_NAME:0.0" "cd '$SESSION_PATH' && nvim ." C-m

        # Set up right top pane (pane 1) - Terminal
        tmux select-pane -t "$SESSION_NAME:0.1"
        tmux send-keys -t "$SESSION_NAME:0.1" "cd '$SESSION_PATH'" C-m

        # Set up right bottom pane (pane 2) - Claude
        tmux select-pane -t "$SESSION_NAME:0.2"
        tmux send-keys -t "$SESSION_NAME:0.2" "cd '$SESSION_PATH' && claude" C-m

        # Select the neovim pane by default
        tmux select-pane -t "$SESSION_NAME:0.0"
    fi
fi
