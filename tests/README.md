# Dotfiles Testing Framework

This directory contains comprehensive testing infrastructure for validating dotfiles installation and functionality using a hybrid approach: **bats-core for fast feature tests** and **Docker for end-to-end bootstrap validation**.

## Testing Philosophy

This framework follows a **test pyramid** approach with different types of tests serving complementary purposes:

```
                /\
               /  \
              / E2E \          ← Docker Tests (Integration)
             /  Tests \          Full bootstrap from scratch
            /----------\         5-10 minutes, comprehensive
           /            \
          /   Feature    \     ← Bats Tests (Unit/Feature)
         /     Tests      \      Specific dotfile features
        /------------------\     30 seconds, targeted
       /                    \
      /    Quick/Unit        \  ← Quick Tests (Validation)
     /       Tests            \   Syntax & template checks
    /------------------------  \  5 seconds, instant feedback
```

### Test Types Quick Reference

| Test Type | Tool | Speed | Scope | When to Run |
|-----------|------|-------|-------|-------------|
| **Quick Tests** | Shell | ⚡⚡⚡ Instant (~5s) | Syntax, templates, basic validation | Every save, pre-commit |
| **Feature Tests** | bats-core | ⚡⚡ Fast (~30s) | Specific features (tmux, shell, etc.) | Every commit, local dev |
| **E2E Bootstrap** | Docker | 🐌 Slow (5-10 min) | Full installation from scratch | PR merges, releases |

## Overview

**Quick Tests (Shell)** validate:
- Fish shell syntax for all config files
- Chezmoi template processing without errors
- Critical files exist
- JSON configuration validity
- No common mistakes (hardcoded paths, etc.)

**Feature Tests (bats-core)** validate:
- Tmux automatic layouts and configurations
- Shell environment setup and integrations
- Individual dotfile features and scripts
- Configuration file correctness

**E2E Tests (Docker)** validate:
- The chezmoi bootstrap process works correctly
- Homebrew installation and package management
- All packages from the Brewfile install successfully
- Dotfiles are applied correctly across platforms
- Core tools and applications are available
- Shell configurations work in fresh environments

## Structure

```
tests/
├── README.md                       # This file
├── quick-test.sh                   # Fast validation tests (~5 seconds)
├── run-local-tests.sh             # Runner for quick/bats/legacy tests
├── run-tests.sh                    # Runner for Docker bootstrap tests
├── verify-installation.sh          # Post-install verification script
├── test-shell-env.sh              # Shell environment consistency tests
├── bats/                           # Bats feature tests
│   ├── developer-layout.bats      # Developer project tmux layout
│   ├── tmux-scripts.bats          # Tmux helper scripts
│   └── helpers/
│       └── setup.bash             # Shared test helpers
├── docker/                         # Docker E2E tests
│   ├── ubuntu/
│   │   ├── Dockerfile
│   │   ├── test-bootstrap.sh
│   │   └── test-bootstrap-offline.sh
│   └── macos/
│       ├── Dockerfile
│       ├── test-bootstrap-macos.sh
│       └── test-bootstrap-offline.sh
└── docker-compose.yml              # Multi-platform orchestration
```

## Quick Start

### Quick Tests (Instant - For Rapid Feedback)

```bash
# Run quick validation tests (syntax, templates, basic checks)
cd tests
./run-local-tests.sh --quick

# Or run directly
./quick-test.sh
```

**Use quick tests for:**
- Pre-commit hooks
- Rapid iteration during development
- CI fast-fail checks
- Validating syntax before full tests

### Feature Tests (Fast - For Development)

```bash
# Install bats-core first (if not already installed)
brew install bats-core bats-support bats-assert bats-file

# Run all feature tests
cd tests
./run-local-tests.sh

# Run specific test suite
./run-local-tests.sh -t developer-layout

# Run with verbose output
./run-local-tests.sh -v

# Run bats directly for more control
bats bats/developer-layout.bats
```

### E2E Bootstrap Tests (Slow - For CI/CD)

```bash
# Test all platforms with Docker Compose
cd tests
docker-compose up --abort-on-container-exit

# Or test individual platforms
docker-compose run --rm ubuntu          # Ubuntu with verification
docker-compose run --rm ubuntu-offline  # Ubuntu offline mode
docker-compose run --rm macos-sim       # macOS simulation

# Using the test runner script
./run-tests.sh                          # Default Ubuntu test
./run-tests.sh -p ubuntu,macos -t 900 -v # Multiple platforms with timeout
```

### Advanced Test Runner Options

```bash
# Extended timeout and verbose output
./tests/run-tests.sh -t 900 -v

# Keep containers after tests for debugging
./tests/run-tests.sh -n

# Include shell environment consistency tests
./tests/run-tests.sh -s

# Test specific platform only
./tests/run-tests.sh -p ubuntu
```

### Environment Variables

You can also control the test runner with environment variables:

```bash
# Test both platforms with 15-minute timeout
PLATFORMS=ubuntu,macos TIMEOUT=900 ./tests/run-tests.sh

# Disable cleanup for debugging
CLEANUP=false ./tests/run-tests.sh
```

## Standalone Verification

The `verify-installation.sh` script can be run on any system to verify an existing dotfiles installation:

```bash
# Run on your local system
./tests/verify-installation.sh

# Make it executable first if needed
chmod +x ./tests/verify-installation.sh
```

## Feature Tests with Bats

The framework uses [bats-core](https://github.com/bats-core/bats-core) for fast, focused testing of dotfile features.

### Installation

```bash
# Install via Homebrew (included in Brewfile)
brew install bats-core bats-support bats-assert bats-file

# Or add to your existing setup
# (already included in this repo's Brewfile)
```

### Running Bats Tests

```bash
# Run all bats tests
./run-local-tests.sh

# Run specific test file
./run-local-tests.sh -t developer-layout

# Run with verbose output
./run-local-tests.sh -v

# Run bats directly (for more control)
bats bats/developer-layout.bats

# Run bats with TAP output (for CI)
bats --tap bats/developer-layout.bats

# Run bats with timing info
bats --timing bats/*.bats
```

### Available Bats Tests

**Developer Layout** (`bats/developer-layout.bats`) - 15 tests
- Tests automatic tmux layout for Developer projects
- Validates 3-pane layout creation
- Checks pane commands (nvim, claude) and paths
- Tests layout across multiple projects
- Negative tests (non-Developer directories)
- Edge cases (additional splits, active pane, size ratios)

**Tmux Scripts** (`bats/tmux-scripts.bats`) - 6 tests
- Tests setup-dev-layout.sh script existence and execution
- Validates tmux hooks configuration
- Checks configuration file loading

**Total: 21 tests**

Example test output:
```
bats/developer-layout.bats
 ✓ Developer directory exists
 ✓ Test project exists in Developer directory
 ✓ Developer project session creates exactly 3 panes
 ✓ All panes are in the correct project directory
 ✓ Pane 0 runs neovim
 ✓ Pane 2 runs claude
 ✓ Session layout is split correctly
 ✓ Additional splits can be added after hook runs
 ✓ Active pane after setup is the neovim pane
 ✓ Panes have expected size ratios
 ... and 5 more

bats/tmux-scripts.bats
 ✓ setup-dev-layout.sh script exists and is executable
 ✓ tmux hooks configuration contains developer layout hook
 ... and 4 more

21 tests, 0 failures in ~27s
```

### Test Coverage

**Well Covered:**
- ✅ Developer project automatic layout (15 tests)
- ✅ Tmux configuration and scripts (6 tests)
- ✅ Edge cases and negative tests
- ✅ Pane commands, paths, and dimensions
- ✅ Multiple project support
- ✅ Configuration file validation

**Not Yet Covered:**
- ⏸️ Sesh integration scripts
- ⏸️ Shell environment tests
- ⏸️ Other tmux utility scripts (cpu_usage, ram_usage, etc.)

To add coverage for these areas, create new `.bats` files in the `bats/` directory following the existing patterns.

### Writing New Bats Tests

Create a new `.bats` file in the `bats/` directory:

```bash
#!/usr/bin/env bats

# Load shared helpers
load helpers/setup

setup() {
    # Run before each test
}

teardown() {
    # Run after each test
}

@test "descriptive test name" {
    run some_command
    [ "$status" -eq 0 ]
    [ "$output" = "expected output" ]
}
```

**Available Helper Functions** (from `helpers/setup.bash`):
- `is_tmux_available` - Check if tmux is installed
- `create_test_session <name> <path>` - Create tmux test session
- `kill_test_session <name>` - Clean up test session
- `get_pane_count <session>` - Get number of panes
- `get_pane_command <session> <index>` - Get command in pane
- `all_panes_in_directory <session> <path>` - Verify all panes are in correct dir
- And more... (see `bats/helpers/setup.bash`)

### Bats Best Practices

1. **Use setup/teardown** for common initialization and cleanup
2. **Load helpers** for reusable test functions
3. **Test one thing per test** - keep tests focused
4. **Use descriptive test names** - they serve as documentation
5. **Clean up resources** - always cleanup in teardown
6. **Skip when appropriate** - use `skip` for missing dependencies

Example:
```bash
setup() {
    if ! command -v tmux >/dev/null; then
        skip "tmux not installed"
    fi
}
```

## CI/CD Integration

Both test types (bats and Docker) can be integrated into CI/CD pipelines.

### GitHub Actions

Automated tests run on every push and pull request via `.github/workflows/test-dotfiles.yml`:

**Feature Tests (Bats):**
- Run on every commit for fast feedback
- Test specific features without full bootstrap
- TAP output for CI integration
- Can run in parallel for speed

**E2E Bootstrap Tests (Docker):**
- Run on PR merges and releases
- Full installation validation
- Cross-platform testing (Ubuntu, macOS)

Example GitHub Actions workflow:
```yaml
jobs:
  feature-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: |
          brew install bats-core bats-support bats-assert bats-file
      - name: Run feature tests
        run: ./tests/run-local-tests.sh

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Docker tests
        run: |
          cd tests
          docker-compose up --abort-on-container-exit
```

View test results at: `https://github.com/[user]/[repo]/actions`

### Bats TAP Output for CI

Bats produces TAP (Test Anything Protocol) output, which integrates well with CI systems:

```bash
# Generate TAP output
bats --tap bats/*.bats

# With formatting for CI
bats --formatter junit bats/*.bats > test-results.xml
```

## Platform Support

### Ubuntu (Docker)
- Tests Linux Homebrew installation
- Validates all brew packages install correctly
- Checks dotfile application
- Verifies shell configurations
- **Fast**: 3-5 minutes typical runtime

### macOS (Simulated - Linux with macOS Paths)
- Uses Linux container with macOS-like paths for testing
- Validates cross-platform logic in bootstrap scripts
- Tests formula installations (casks are skipped)
- Tests Homebrew path detection logic
- **Note**: This is a simulation for quick path/logic testing

### macOS (Native - GitHub Actions)
- Runs on actual macOS runners in CI/CD
- Full macOS environment with real Homebrew
- Tests both formulae and casks
- Validates actual macOS-specific features
- **Slower**: 5-10 minutes due to actual package installation

### Advanced: True macOS Containers (dockur/macos)

For local development on Linux with KVM, you can use [dockur/macos](https://github.com/dockur/macos) for true macOS containerization:

**Pros**:
- Real macOS environment in Docker
- Supports macOS versions 11-15
- Local testing without cloud CI

**Cons**:
- Requires Linux host with KVM support
- Manual setup required (disk format, OS install, account creation)
- Resource intensive (full VM)
- Long setup time (not suitable for CI/CD)
- EULA restrictions (Apple hardware only)

**When to use**:
- Local development testing on Linux
- Debugging macOS-specific issues
- Testing across multiple macOS versions

**Not recommended for**:
- Automated CI/CD pipelines
- Quick iteration testing
- Resource-constrained environments

## Test Components

### Bootstrap Process
1. **Chezmoi Installation**: Verifies chezmoi can be downloaded and installed
2. **Repository Clone**: Tests SSH clone of dotfiles repository
3. **Dotfile Application**: Validates all files are copied to correct locations
4. **Homebrew Setup**: Confirms Homebrew installation and configuration
5. **Package Installation**: Verifies all Brewfile packages are installed

### Verification Checks
- **Core Tools**: git, fish, neovim, tmux, etc.
- **Programming Languages**: Go, Node.js, Rust
- **Development Tools**: AWS CLI, Google Cloud SDK, Terraform, etc.
- **Shell Integration**: Fish, Starship prompt configuration
- **Configuration Files**: Presence and basic validation of dotfiles

## Debugging

### View Container Logs
When tests fail, the runner automatically shows the last 50 lines of container logs.

### Keep Containers for Debugging
```bash
./tests/run-tests.sh -n
# Then connect to the container
docker exec -it <container-name> /bin/bash
```

### Run Individual Platform Tests
```bash
# Build and run Ubuntu test manually
cd tests/docker/ubuntu
docker build -t dotfiles-test-ubuntu .
docker run --name debug-ubuntu dotfiles-test-ubuntu

# Check logs
docker logs debug-ubuntu
```

### Manual Verification
You can run the verification script in any environment:
```bash
# On your local machine
./tests/verify-installation.sh

# In a running container
docker exec -it <container-name> /home/testuser/verify-installation.sh
```

## Requirements

- Docker installed and running
- Network access for downloading packages
- SSH access to the dotfiles repository (for the bootstrap process)

## Customization

### Adding New Platforms
1. Create a new directory under `tests/docker/`
2. Add a `Dockerfile` with the platform setup
3. Create a platform-specific test script
4. Update the `run-tests.sh` script to recognize the new platform

### Modifying Tests
- Edit the test scripts in each platform directory
- Update `verify-installation.sh` for new verification checks
- Adjust timeouts and other parameters in `run-tests.sh`

## Troubleshooting

### Common Issues

1. **SSH Key Access**: The bootstrap requires SSH access to GitHub
   - Solution: Ensure your SSH keys are properly configured

2. **Timeout Errors**: Default timeout is 10 minutes
   - Solution: Increase timeout with `-t 900` (15 minutes)

3. **Network Issues**: Package downloads may fail on slow connections
   - Solution: Retry tests or increase timeout

4. **Permission Errors**: Docker permission issues
   - Solution: Ensure your user is in the docker group or use sudo

### Getting Help

If tests fail consistently:
1. Run with verbose output: `./tests/run-tests.sh -v`
2. Keep containers for inspection: `./tests/run-tests.sh -n`
3. Check individual component installation manually
4. Verify your Brewfile and dotfiles are valid