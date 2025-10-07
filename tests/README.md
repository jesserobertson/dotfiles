# Dotfiles Testing Framework

This directory contains a Docker-based testing framework for validating the dotfiles setup across different platforms.

## Overview

The testing framework validates that:
- The chezmoi bootstrap process works correctly
- Homebrew is installed and configured properly
- All packages from the Brewfile are installed
- Dotfiles are applied correctly
- Core tools and applications are available and functional

## Structure

```
tests/
├── README.md                     # This file
├── run-tests.sh                  # Main test runner
├── verify-installation.sh        # Standalone verification script
└── docker/
    ├── ubuntu/
    │   ├── Dockerfile            # Ubuntu container setup
    │   └── test-bootstrap.sh     # Ubuntu-specific tests
    └── macos/
        ├── Dockerfile            # macOS-like container setup
        └── test-bootstrap-macos.sh # macOS-specific tests
```

## Usage

### Quick Start

Run the default Ubuntu test:
```bash
./tests/run-tests.sh
```

### Test Both Platforms

```bash
./tests/run-tests.sh --platforms ubuntu,macos
```

### Advanced Options

```bash
# Extended timeout and verbose output
./tests/run-tests.sh -t 900 -v

# Keep containers after tests for debugging
./tests/run-tests.sh -n

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

## Platform Support

### Ubuntu
- Tests Linux Homebrew installation
- Validates all brew packages install correctly
- Checks dotfile application
- Verifies shell configurations

### macOS (Simulated)
- Uses Linux container with macOS-like paths for testing
- Validates the cross-platform logic in the bootstrap script
- Tests formula installations (casks are skipped in container)
- Note: True macOS testing requires macOS Docker support or native execution

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