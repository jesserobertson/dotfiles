# Env Var Single-Source Design (data-driven loop)

**Date:** 2026-07-07
**Status:** Proposed — not yet implemented
**Requires:** a working `chezmoi` binary to render/verify templates (this doc was written from inside the chezmoi source dir, where `chezmoi` itself isn't installed — implement and verify from an environment where `chezmoi execute-template` works)

## Goal

Right now every environment variable's *value* is defined once (`.chezmoi.toml.tmpl` `[data]`), but the *list of which vars to export* is still hand-duplicated across three shell-specific files. Adding a new tool env var means remembering to touch bash, fish, and PowerShell separately — miss one and the shells silently drift out of sync. This design makes the var list itself data-driven so a new var is added in exactly one place.

## Current state (as of 2026-07-07, post env-consolidation)

- `.chezmoi.toml.tmpl` `[data]` — single source of truth for *values* (XDG dirs, `local_dir`, `rustup_home`, `cargo_home`, `pixi_home`, `juliaup_home`, `julia_depot_path`, `ghcup_install_base_prefix`, `homebrew_*`, `editor`/`pager`/`git_pager`, `ssh_auth_sock`).
- `dot_config/bash/env.sh.tmpl` — canonical POSIX file; one `export NAME="{{ .value }}"` line per var, plus `PATH`/`MANPATH`/`INFOPATH` construction and an OS-guarded `SSH_AUTH_SOCK`.
- `dot_config/zsh/env.zsh.tmpl` — just `source "{{ .xdg_config_home }}/bash/env.sh"`. No duplication here — already solved.
- `dot_config/fish/env.fish.tmpl` — same var list as bash, hand-written again in fish syntax (`set -gx NAME "value"`, `fish_add_path`).
- `dot_config/powershell/profile.ps1` — same var list again, hand-written in PowerShell (`Set-EnvDefault NAME @(...)`), because fish/PowerShell can't `source` a POSIX `.sh` file.
- `dot_bashrc.tmpl` / `dot_zshrc.tmpl` — just `source` the env files above; not part of the duplication problem (this was already fixed this session).

So today: **3 files** (`bash/env.sh.tmpl`, `fish/env.fish.tmpl`, `profile.ps1`) each hand-list the same ~20 vars. That's the drift surface.

## Proposed design

Turn the "plain value" vars (the ones that are just `NAME="literal string"` with no shell-specific construction) into a data-driven list in `.chezmoi.toml.tmpl`, and have each per-shell file `range` over it instead of hand-writing each line.

### 1. `.chezmoi.toml.tmpl`: build the list(s)

Add two TOML array-of-tables under `[data]`, built from the Go template vars already computed in the file (`$localDir`, `$homebrewPrefix`, etc.):

```gotemplate
# Vars valid on every platform (bash/zsh/fish AND PowerShell)
[[data.env_vars]]
  name = "XDG_CONFIG_HOME"
  value = {{ joinPath .chezmoi.homeDir ".config" | quote }}
[[data.env_vars]]
  name = "XDG_DATA_HOME"
  value = {{ joinPath $localDir "share" | quote }}
[[data.env_vars]]
  name = "XDG_CACHE_HOME"
  value = {{ joinPath .chezmoi.homeDir ".cache" | quote }}
[[data.env_vars]]
  name = "XDG_STATE_HOME"
  value = {{ joinPath $localDir "state" | quote }}
[[data.env_vars]]
  name = "LOCAL"
  value = {{ $localDir | quote }}
[[data.env_vars]]
  name = "LOCAL_BIN"
  value = {{ joinPath $localDir "bin" | quote }}
[[data.env_vars]]
  name = "CONFIG"
  value = {{ joinPath .chezmoi.homeDir ".config" | quote }}
[[data.env_vars]]
  name = "RUSTUP_HOME"
  value = {{ joinPath $localDir "share" "rustup" | quote }}
[[data.env_vars]]
  name = "CARGO_HOME"
  value = {{ joinPath $localDir "share" "cargo" | quote }}
[[data.env_vars]]
  name = "PIXI_HOME"
  value = {{ joinPath $localDir "share" "pixi" | quote }}
[[data.env_vars]]
  name = "JULIAUP_HOME"
  value = {{ joinPath $localDir "share" "juliaup" | quote }}
[[data.env_vars]]
  name = "JULIA_DEPOT_PATH"
  value = {{ joinPath $localDir "share" "julia" | quote }}
[[data.env_vars]]
  name = "GHCUP_INSTALL_BASE_PREFIX"
  value = {{ joinPath $localDir "share" | quote }}
[[data.env_vars]]
  name = "EDITOR"
  value = "hx"
[[data.env_vars]]
  name = "PAGER"
  value = "less"
[[data.env_vars]]
  name = "GIT_PAGER"
  value = "delta"
[[data.env_vars]]
  name = "FZF_DEFAULT_COMMAND"
  value = "fd --type file --color=always --follow --hidden --exclude .git"
[[data.env_vars]]
  name = "FZF_CTRL_T_COMMAND"
  value = "fd --type file --color=always --follow --hidden --exclude .git"
[[data.env_vars]]
  name = "FZF_DEFAULT_OPTS"
  value = "--ansi"

# Homebrew vars — only meaningful on mac/linux (bash/zsh/fish); PowerShell/Windows
# has no Homebrew, so this is a separate list that only those templates loop over.
[[data.homebrew_env_vars]]
  name = "HOMEBREW_PREFIX"
  value = {{ $homebrewPrefix | quote }}
[[data.homebrew_env_vars]]
  name = "HOMEBREW_CELLAR"
  value = {{ joinPath $homebrewPrefix "Cellar" | quote }}
[[data.homebrew_env_vars]]
  name = "HOMEBREW_REPOSITORY"
  value = {{ $homebrewPrefix | quote }}
```

Notes:
- `FZF_CTRL_T_COMMAND` is written as a literal duplicate of `FZF_DEFAULT_COMMAND`'s value rather than a shell self-reference (`$FZF_DEFAULT_COMMAND`) — that keeps every entry a plain, shell-agnostic string, which is what makes the generic loop possible. If that self-reference matters to you stylistically, keep it hand-written instead (see "what stays special-cased" below) — either is defensible, but plain values are simpler to loop over.
- Don't add `SSH_AUTH_SOCK` to this list — its value is `""` on Linux and it's currently only exported when non-empty (`{{- if .ssh_auth_sock }}`). A generic loop has no clean way to express "skip if empty" per-entry without extra metadata, and it's one variable — leave it hand-written (see below).

### 2. `dot_config/bash/env.sh.tmpl`: loop instead of hand-list

Replace the individual `export NAME="value"` lines with:

```gotemplate
{{- range .env_vars }}
export {{ .name }}="{{ .value }}"
{{- end }}

{{- range .homebrew_env_vars }}
export {{ .name }}="{{ .value }}"
{{- end }}
```

`PATH`, `MANPATH`, `INFOPATH`, and the OS-guarded `SSH_AUTH_SOCK` block stay exactly as they are today (hand-written) — see "what stays special-cased."

### 3. `dot_config/fish/env.fish.tmpl`: same loop, fish syntax

```gotemplate
{{- range .env_vars }}
set -gx {{ .name }} "{{ .value }}"
{{- end }}

{{- range .homebrew_env_vars }}
set -gx {{ .name }} "{{ .value }}"
{{- end }}
```

`fish_add_path` calls and the `SSH_AUTH_SOCK` conditional stay hand-written.

### 4. `dot_config/zsh/env.zsh.tmpl`: unchanged

Still just sources `bash/env.sh` — nothing to do here.

### 5. `dot_config/powershell/profile.ps1`: same loop, PowerShell syntax

Replace the individual `[void](Set-EnvDefault NAME @(...))` lines with a loop over the **same** `.env_vars` list (not `.homebrew_env_vars` — Windows has no Homebrew):

```gotemplate
{{- range .env_vars }}
[void](Set-EnvDefault {{ .name }} @("{{ .value }}"))
{{- end }}
```

Keep `EDITOR`/`VISUAL` set explicitly right after the loop (it currently overrides with a comment about Zed as an alternative — that's a deliberate manual override point, not drift, so leave `Set-Item "env:EDITOR" hx` / `Set-Item "env:VISUAL" hx` as-is after the loop). Keep `XDG_DATA_HOME`/`SCOOP`/`PsModulePath`/`$paths` PATH block/`SSH_AUTH_SOCK` hand-written as they are today.

### What stays special-cased (not data-driven, by design)

These have real per-shell construction logic (ordering, separators, conditionals) that a flat name/value loop can't express cleanly — don't try to force them into the loop:

- `PATH` (colon vs semicolon, prepend order, `fish_add_path` vs `export PATH=` vs `Add-EnvPath`)
- `MANPATH` / `INFOPATH` (append to pre-existing shell value)
- `SSH_AUTH_SOCK` (empty-string skip on Linux; different value entirely on Windows — the value differs by OS today via `.ssh_auth_sock`, but the emptiness check is per-shell)
- `EDITOR`/`VISUAL` override in `profile.ps1` (intentional manual override point, commented alternative for Zed)

## Migration checklist for the implementing agent

1. Confirm `chezmoi execute-template < .chezmoi.toml.tmpl` (or `chezmoi data`) renders without error and produces the expected `env_vars`/`homebrew_env_vars` arrays.
2. Update the four files as above.
3. Render each shell file with `chezmoi execute-template < dot_config/bash/env.sh.tmpl` (etc., matching the pattern already used for fish in the `Makefile` and `.github/workflows/test-dotfiles.yml`) and diff against the current rendered output (before/after) to confirm no variable was dropped or renamed.
4. **`tests/quick-test.sh`'s "Bash/Zsh" and "Fish" checks in the "Check shell environment variable consistency" section grep the *template source* for literal `export NAME` / `set -gx NAME`.** Once these lines come from a `{{ range }}` loop, that literal text won't appear in the source for any specific var name. Update those checks to either:
   - grep the *rendered* output (`chezmoi execute-template < ... | grep ...`), or
   - just assert the loop exists (`grep -q 'range .env_vars'`) and separately assert the var is present in `.chezmoi.toml.tmpl`'s `env_vars` list.
5. Run `tests/bats/shell-env.bats` (needs actual `chezmoi apply` + bash/zsh/fish present) to confirm `EDITOR`/`PAGER`/`CONFIG`/PATH consistency still holds at runtime.
6. Spot-check one full `chezmoi apply` on a real machine (or the Docker bootstrap test) before merging, since this touches every interactive shell's startup.

## Non-goals

- Not touching `run_onchange_*` install scripts.
- Not changing any actual directory values (this is a pure refactor of *how* vars are declared, not *what* they're set to) — this follows directly from the cabal/pixi/ghcup/juliaup relocation and bash/zsh consolidation done in the same session (see git history around 2026-07-07 for that prior change).
