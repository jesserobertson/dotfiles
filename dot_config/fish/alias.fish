# Git abbreviations (now in conf.d/git-abbrs.fish)
# Kept here for reference - these are now abbreviations not aliases

# Add bat and batextras
alias cat bat
alias rg batgrep
alias pretty prettybat

# Add eza rather than ls
alias ls eza

# Add and configure rip2
alias rm "echo use 'rip' instead of 'rm'"
alias rip "rip --graveyard $LOCAL/share/trash"

# Add serena aliases
alias serena "uvx --from git+https://github.com/oraios/serena serena"
alias start-serena "uvx --from git+https://github.com/oraios/serena serena start-mcp-server --project-from-cwd --transport sse --port 9121 --context=claude-code"
