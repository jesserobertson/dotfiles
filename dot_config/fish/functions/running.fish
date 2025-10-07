function running -d "Lists running processes with a given name"
    ps -o pid,command | rg -i $argv | rg -v rg
end
