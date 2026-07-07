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
├── run-local-tests.sh              # Runner for quick/bats/legacy tests
├── run-tests.sh                    # Runner for Docker bootstrap tests (Ubuntu only today)
├── verify-installation.sh          # Post-install verification script (any system)
├── test-shell-env.sh               # Shell environment consistency tests (any system)
├── bats/                           # Bats feature tests
│   ├── install.bats               # Post-bootstrap verification (Docker/CI)
│   ├── shell-env.bats             # EDITOR/PAGER/CONFIG/PATH consistency across bash/zsh/fish
│   ├── fish.bats                  # Fish-specific startup, config, and tool-init checks
│   ├── developer-layout.bats      # Developer project tmux layout
│   ├── tmux-scripts.bats          # Tmux helper scripts
│   └── helpers/
│       ├── setup.bash             # Shared tmux test helpers
│       └── brew.bash              # Homebrew env setup for bats
├── powershell/                     # Pester unit tests (Windows)
│   └── functions.Tests.ps1
└── docker/                         # Docker E2E tests
    └── ubuntu/
        ├── Dockerfile
        ├── test-bootstrap.sh          # Full bootstrap using local/GitHub source
        ├── test-bootstrap-offline.sh  # Offline bootstrap using a mock repo
        └── run-bats-tests.sh          # Runs install.bats/shell-env.bats/fish.bats post-bootstrap
```

There is no `docker-compose.yml` and no `docker/macos/` directory in this repo
today — macOS is tested natively via GitHub Actions (`test-dotfiles.yml`'s
`test-macos` job), not via a local Linux-simulated container. `run-tests.sh`
still advertises a `-p macos` option, but there's no `docker/macos/Dockerfile`
backing it, so it currently fails with "Dockerfile not found for platform:
macos" — only `-p ubuntu` (the default) actually works locally.

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
# Using the test runner script (builds the Docker image and runs the offline
# bootstrap by default; only the "ubuntu" platform is implemented locally)
cd tests
./run-tests.sh
./run-tests.sh -t 900 -v                 # extended timeout, verbose

# Or drive Docker directly for more control (e.g. to mount your local
# checkout instead of testing against a mock/GitHub source, or to also
# run the bats tests in the same container):
docker build -t dotfiles-test-ubuntu docker/ubuntu
docker run --rm -v "$PWD/..:/dotfiles-source:ro" dotfiles-test-ubuntu \
  bash -c "bash /home/testuser/test-bootstrap.sh && bash /home/testuser/run-bats-tests.sh"
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

**Install** (`bats/install.bats`) - 18 tests
- Post-bootstrap verification for Docker/CI: brew/chezmoi/git/fish/jq/tmux/etc.
  are installed, config files and directories exist
- Replaces `verify-installation.sh` for the containerized flow

**Shell Environment** (`bats/shell-env.bats`) - 15 tests
- EDITOR/PAGER/CONFIG consistency across bash, zsh, and fish (after a real
  `chezmoi apply`) — this is what verifies the `[[data.env_vars]]` single
  source of truth in `.chezmoi.toml.tmpl` actually reaches every shell
- Homebrew bin present in PATH for each shell

**Fish** (`bats/fish.bats`) - 13 tests
- Fish starts and parses `config.fish`/`env.fish` without errors
- EDITOR/PAGER/CONFIG set correctly, `init_cached` helper defined
- starship/zoxide/fzf fish integrations run without errors

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

**Total: 67 tests.** `docker/ubuntu/run-bats-tests.sh` runs `install.bats`,
`shell-env.bats`, and `fish.bats` (46 tests) after a real bootstrap inside the
Docker container — those three need the packages/dotfiles a bootstrap
provides. `developer-layout.bats` and `tmux-scripts.bats` (21 tests) are
meant for a local machine with tmux and an existing `~/Developer` layout, and
aren't wired into the Docker flow.

### Test Coverage

**Well Covered:**
- ✅ Shell environment variable consistency across bash/zsh/fish (15 tests)
- ✅ Fish startup, config parsing, and tool integrations (13 tests)
- ✅ Post-bootstrap package/config verification (18 tests)
- ✅ Developer project automatic layout (15 tests)
- ✅ Tmux configuration and scripts (6 tests)

**Not Yet Covered:**
- ⏸️ Sesh integration scripts
- ⏸️ PowerShell environment variable consistency (Pester covers function
  units in `tests/powershell/`, but not env-var consistency the way
  `shell-env.bats` does for bash/zsh/fish)
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

Automated tests run on every push and pull request via `.github/workflows/test-dotfiles.yml`, which has six jobs:

**Smoke tests** (validate templates/syntax, run once per push/PR):
- `test-ubuntu` — builds `docker/ubuntu`, runs the online bootstrap
  (`test-bootstrap.sh`) against the checked-out repo, then `run-bats-tests.sh`
  (`install.bats`, `shell-env.bats`, `fish.bats`)
- `test-macos` — runs natively on a `macos-latest` runner
- `test-windows` — validates PowerShell syntax (including rendering
  `*.ps1.tmpl` files first), Pester unit tests, and a `chezmoi --dry-run`

**Full install jobs** (gated on the matching smoke test passing):
- `full-install-ubuntu` / `full-install-macos` / `full-install-windows` — a
  real, undiluted `chezmoi init --apply` with `DOTFILES_FULL_INSTALL=1`, since
  the smoke tests above skip heavy packages or only dry-run

View test results at: `https://github.com/jesserobertson/dotfiles/actions`

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
- Runnable locally via `./run-tests.sh` or `docker build`/`docker run` (see
  Quick Start above) — the only platform with a local Docker path today

### Windows (GitHub Actions + local)
- CI validates PowerShell syntax (including chezmoi-templated `.ps1.tmpl`
  files, rendered before parsing), runs Pester unit tests
  (`tests/powershell/functions.Tests.ps1`), and does a `chezmoi --dry-run`
- Locally: `Invoke-Pester tests/powershell -Output Detailed` and
  `$env:CI = "true"; chezmoi init --source="$PWD" --apply --dry-run`
- No Windows container path exists for local Docker-based testing — Windows
  containers require a Windows Docker host, which this repo doesn't set up

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
- **Core Tools** (always installed): git, fish, jq, tmux, neovim, bat, fzf, gh
- **Optional/heavy toolchains** (only with `DOTFILES_FULL_INSTALL=1`,
  independent of CI/container mode): Go, Node.js
- **Skipped in containers** (`packages/brewfile.tmpl`'s `$skip_heavy`, tied
  to `/.dockerenv` detection): AWS CLI and other heavy formulae
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

# Without a volume mount, the container's default CMD
# (test-bootstrap-offline.sh) runs against a mock repo, not your checkout.
# To test your actual local changes, mount the repo root as /dotfiles-source
# and run the online bootstrap + bats explicitly:
docker run --rm -v "$(cd .. && cd .. && pwd):/dotfiles-source:ro" dotfiles-test-ubuntu \
  bash -c "bash /home/testuser/test-bootstrap.sh && bash /home/testuser/run-bats-tests.sh"

# On Windows Git Bash, prefix with MSYS_NO_PATHCONV=1 so the /dotfiles-source
# container-side path in -v isn't mistranslated to a Windows path.
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
- No SSH access needed: `test-bootstrap.sh` either mounts your local checkout
  at `/dotfiles-source`, or falls back to an HTTPS clone of the public GitHub
  repo — nothing here needs SSH keys

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

1. **Timeout Errors**: Default timeout is 10 minutes
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