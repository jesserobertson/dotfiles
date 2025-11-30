# Direnv integration for per-directory environment variables
if status is-interactive && type -q direnv
    direnv hook fish | source
end
