function chezmoi-cleanup --description "Nuke all brew/crates installs, managed dotfiles, and do fresh install"
    set -l red (set_color red)
    set -l yellow (set_color yellow)
    set -l green (set_color green)
    set -l normal (set_color normal)

    echo "$red=== Chezmoi Nuclear Cleanup Script ===$normal"
    echo "This will COMPLETELY REMOVE:"
    echo "  - All Homebrew packages and brew itself"
    echo "  - All Cargo/Rust installed packages"
    echo "  - All managed dotfiles in your home directory"
    echo "  - All application data and caches"
    echo ""
    echo "$red WARNING: This is destructive and will require a full reinstall!$normal"
    echo ""

    # Confirm before proceeding
    if not confirm "Are you ABSOLUTELY SURE you want to proceed?"
        echo "$yellow Cleanup cancelled.$normal"
        return 0
    end

    echo ""
    echo "$red Starting nuclear cleanup...$normal"

    # PHASE 1: Uninstall all Homebrew packages
    echo ""
    echo "$yellow Phase 1: Removing all Homebrew packages...$normal"
    if command -q brew
        echo "  Listing all installed packages..."
        set -l brew_packages (brew list --formula)
        set -l brew_casks (brew list --cask)

        if test (count $brew_packages) -gt 0
            echo "  Uninstalling all Homebrew formulae..."
            for pkg in $brew_packages
                echo "    Removing: $pkg"
                brew uninstall --force --ignore-dependencies $pkg 2>/dev/null || true
            end
        end

        if test (count $brew_casks) -gt 0
            echo "  Uninstalling all Homebrew casks..."
            for cask in $brew_casks
                echo "    Removing: $cask"
                brew uninstall --cask --force $cask 2>/dev/null || true
            end
        end

        echo "  Removing Homebrew installation..."
        /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" 2>/dev/null || true

        # Clean up Homebrew directories
        rip /opt/homebrew 2>/dev/null || sudo rm -rf /opt/homebrew 2>/dev/null || true
        rip /usr/local/Homebrew 2>/dev/null || sudo rm -rf /usr/local/Homebrew 2>/dev/null || true
    else
        echo "  Homebrew not found, skipping..."
    end

    # PHASE 2: Remove all Cargo/Rust installed packages
    echo ""
    echo "$yellow Phase 2: Removing all Cargo packages...$normal"
    if test -d ~/.cargo/bin
        echo "  Uninstalling all cargo-installed binaries..."
        if command -q cargo
            set -l cargo_bins (ls ~/.cargo/bin/ 2>/dev/null)
            for bin in $cargo_bins
                # Skip cargo and rustc themselves
                if not string match -q -r '^(cargo|rustc|rustup)' $bin
                    echo "    Removing: $bin"
                    cargo uninstall $bin 2>/dev/null || true
                end
            end
        end
    end

    echo "  Removing entire ~/.cargo directory..."
    rip ~/.cargo 2>/dev/null || rm -rf ~/.cargo 2>/dev/null || true

    echo "  Removing ~/.rustup directory..."
    rip ~/.rustup 2>/dev/null || rm -rf ~/.rustup 2>/dev/null || true

    # PHASE 3: Remove all managed dotfiles
    echo ""
    echo "$yellow Phase 3: Removing all managed dotfiles...$normal"

    # Get list of files managed by chezmoi
    if command -q chezmoi
        echo "  Getting list of managed files from chezmoi..."
        set -l managed_files (chezmoi managed -i files 2>/dev/null)

        for file in $managed_files
            if test -e ~/$file
                echo "    Removing: ~/$file"
                rip ~/$file 2>/dev/null || rm -f ~/$file 2>/dev/null || true
            end
        end

        # Remove managed directories
        set -l managed_dirs (chezmoi managed -i dirs 2>/dev/null)
        for dir in $managed_dirs
            if test -d ~/$dir
                echo "    Removing: ~/$dir"
                rip ~/$dir 2>/dev/null || rm -rf ~/$dir 2>/dev/null || true
            end
        end
    end

    # PHASE 4: Clean application data directories
    echo ""
    echo "$yellow Phase 4: Cleaning application data directories...$normal"
    set -l app_dirs \
        ~/.local/share/nvim \
        ~/.cache/nvim \
        ~/.local/state/nvim \
        ~/.local/share/alacritty \
        ~/.cache/alacritty \
        ~/.local/share/bat \
        ~/.cache/bat \
        ~/.local/share/fish \
        ~/.cache/fish \
        ~/.local/share/tmux \
        ~/.cache/starship \
        ~/.cache/chezmoi \
        ~/.tmux \
        ~/.config/nvim \
        ~/.config/alacritty \
        ~/.config/tmux \
        ~/.config/fish \
        ~/.config/starship.toml \
        ~/.config/sesh

    for dir in $app_dirs
        if test -e $dir
            echo "  Removing: $dir"
            rip $dir 2>/dev/null || rm -rf $dir 2>/dev/null || true
        else
            echo "  Skipping: $dir (not found)"
        end
    end

    # PHASE 5: Clean history and temp files
    echo ""
    echo "$yellow Phase 5: Cleaning history and temp files...$normal"
    set -l cleanup_files \
        ~/.viminfo \
        ~/.lesshst \
        ~/.bash_history \
        ~/.zsh_history \
        ~/.fish_history

    for file in $cleanup_files
        if test -f $file
            echo "  Removing: $file"
            rip $file 2>/dev/null || rm -f $file 2>/dev/null || true
        end
    end

    # PHASE 6: Fresh install
    echo ""
    echo "$yellow Phase 6: Starting fresh installation...$normal"

    # Reinstall Homebrew
    echo "  Installing Homebrew..."
    /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Reinstall Rust
    echo "  Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo env
    if test -f ~/.cargo/env
        source ~/.cargo/env
    end

    # Apply chezmoi configuration
    if command -q chezmoi
        echo "  Applying chezmoi configuration..."
        chezmoi apply

        echo "  Running chezmoi install scripts..."
        chezmoi init --apply
    else
        echo "  $red Warning: chezmoi not found, skipping dotfile installation$normal"
    end

    echo ""
    echo "$green Nuclear cleanup and reinstall completed!$normal"
    echo ""
    echo "$yellow Next steps:$normal"
    echo "  1. Restart your terminal/shell"
    echo "  2. Verify installations with: brew --version && cargo --version"
    echo "  3. Open nvim - it will install plugins automatically"
    echo "  4. Check that all your dotfiles are in place"

    return 0
end
