#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Claude Code skill installation"
    exit 0
end

echo "Installing Claude Code skills..."

if not type -q git
    echo "Error: git not found. Please ensure git is installed."
    exit 1
end

set SKILLS_DIR "$HOME/.claude/skills"
set SKILLFILE "$HOME/.claude/skillfile"

if not test -d "$SKILLS_DIR"
    echo "Creating skills directory at $SKILLS_DIR..."
    mkdir -p "$SKILLS_DIR"
end

if not test -f "$SKILLFILE"
    echo "No skillfile found at $SKILLFILE - skipping skill installation"
    exit 0
end

set SKILL_URLS (grep -v '^#' "$SKILLFILE" | grep -v '^$' | sed 's/#.*//')

if test -z "$SKILL_URLS"
    echo "No skills to install"
    exit 0
end

echo "Skills to process: "(count $SKILL_URLS)

for url in $SKILL_URLS
    set repo_name (basename "$url" .git)
    set skill_path "$SKILLS_DIR/$repo_name"

    if test -d "$skill_path"
        echo "Updating skill: $repo_name..."
        cd "$skill_path"

        if test -d .git
            git fetch origin
            if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1
                git pull --ff-only
                echo "  Updated $repo_name"
            else
                echo "  $repo_name is not tracking a remote branch - skipping update"
            end
        else
            echo "  Warning: $skill_path exists but is not a git repository"
        end
    else
        echo "Installing skill: $repo_name..."
        if git clone "$url" "$skill_path"
            echo "  Installed $repo_name successfully"
        else
            echo "  Error: Failed to clone $repo_name from $url"
        end
    end
end

echo ""
echo "Claude Code skills installation complete!"
echo "Installed skills are located at: $SKILLS_DIR"
