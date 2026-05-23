# Pull Request Review (C#/.NET)

Cursor Agent Skill for constraint-driven reviews of team PRs on **Bitbucket Cloud** or **GitHub** (including Enterprise): metadata, diff, and comments via `bb` or `gh`; Jira via Atlassian MCP; C#/.NET checklist; one markdown deliverable under a configurable output root.

## Before you start (recommended)

1. **Clone or locate** the repository on disk.
2. **Open that folder in Cursor** (*File → Open Folder*) so it is the workspace root—or open a PR worktree folder.
3. Run setup from that context (see [Setup](#setup)).
4. Start a **new Agent chat** with the **PR URL**.

Opening the repo first avoids path guessing when clones live in different directories. The skill uses the workspace first, then config maps, then search roots, then asks you.

## What it does

When invoked with a **PR URL**, the agent:

1. Runs **`setup-pr-review.ps1`** with `-RepoPath` pointing at the opened repo (MCP, CLI markers, output folder).
2. **Detects host** — Bitbucket or GitHub (incl. Enterprise via `githubHost`).
3. Reads **`pr-review.config.json`**.
4. Gathers **metadata**, **diff**, and **comments** via `bb` or `gh`.
5. **Resolves clone path** (workspace → `repoPaths` → `reposRoots` search → ask) if local sync is needed.
6. Fetches **Jira**, runs the checklist, writes one review under `prOutputLocation`, opens it in Cursor.

Summary/Verdict use caveman voice; Findings stay normal technical English.

## Supported PR URLs

| Host | Example | CLI |
|------|---------|-----|
| Bitbucket Cloud | `https://bitbucket.org/workspace/repo/pull-requests/123` | [`bb`](https://github.com/dlbroadfoot/bitbucket-cli/tree/main/bb) |
| GitHub.com | `https://github.com/owner/repo/pull/123` | [`gh`](https://cli.github.com/) |
| GitHub Enterprise | `https://<your-host>/owner/repo/pull/123` | `gh` + `githubHost` |

## Configuration

JSON in **this skill directory** (agent reads at runtime):

| File | Committed | Purpose |
|------|-----------|---------|
| **`pr-review.config.json`** | Yes | Team defaults |
| **`pr-review.config.local.json`** | No (gitignored) | Per-machine overrides |

| Key | Purpose |
|-----|---------|
| **`prOutputLocation`** | Where review `.md` files are written |
| **`repoPaths`** | Map `workspace/repo` or `owner/repo` → absolute clone path (scattered clones) |
| **`reposRoots`** | Array of parent dirs to search for `<repo-slug>` folders (default `["D:\\projects"]`) |
| **`githubHost`** | `github.com` or GHE hostname |

Legacy single **`reposRoot`** in JSON is still read as one `reposRoots` entry.

```json
{
  "prOutputLocation": "D:\\analysis\\pr_reviews",
  "reposRoots": ["D:\\projects", "E:\\client-git"],
  "repoPaths": {
    "acme/legacy-api": "E:\\client-work\\legacy-api"
  },
  "githubHost": "github.com"
}
```

### Finding clones when paths differ

| Priority | Source |
|----------|--------|
| 1 | **Cursor workspace** (if `origin` matches the PR repo) |
| 2 | **`repoPaths["workspace/repo"]`** or **`repoPaths["owner/repo"]`** |
| 3 | **Search** each path in **`reposRoots`** for a matching `<repo-slug>` folder |
| 4 | **Ask** you for the absolute path, or skip local sync |

You can also paste `Clone path: D:\...\repo` in the chat for one-off reviews.

## Prerequisites

| Requirement | When |
|-------------|------|
| **Cursor** + this skill | Always |
| **Repo opened in Cursor** | Strongly recommended |
| **PR URL** | Always |
| **`bb`** + auth | Bitbucket PRs |
| **`gh`** + auth | GitHub PRs |
| **PowerShell** | Setup script |
| **`cursor` on PATH** | Open output `.md` |

## Setup

With the **target repo folder open in Cursor**, run (adjust paths):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\analysis\pr-review-skill\setup-pr-review.ps1" -RepoPath "D:\path\to\that-repo"
```

`-RepoPath` should be the workspace root you opened—not the skill folder.

The script syncs **`mcp.json`**, verifies **`bb`** / **`gh`** when on PATH, and ensures **`prOutputLocation`** exists.

## Run a review

New Agent chat in the **opened repo workspace**. Example:

```
Review this PR using the pr-review skill: https://github.com/owner/repo/pull/42
```

Flow: open repo → setup → PR URL → detect host → `bb`/`gh` → resolve clone (usually workspace) → Jira → deliverable.

## Review output

`<prOutputLocation>\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.md`

- No Jira key: `NOJIRA_<slug>_<timestamp>.md`
- Re-review: appends `## Re-review <date>` unless you request overwrite

## Files in this repo

| File | Purpose |
|------|--------|
| **`SKILL.md`** | Full agent workflow |
| **`pr-review.config.json`** | Output path, clone maps, GitHub host |
| **`setup-pr-review.ps1`** | MCP sync, CLI markers |
| **`mcp.json`** | Atlassian MCP template |
| **`readme.md`** | This file |

## Notes

- **`.bb-cli-verified` / `.gh-cli-verified`:** Delete and re-run setup if a CLI breaks.
- **No local tree:** If clone path cannot be resolved, review can still proceed from diff/API only (called out in the write-up).
- **GHE:** Set `githubHost`; agent uses `GH_HOST` / `gh --hostname`.
