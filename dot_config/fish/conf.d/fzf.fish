# FZF fuzzy finder integration
if status is-interactive && type -q fzf
    fzf --fish | source
end
