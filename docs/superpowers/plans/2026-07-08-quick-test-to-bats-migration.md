# Migrate quick-test.sh to bats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `tests/quick-test.sh`'s eight hand-rolled bash checks with three bats-core files, so bats is the repo's single test framework instead of two parallel implementations of similar checks.

**Architecture:** Three new `.bats` files under `tests/bats/` (`syntax.bats`, `templates.bats`, `repo-hygiene.bats`), each file self-contained (computes its own `REPO_ROOT` from `$BATS_TEST_FILENAME`, no shared helper needed). `run-local-tests.sh --quick` runs these three files via `bats` instead of exec'ing the old script. `quick-test.sh` is deleted once the new files are verified equivalent.

**Tech Stack:** bash, bats-core (already a repo dependency), chezmoi, optionally fish/zsh/pwsh/jq (each check skips cleanly if its interpreter is absent, matching the original script's warn-and-skip behavior).

## Global Constraints

- Every check must skip (not fail) when its interpreter (`fish`, `zsh`, `pwsh`, `chezmoi`, `jq`) is unavailable — matches `quick-test.sh`'s existing `warn`-and-continue behavior. Use bats' `skip "<reason>"`.
- Do not modify `tests/bats/install.bats`, `shell-env.bats`, `fish.bats`, `developer-layout.bats`, or `tmux-scripts.bats`.
- Do not add the new files to `tests/docker/ubuntu/run-bats-tests.sh` (CI's Docker bats run) — their coverage already runs in CI via the separate "Validate templates" step and the Windows PowerShell-syntax job (see spec, "Wiring changes").
- `tests/quick-test.sh` is deleted only after the three new files are confirmed to run and their checks verified against the original script's output (Task 6).
- Reference spec: `docs/superpowers/specs/2026-07-08-quick-test-to-bats-migration-design.md`.

---

### Task 1: Create `tests/bats/repo-hygiene.bats`

**Files:**
- Create: `tests/bats/repo-hygiene.bats`

**Interfaces:**
- Consumes: nothing from other tasks
- Produces: a `bats`-runnable file with 9 tests (6 critical-file existence, JSON validity, no hardcoded paths, no untracked conf.d files) that later tasks (4, 5, 6) reference by path `tests/bats/repo-hygiene.bats`

- [ ] **Step 1: Write the file**

```bash
#!/usr/bin/env bats
# Repo hygiene checks: critical files exist, JSON configs are valid, no
# hardcoded home paths, no untracked conf.d files. No interpreter
# dependency beyond bash/git/find/jq.
# Run: bats tests/bats/repo-hygiene.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ── Critical files ──────────────────────────────────────────────────────────

@test "dot_config/fish/config.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/config.fish" ]
}

@test "dot_config/fish/alias.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/alias.fish" ]
}

@test "dot_config/fish/conf.d/git-abbrs.fish exists" {
    [ -e "$REPO_ROOT/dot_config/fish/conf.d/git-abbrs.fish" ]
}

@test "dot_config/nvim/init.lua exists" {
    [ -e "$REPO_ROOT/dot_config/nvim/init.lua" ]
}

@test "dot_config/tmux/tmux.conf exists" {
    [ -e "$REPO_ROOT/dot_config/tmux/tmux.conf" ]
}

@test ".chezmoiignore.tmpl exists" {
    [ -e "$REPO_ROOT/.chezmoiignore.tmpl" ]
}

# ── JSON validity ────────────────────────────────────────────────────────────

@test "JSON configs are valid" {
    command -v jq >/dev/null 2>&1 || skip "jq not available"

    local failed=0
    local json_file
    while IFS= read -r -d '' json_file; do
        if ! jq empty "$json_file" 2>/dev/null; then
            echo "invalid JSON: ${json_file#$REPO_ROOT/}" >&2
            failed=1
        fi
    done < <(find "$REPO_ROOT" -name "*.json" -not -path "*/.*" -print0)

    [ "$failed" -eq 0 ]
}

# ── Common mistakes ──────────────────────────────────────────────────────────

@test "no hardcoded home directory paths" {
    ! grep -r "/Users/jess.robertson" "$REPO_ROOT/dot_config" 2>/dev/null \
        | grep -v "Binary file" \
        | grep -v "\.claude/" \
        | grep -q .
}

@test "no untracked files in fish conf.d" {
    [ -d "$REPO_ROOT/dot_config/fish/conf.d" ] || skip "conf.d directory not found"
    cd "$REPO_ROOT"
    ! git ls-files --others --exclude-standard dot_config/fish/conf.d/ | grep -q .
}
```

- [ ] **Step 2: Run it and verify all tests pass**

Run: `cd /c/Users/robejess/.local/share/chezmoi && bats tests/bats/repo-hygiene.bats`
Expected: `9 tests, 0 failures` (all pass; none should skip on a normal dev machine since `jq` and `git` are present)

- [ ] **Step 3: Compare against the original check**

Run the equivalent section of the still-present `quick-test.sh` for comparison:
`cd tests && bash -c 'source <(sed -n "234,363p" quick-test.sh)'` will not work standalone (it depends on functions defined earlier in the file) — instead just run the full script and confirm its "Checking critical files...", "Validating JSON configuration files...", and "Checking for common configuration mistakes..." sections report the same pass/fail results as the new bats file:

Run: `bash tests/quick-test.sh 2>&1 | grep -A 20 "Checking critical files"`
Expected: same 6 files reported present, JSON valid, no hardcoded paths, all conf.d tracked — matching the bats output from Step 2

- [ ] **Step 4: Commit**

```bash
git add tests/bats/repo-hygiene.bats
git commit -m "test: add repo-hygiene.bats (part of quick-test.sh -> bats migration)"
```

---

### Task 2: Create `tests/bats/templates.bats`

**Files:**
- Create: `tests/bats/templates.bats`

**Interfaces:**
- Consumes: nothing from other tasks
- Produces: a `bats`-runnable file with 7 tests (4 chezmoi-dependent, 3 always-on static checks) that later tasks (4, 5, 6) reference by path `tests/bats/templates.bats`

- [ ] **Step 1: Write the file**

```bash
#!/usr/bin/env bats
# Chezmoi template processing checks: templates render without error, and
# the [[data.env_vars]] single source of truth (.chezmoi.toml.tmpl) actually
# reaches the bash and fish env templates.
# Run: bats tests/bats/templates.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# ── Chezmoi-dependent (skip if chezmoi isn't installed) ─────────────────────

@test "chezmoi ignore template renders" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    run env CI=true chezmoi execute-template < "$REPO_ROOT/.chezmoiignore.tmpl"
    [ "$status" -eq 0 ]
}

@test "chezmoi dry-run applies cleanly" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    cd "$REPO_ROOT"
    run env CI=true timeout 30 chezmoi apply --dry-run
    [ "$status" -eq 0 ]
}

@test "env_vars render into bash env.sh.tmpl" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    local rendered
    rendered="$(env CI=true chezmoi execute-template < "$REPO_ROOT/dot_config/bash/env.sh.tmpl")"
    echo "$rendered" | grep -q 'export EDITOR='
    echo "$rendered" | grep -q 'export CARGO_HOME='
    echo "$rendered" | grep -q 'export HOMEBREW_PREFIX='
}

@test "env_vars render into fish env.fish.tmpl" {
    command -v chezmoi >/dev/null 2>&1 || skip "chezmoi not available"
    local rendered
    rendered="$(env CI=true chezmoi execute-template < "$REPO_ROOT/dot_config/fish/env.fish.tmpl")"
    echo "$rendered" | grep -q 'set -gx EDITOR '
    echo "$rendered" | grep -q 'set -gx CARGO_HOME '
    echo "$rendered" | grep -q 'set -gx HOMEBREW_PREFIX '
}

# ── Always run, no chezmoi dependency ───────────────────────────────────────

@test "env_vars declared in .chezmoi.toml.tmpl" {
    for var in EDITOR CARGO_HOME HOMEBREW_PREFIX; do
        grep -q "\"${var}\"" "$REPO_ROOT/.chezmoi.toml.tmpl"
    done
}

@test "bash and fish templates loop over env_vars" {
    grep -q 'range \.env_vars' "$REPO_ROOT/dot_config/bash/env.sh.tmpl"
    grep -q 'range \.env_vars' "$REPO_ROOT/dot_config/fish/env.fish.tmpl"
}

@test "dot_bashrc.tmpl and dot_zshrc.tmpl source the shared env file" {
    for rc in "$REPO_ROOT/dot_bashrc.tmpl" "$REPO_ROOT/dot_zshrc.tmpl"; do
        grep -q "^source " "$rc"
    done
}
```

- [ ] **Step 2: Run it and verify all tests pass**

Run: `cd /c/Users/robejess/.local/share/chezmoi && bats tests/bats/templates.bats`
Expected: `7 tests, 0 failures`

- [ ] **Step 3: Compare against the original check**

Run: `bash tests/quick-test.sh 2>&1 | grep -A 5 "Testing Chezmoi template processing"`
Expected: "Chezmoi ignore template processes correctly" and "Chezmoi dry-run completes without errors" both pass, matching the bats results

Run: `bash tests/quick-test.sh 2>&1 | grep -A 3 "Checking shell environment variable consistency"`
Expected: "Bash/Zsh and Fish: all critical variables rendered" passes, matching the bats results

- [ ] **Step 4: Commit**

```bash
git add tests/bats/templates.bats
git commit -m "test: add templates.bats (part of quick-test.sh -> bats migration)"
```

---

### Task 3: Create `tests/bats/syntax.bats`

**Files:**
- Create: `tests/bats/syntax.bats`

**Interfaces:**
- Consumes: nothing from other tasks
- Produces: a `bats`-runnable file with 4 tests (fish/bash/powershell/zsh syntax, each aggregating per-file failures internally) that later tasks (4, 5, 6) reference by path `tests/bats/syntax.bats`

**Note on the PowerShell check:** the original `quick-test.sh` builds one giant `bash -c "... pwsh -Command \"...\" ..."` string with several layers of backslash-escaping. That's fragile to modify. This task instead writes the PowerShell checker to a temp `.ps1` file (via a quoted heredoc, so no bash variable expansion inside it) and invokes it with `pwsh -File`, passing the extra directory as a real argument — same checks, no nested-quoting risk.

- [ ] **Step 1: Write the file**

```bash
#!/usr/bin/env bats
# Syntax checks for fish, bash, PowerShell, and zsh files across the repo.
# Each test aggregates all failures in its file set into one message (bats
# can't dynamically generate @test blocks from a runtime file-discovery
# loop, so this keeps the "check every matching file, report all failures"
# behavior of the original quick-test.sh in a single test per language).
# Run: bats tests/bats/syntax.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "fish syntax" {
    command -v fish >/dev/null 2>&1 || skip "fish not available"

    local failed=0
    local file

    for file in "$REPO_ROOT/dot_config/fish"/*.fish; do
        [ -f "$file" ] || continue
        fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done

    if [ -d "$REPO_ROOT/dot_config/fish/conf.d" ]; then
        for file in "$REPO_ROOT/dot_config/fish/conf.d"/*.fish; do
            [ -f "$file" ] || continue
            fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
        done
    fi

    for func in source_if_exists edit; do
        file="$REPO_ROOT/dot_config/fish/functions/${func}.fish"
        [ -f "$file" ] || continue
        fish -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done

    [ "$failed" -eq 0 ]
}

@test "bash syntax" {
    command -v bash >/dev/null 2>&1 || skip "bash not available"

    local failed=0
    local file
    while IFS= read -r -d '' file; do
        bash -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done < <(find "$REPO_ROOT" -name "*.sh" -type f ! -path "*/.git/*" ! -path "*/node_modules/*" -print0)

    [ "$failed" -eq 0 ]
}

@test "powershell syntax" {
    command -v pwsh >/dev/null 2>&1 || skip "pwsh not available"

    local ps1_tmpl_render_dir=""
    local ps1_tmpl_render_dir_win=""
    if command -v chezmoi >/dev/null 2>&1; then
        ps1_tmpl_render_dir="$(mktemp -d)"
        # pwsh is a native Windows process, so pass it a Windows-style path
        # rather than a Git Bash /tmp/... POSIX path it can't resolve.
        if command -v cygpath >/dev/null 2>&1; then
            ps1_tmpl_render_dir_win="$(cygpath -w "$ps1_tmpl_render_dir")"
        else
            ps1_tmpl_render_dir_win="$ps1_tmpl_render_dir"
        fi
        local tmpl_file rendered_name
        while IFS= read -r -d '' tmpl_file; do
            rendered_name="$(basename "$tmpl_file" .tmpl)"
            env CI=true chezmoi execute-template < "$tmpl_file" > "$ps1_tmpl_render_dir/$rendered_name" 2>/dev/null
        done < <(find "$REPO_ROOT" -name "*.ps1.tmpl" -not -path "*/.git/*" -print0)
    fi

    local checker_dir checker_script
    checker_dir="$(mktemp -d)"
    checker_script="$checker_dir/checker.ps1"
    cat > "$checker_script" <<'PS1EOF'
param([string]$ExtraDir)
$failed = $false
$dirs = @('.')
if ($ExtraDir) { $dirs += $ExtraDir }
Get-ChildItem -Path $dirs -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\.git' } | ForEach-Object {
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        Write-Host "FAIL: $($_.Name): $($parseErrors -join '; ')"
        $failed = $true
    }
}
if ($failed) { exit 1 }
PS1EOF

    cd "$REPO_ROOT"
    run pwsh -NoProfile -NonInteractive -File "$checker_script" -ExtraDir "$ps1_tmpl_render_dir_win"

    rm -rf "$checker_dir"
    [ -n "$ps1_tmpl_render_dir" ] && rm -rf "$ps1_tmpl_render_dir"

    [ "$status" -eq 0 ]
}

@test "zsh syntax" {
    command -v zsh >/dev/null 2>&1 || skip "zsh not available"

    local failed=0

    if [ -f "$REPO_ROOT/dot_zshrc.tmpl" ] && command -v chezmoi >/dev/null 2>&1; then
        if ! env CI=true chezmoi execute-template < "$REPO_ROOT/dot_zshrc.tmpl" 2>/dev/null | zsh -n 2>/dev/null; then
            echo "syntax error: dot_zshrc.tmpl (after template processing)" >&2
            failed=1
        fi
    fi

    local file
    while IFS= read -r -d '' file; do
        zsh -n "$file" 2>/dev/null || { echo "syntax error: ${file#$REPO_ROOT/}" >&2; failed=1; }
    done < <(find "$REPO_ROOT" -name "*.zsh" -type f ! -path "*/.git/*" -print0)

    [ "$failed" -eq 0 ]
}
```

- [ ] **Step 2: Run it and verify results**

Run: `cd /c/Users/robejess/.local/share/chezmoi && bats tests/bats/syntax.bats`
Expected on this Windows dev machine (no `fish`/`zsh` installed natively):
```
1..4
ok 1 fish syntax # skip fish not available
ok 2 bash syntax
ok 3 powershell syntax
ok 4 zsh syntax # skip zsh not available
```

- [ ] **Step 3: Compare against the original check**

Run: `bash tests/quick-test.sh 2>&1 | grep -A 3 "Testing PowerShell script syntax"`
Expected: same "All PowerShell files have valid syntax" result as the bats "powershell syntax" test

- [ ] **Step 4: Commit**

```bash
git add tests/bats/syntax.bats
git commit -m "test: add syntax.bats (part of quick-test.sh -> bats migration)"
```

---

### Task 4: Wire `run-local-tests.sh --quick` to the new bats files

**Files:**
- Modify: `tests/run-local-tests.sh:31-42` (usage help text)
- Modify: `tests/run-local-tests.sh:179-189` (main() QUICK_MODE handling)

**Interfaces:**
- Consumes: `tests/bats/syntax.bats`, `tests/bats/templates.bats`, `tests/bats/repo-hygiene.bats` (from Tasks 1-3)
- Produces: `./run-local-tests.sh --quick` now runs those three files via `bats` and exits with their combined exit code

- [ ] **Step 1: Update the usage help text**

In `tests/run-local-tests.sh`, find:
```bash
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --quick           Run quick validation tests (fastest, ~5 seconds)"
    echo "  -t, --test SUITE      Run specific test suite (default: all)"
    if [ "$BATS_AVAILABLE" = true ]; then
        echo "                        Available (bats): developer-layout, shell-env"
    else
        echo "                        Available (legacy): developer-layout, shell-env"
        echo "                        Note: Install bats-core for improved test experience"
    fi
```

Replace with:
```bash
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -q, --quick           Run syntax.bats/templates.bats/repo-hygiene.bats (fastest, ~5 seconds)"
    echo "  -t, --test SUITE      Run specific test suite (default: all)"
    if [ "$BATS_AVAILABLE" = true ]; then
        echo "                        Available (bats): install, shell-env, fish, syntax, templates,"
        echo "                        repo-hygiene, developer-layout, tmux-scripts"
    else
        echo "                        Available (legacy): developer-layout, shell-env"
        echo "                        Note: Install bats-core for improved test experience"
    fi
```

- [ ] **Step 2: Replace the QUICK_MODE handling in main()**

Find:
```bash
main() {
    # Run quick tests if requested
    if [ "$QUICK_MODE" = true ]; then
        local quick_test="$SCRIPT_DIR/quick-test.sh"
        if [ -x "$quick_test" ]; then
            exec "$quick_test"
        else
            error "Quick test script not found or not executable: $quick_test"
            exit 1
        fi
    fi
```

Replace with:
```bash
main() {
    # Run quick tests if requested
    if [ "$QUICK_MODE" = true ]; then
        if ! command -v bats >/dev/null 2>&1; then
            error "bats-core not found. Install with: brew install bats-core"
            exit 1
        fi
        exec bats "$BATS_DIR/syntax.bats" "$BATS_DIR/templates.bats" "$BATS_DIR/repo-hygiene.bats"
    fi
```

- [ ] **Step 3: Verify bash syntax**

Run: `bash -n tests/run-local-tests.sh`
Expected: no output (syntax OK)

- [ ] **Step 4: Run it and verify equivalent output to running the three files directly**

Run: `cd tests && ./run-local-tests.sh --quick`
Expected: bats TAP-ish output for all 20 tests across the three files (9 + 7 + 4), same pass/skip results as running each file individually in Tasks 1-3 Step 2, exit code 0

- [ ] **Step 5: Commit**

```bash
git add tests/run-local-tests.sh
git commit -m "feat: wire run-local-tests.sh --quick to the new bats files"
```

---

### Task 5: Update `tests/README.md`

**Files:**
- Modify: `tests/README.md` (Test Types Quick Reference table, Overview bullets, Structure tree, Quick Start section)

**Interfaces:**
- Consumes: nothing new (documents the files created in Tasks 1-4)
- Produces: accurate documentation, no functional change

- [ ] **Step 1: Update the Test Types Quick Reference row**

Find:
```
| **Quick Tests** | Shell | ⚡⚡⚡ Instant (~5s) | Syntax, templates, basic validation | Every save, pre-commit |
```

Replace with:
```
| **Quick Tests** | bats-core | ⚡⚡⚡ Instant (~5s) | Syntax, templates, basic validation | Every save, pre-commit |
```

- [ ] **Step 2: Update the Overview bullets**

Find:
```
**Quick Tests (Shell)** validate:
- Fish shell syntax for all config files
- Chezmoi template processing without errors
- Critical files exist
- JSON configuration validity
- No common mistakes (hardcoded paths, etc.)
```

Replace with:
```
**Quick Tests (`syntax.bats`/`templates.bats`/`repo-hygiene.bats`)** validate:
- Fish/bash/PowerShell/zsh syntax for all config files
- Chezmoi template processing without errors, including the `[[data.env_vars]]` single source of truth reaching bash and fish
- Critical files exist
- JSON configuration validity
- No common mistakes (hardcoded paths, etc.)
```

- [ ] **Step 3: Update the Structure tree**

Find:
```
tests/
├── README.md                       # This file
├── quick-test.sh                   # Fast validation tests (~5 seconds)
├── run-local-tests.sh              # Runner for quick/bats/legacy tests
├── run-tests.sh                    # Runner for Docker bootstrap tests (Ubuntu only today)
├── verify-installation.sh          # Post-install verification script (any system)
├── test-shell-env.sh               # Shell environment consistency tests (any system)
├── bats/                           # Bats feature tests
│   ├── install.bats               # Post-bootstrap verification (Docker/CI)
│   ├── shell-env.bats             # EDITOR/PAGER/CONFIG/PATH consistency across bash/zsh/fish
│   ├── fish.bats                  # Fish-specific startup, config, and tool-init checks
│   ├── developer-layout.bats      # Developer project tmux layout
│   ├── tmux-scripts.bats          # Tmux helper scripts
│   └── helpers/
│       ├── setup.bash             # Shared tmux test helpers
│       └── brew.bash              # Homebrew env setup for bats
```

Replace with:
```
tests/
├── README.md                       # This file
├── run-local-tests.sh              # Runner for bats tests
├── run-tests.sh                    # Runner for Docker bootstrap tests (Ubuntu only today)
├── verify-installation.sh          # Post-install verification script (any system)
├── test-shell-env.sh               # Shell environment consistency tests (any system)
├── bats/                           # Bats feature tests
│   ├── syntax.bats                # Fish/bash/PowerShell/zsh syntax checks
│   ├── templates.bats             # Chezmoi template rendering + env_vars consistency
│   ├── repo-hygiene.bats          # Critical files, JSON validity, hardcoded paths
│   ├── install.bats               # Post-bootstrap verification (Docker/CI)
│   ├── shell-env.bats             # EDITOR/PAGER/CONFIG/PATH consistency across bash/zsh/fish
│   ├── fish.bats                  # Fish-specific startup, config, and tool-init checks
│   ├── developer-layout.bats      # Developer project tmux layout
│   ├── tmux-scripts.bats          # Tmux helper scripts
│   └── helpers/
│       ├── setup.bash             # Shared tmux test helpers
│       └── brew.bash              # Homebrew env setup for bats
```

- [ ] **Step 4: Update the Quick Start section**

Find:
```
### Quick Tests (Instant - For Rapid Feedback)

```bash
# Run quick validation tests (syntax, templates, basic checks)
cd tests
./run-local-tests.sh --quick

# Or run directly
./quick-test.sh
```
```

Replace with:
```
### Quick Tests (Instant - For Rapid Feedback)

```bash
# Run quick validation tests (syntax, templates, basic checks)
cd tests
./run-local-tests.sh --quick

# Or run the three bats files directly
bats bats/syntax.bats bats/templates.bats bats/repo-hygiene.bats
```
```

- [ ] **Step 5: Commit**

```bash
git add tests/README.md
git commit -m "docs: update tests/README.md for the quick-test.sh -> bats migration"
```

---

### Task 6: Delete `tests/quick-test.sh` and verify no dangling references

**Files:**
- Delete: `tests/quick-test.sh`

**Interfaces:**
- Consumes: Tasks 1-5 must all be complete and committed first (this task removes the thing they replaced)
- Produces: nothing (cleanup task); final state has zero references to `quick-test.sh` anywhere in the repo

- [ ] **Step 1: Search for any remaining references**

Run: `cd /c/Users/robejess/.local/share/chezmoi && grep -rn "quick-test" --include="*.md" --include="*.sh" --include="*.yml" --include="*.ps1" . 2>/dev/null | grep -v "\.git/"`
Expected output: only `docs/superpowers/specs/2026-07-08-quick-test-to-bats-migration-design.md` and `docs/superpowers/plans/2026-07-08-quick-test-to-bats-migration.md` (this plan and its spec — both intentionally reference the old filename as historical context, not live tooling). If anything else appears (e.g. a leftover mention in `tests/README.md` or `.github/workflows/`), fix it before proceeding.

- [ ] **Step 2: Delete the file**

```bash
git rm tests/quick-test.sh
```

- [ ] **Step 3: Run the full local bats suite to confirm nothing broke**

Run: `cd tests && ./run-local-tests.sh`
Expected: all `*.bats` files in `tests/bats/` run (now 8 files: the 3 new ones plus the existing 5), combined result reported, exit code reflects pass/fail

Run: `cd tests && ./run-local-tests.sh --quick`
Expected: same as Task 4 Step 4 (20 tests across the 3 quick files), confirms `--quick` still works after `quick-test.sh` is gone

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore: remove quick-test.sh, fully replaced by syntax/templates/repo-hygiene.bats

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
