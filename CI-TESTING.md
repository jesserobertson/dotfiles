# CI/CD Testing Configuration

This document explains how the dotfiles handle CI/CD environments where certain dependencies (like 1Password) are not available.

## Problem

Some dotfile templates use 1Password to securely inject secrets:
- `.aws/config` - Uses `onepasswordDocument` for AWS credentials
- `.gitconfig` - Uses `onepasswordDocument` for git configuration

These templates require the 1Password CLI (`op`) to be available, but in CI environments (GitHub Actions, GitLab CI, etc.), we don't have access to 1Password vaults.

## Solution

The dotfiles automatically detect CI environments and gracefully skip 1Password-dependent features:

### 1. CI Detection (`run_before_00-install-prereqs.sh`)

The prerequisite installation script detects CI environments using standard environment variables:
- `CI` - Generic CI indicator
- `GITHUB_ACTIONS` - GitHub Actions
- `GITLAB_CI` - GitLab CI

When CI is detected, 1Password CLI installation is skipped entirely.

### 2. Conditional File Ignore (`.chezmoiignore.tmpl`)

A templated ignore file conditionally excludes 1Password-dependent files in CI:

```bash
{{- if or (env "CI") (env "GITHUB_ACTIONS") (env "GITLAB_CI") }}
# Skip 1Password-dependent templates in CI
.aws/config
.gitconfig
{{ end -}}
```

**Result:**
- **Local development**: All files are applied, 1Password CLI is used for secrets
- **CI environment**: 1Password-dependent files are skipped, no secrets required

## Testing

You can test CI behavior locally:

```bash
# Test that files are ignored in CI
env CI=true chezmoi apply --dry-run

# Test that chezmoi ignore works
env CI=true chezmoi execute-template < .chezmoiignore.tmpl
```

## Adding New 1Password Templates

When adding new templates that use 1Password (`onepasswordDocument`, `onepasswordRead`, etc.):

1. Add the file path to `.chezmoiignore.tmpl` in the CI conditional block
2. Ensure the template has a sensible fallback or default value if possible
3. Document the 1Password dependency in this file

Example:
```tmpl
{{- if or (env "CI") (env "GITHUB_ACTIONS") (env "GITLAB_CI") }}
.aws/config
.gitconfig
.ssh/config  # <-- Add new 1Password-dependent file here
{{ end -}}
```

## CI/CD Workflows

### GitHub Actions

The `.github/workflows/test-dotfiles.yml` workflow automatically sets `GITHUB_ACTIONS=true`, so no additional configuration is needed.

### Local Testing Without 1Password

To simulate CI behavior locally without 1Password:

```bash
# Set CI env var
export CI=true

# Run chezmoi as normal
chezmoi apply

# Unset when done
unset CI
```

## Limitations

Files skipped in CI:
- `.aws/config` - AWS credentials won't be configured
- `.gitconfig` - Git user configuration won't be set

This is acceptable for CI as these are environment-specific settings that aren't needed for build/test operations.
