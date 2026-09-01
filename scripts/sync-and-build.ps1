<#
.SYNOPSIS
    Sync the fork with upstream and build the vllm-router image locally via docker buildx.

.DESCRIPTION
    1. git fetch upstream main
    2. merge upstream/main into the current branch
    3. docker buildx build -f Dockerfile.router --platform <platforms> ... [--push]

    Requirements: git, docker with buildx (Docker Desktop includes it).
    Multi-arch (arm64) builds on an x86 host need QEMU emulation:
      docker run --privileged --rm tonistiigi/binfmt --install all
    Without QEMU, use -Platforms "linux/amd64" (native) or run this script on an arm64 host.

.EXAMPLE
    # quick local build (amd64 only, no push)
    ./scripts/sync-and-build.ps1 -Tag local -Platforms linux/amd64

    # multi-arch build & push to GHCR
    ./scripts/sync-and-build.ps1 -Tag latest -Push

    # build only, skip the git sync
    ./scripts/sync-and-build.ps1 -Tag test -SkipSync
#>
param(
    [string]$Tag = "latest",
    [string]$Image = "ghcr.io/potterluo/router",
    [string]$Platforms = "linux/amd64,linux/arm64",
    [switch]$Push,
    [switch]$SkipSync
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not $SkipSync) {
    git -C $root fetch upstream main
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch upstream failed. Add the upstream first: git remote add upstream https://github.com/vllm-project/router.git"
    }
    git -C $root merge --no-edit upstream/main
    if ($LASTEXITCODE -ne 0) {
        throw "Merge conflict with upstream/main - resolve it manually, then rerun."
    }
    Write-Host "[sync] merged upstream/main into $root" -ForegroundColor Green
}

docker buildx version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "docker buildx is not available. Update Docker Desktop / install buildx first."
}

$buildArgs = @(
    'buildx', 'build',
    '--platform', $Platforms,
    '-f', 'Dockerfile.router',
    '-t', "${Image}:${Tag}"
)
if ($Push) { $buildArgs += '--push' } else { $buildArgs += '--load' }
$buildArgs += $root

docker @buildArgs
if ($LASTEXITCODE -ne 0) { throw "docker buildx failed" }
Write-Host "[build] done: ${Image}:${Tag} ($Platforms)" -ForegroundColor Green