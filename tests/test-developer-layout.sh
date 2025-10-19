#!/usr/bin/env bash
# Test script for Developer project layout automation
# This validates that the tmux+sesh Developer layout setup works correctly
#
# Usage: ./test-developer-layout.sh [options]
#
# Options:
#   -p PROJECT    Test specific project (default: first available)
#   -a            Test all projects (up to 5)
#   -v            Verbose output
#   -h            Show help

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
TEST_ALL=false
SPECIFIC_PROJECT=""

# Parse arguments
while getopts "p:avh" opt; do
    case $opt in
        p) SPECIFIC_PROJECT="$OPTARG" ;;
        a) TEST_ALL=true ;;
        v) VERBOSE=true ;;
        h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -p PROJECT    Test specific project (default: first available)"
            echo "  -a            Test all projects (up to 5)"
            echo "  -v            Verbose output"
            echo "  -h            Show help"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Helper functions
log() {
    echo -e "$1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "$1"
    fi
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Test a single project
test_project() {
    local project="$1"
    local test_path="$HOME/Developer/$project"
    local test_session="test-dev-layout-$$-${project}"

    log_info "Testing project: $project"

    # Check if project exists
    if [ ! -d "$test_path" ]; then
        log_error "Project directory does not exist: $test_path"
        return 1
    fi
    log_verbose "  Project directory exists: $test_path"

    # Create test session
    log_verbose "  Creating test session: $test_session"
    if ! tmux new-session -d -s "$test_session" -c "$test_path" 2>/dev/null; then
        log_error "Failed to create tmux session"
        return 1
    fi

    # Wait for hook to execute
    sleep 2

    # Test 1: Check pane count
    local pane_count
    pane_count=$(tmux list-panes -t "$test_session" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pane_count" != "3" ]; then
        log_error "Expected 3 panes, found $pane_count"
        tmux kill-session -t "$test_session" 2>/dev/null || true
        return 1
    fi
    log_verbose "  Pane count: 3 ✓"

    # Test 2: Check pane paths
    local paths
    paths=$(tmux list-panes -t "$test_session" -F '#{pane_current_path}' 2>/dev/null)
    local path_ok=true
    while IFS= read -r path; do
        if [ "$path" != "$test_path" ]; then
            path_ok=false
            break
        fi
    done <<< "$paths"

    if [ "$path_ok" != "true" ]; then
        log_error "Some panes not in correct directory"
        tmux kill-session -t "$test_session" 2>/dev/null || true
        return 1
    fi
    log_verbose "  All panes in correct directory ✓"

    # Test 3: Check running commands
    local commands
    commands=$(tmux list-panes -t "$test_session" -F '#{pane_current_command}' 2>/dev/null)
    local pane0_cmd pane2_cmd
    pane0_cmd=$(echo "$commands" | sed -n '1p')
    pane2_cmd=$(echo "$commands" | sed -n '3p')

    local commands_ok=true
    if [ "$pane0_cmd" != "nvim" ]; then
        log_verbose "  Pane 0 command: $pane0_cmd (expected: nvim)"
        commands_ok=false
    fi
    if [ "$pane2_cmd" != "claude" ]; then
        log_verbose "  Pane 2 command: $pane2_cmd (expected: claude)"
        commands_ok=false
    fi

    if [ "$commands_ok" != "true" ]; then
        log_error "Commands not as expected"
        tmux kill-session -t "$test_session" 2>/dev/null || true
        return 1
    fi
    log_verbose "  Expected commands running ✓"

    # Test 4: Check layout
    local layout
    layout=$(tmux list-windows -t "$test_session" -F '#{window_layout}' 2>/dev/null)
    if [[ ! $layout == *","* ]]; then
        log_error "Layout doesn't match expected split"
        tmux kill-session -t "$test_session" 2>/dev/null || true
        return 1
    fi
    log_verbose "  Panes split correctly ✓"

    # Cleanup
    tmux kill-session -t "$test_session" 2>/dev/null || true

    log_success "Project $project passed all tests"
    return 0
}

# Main test logic
main() {
    log "${BLUE}================================${NC}"
    log "${BLUE}Developer Layout Test Suite${NC}"
    log "${BLUE}================================${NC}"
    echo ""

    # Check if tmux is running
    if ! tmux list-sessions &>/dev/null && [ -z "$TMUX" ]; then
        # Start tmux server in background
        log_verbose "Starting tmux server..."
        tmux start-server || true
    fi

    # Check if ~/Developer exists
    if [ ! -d "$HOME/Developer" ]; then
        log_error "~/Developer directory does not exist"
        exit 1
    fi

    # Get list of projects
    local projects=()
    if [ -n "$SPECIFIC_PROJECT" ]; then
        projects=("$SPECIFIC_PROJECT")
    elif [ "$TEST_ALL" = true ]; then
        # Get up to 5 projects
        while IFS= read -r project; do
            projects+=("$project")
        done < <(find "$HOME/Developer" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -v '^\.' | head -5)
    else
        # Get first project
        while IFS= read -r project; do
            projects+=("$project")
        done < <(find "$HOME/Developer" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | grep -v '^\.' | head -1)
    fi

    if [ ${#projects[@]} -eq 0 ]; then
        log_error "No projects found in ~/Developer"
        exit 1
    fi

    log_info "Testing ${#projects[@]} project(s)"
    echo ""

    # Test each project
    local passed=0
    local failed=0

    for project in "${projects[@]}"; do
        if test_project "$project"; then
            ((passed++))
        else
            ((failed++))
        fi
        echo ""
    done

    # Summary
    log "${BLUE}================================${NC}"
    log "${BLUE}Test Summary${NC}"
    log "${BLUE}================================${NC}"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo ""

    if [ $failed -eq 0 ]; then
        log_success "All tests passed!"
        log_info "Your Developer project layout automation is working correctly"
        echo ""
        log "Usage: sesh connect <project-name>"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main
main
