# Migrate quick-test.sh to bats (design)

**Date:** 2026-07-08
**Status:** Approved — ready for implementation plan

## Goal

`tests/quick-test.sh` and `tests/bats/*.bats` are two separate test
implementations (hand-rolled bash accumulating a `FAILED` flag vs. bats-core's
`@test` blocks with built-in skip/pass/fail semantics). Since bats-core is
already a required dependency for this repo's test suite (`install.bats`,
`shell-env.bats`, `fish.bats`, `developer-layout.bats`, `tmux-scripts.bats`
all need it), keeping a second, bats-free implementation of the same kind of
checks buys nothing and is a second place to keep in sync. Migrate
`quick-test.sh`'s eight checks into bats files and delete the script.

## Current state

`tests/quick-test.sh` runs eight checks sequentially, using `pass`/`fail`/`warn`
helpers and a `FAILED` exit-code flag:

1. Fish shell syntax (`dot_config/fish/*.fish`, `conf.d/*.fish`, two named
   function files) — via `fish -n`
2. Bash script syntax (all `*.sh` repo-wide) — via `bash -n`
3. PowerShell script syntax — renders `*.ps1.tmpl` via
   `chezmoi execute-template` into a temp dir first (since chezmoi templates
   aren't valid PowerShell on their own), then parses both those and native
   `*.ps1` via `[System.Management.Automation.Language.Parser]::ParseFile`
4. Zsh configuration syntax — renders `dot_zshrc.tmpl` first, then `zsh -n`
   on that plus any raw `*.zsh` files
5. Chezmoi template processing — `.chezmoiignore.tmpl` renders, and
   `chezmoi apply --dry-run` completes without error
6. Critical files exist (static list of 6 paths)
7. JSON config validity — `jq empty` over all `*.json`
8. Shell environment variable consistency — checks that `EDITOR`/
   `CARGO_HOME`/`HOMEBREW_PREFIX` appear in the *rendered* output of
   `dot_config/bash/env.sh.tmpl` and `dot_config/fish/env.fish.tmpl` (falls
   back to a static grep-based check if chezmoi isn't installed)
9. Common mistakes — no hardcoded `/Users/jess.robertson` paths, no
   untracked files in `dot_config/fish/conf.d/`

Every check already tolerates a missing tool (`fish`, `pwsh`, `zsh`, `chezmoi`,
`jq`) by printing a warning and skipping — this maps directly onto bats'
`skip` primitive.

`run-local-tests.sh --quick` currently `exec`s `quick-test.sh` directly,
bypassing the bats runner entirely. Without `--quick`, it auto-discovers and
runs every `*.bats` file under `tests/bats/` via `find ... -name "*.bats"`.

## New structure

Three new files under `tests/bats/`, replacing `quick-test.sh`:

### `tests/bats/syntax.bats`

One `@test` per language, each internally iterating its file set and
aggregating any failures into one clear message (bats can't dynamically
generate `@test` blocks from a runtime loop over discovered files, so this
preserves today's "check every matching file, report all failures at once"
behavior rather than hand-listing every file as a separate `@test`):

- `fish syntax` — skip if `fish` unavailable
- `bash syntax` — skip if `bash` unavailable (effectively never, but kept
  for symmetry and to match the original script's guard)
- `powershell syntax` — skip if `pwsh` unavailable; renders `*.ps1.tmpl` via
  `chezmoi execute-template` into a temp dir first (reuses the Windows-path
  handling already fixed in `quick-test.sh`: `cygpath -w` when available, so
  `pwsh` — a native Windows process — gets a Windows-style path)
- `zsh syntax` — skip if `zsh` unavailable; renders `dot_zshrc.tmpl` first

### `tests/bats/templates.bats`

- `chezmoi ignore template renders` — skip if `chezmoi` unavailable
- `chezmoi dry-run applies cleanly` — skip if `chezmoi` unavailable
- `env_vars render into bash env.sh.tmpl` — skip if `chezmoi` unavailable;
  asserts `EDITOR`/`CARGO_HOME`/`HOMEBREW_PREFIX` appear in rendered output
- `env_vars render into fish env.fish.tmpl` — same, for the fish template
- `env_vars declared in .chezmoi.toml.tmpl` — no chezmoi dependency, always
  runs; static grep for the three critical vars in the `env_vars`/
  `homebrew_env_vars` blocks
- `bash and fish templates loop over env_vars` — no chezmoi dependency,
  always runs; static grep for `range .env_vars` in both templates
- `dot_bashrc.tmpl and dot_zshrc.tmpl source the shared env file` — no
  chezmoi dependency, always runs; carried over from `quick-test.sh`'s
  existing check (missed in an earlier draft of this spec, added back during
  plan self-review — see the implementation plan's Task 2)

Splitting the chezmoi-dependent rendered check from the always-on static
check (rather than one test with runtime branching, as `quick-test.sh` does
today) gives each a clear, single-condition skip/pass rather than nested
conditional logic inside one test body.

### `tests/bats/repo-hygiene.bats`

No interpreter dependency beyond bash/git/find, always runs:

- One `@test` per critical file (6 tests, matching the existing static list)
- `JSON configs are valid` — skip if `jq` unavailable
- `no hardcoded home directory paths`
- `no untracked files in fish conf.d`

## Wiring changes

- **`tests/quick-test.sh`**: deleted.
- **`run-local-tests.sh`**: `--quick` now runs
  `bats tests/bats/syntax.bats tests/bats/templates.bats tests/bats/repo-hygiene.bats`
  instead of exec'ing the deleted script. Help text's "Available (bats):" list
  and the `--quick` description update to mention these three files.
- **`run-local-tests.sh` (no flags)**: no change needed — `run_all_bats_tests`
  already globs every `*.bats` file, so the three new files are picked up
  automatically alongside the existing five.
- **`tests/README.md`**: "Quick Tests" section's `./quick-test.sh` example
  replaced with the bats invocation; "Structure" tree entry for
  `quick-test.sh` removed and the three new files added under `bats/`.
- **CI (`docker/ubuntu/run-bats-tests.sh`)**: *not* changed. That script only
  runs bats files that depend on a real bootstrap having happened
  (`install.bats`, `shell-env.bats`, `fish.bats`). The three new files are
  pre-bootstrap/local-dev checks; their coverage (template rendering,
  PowerShell syntax) already runs in CI via the separate "Validate templates"
  step (`test-ubuntu` job) and the Windows PowerShell-syntax job
  (`test-windows` job). Adding them to the Docker run would duplicate that
  coverage without new signal.

## Non-goals

- Not changing `tests/bats/install.bats`, `shell-env.bats`, `fish.bats`,
  `developer-layout.bats`, or `tmux-scripts.bats`.
- Not adding the new files to the Docker CI bats run (see above).
- Not changing bats-core's installation requirement — it's already required
  for the existing five bats files, so this migration doesn't add a new
  dependency, it removes the last thing that *didn't* need one.
