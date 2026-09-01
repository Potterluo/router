<#
.SYNOPSIS
    Merge upstream (vllm-project/router) changes into the current branch and push to the fork.

.DESCRIPTION
    Convenience local alternative to the sync-upstream GitHub Action:
      1. git fetch upstream main
      2. git merge --no-edit upstream/main
      3. (with -Push) git push origin <current branch>

.EXAMPLE
    ./scripts/sync-upstream-local.ps1 -Push
#>
param(
    [switch]$Push
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

git -C $root fetch upstream main
if ($LASTEXITCODE -ne 0) {
    throw "git fetch upstream failed. Add the upstream first: git remote add upstream https://github.com/vllm-project/router.git"
}
$branch = git -C $root rev-parse --abbrev-ref HEAD
git -C $root merge --no-edit upstream/main
if ($LASTEXITCODE -ne 0) {
    throw "Merge conflict with upstream/main - resolve it manually."
}
Write-Host "[sync] merged upstream/main into $branch" -ForegroundColor Green

if ($Push) {
    git -C $root push origin $branch
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    Write-Host "[sync] pushed $branch to origin" -ForegroundColor Green
}