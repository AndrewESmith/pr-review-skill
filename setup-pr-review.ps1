# Syncs Cursor MCP config into the target repo and excludes it via .git/info/exclude.
# Usage: .\setup-pr-review.ps1 [-RepoPath D:\projects\foo]
# Or from repo root: .\path\to\setup-pr-review.ps1

param(
    [string] $RepoPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$DefaultPrOutputLocation = 'D:\analysis\pr_reviews'

function Get-PrReviewConfig {
    param([string] $SkillRoot = $PSScriptRoot)

    $config = @{
        prOutputLocation = $DefaultPrOutputLocation
        reposRoots       = @('D:\projects')
        repoPaths        = @{}
        githubHost       = 'github.com'
    }
    $basePath = Join-Path $SkillRoot 'pr-review.config.json'
    $localPath = Join-Path $SkillRoot 'pr-review.config.local.json'

    foreach ($path in @($basePath, $localPath)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($parsed.prOutputLocation) { $config.prOutputLocation = [string]$parsed.prOutputLocation }
        if ($parsed.githubHost) { $config.githubHost = [string]$parsed.githubHost }
        if ($parsed.reposRoots) {
            $config.reposRoots = @($parsed.reposRoots | ForEach-Object { [string]$_ })
        } elseif ($parsed.reposRoot) {
            $config.reposRoots = @([string]$parsed.reposRoot)
        }
        if ($parsed.repoPaths) {
            foreach ($prop in $parsed.repoPaths.PSObject.Properties) {
                $config.repoPaths[$prop.Name] = [string]$prop.Value
            }
        }
    }

    foreach ($root in $config.reposRoots) {
        if ($root -and -not [System.IO.Path]::IsPathRooted($root)) {
            throw "Each reposRoots entry must be an absolute path: $root"
        }
    }
    foreach ($entry in $config.repoPaths.GetEnumerator()) {
        if (-not [System.IO.Path]::IsPathRooted($entry.Value)) {
            throw "repoPaths['$($entry.Key)'] must be an absolute path: $($entry.Value)"
        }
    }

    if (-not [System.IO.Path]::IsPathRooted($config.prOutputLocation)) {
        throw "prOutputLocation must be an absolute path: $($config.prOutputLocation)"
    }

    return $config
}

function Ensure-PrReviewOutputRoot {
    param([string] $OutputRoot)

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
        Write-Host "Created PR review output folder: $OutputRoot"
    } else {
        Write-Host "PR review output folder: $OutputRoot"
    }
}

function Add-GitInfoExcludeEntry {
    param(
        [string] $RepoPath,
        [string] $Entry
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Warning "git not on PATH; cannot add $Entry to .git/info/exclude."
        return
    }

    $gitDir = (& git -C $RepoPath rev-parse --absolute-git-dir 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitDir)) {
        Write-Warning "RepoPath is not a git repository; cannot add $Entry to .git/info/exclude: $RepoPath"
        return
    }

    $excludePath = Join-Path $gitDir.Trim() 'info\exclude'
    $excludeDir = Split-Path $excludePath -Parent
    if (-not (Test-Path -LiteralPath $excludeDir)) {
        New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null
    }

    $excludeContent = Get-Content -LiteralPath $excludePath -Raw -ErrorAction SilentlyContinue
    $entryExists = $excludeContent -and (($excludeContent -split "`r?`n") -contains $Entry)
    if ($entryExists) {
        Write-Host "$Entry already present in .git/info/exclude"
        return
    }

    $prefix = if ([string]::IsNullOrWhiteSpace($excludeContent)) { '' } else { "`n" }
    Add-Content -LiteralPath $excludePath -Value "$prefix# Cursor MCP (local duplicate of global; not committed)`n$Entry"
    Write-Host "Added $Entry to .git/info/exclude"
}

$DefaultMcpJson = @'
{
  "mcpServers": {
    "Atlassian-MCP-Server": {
      "url": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
'@

function Sync-CursorMcpConfig {
    param(
        [string] $RepoPath = (Get-Location).Path,
        [string] $PrReviewsPath = $PSScriptRoot
    )
    $source = Join-Path $PrReviewsPath 'mcp.json'
    $cursorDir = Join-Path $RepoPath '.cursor'
    $target = Join-Path $cursorDir 'mcp.json'
    $newlyCreated = $false

    if (Test-Path -LiteralPath $source) {
        $desiredContent = Get-Content -LiteralPath $source -Raw
        Write-Verbose "Using mcp.json from skill directory: $source"
    } else {
        $desiredContent = $DefaultMcpJson
        Write-Host "No mcp.json at $source; using built-in Atlassian MCP config."
    }

    $targetExisted = Test-Path -LiteralPath $target
    $copy = $false
    if (-not $targetExisted) {
        $copy = $true
    } else {
        $tgtContent = Get-Content -LiteralPath $target -Raw
        if ($desiredContent -ne $tgtContent) {
            $copy = $true
        }
    }

    if ($copy) {
        if (-not (Test-Path -LiteralPath $cursorDir)) {
            New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
        }
        Set-Content -LiteralPath $target -Value $desiredContent -Encoding utf8 -NoNewline
        Write-Host "Wrote mcp.json to $target"
        if (-not $targetExisted) {
            $newlyCreated = $true
        }
    }

    if (Test-Path -LiteralPath $target) {
        Add-GitInfoExcludeEntry -RepoPath $RepoPath -Entry '.cursor/mcp.json'
    }

    return $newlyCreated
}

function Set-BitbucketCliVerifiedMarker {
    <#
    Creates .bb-cli-verified next to this script after the first successful bb check.
    Later runs skip calling bb entirely when this file exists (see pr-review SKILL.md).
    #>
    $marker = Join-Path $PSScriptRoot '.bb-cli-verified'
    if (Test-Path -LiteralPath $marker) {
        Write-Host "Bitbucket CLI (bb) is configured and verified: $marker"
        return
    }
    $bb = Get-Command bb -ErrorAction SilentlyContinue
    if (-not $bb) {
        Write-Warning "Bitbucket CLI (bb) not on PATH; skipping .bb-cli-verified marker. Install bb or add it to PATH, then re-run this script."
        return
    }
    & bb version
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "bb version failed; not writing .bb-cli-verified marker."
        return
    }
    Get-Date -Format 'o' | Set-Content -LiteralPath $marker -Encoding utf8
    Write-Host "Recorded Bitbucket CLI (bb) verification: $marker"
}

function Set-GitHubCliVerifiedMarker {
    <#
    Creates .gh-cli-verified next to this script after the first successful gh check.
    Later runs skip calling gh --version when this file exists (see pr-review SKILL.md).
    #>
    $marker = Join-Path $PSScriptRoot '.gh-cli-verified'
    if (Test-Path -LiteralPath $marker) {
        Write-Host "GitHub CLI (gh) is configured and verified: $marker"
        return
    }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Warning "GitHub CLI (gh) not on PATH; skipping .gh-cli-verified marker. Install gh or add it to PATH, then re-run this script."
        return
    }
    & gh --version
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "gh --version failed; not writing .gh-cli-verified marker."
        return
    }
    Get-Date -Format 'o' | Set-Content -LiteralPath $marker -Encoding utf8
    Write-Host "Recorded GitHub CLI (gh) verification: $marker"
}

Write-Host "Syncing Cursor MCP config for repo: $RepoPath"
$mcpCreated = Sync-CursorMcpConfig -RepoPath $RepoPath -PrReviewsPath $PSScriptRoot
Set-BitbucketCliVerifiedMarker
Set-GitHubCliVerifiedMarker

$prConfig = Get-PrReviewConfig -SkillRoot $PSScriptRoot
Ensure-PrReviewOutputRoot -OutputRoot $prConfig.prOutputLocation

if ($mcpCreated) {
    Write-Host ""
    Write-Host "Next: restart Cursor (new .cursor/mcp.json), then re-run the pr-review skill."
} else {
    Write-Host ""
    Write-Host "Next: agent verifies Atlassian MCP auth (getAccessibleAtlassianResources) before fetching Jira."
}
