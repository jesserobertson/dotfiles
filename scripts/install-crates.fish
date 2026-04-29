#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Rust crate installation"
    exit 0
end

if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end
set -q RUSTUP_HOME;     or set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -q CARGO_HOME;      or set -gx CARGO_HOME "$HOME/.local/share/cargo"
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set PATH "$CARGO_HOME/bin" $PATH

echo "Installing Rust crates..."

if not type -q cargo
    echo "Error: cargo not found. Please ensure Rust is installed."
    echo "RUSTUP_HOME: $RUSTUP_HOME"
    echo "CARGO_HOME: $CARGO_HOME"
    echo "Current PATH: $PATH"
    echo "Contents of $CARGO_HOME/bin:"
    ls -la "$CARGO_HOME/bin" 2>/dev/null; or echo "Directory does not exist"
    exit 1
end

set CRATES_FILE "$XDG_CONFIG_HOME/cratefile"
if not test -f "$CRATES_FILE"
    echo "Error: Crates file not found at $CRATES_FILE"
    exit 1
end

set CRATES (grep -v '^#' "$CRATES_FILE" | grep -v '^$' | sed 's/#.*//')

if test -z "$CRATES"
    echo "No crates to install"
    exit 0
end

echo "Crates to install: $CRATES"

if test "$FORCE" = "true"
    echo "Force mode enabled - reinstalling all crates..."
    for crate in $CRATES
        echo "Reinstalling $crate..."
        cargo install --force "$crate"
    end
else
    for crate in $CRATES
        if not cargo install --list | grep -q "^$crate v"
            echo "Installing $crate..."
            cargo install "$crate"
        else
            echo "$crate already installed"
        end
    end
end

echo "Rust crates installation complete!"
