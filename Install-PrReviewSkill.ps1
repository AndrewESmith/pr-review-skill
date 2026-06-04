# Installs the pr-review Cursor skill into %USERPROFILE%\.cursor\skills\pr-review
# Usage (from this repo):
#   .\Install-PrReviewSkill.ps1 -Mode Link
#   .\Install-PrReviewSkill.ps1 -Mode Clone
#   .\Install-PrReviewSkill.ps1 -Mode Copy
#   .\Install-PrReviewSkill.ps1 -Mode Copy -Force   # refresh copy; keeps pr-review.config.local.json

[CmdletBinding()]
param(
    [ValidateSet('Link', 'Clone', 'Copy')]
    [string] $Mode = 'Copy',

    [string] $Source,

    [string] $Target = (Join-Path $env:USERPROFILE '.cursor\skills\pr-review'),

    [string] $RepositoryUrl = 'https://github.com/AndrewESmith/pr-review-skill.git',

    [switch] $Force
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Source)) {
    $Source = $PSScriptRoot
}

function Test-PrReviewSkillRoot {
    param([string] $Path)
    $skillMd = Join-Path $Path 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd)) {
        throw "Not a pr-review skill folder (missing SKILL.md): $Path"
    }
}

function Test-PathIsReparsePoint {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return ([System.IO.FileAttributes]::ReparsePoint -band (Get-Item -LiteralPath $Path -Force).Attributes) -ne 0
}

function Remove-InstallTarget {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }

    if (Test-PathIsReparsePoint -Path $Path) {
        cmd /c rmdir "$Path"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove junction/symlink at $Path (use rmdir, not Remove-Item -Recurse)."
        }
        Write-Host "Removed junction/symlink: $Path"
        return
    }

    Remove-Item -LiteralPath $Path -Recurse -Force
    Write-Host "Removed: $Path"
}

function Backup-LocalConfig {
    param([string] $TargetDir)
    $localPath = Join-Path $TargetDir 'pr-review.config.local.json'
    if (Test-Path -LiteralPath $localPath) {
        return Get-Content -LiteralPath $localPath -Raw
    }
    return $null
}

function Restore-LocalConfig {
    param(
        [string] $TargetDir,
        [string] $Backup
    )
    if (-not $Backup) { return }
    $localPath = Join-Path $TargetDir 'pr-review.config.local.json'
    Set-Content -LiteralPath $localPath -Value $Backup -Encoding utf8 -NoNewline
    Write-Host "Preserved existing pr-review.config.local.json"
}

function Ensure-LocalConfigFromExample {
    param([string] $TargetDir)

    $localPath = Join-Path $TargetDir 'pr-review.config.local.json'
    if (Test-Path -LiteralPath $localPath) { return }

    $examplePath = Join-Path $TargetDir 'pr-review.config.local.json.example'
    if (-not (Test-Path -LiteralPath $examplePath)) {
        $examplePath = Join-Path $PSScriptRoot 'pr-review.config.local.json.example'
    }
    if (-not (Test-Path -LiteralPath $examplePath)) {
        Write-Warning 'No pr-review.config.local.json.example found; create pr-review.config.local.json manually.'
        return
    }

    Copy-Item -LiteralPath $examplePath -Destination $localPath
    Write-Host "Created pr-review.config.local.json from example - edit machine paths before your first review."
}

function Install-PrReviewSkillLink {
    param(
        [string] $Source,
        [string] $Target
    )

    Test-PrReviewSkillRoot -Path $Source
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path

    if (Test-Path -LiteralPath $Target) {
        throw "Target already exists: $Target. Use -Force to replace."
    }

    $parent = Split-Path $Target -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($IsWindows -or $env:OS -like '*Windows*') {
        cmd /c mklink /J "$Target" "$sourceFull"
        if ($LASTEXITCODE -ne 0) {
            throw "mklink /J failed (exit $LASTEXITCODE). Run from an elevated prompt only if mklink reports access denied."
        }
        Write-Host "Created directory junction: $Target -> $sourceFull"
    } else {
        New-Item -ItemType SymbolicLink -Path $Target -Target $sourceFull | Out-Null
        Write-Host "Created symbolic link: $Target -> $sourceFull"
    }

    Ensure-LocalConfigFromExample -TargetDir $Target
}

function Install-PrReviewSkillClone {
    param(
        [string] $Target,
        [string] $RepositoryUrl,
        [bool] $ReplaceExisting
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw 'git is required for -Mode Clone. Install git or use -Mode Copy.'
    }

    if (Test-Path -LiteralPath $Target) {
        if (-not (Test-Path -LiteralPath (Join-Path $Target '.git'))) {
            if (-not $ReplaceExisting) {
                throw "Target exists but is not a git clone: $Target. Use -Force to replace."
            }
            Remove-InstallTarget -Path $Target
        } else {
            Write-Host "Updating existing clone: $Target"
            & git -C $Target pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                throw "git pull failed in $Target"
            }
            Test-PrReviewSkillRoot -Path $Target
            Ensure-LocalConfigFromExample -TargetDir $Target
            return
        }
    }

    $parent = Split-Path $Target -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-Host "Cloning $RepositoryUrl -> $Target"
    & git clone $RepositoryUrl $Target
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed"
    }

    Test-PrReviewSkillRoot -Path $Target
    Ensure-LocalConfigFromExample -TargetDir $Target
}

function Install-PrReviewSkillCopy {
    param(
        [string] $Source,
        [string] $Target,
        [bool] $ReplaceExisting
    )

    Test-PrReviewSkillRoot -Path $Source
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path

    $localBackup = $null
    if (Test-Path -LiteralPath $Target) {
        if (-not $ReplaceExisting) {
            throw "Target already exists: $Target. Use -Force to refresh the copy."
        }
        $localBackup = Backup-LocalConfig -TargetDir $Target
    }

    $parent = Split-Path $Target -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Target)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }

    $robocopy = Get-Command robocopy -ErrorAction SilentlyContinue
    if ($robocopy) {
        $roboArgs = @(
            $sourceFull,
            $Target,
            '/E', '/IS', '/IT',
            '/XD', '.git',
            '/XF', 'pr-review.config.local.json', '.bb-cli-verified', '.gh-cli-verified',
            '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS'
        )
        if ($ReplaceExisting) {
            $roboArgs += '/MIR'
        }
        & robocopy @roboArgs | Out-Null
        $code = $LASTEXITCODE
        if ($code -ge 8) {
            throw "robocopy failed with exit code $code"
        }
    } else {
        Write-Warning 'robocopy not found; using Copy-Item (slower, no mirror purge).'
        Get-ChildItem -LiteralPath $sourceFull -Force | Where-Object {
            $_.Name -ne '.git'
        } | ForEach-Object {
            $dest = Join-Path $Target $_.Name
            if ($_.Name -eq 'pr-review.config.local.json') { return }
            if ($_.PSIsContainer) {
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
            } else {
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
    }

    Restore-LocalConfig -TargetDir $Target -Backup $localBackup
    Ensure-LocalConfigFromExample -TargetDir $Target
    Write-Host "Copied skill to: $Target"
}

Write-Host "Install pr-review skill: Mode=$Mode Target=$Target"

if ($Force -and (Test-Path -LiteralPath $Target)) {
    if ($Mode -eq 'Clone' -and (Test-Path -LiteralPath (Join-Path $Target '.git'))) {
        Write-Host 'Force with Clone: will git pull instead of removing clone.'
    } else {
        Remove-InstallTarget -Path $Target
    }
}

switch ($Mode) {
    'Link' {
        Install-PrReviewSkillLink -Source $Source -Target $Target
    }
    'Clone' {
        Install-PrReviewSkillClone -Target $Target -RepositoryUrl $RepositoryUrl -ReplaceExisting:([bool]$Force)
    }
    'Copy' {
        Install-PrReviewSkillCopy -Source $Source -Target $Target -ReplaceExisting:([bool]$Force)
    }
}

Write-Host ''
Write-Host 'Next:'
Write-Host '  1. Edit pr-review.config.local.json under the install target (paths are per machine).'
Write-Host '  2. Start a new Cursor Agent chat (or restart Cursor) so the skill is discovered.'
Write-Host '  3. Per repo under review, run setup-pr-review.ps1 with -RepoPath (not required for skill file updates).'
