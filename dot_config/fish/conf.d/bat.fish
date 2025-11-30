# Bat integration for better cat/man pages
if status is-interactive
    if type -q batpipe
        eval (batpipe)
    end
    if type -q batman
        batman --export-env | source
    end
end
