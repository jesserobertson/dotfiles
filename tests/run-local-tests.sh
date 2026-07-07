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
BATS_DIR="$SCRIPT_DIR/bats"

# Default values
VERBOSE=false
TEST_SUITE=""
USE_BATS=true
QUICK_MODE=false

# Check if bats is available
BATS_AVAILABLE=false
if command -v bats >/dev/null 2>&1; then
    BATS_AVAILABLE=true
fi

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --quick           Run syntax.bats/templates.bats/repo-hygiene.bats (fastest, ~5 seconds)"
    echo "  -t, --test SUITE      Run specific test suite (default: all)"
    if [ "$BATS_AVAILABLE" = true ]; then
        echo "                        Available (bats): install, shell-env, fish, syntax, templates,"
        echo "                        repo-hygiene, developer-layout, tmux-scripts"
    else
        echo "                        Available (legacy): developer-layout, shell-env"
        echo "                        Note: Install bats-core for improved test experience"
    fi
    echo "  -v, --verbose         Verbose output"
    echo "  --no-bats             Use legacy shell scripts instead of bats"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Test Types:"
    echo "  Quick Tests:         Fast syntax and template validation (~5 seconds)"
    echo "  Feature Tests:       Bats tests for specific features (~30 seconds)"
    echo "  Bootstrap Tests:     Full Docker integration tests (see run-tests.sh)"
    echo ""
    echo "Examples:"
    echo "  $0 --quick                     # Quick validation (fastest)"
    echo "  $0                              # Run all feature tests"
    echo "  $0 -t developer-layout         # Test Developer project layout only"
    echo "  $0 -v                          # Run all tests with verbose output"
    if [ "$BATS_AVAILABLE" = true ]; then
        echo "  $0 --no-bats                   # Use legacy test scripts"
    fi
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

warning() {
    echo -e "${YELLOW}[WARNING] $*${NC}"
}

# Run a bats test file
run_bats_test() {
    local test_name="$1"
    local test_file="$2"

    log "Running bats test: $test_name"

    local bats_args=()
    if [ "$VERBOSE" = true ]; then
        bats_args+=("--verbose-run" "--show-output-of-passing-tests")
    fi

    # Bats helper libraries are loaded automatically in helpers/setup.bash
    # No need to set environment variables

    if bats "${bats_args[@]}" "$test_file"; then
        success "$test_name passed"
        return 0
    else
        error "$test_name failed"
        return 1
    fi
}

# Run a legacy shell test script
run_legacy_test() {
    local test_name="$1"
    local test_script="$2"

    log "Running legacy test: $test_name"

    if [ ! -x "$test_script" ]; then
        error "Test script not found or not executable: $test_script"
        return 1
    fi

    local verbose_flag=""
    if [ "$VERBOSE" = true ]; then
        verbose_flag="-v"
    fi

    if "$test_script" $verbose_flag; then
        success "$test_name passed"
        return 0
    else
        error "$test_name failed"
        return 1
    fi
}

# Run all bats tests
run_all_bats_tests() {
    local failed=0

    # Find all .bats files
    local bats_files
    bats_files=$(find "$BATS_DIR" -maxdepth 1 -name "*.bats" -type f 2>/dev/null | sort)

    if [ -z "$bats_files" ]; then
        warning "No bats test files found in $BATS_DIR"
        return 0
    fi

    while IFS= read -r bats_file; do
        local test_name
        test_name=$(basename "$bats_file" .bats)
        test_name="${test_name//-/ }"  # Replace hyphens with spaces
        test_name="$(tr '[:lower:]' '[:upper:]' <<< ${test_name:0:1})${test_name:1}"  # Capitalize

        if ! run_bats_test "$test_name" "$bats_file"; then
            failed=1
        fi
        echo ""
    done <<< "$bats_files"

    return $failed
}

# Run all legacy tests
run_all_legacy_tests() {
    local failed=0

    # Developer layout test
    if [ -x "$SCRIPT_DIR/test-developer-layout.sh" ]; then
        if ! run_legacy_test "Developer Layout" "$SCRIPT_DIR/test-developer-layout.sh"; then
            failed=1
        fi
        echo ""
    fi

    # Shell environment test
    if [ -x "$SCRIPT_DIR/test-shell-env.sh" ]; then
        if ! run_legacy_test "Shell Environment" "$SCRIPT_DIR/test-shell-env.sh"; then
            failed=1
        fi
        echo ""
    fi

    return $failed
}

main() {
    # Run quick tests if requested
    if [ "$QUICK_MODE" = true ]; then
        if ! command -v bats >/dev/null 2>&1; then
            error "bats-core not found. Install with: brew install bats-core"
            exit 1
        fi
        exec bats "$BATS_DIR/syntax.bats" "$BATS_DIR/templates.bats" "$BATS_DIR/repo-hygiene.bats"
    fi

    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Local Dotfiles Tests${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""

    # Generate setup.bash from template if needed (for bats tests)
    if [ "$BATS_AVAILABLE" = true ] && [ "$USE_BATS" = true ]; then
        local setup_template="$BATS_DIR/helpers/setup.bash.tmpl"
        local setup_file="$BATS_DIR/helpers/setup.bash"

        if [ -f "$setup_template" ]; then
            # Generate if setup.bash doesn't exist or template is newer
            if [ ! -f "$setup_file" ] || [ "$setup_template" -nt "$setup_file" ]; then
                if command -v chezmoi >/dev/null 2>&1; then
                    log "Generating setup.bash from template..."
                    chezmoi execute-template < "$setup_template" > "$setup_file"
                else
                    warning "chezmoi not found, using existing setup.bash"
                fi
            fi
        fi
    fi

    # Show test framework being used
    if [ "$BATS_AVAILABLE" = true ] && [ "$USE_BATS" = true ]; then
        log "Using bats-core test framework"
        echo ""
    elif [ "$BATS_AVAILABLE" = false ]; then
        warning "bats-core not found. Install with: brew install bats-core"
        log "Using legacy test scripts"
        echo ""
    else
        log "Using legacy test scripts (--no-bats specified)"
        echo ""
    fi

    local exit_code=0

    # Run tests based on suite selection
    if [ -n "$TEST_SUITE" ]; then
        # Run specific test suite
        if [ "$BATS_AVAILABLE" = true ] && [ "$USE_BATS" = true ]; then
            # Check for bats test file
            local bats_file="$BATS_DIR/${TEST_SUITE}.bats"
            if [ -f "$bats_file" ]; then
                run_bats_test "$TEST_SUITE" "$bats_file" || exit_code=1
            else
                error "Bats test file not found: $bats_file"
                exit_code=1
            fi
        else
            # Use legacy script
            local legacy_script="$SCRIPT_DIR/test-${TEST_SUITE}.sh"
            if [ -x "$legacy_script" ]; then
                run_legacy_test "$TEST_SUITE" "$legacy_script" || exit_code=1
            else
                error "Legacy test script not found: $legacy_script"
                exit_code=1
            fi
        fi
    else
        # Run all tests
        if [ "$BATS_AVAILABLE" = true ] && [ "$USE_BATS" = true ]; then
            run_all_bats_tests || exit_code=1
        else
            run_all_legacy_tests || exit_code=1
        fi
    fi

    # Summary
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}================================${NC}"

    if [ $exit_code -eq 0 ]; then
        success "All tests passed!"
    else
        error "Some tests failed"
    fi
    echo ""

    exit $exit_code
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -t|--test)
            TEST_SUITE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-bats)
            USE_BATS=false
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

main
