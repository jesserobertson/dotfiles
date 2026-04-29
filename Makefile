.PHONY: bootstrap dotfiles prereqs brew rust crates python skills mcp pixi tmux powershell

bootstrap: dotfiles prereqs brew rust crates python skills mcp pixi  ## Full new-machine setup

dotfiles:  ## Apply dotfiles (chezmoi apply)
	chezmoi apply

prereqs:  ## Homebrew + 1Password (macOS/Linux) or Scoop + tools (Windows)
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
