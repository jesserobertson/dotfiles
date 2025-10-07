#!/bin/bash
# Main test runner for dotfiles Docker testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"

# Test configuration
DEFAULT_PLATFORMS="ubuntu"
PLATFORMS="${PLATFORMS:-$DEFAULT_PLATFORMS}"
TIMEOUT="${TIMEOUT:-600}"  # 10 minutes default timeout
CLEANUP="${CLEANUP:-true}"
SHELL_ENV_TEST="${SHELL_ENV_TEST:-false}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --platforms PLATFORMS    Comma-separated list of platforms to test (default: ubuntu)"
    echo "                               Available: ubuntu, macos"
    echo "  -t, --timeout SECONDS        Timeout for each test (default: 600)"
    echo "  -n, --no-cleanup             Don't clean up containers after tests"
    echo "  -v, --verbose                Verbose output"
    echo "  -s, --shell-env              Run shell environment consistency tests on host"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PLATFORMS                    Override default platforms"
    echo "  TIMEOUT                      Override default timeout"
    echo "  CLEANUP                      Set to 'false' to disable cleanup"
    echo "  SHELL_ENV_TEST               Set to 'true' to enable shell environment tests"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test Ubuntu only (default)"
    echo "  $0 -p ubuntu,macos          # Test both platforms"
    echo "  $0 -t 900 -v                # 15 minute timeout with verbose output"
    echo "  $0 -n                       # Keep containers after tests"
    echo "  $0 -s                       # Include shell environment tests on host"
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

cleanup_container() {
    local container_name="$1"
    if [ "$CLEANUP" = "true" ]; then
        log "Cleaning up container: $container_name"
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    else
        log "Keeping container: $container_name (cleanup disabled)"
    fi
}

run_platform_test() {
    local platform="$1"
    local container_name="dotfiles-test-$platform-$(date +%s)"
    local dockerfile_path="$DOCKER_DIR/$platform/Dockerfile"

    if [ ! -f "$dockerfile_path" ]; then
        error "Dockerfile not found for platform: $platform"
        error "Expected: $dockerfile_path"
        return 1
    fi

    log "Starting test for platform: $platform"
    log "Container name: $container_name"

    # Build the Docker image
    log "Building Docker image for $platform..."
    if ! docker build -t "dotfiles-test-$platform" "$DOCKER_DIR/$platform" ${VERBOSE:+--progress=plain}; then
        error "Failed to build Docker image for $platform"
        return 1
    fi

    # Run the container with timeout
    log "Running bootstrap test for $platform (timeout: ${TIMEOUT}s)..."
    local start_time=$(date +%s)

    # Use gtimeout on macOS if available, otherwise try timeout, otherwise run without timeout
    local timeout_cmd=""
    if command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout $TIMEOUT"
    elif command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout $TIMEOUT"
    else
        warning "No timeout command available, running without timeout"
        timeout_cmd=""
    fi

    if [ -n "$timeout_cmd" ]; then
        eval "$timeout_cmd docker run --name \"$container_name\" \"dotfiles-test-$platform\""
        local exit_code=$?
    else
        docker run --name "$container_name" "dotfiles-test-$platform"
        local exit_code=$?
    fi

    if [ "$exit_code" -eq 0 ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        success "Platform $platform test completed successfully in ${duration}s"
        cleanup_container "$container_name"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [ $exit_code -eq 124 ]; then
            error "Platform $platform test timed out after ${TIMEOUT}s"
        else
            error "Platform $platform test failed after ${duration}s (exit code: $exit_code)"
        fi

        # Show container logs for debugging
        log "Container logs for debugging:"
        docker logs "$container_name" 2>&1 | tail -50

        cleanup_container "$container_name"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -n|--no-cleanup)
            CLEANUP="false"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -s|--shell-env)
            SHELL_ENV_TEST="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate Docker is available
if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    error "Docker is not running or not accessible"
    exit 1
fi

# Function to run shell environment tests on host
run_shell_env_tests() {
    log "Running shell environment consistency tests on host..."

    if [ ! -x "$SCRIPT_DIR/test-shell-env.sh" ]; then
        warning "Shell environment test script not found at: $SCRIPT_DIR/test-shell-env.sh"
        return 1
    fi

    if "$SCRIPT_DIR/test-shell-env.sh"; then
        success "Shell environment consistency tests passed"
        return 0
    else
        error "Shell environment consistency tests failed"
        return 1
    fi
}

# Main execution
log "Starting dotfiles testing framework"
log "Platforms: $PLATFORMS"
log "Timeout: ${TIMEOUT}s"
log "Cleanup: $CLEANUP"
log "Shell environment tests: $SHELL_ENV_TEST"

# Convert comma-separated platforms to array
IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"

# Calculate total tests (including shell env test if enabled)
TOTAL_TESTS=${#PLATFORM_ARRAY[@]}
if [ "$SHELL_ENV_TEST" = "true" ]; then
    ((TOTAL_TESTS++))
fi

PASSED_TESTS=0
FAILED_TESTS=0

# Run shell environment tests first if enabled
if [ "$SHELL_ENV_TEST" = "true" ]; then
    if run_shell_env_tests; then
        ((PASSED_TESTS++))
    else
        ((FAILED_TESTS++))
    fi
    echo ""  # Add spacing
fi

log "Running tests for ${#PLATFORM_ARRAY[@]} platform(s)..."

for platform in "${PLATFORM_ARRAY[@]}"; do
    platform=$(echo "$platform" | xargs)  # Trim whitespace

    if [[ ! "$platform" =~ ^(ubuntu|macos)$ ]]; then
        error "Invalid platform: $platform"
        error "Supported platforms: ubuntu, macos"
        ((FAILED_TESTS++))
        continue
    fi

    if run_platform_test "$platform"; then
        ((PASSED_TESTS++))
    else
        ((FAILED_TESTS++))
    fi

    echo ""  # Add spacing between platform tests
done

# Final summary
echo "=================================================="
log "Test Summary:"
success "Passed: $PASSED_TESTS/$TOTAL_TESTS"
if [ $FAILED_TESTS -gt 0 ]; then
    error "Failed: $FAILED_TESTS/$TOTAL_TESTS"
fi

if [ $FAILED_TESTS -eq 0 ]; then
    success "All tests passed! 🎉"
    exit 0
else
    error "Some tests failed. Check the output above for details."
    exit 1
fi