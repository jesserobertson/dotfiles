#!/usr/bin/env bats
# Tests for Developer project automatic tmux layout
#
# This validates that the tmux hook automatically creates the correct
# 3-pane layout when a session is created in ~/Developer/*

# Load test helpers
load helpers/setup

# Skip all tests if tmux is not available
setup_file() {
    if ! is_tmux_available; then
        skip "tmux is not available"
    fi

    if ! has_developer_directory; then
        skip "~/Developer directory does not exist"
    fi

    # Find a test project
    TEST_PROJECT=$(get_first_developer_project)
    if [ -z "$TEST_PROJECT" ]; then
        skip "No projects found in ~/Developer"
    fi

    export TEST_PROJECT
    export TEST_PATH="$HOME/Developer/$TEST_PROJECT"
}

# Clean up any leftover test sessions before each test
setup() {
    cleanup_all_test_sessions
    export TEST_SESSION=$(generate_test_session_name)
}

# Clean up test session after each test
teardown() {
    if [ -n "$TEST_SESSION" ]; then
        kill_test_session "$TEST_SESSION"
    fi
}

@test "Developer directory exists" {
    [ -d "$HOME/Developer" ]
}

@test "Test project exists in Developer directory" {
    [ -d "$TEST_PATH" ]
}

@test "tmux session can be created in Developer project" {
    run create_test_session "$TEST_SESSION" "$TEST_PATH"
    [ "$status" -eq 0 ]
}

@test "Developer project session creates exactly 3 panes" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2  # Wait for hook to execute

    pane_count=$(get_pane_count "$TEST_SESSION")
    [ "$pane_count" -eq 3 ]
}

@test "All panes are in the correct project directory" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    run all_panes_in_directory "$TEST_SESSION" "$TEST_PATH"
    [ "$status" -eq 0 ]
}

@test "Pane 0 runs neovim" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    cmd=$(get_pane_command "$TEST_SESSION" 0)
    [ "$cmd" = "nvim" ]
}

@test "Pane 1 is a terminal in project directory" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    path=$(get_pane_path "$TEST_SESSION" 1)
    [ "$path" = "$TEST_PATH" ]
}

@test "Pane 2 runs claude" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    cmd=$(get_pane_command "$TEST_SESSION" 2)
    [ "$cmd" = "claude" ]
}

@test "Session layout is split correctly (has multiple splits)" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    layout=$(tmux list-windows -t "$TEST_SESSION" -F '#{window_layout}' 2>/dev/null)
    # Layout should contain commas indicating splits
    [[ "$layout" == *","* ]]
}

@test "Session is cleaned up after test" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    kill_test_session "$TEST_SESSION"

    # Verify session no longer exists
    run tmux has-session -t "$TEST_SESSION" 2>/dev/null
    [ "$status" -ne 0 ]
}

# Test with a different project if available
@test "Layout works with different Developer projects" {
    # Get second project
    second_project=$(find "$HOME/Developer" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -v '^\.' | sed -n '2p')

    if [ -z "$second_project" ]; then
        skip "Only one project available in ~/Developer"
    fi

    second_path="$HOME/Developer/$second_project"
    second_session=$(generate_test_session_name)

    create_test_session "$second_session" "$second_path"
    sleep 2

    pane_count=$(get_pane_count "$second_session")
    [ "$pane_count" -eq 3 ]

    # Cleanup
    kill_test_session "$second_session"
}

# Negative test: session outside Developer should not trigger layout
@test "Session outside Developer directory has only 1 pane" {
    temp_session=$(generate_test_session_name)
    create_test_session "$temp_session" "$HOME"
    sleep 2

    pane_count=$(get_pane_count "$temp_session")
    [ "$pane_count" -eq 1 ]

    # Cleanup
    kill_test_session "$temp_session"
}

# Edge case: manually created split after hook still results in more panes
@test "Additional splits can be added after hook runs" {
    temp_session=$(generate_test_session_name)
    create_test_session "$temp_session" "$TEST_PATH"
    sleep 2

    # Hook should have created 3 panes
    pane_count=$(get_pane_count "$temp_session")
    [ "$pane_count" -eq 3 ]

    # Manually add another split
    tmux split-window -t "$temp_session:0.0" -v
    sleep 0.5

    # Should now have 4 panes
    pane_count=$(get_pane_count "$temp_session")
    [ "$pane_count" -eq 4 ]

    # Cleanup
    kill_test_session "$temp_session"
}

# Test that default pane is neovim pane
@test "Active pane after setup is the neovim pane" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    # Get active pane index
    active_pane=$(tmux display-message -t "$TEST_SESSION" -p '#{pane_index}')
    [ "$active_pane" -eq 0 ]

    # Verify it's running nvim
    cmd=$(get_pane_command "$TEST_SESSION" "$active_pane")
    [ "$cmd" = "nvim" ]
}

# Test pane dimensions (approximate)
@test "Panes have expected size ratios" {
    create_test_session "$TEST_SESSION" "$TEST_PATH"
    sleep 2

    # Get pane widths
    pane0_width=$(tmux list-panes -t "$TEST_SESSION" -F '#{pane_width}' | sed -n '1p')
    pane1_width=$(tmux list-panes -t "$TEST_SESSION" -F '#{pane_width}' | sed -n '2p')

    # Left pane and right panes should be approximately equal (50/50 split)
    # Allow some variance
    diff=$((pane0_width - pane1_width))
    [ ${diff#-} -lt 5 ]  # Absolute difference less than 5 columns
}
