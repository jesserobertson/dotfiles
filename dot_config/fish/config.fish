# Use the editor of the beast
fish_vi_key_bindings

# Add completions and aliases
set dir (dirname (status --current-filename))
source_if_exists "$dir/env.fish"
source_if_exists "$dir/alias.fish"

# Function to check whether command exists before running setup
function check
    # Parse arguments
    set --local program $argv[1]
    set --local command $argv[2..-1]

    # Check for presence of program, run command if so
    if type -q $program # returns 0 if something is function/builtin/program
        eval $command
    else
        echo "Couldn't find $program"
    end
end

# Command to run in an interactive session
if status is-interactive
    starship init fish | source

    # Add python packaging
    direnv hook fish | source
    pixi completion --shell fish | source

    # Add autojump
    zoxide init fish | source

    # Add bat rather than cat
    eval (batpipe)
    batman --export-env | source

    # Set up FZF
    fzf --fish | source
end
