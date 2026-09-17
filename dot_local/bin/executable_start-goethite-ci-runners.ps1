# Starts both goethite self-hosted CI runners (Windows + WSL Linux) in
# separate console windows. Run this once per session before pushing /
# opening a PR against jesserobertson/goethite so ci.yml's `local-windows` /
# `local-linux` jobs have somewhere to run -- avoids paying for GitHub-hosted
# VM minutes on that private, single-owner repo. Close a window (or Ctrl+C
# inside it) to stop that runner.
#
# Both start-runner scripts are idempotent: safe to re-run any time (after
# a crash, a kill, or just to be sure) -- each always kills its own
# leftover local listener process and re-registers with --replace, so a
# stale "A session for this runner already exists" server-side session can
# never block startup.

Start-Process -FilePath "pwsh.exe" `
    -ArgumentList '-NoExit', '-File', 'C:\Users\robejess\.local\share\goethite-ci-runners\windows\start-runner.ps1' `
    -WindowStyle Normal

Start-Process -FilePath "wsl.exe" `
    -ArgumentList "-d", "Ubuntu-24.04", "--", "bash", "/home/jess/.local/share/goethite-ci-runners/linux/start-runner.sh" `
    -WindowStyle Normal

Write-Host "Both runner windows launched. Leave them open while CI needs to run."
