# Use the editor of the beast
fish_vi_key_bindings

# Add completions and aliases
set dir (dirname (status --current-filename))
source_if_exists "$dir/env.fish"
source_if_exists "$dir/alias.fish"

# Tool integrations are now in conf.d/ and loaded automatically
