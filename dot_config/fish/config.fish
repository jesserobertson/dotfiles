# Use the editor of the beast
fish_vi_key_bindings

# Add completions and aliases
set dir (dirname (status --current-filename))
test -f "$dir/env.fish" && source "$dir/env.fish"
test -f "$dir/alias.fish" && source "$dir/alias.fish"

# Tool integrations are now in conf.d/ and loaded automatically
