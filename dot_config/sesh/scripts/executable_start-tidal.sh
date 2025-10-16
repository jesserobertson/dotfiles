#!/bin/bash
# Tidal multi-pane startup script for sesh
# Layout: Left third has sclang (top) and ghci (bottom) stacked vertically
#         Right two-thirds has neovim

# Split window vertically: left (33%) and right (67%)
# -h = horizontal split (side by side), -p 67 = right pane gets 67% width
tmux split-window -h -p 67

# Select the left pane (pane 0) and split it horizontally (top/bottom)
tmux select-pane -t 0
tmux split-window -v

# Now we have:
# Pane 0: top-left (sclang)
# Pane 1: bottom-left (ghci)
# Pane 2: right (neovim, 2/3 width)

# Send commands to each pane
# Pane 0: SuperCollider with SuperDirt
tmux send-keys -t 0 "/Applications/SuperCollider.app/Contents/MacOS/sclang ~/.config/tidal/startup.scd" C-m

# Pane 1: GHCi with TidalCycles (with delay)
tmux send-keys -t 1 "sleep 3 && ghci -ghci-script ~/.config/tidal/BootTidal.hs" C-m

# Pane 2: Neovim (with delay and focused)
tmux send-keys -t 2 "sleep 4 && nvim" C-m

# Focus on the nvim pane (pane 2)
tmux select-pane -t 2
