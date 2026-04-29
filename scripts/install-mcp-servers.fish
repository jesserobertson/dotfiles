#!/usr/bin/env fish

if set -q CI
    echo "CI environment detected - skipping Claude Code MCP server setup"
    exit 0
end

if test (uname -s) != "Darwin"
    echo "MCP server setup is only available on macOS"
    exit 0
end

echo "Setting up Claude Code MCP servers..."

if not type -q npx
    echo "Warning: npx not found. Things MCP requires Node.js and npm."
    echo "Install Node.js from https://nodejs.org/ or via Homebrew: brew install node"
    exit 1
end

echo "Verifying Things MCP server..."
if npx -y @hald/things-mcp --version >/dev/null 2>&1
    echo "  Things MCP server is ready"
else
    echo "  Installing Things MCP server..."
    npx -y @hald/things-mcp --version
end

echo ""
echo "MCP servers setup complete!"
echo "Things integration is available in Claude Code sessions."
