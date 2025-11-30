# Pixi completion for Python packaging
if status is-interactive && type -q pixi
    pixi completion --shell fish | source
end
