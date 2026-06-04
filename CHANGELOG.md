# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-06-05

### Added

- Atlassian MCP auth probe before Jira fetch: setup only syncs `mcp.json`; the agent verifies OAuth via `getAccessibleAtlassianResources` and prompts for authorization mid-session when needed.

## [0.2.0] - 2026-06-04

### Added

- Self-contained HTML review deliverable via `Write-PrReviewHtml.ps1` with vendored assets (`marked.min.js`, `pr-review-page.css`, `pr-review-page.js`): interactive rendering, inline commenting, copy-to-clipboard, and Save that embeds annotations in the file.
- Server-side markdown pre-render (Node) so review content is always visible in the HTML output.

### Changed

- Replaced markdown deliverable with HTML as the required review output; `SKILL.md` updated to forbid `.md` deliverables.

### Fixed

- Empty HTML output when client-side rendering failed.
- Truncated `pr-review-page.js` caused by unescaped literal `</script>` sequences in inlined script blocks.

## [0.1.1] - 2026-05-29

### Changed

- Improved discovery of Jira issue keys from branch names.

## [0.1.0] - 2026-05-23

### Added

- Initial Cursor Agent Skill for constraint-driven C#/.NET PR reviews on Bitbucket Cloud (`bb` CLI).
- GitHub and GitHub Enterprise support (`gh` CLI, configurable `githubHost`).
- Configurable PR review output root (`prOutputLocation` in `pr-review.config.json`).
- Flexible repository discovery: multiple search roots and per-repo path maps.
- `setup-pr-review.ps1` for MCP wiring, CLI markers, output folder, and local Git exclude for generated `.cursor/mcp.json`.
- Atlassian MCP integration for linked Jira issues.
- Install and configuration documentation in `readme.md`.

### Changed

- Git worktree creation uses `origin/<base>` checkout instead of `--no-checkout`, so a failed `bb pr checkout` leaves a populated tree instead of appearing as mass deletions.
- When setup creates `.cursor/mcp.json`, it is added to the repo’s local Git exclude list.

### Removed

- Prompt history artifacts from the repository.
