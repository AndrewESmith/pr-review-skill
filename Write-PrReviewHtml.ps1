# Generates a self-contained HTML PR review page from markdown content.
# Usage:
#   .\Write-PrReviewHtml.ps1 -OutputPath "D:\reviews\branch\NV-123_slug_20260603_1200.html" -MarkdownPath ".\review.md"
#   .\Write-PrReviewHtml.ps1 -OutputPath "..." -MarkdownContent "**PR:** ..."

param(
    [Parameter(Mandatory)]
    [string] $OutputPath,

    [string] $MarkdownPath,

    [string] $MarkdownContent,

    [switch] $NoOpen
)

$ErrorActionPreference = 'Stop'

if (-not $MarkdownPath -and -not $MarkdownContent) {
    throw 'Provide -MarkdownPath or -MarkdownContent.'
}

if ($MarkdownPath -and $MarkdownContent) {
    throw 'Provide only one of -MarkdownPath or -MarkdownContent.'
}

if ($MarkdownPath) {
    if (-not (Test-Path -LiteralPath $MarkdownPath)) {
        throw "Markdown file not found: $MarkdownPath"
    }
    $MarkdownContent = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($MarkdownContent)) {
    throw 'Markdown content is empty.'
}

if ($OutputPath -notmatch '\.html$') {
    throw 'OutputPath must end with .html'
}

$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$skillRoot = $PSScriptRoot
$assetsDir = Join-Path $skillRoot 'assets'

foreach ($asset in @('marked.min.js', 'pr-review-page.css', 'pr-review-page.js')) {
    $assetPath = Join-Path $assetsDir $asset
    if (-not (Test-Path -LiteralPath $assetPath)) {
        throw "Missing asset: $assetPath"
    }
}

$markedJs = Get-Content -LiteralPath (Join-Path $assetsDir 'marked.min.js') -Raw -Encoding UTF8
$pageCss = Get-Content -LiteralPath (Join-Path $assetsDir 'pr-review-page.css') -Raw -Encoding UTF8
$pageJs = Get-Content -LiteralPath (Join-Path $assetsDir 'pr-review-page.js') -Raw -Encoding UTF8

# Escape for embedding inside JSON script tag
$markdownJson = ($MarkdownContent | ConvertTo-Json -Compress)
$commentsJson = '[]'

$suggestedFilename = Split-Path $OutputPath -Leaf
$title = [System.IO.Path]::GetFileNameWithoutExtension($suggestedFilename)

if (-not ([System.Management.Automation.PSTypeName]'System.Web.HttpUtility').Type) {
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
}
$encodedTitle = [System.Web.HttpUtility]::HtmlEncode($title)

$metaJson = (@{
    title             = $title
    suggestedFilename = $suggestedFilename
    outputPath        = $OutputPath
    generated         = (Get-Date -Format 'o')
} | ConvertTo-Json -Compress)

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$encodedTitle</title>
  <style>
$pageCss
  </style>
</head>
<body>
  <div class="toolbar">
    <span>Select text to comment &middot; Save embeds comments in this file</span>
    <button type="button" id="btn-copy-all">Copy all comments</button>
    <button type="button" id="btn-clear">Clear comments</button>
    <button type="button" id="btn-save" class="primary">Save</button>
  </div>
  <div class="layout">
    <div class="main">
      <div id="review-content"></div>
    </div>
    <aside class="sidebar">
      <div class="sidebar-header">
        <h2>Comments</h2>
        <div class="sidebar-actions">
          <button type="button" id="btn-copy-all-sidebar" onclick="document.getElementById('btn-copy-all').click()">Copy all</button>
          <button type="button" class="primary" onclick="document.getElementById('btn-save').click()">Save</button>
        </div>
      </div>
      <div id="comment-list" class="comment-list"></div>
    </aside>
  </div>
  <script type="application/json" id="review-meta">$metaJson</script>
  <script type="application/json" id="review-source">$markdownJson</script>
  <script type="application/json" id="review-comments">$commentsJson</script>
  <script>
$markedJs
  </script>
  <script>
$pageJs
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $OutputPath -Value $html -Encoding utf8 -NoNewline
Write-Host "Wrote PR review HTML: $OutputPath"

if (-not $NoOpen) {
    Start-Process -FilePath $OutputPath
    Write-Host "Opened in default browser."
}
