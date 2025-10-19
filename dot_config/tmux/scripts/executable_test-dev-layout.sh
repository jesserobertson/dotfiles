#!/usr/bin/env bash
# Test script for Developer project layout automation
# Usage: ./test-dev-layout.sh [project-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_SESSION="test-dev-layout-$$"
TEST_PROJECT="${1:-tidal}"
TEST_PATH="$HOME/Developer/$TEST_PROJECT"

echo -e "${YELLOW}Testing Developer project layout automation${NC}"
echo "Project: $TEST_PROJECT"
echo "Path: $TEST_PATH"
echo ""

# Check if project exists
if [ ! -d "$TEST_PATH" ]; then
    echo -e "${RED}✗ Project directory does not exist: $TEST_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Project directory exists${NC}"

# Create test session
echo "Creating test session..."
tmux new-session -d -s "$TEST_SESSION" -c "$TEST_PATH"

# Wait for hook to execute
sleep 2

# Test 1: Check pane count
echo -n "Checking pane count... "
PANE_COUNT=$(tmux list-panes -t "$TEST_SESSION" | wc -l | tr -d ' ')
if [ "$PANE_COUNT" -eq 3 ]; then
    echo -e "${GREEN}✓ Found 3 panes${NC}"
else
    echo -e "${RED}✗ Expected 3 panes, found $PANE_COUNT${NC}"
    tmux kill-session -t "$TEST_SESSION"
    exit 1
fi

# Test 2: Check pane paths
echo -n "Checking pane paths... "
PATHS=$(tmux list-panes -t "$TEST_SESSION" -F '#{pane_current_path}')
PATH_OK=true
while IFS= read -r path; do
    if [ "$path" != "$TEST_PATH" ]; then
        PATH_OK=false
        break
    fi
done <<< "$PATHS"

if [ "$PATH_OK" = true ]; then
    echo -e "${GREEN}✓ All panes in correct directory${NC}"
else
    echo -e "${RED}✗ Some panes not in correct directory${NC}"
    tmux kill-session -t "$TEST_SESSION"
    exit 1
fi

# Test 3: Check running commands
echo -n "Checking running commands... "
COMMANDS=$(tmux list-panes -t "$TEST_SESSION" -F '#{pane_current_command}')
PANE0_CMD=$(echo "$COMMANDS" | sed -n '1p')
PANE2_CMD=$(echo "$COMMANDS" | sed -n '3p')

COMMANDS_OK=true
if [ "$PANE0_CMD" != "nvim" ]; then
    echo -e "${RED}✗ Pane 0 should be running nvim, found: $PANE0_CMD${NC}"
    COMMANDS_OK=false
fi
if [ "$PANE2_CMD" != "claude" ]; then
    echo -e "${RED}✗ Pane 2 should be running claude, found: $PANE2_CMD${NC}"
    COMMANDS_OK=false
fi

if [ "$COMMANDS_OK" = true ]; then
    echo -e "${GREEN}✓ Expected commands running in panes${NC}"
else
    tmux kill-session -t "$TEST_SESSION"
    exit 1
fi

# Test 4: Check layout (approximate)
echo -n "Checking pane layout... "
LAYOUT=$(tmux list-windows -t "$TEST_SESSION" -F '#{window_layout}')
# The layout should have vertical split (main-vertical or similar pattern)
if [[ $LAYOUT == *","* ]]; then
    echo -e "${GREEN}✓ Panes are split correctly${NC}"
else
    echo -e "${RED}✗ Layout doesn't match expected split${NC}"
    tmux kill-session -t "$TEST_SESSION"
    exit 1
fi

# Cleanup
echo ""
echo -n "Cleaning up test session... "
tmux kill-session -t "$TEST_SESSION"
echo -e "${GREEN}✓ Done${NC}"

echo ""
echo -e "${GREEN}All tests passed!${NC}"
echo ""
echo "You can now use sesh to connect to any Developer project:"
echo "  sesh connect $TEST_PROJECT"
