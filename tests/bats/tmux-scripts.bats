#!/usr/bin/env bats
# Tests for tmux scripts and configuration
#
# This validates tmux helper scripts and configurations

# Load test helpers
load helpers/setup

@test "setup-dev-layout.sh script exists and is executable" {
    [ -f "$HOME/.config/tmux/scripts/setup-dev-layout.sh" ]
    [ -x "$HOME/.config/tmux/scripts/setup-dev-layout.sh" ]
}

@test "setup-dev-layout.sh can be invoked directly" {
    # Create a test session first
    test_session=$(generate_test_session_name)
    tmux new-session -d -s "$test_session" -c "$HOME"

    # Run the script directly
    run bash "$HOME/.config/tmux/scripts/setup-dev-layout.sh" "$test_session"
    [ "$status" -eq 0 ]

    # Should not create layout (not in Developer)
    pane_count=$(get_pane_count "$test_session")
    [ "$pane_count" -eq 1 ]

    # Cleanup
    kill_test_session "$test_session"
}

@test "tmux hooks configuration exists" {
    [ -f "$HOME/.config/tmux/conf.d/hooks.conf" ]
}

@test "tmux hooks configuration contains developer layout hook" {
    grep -q "setup-dev-layout.sh" "$HOME/.config/tmux/conf.d/hooks.conf"
}

@test "tmux main configuration exists" {
    [ -f "$HOME/.config/tmux/tmux.conf" ]
}

@test "tmux loads hooks configuration" {
    grep -q "hooks.conf" "$HOME/.config/tmux/tmux.conf"
}
