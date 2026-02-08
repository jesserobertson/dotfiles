# Claude Code Configuration Management

This directory contains Claude Code configuration managed through [chezmoi](https://www.chezmoi.io/).

## Overview

Claude Code configuration is managed in two main ways:

### 1. Skills (GitHub Repositories)

**Skills** are GitHub repositories that extend Claude Code with custom capabilities, agents, and workflows.

- **Configuration**: `skillfile` - List of GitHub URLs for skills to install
- **Installation**: Automatic via `run_onchange_after_04-install-skills.fish.tmpl`
- **Location**: Installed to `~/.claude/skills/`
- **Updates**: Skills are automatically updated when you run `chezmoi apply`

#### Adding New Skills

1. Edit `skillfile` in your chezmoi source directory
2. Add GitHub URLs (one per line)
3. Run `chezmoi apply`

Example:
```
# Git workflow automation
https://github.com/ChrisWiles/claude-code-showcase
```

#### Available Skills

Currently installed:
- [cody-article-writer](https://github.com/ibuildwith-ai/cody-article-writer) - Article writing assistance
- roborev-address - Code review addressing
- roborev-respond - Code review responses

Suggested skills (commented in skillfile):
- [claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) - Git workflow examples
- [claude-skills](https://github.com/alirezarezvani/claude-skills) - Collection of practical skills

More skills available at:
- [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills)
- [claude-flow](https://github.com/ruvnet/claude-flow)

### 2. MCP Servers (Model Context Protocol)

**MCP Servers** provide Claude Code with access to external tools and data sources.

- **Configuration**: `settings.json.tmpl` - Template for main settings file
- **Installation**: Platform-specific via `run_onchange_after_05-install-mcp-servers.fish.tmpl`
- **Location**: Configured in `~/.claude/settings.json`

#### Configured MCP Servers

**macOS Only:**
- **Things MCP** ([things-mcp](https://github.com/hald/things-mcp/)) - Integrates with Things 3 task manager
  - Allows Claude to read/create/update tasks and projects
  - Requires Node.js/npm installed
  - Auto-installed via npx

#### Adding New MCP Servers

1. Edit `settings.json.tmpl` to add server configuration
2. Add installation logic to `run_onchange_after_05-install-mcp-servers.fish.tmpl` if needed
3. Run `chezmoi apply`

Example MCP server configuration:
```json
"mcpServers": {
  "server-name": {
    "command": "npx",
    "args": ["-y", "@package/name"]
  }
}
```

## How It Works

### Installation Flow

1. **Skills Installation** (`run_onchange_after_04-install-skills.fish.tmpl`):
   - Triggered when `skillfile` changes (detected via hash)
   - Clones new skills from GitHub
   - Updates existing skills with `git pull`
   - Skills remain as git repositories for easy development

2. **MCP Server Setup** (`run_onchange_after_05-install-mcp-servers.fish.tmpl`):
   - Triggered when `settings.json.tmpl` changes
   - Verifies dependencies (e.g., Node.js for Things MCP)
   - Tests MCP server installation
   - Platform-specific setup (currently macOS only)

3. **Settings Application** (`settings.json.tmpl`):
   - Templated to support platform-specific configuration
   - Uses chezmoi variables like `.chezmoi.os` for conditional config
   - Applied to `~/.claude/settings.json` on `chezmoi apply`

### Chezmoi Integration

Files are managed using chezmoi naming conventions:

- `dot_claude/` → `~/.claude/`
- `*.tmpl` → Template files processed with Go templates
- `run_onchange_after_*.fish.tmpl` → Scripts that run when dependencies change

## References

- [Claude Code Documentation](https://code.claude.com/docs)
- [Complete Guide to Git Flow in Claude Code](https://medium.com/@dan.avila7/complete-guide-to-setting-up-git-flow-in-claude-code-616477941f78)
- [Common Claude Code Workflows](https://code.claude.com/docs/en/common-workflows)
- [Awesome Claude Skills](https://github.com/ComposioHQ/awesome-claude-skills)
- [Things MCP Server](https://github.com/hald/things-mcp/)

## Best Practices

1. **Version Control**: Keep skillfile and settings templates in git
2. **Comments**: Document why specific skills/servers are installed
3. **Platform-Specific**: Use chezmoi templates for OS-specific configuration
4. **Testing**: Test skill installations in isolated environments first
5. **Updates**: Regularly update skills by running `chezmoi apply`

## Troubleshooting

### Skills not installing
- Check git is available: `which git`
- Verify skillfile syntax (no extra spaces, valid URLs)
- Check `~/.claude/skills/` for error logs

### MCP servers not working
- Verify Node.js installation: `which node && which npx`
- Check Claude Code settings: `cat ~/.claude/settings.json`
- Review MCP server logs in Claude Code debug output

### Chezmoi not applying changes
- Run `chezmoi diff` to see pending changes
- Use `chezmoi apply -v` for verbose output
- Check file permissions on `~/.claude/`
