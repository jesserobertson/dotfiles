# Add some keybindings for git
alias ga "git add"
alias gaa "git add --all"
alias msg magic_diff # use magic_diff to create a commit message
alias gac "git add --all && magic_diff && git commit"
alias gc "git commit"
alias gs "git status"
alias gd "git diff"
alias push "git push"
alias pull "git pull"

# Add bat and batextras
alias cat bat
alias rg batgrep
alias pretty prettybat

# Add eza rather than ls
alias ls eza

# Add and configure rip2
alias rm "echo use 'rip' instead of 'rm'"
alias rip "rip --graveyard $LOCAL/share/trash"
