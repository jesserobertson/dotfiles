function init_cached --description 'Run an init command once per binary version, caching the result'
    # Usage: init_cached <tool_name> <command...>
    # Mirrors the PowerShell profile pattern: caches init script output keyed
    # by binary mtime so subsequent shells source a plain file instead of
    # spawning a subprocess.
    set -l tool $argv[1]
    set -l cmd $argv[2..]

    set -l binary (command -v $tool 2>/dev/null)
    if test -z "$binary"
        return 0
    end

    # Get binary mtime — handle GNU stat (-c) and BSD/macOS stat (-f)
    set -l mtime (command stat -c '%Y' "$binary" 2>/dev/null \
                  || command stat -f '%m' "$binary" 2>/dev/null \
                  || echo '0')

    set -l xdg_cache (if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"; echo $XDG_CACHE_HOME; else; echo "$HOME/.cache"; end)
    set -l cache_dir "$xdg_cache/fish"
    set -l cache_file "$cache_dir/{$tool}_init_{$mtime}.fish"

    if not test -f "$cache_file"
        command mkdir -p "$cache_dir"
        # Remove stale cache files for this tool before writing the new one
        for stale in $cache_dir/{$tool}_init_*.fish
            command rm -f "$stale"
        end
        $cmd >"$cache_file" 2>/dev/null
        if not test -s "$cache_file"
            command rm -f "$cache_file"
        end
    end

    test -s "$cache_file" && source "$cache_file"
    return 0
end
