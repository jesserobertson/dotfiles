#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Rust installation"
    exit 0
end

# Source env.fish for correct XDG/tool paths; fall back to XDG defaults
if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
set -q RUSTUP_HOME; or set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -q CARGO_HOME;  or set -gx CARGO_HOME "$HOME/.local/share/cargo"
set PATH "$CARGO_HOME/bin" $PATH

if not test -d "$CARGO_HOME/bin"
    if type -q rustup
        echo "rustup found but not in correct location, removing old installation..."
        rustup self uninstall -y 2>/dev/null; or true
        brew uninstall rustup 2>/dev/null; or true
        rm -rf ~/.cargo ~/.rustup 2>/dev/null; or true
    end

    echo "Installing rustup to custom location..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    set PATH "$CARGO_HOME/bin" $PATH
end

echo "Checking Rust toolchain..."
if type -q rustup
    if test "$FORCE" = "true"
        echo "Force mode enabled - reinstalling Rust toolchains..."
        rustup toolchain uninstall stable 2>/dev/null; or true
        rustup toolchain uninstall nightly 2>/dev/null; or true
        rustup toolchain install stable
        rustup toolchain install nightly
    else
        if not rustup toolchain list | grep -q 'stable'
            echo "Installing stable toolchain..."
            rustup toolchain install stable
        else
            echo "Stable toolchain already installed"
        end

        if not rustup toolchain list | grep -q 'nightly'
            echo "Installing nightly toolchain..."
            rustup toolchain install nightly
        else
            echo "Nightly toolchain already installed"
        end
    end

    echo "Rust toolchain check complete!"
else
    echo "Warning: rustup not found, skipping Rust toolchain installation"
end
