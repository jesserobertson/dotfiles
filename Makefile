.PHONY: bootstrap dotfiles prereqs brew rust crates python skills mcp pixi tmux powershell test test-templates test-docker test-windows

bootstrap:  ## Full new-machine setup (dotfiles + all tools via run_onchange_ scripts)
	chezmoi apply

dotfiles:  ## Apply dotfiles (chezmoi apply)
	chezmoi apply

prereqs:  ## Homebrew (macOS/Linux) or winget packages (Windows)
ifeq ($(OS),Windows_NT)
	powershell -ExecutionPolicy Bypass -File scripts/install-prereqs.ps1
else
	bash scripts/install-prereqs.sh
endif

brew:  ## Install Homebrew packages from Brewfile
	bash scripts/install-brew.sh

rust:  ## Install Rust toolchain via rustup
	fish scripts/install-rust.fish

crates:  ## Install Rust crates
	fish scripts/install-crates.fish

python:  ## Sync pixi global environments
	fish scripts/install-python.fish

skills:  ## Install Claude Code skills
	fish scripts/install-skills.fish

mcp:  ## Install MCP servers (macOS only)
	fish scripts/install-mcp-servers.fish

pixi:  ## Install pixi global packages
	bash scripts/install-pixi.sh

tmux:  ## Install/update tmux plugin manager
	bash scripts/update-tmux.sh

powershell:  ## Write PowerShell $PROFILE wrapper (Windows)
	powershell -ExecutionPolicy Bypass -File scripts/setup-powershell.ps1

test: test-templates test-docker  ## Run all tests

test-templates:  ## Validate chezmoi templates render without errors
	chezmoi execute-template < dot_bashrc.tmpl > /dev/null
	chezmoi execute-template < dot_zshrc.tmpl > /dev/null
	chezmoi execute-template < dot_config/fish/env.fish.tmpl > /dev/null
	chezmoi execute-template < packages/brewfile.tmpl > /dev/null
	chezmoi execute-template < .chezmoiignore.tmpl > /dev/null
	@echo "All templates OK"

test-docker:  ## Run Docker Compose tests (Linux)
	cd tests && docker compose run --rm ubuntu
	cd tests && docker compose run --rm ubuntu-offline

test-windows:  ## Run Windows tests (Pester + chezmoi dry-run)
	powershell -Command "Invoke-Pester tests/powershell -Output Detailed"
	powershell -Command "$$env:CI='true'; chezmoi init --source='$$PWD' --apply --dry-run"
