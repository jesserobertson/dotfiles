function install_crates --description "Install cargo crates only if not already installed"
    # Arguments: list of crate names to install
    # Example: install_crates bat eza ripgrep
    #
    # Checks if each crate is already installed via `cargo install --list`
    # and only installs if not present

    for crate in $argv
        if not cargo install --list | grep -q "^$crate v"
            cargo install $crate
        end
    end
end
