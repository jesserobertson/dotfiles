# Dotfiles Testing Framework

This directory contains comprehensive testing infrastructure for validating dotfiles installation across different platforms using Docker, docker-compose, and CI/CD.

## Overview

The testing framework validates that:
- The chezmoi bootstrap process works correctly
- Homebrew is installed and configured properly
- All packages from the Brewfile are installed
- Dotfiles are applied correctly
- Core tools and applications are available and functional
- Shell configurations work across environments

## Structure

```
tests/
├── README.md                       # This file
├── docker-compose.yml              # Multi-platform orchestration
├── run-tests.sh                    # Main test runner with options
├── verify-installation.sh          # Comprehensive verification script
├── test-shell-env.sh              # Shell environment consistency tests
└── docker/
    ├── ubuntu/
    │   ├── Dockerfile              # Ubuntu 22.04 container
    │   ├── test-bootstrap.sh       # Ubuntu bootstrap tests
    │   └── test-bootstrap-offline.sh # Offline mode tests
    └── macos/
        ├── Dockerfile              # macOS-like environment
        ├── test-bootstrap-macos.sh # macOS bootstrap tests
        └── test-bootstrap-offline.sh # macOS offline tests
```

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Test all platforms
cd tests
docker-compose up --abort-on-container-exit

# Or test individual platforms
docker-compose run --rm ubuntu          # Ubuntu with verification
docker-compose run --rm ubuntu-offline  # Ubuntu offline mode
docker-compose run --rm macos-sim       # macOS simulation
```

### Using the Test Runner

```bash
# Run default Ubuntu test
./tests/run-tests.sh

# Test with options
./tests/run-tests.sh -p ubuntu,macos -t 900 -v
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

## CI/CD Integration

### GitHub Actions

Automated tests run on every push and pull request via `.github/workflows/test-dotfiles.yml`:

- **Ubuntu tests**: Run in Docker containers (fast, consistent)
- **macOS tests**: Run on GitHub's native macOS runners (true macOS environment)
- **Docker Compose tests**: Full test suite validation

View test results at: `https://github.com/[user]/[repo]/actions`

The workflow includes:
- `test-ubuntu`: Docker-based Ubuntu testing
- `test-macos`: Native macOS runner with full installation
- `test-docker-compose`: Comprehensive docker-compose test suite

### Manual GitHub Actions Trigger

You can manually trigger the workflow from the Actions tab in GitHub.

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