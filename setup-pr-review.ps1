# Ensures Cursor MCP config is synced into the target repo's .cursor/mcp.json.
# Usage: .\setup-pr-review.ps1 [-RepoPath D:\projects\foo]
# Or from repo root: .\path\to\setup-pr-review.ps1

param(
    [string] $RepoPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

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
    $gitignore = Join-Path $RepoPath '.gitignore'

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
    }

    if ($copy -and -not $targetExisted) {
        $ignoreEntry = '.cursor/mcp.json'
        $ignoreContent = Get-Content -LiteralPath $gitignore -Raw -ErrorAction SilentlyContinue
        $entryMissing = -not $ignoreContent -or ($ignoreContent -notmatch [regex]::Escape($ignoreEntry))
        if ($entryMissing) {
            $comment = "`n# Cursor MCP (local duplicate of global; not committed)`n$ignoreEntry`n"
            Add-Content -LiteralPath $gitignore -Value $comment
            Write-Host "Added $ignoreEntry to .gitignore"
        }
    }
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

Write-Host "Syncing Cursor MCP config for repo: $RepoPath"
Sync-CursorMcpConfig -RepoPath $RepoPath -PrReviewsPath $PSScriptRoot
Set-BitbucketCliVerifiedMarker
