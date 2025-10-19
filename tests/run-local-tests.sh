#!/usr/bin/env bash
# Run local tests for dotfiles configuration
# These tests validate specific features on the local machine
# (as opposed to Docker-based bootstrap tests)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
VERBOSE=false
TEST_SUITE=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --test SUITE      Run specific test suite (default: all)"
    echo "                        Available: developer-layout, shell-env"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all local tests"
    echo "  $0 -t developer-layout         # Test Developer project layout only"
    echo "  $0 -v                          # Run all tests with verbose output"
}

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

error() {
    echo -e "${RED}[ERROR] $*${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $*${NC}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test)
            TEST_SUITE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_script="$2"
    shift 2
    local test_args=("$@")

    log "Running test: $test_name"
    ((TOTAL_TESTS++))

    if [ ! -x "$test_script" ]; then
        error "Test script not found or not executable: $test_script"
        ((FAILED_TESTS++))
        return 1
    fi

    local verbose_flag=""
    if [ "$VERBOSE" = true ]; then
        verbose_flag="-v"
    fi

    if "$test_script" $verbose_flag "${test_args[@]}"; then
        success "$test_name passed"
        ((PASSED_TESTS++))
        return 0
    else
        error "$test_name failed"
        ((FAILED_TESTS++))
        return 1
    fi
}

main() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Local Dotfiles Tests${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""

    # Run tests based on suite selection
    case "$TEST_SUITE" in
        "developer-layout")
            run_test "Developer Layout" "$SCRIPT_DIR/test-developer-layout.sh"
            ;;
        "shell-env")
            run_test "Shell Environment" "$SCRIPT_DIR/test-shell-env.sh"
            ;;
        "")
            # Run all tests
            log "Running all local tests..."
            echo ""

            # Developer layout test
            if [ -x "$SCRIPT_DIR/test-developer-layout.sh" ]; then
                run_test "Developer Layout" "$SCRIPT_DIR/test-developer-layout.sh" || true
                echo ""
            fi

            # Shell environment test
            if [ -x "$SCRIPT_DIR/test-shell-env.sh" ]; then
                run_test "Shell Environment" "$SCRIPT_DIR/test-shell-env.sh" || true
                echo ""
            fi
            ;;
        *)
            error "Unknown test suite: $TEST_SUITE"
            usage
            exit 1
            ;;
    esac

    # Summary
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Total:  $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        success "All tests passed!"
        exit 0
    else
        error "$FAILED_TESTS test(s) failed"
        exit 1
    fi
}

main
