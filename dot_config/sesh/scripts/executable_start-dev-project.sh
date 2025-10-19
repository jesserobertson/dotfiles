#!/usr/bin/env bash
# Start a developer project session with tmux layout
# Usage: start-dev-project.sh <project_path>

PROJECT_PATH="$1"

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path required"
    exit 1
fi

# Change to the project directory
cd "$PROJECT_PATH" || exit 1

# Get the current tmux session name
SESSION_NAME=$(tmux display-message -p '#S')

# Split the window vertically (left/right) with left pane 50%
tmux split-window -h -p 50

# Select the right pane and split it horizontally (top/bottom) with top pane 50%
tmux select-pane -t 1
tmux split-window -v -p 50

# Set up left pane (pane 0) - Neovim
tmux select-pane -t 0
tmux send-keys "nvim ." C-m

# Set up right top pane (pane 1) - Terminal
tmux select-pane -t 1
# Already in the project directory

# Set up right bottom pane (pane 2) - Claude
tmux select-pane -t 2
tmux send-keys "claude" C-m

# Select the neovim pane by default
tmux select-pane -t 0
