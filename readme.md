# Pull Request Review (C#/.NET)

Cursor Agent Skill for constraint-driven reviews of team PRs on **Bitbucket Cloud** or **GitHub** (including Enterprise): metadata, diff, and comments via `bb` or `gh`; Jira via Atlassian MCP; C#/.NET checklist; one self-contained HTML deliverable under a configurable output root.

## Making the skill available to your agent

Cursor loads skills from folders that contain a **`SKILL.md`** file. Install **this entire repository** (not `SKILL.md` alone)—the agent also needs `setup-pr-review.ps1`, `Write-PrReviewHtml.ps1`, `assets/`, `pr-review.config.json`, and `mcp.json`.

### Choose where to install

| Location | Path (Windows) | Who gets it |
|----------|----------------|-------------|
| **Personal** (typical) | `%USERPROFILE%\.cursor\skills\pr-review\` | You, in all projects |
| **Project** | `<repo>\.cursor\skills\pr-review\` | Anyone who clones that repo |

Do **not** copy into `%USERPROFILE%\.cursor\skills-cursor\`—that directory is for Cursor’s built-in skills only.

### Install with `Install-PrReviewSkill.ps1` (recommended)

Run from a clone of this repo (adjust paths). Default target: `%USERPROFILE%\.cursor\skills\pr-review`.

| Mode | Who | What it does | Update after `git pull` in your dev clone |
|------|-----|--------------|---------------------------------------------|
| **`Link`** | Skill maintainers (Windows dev) | Directory junction / symlink: skills folder → your clone | Automatic (same files) |
| **`Clone`** | Teammates | `git clone` into the skills folder | `.\Install-PrReviewSkill.ps1 -Mode Clone` (runs `git pull`) |
| **`Copy`** | Teammates without git in skills dir | Copies tree; never overwrites `pr-review.config.local.json` | `.\Install-PrReviewSkill.ps1 -Mode Copy -Force` from your updated clone |

**Maintainer (junction to dev clone):**

```powershell
Open repository location in powershell terminal eg: cd D:\analysis\pr-review-skill
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PrReviewSkill.ps1 -Mode Link
```

**Teammate (clone into skills — easiest):**

```powershell
git clone https://github.com/AndrewESmith/pr-review-skill.git $env:USERPROFILE\tools\pr-review-skill
cd $env:USERPROFILE\tools\pr-review-skill
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PrReviewSkill.ps1 -Mode Clone
```

**Teammate (copy snapshot from a clone):**

```powershell
cd $env:USERPROFILE\tools\pr-review-skill   # any clone of this repo
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PrReviewSkill.ps1 -Mode Copy
# later, refresh:
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PrReviewSkill.ps1 -Mode Copy -Force
```

Parameters:

| Parameter | Default | Purpose |
|-----------|---------|---------|
| **`-Mode`** | `Copy` | `Link`, `Clone`, or `Copy` |
| **`-Source`** | Script directory | Source tree for `Link` / `Copy` |
| **`-Target`** | `%USERPROFILE%\.cursor\skills\pr-review` | Cursor skills install path |
| **`-RepositoryUrl`** | This GitHub repo | Used by `-Mode Clone` |
| **`-Force`** | off | Replace junction/copy; `Clone` + existing `.git` runs `git pull` instead of deleting |

On first install, if `pr-review.config.local.json` is missing, the script creates it from **`pr-review.config.local.json.example`**. Edit that file for your machine paths.

**After any install:** start a **new Agent chat** (or restart Cursor) so the skill is discovered.

**Junction safety:** If you replace a `Link` install, the script uses `rmdir` on the junction path only — it does not delete your dev clone.

### Manual install (without the script)

Same layout under `%USERPROFILE%\.cursor\skills\pr-review\`:

```
%USERPROFILE%\.cursor\skills\pr-review\
├── SKILL.md
├── Install-PrReviewSkill.ps1
├── setup-pr-review.ps1
├── Write-PrReviewHtml.ps1
├── assets/
├── pr-review.config.json
├── pr-review.config.local.json   ← per machine (gitignored)
├── mcp.json
└── readme.md
```

Copy, clone, or junction that folder as described above.

### Install steps (project)

Same file layout under **`.cursor/skills/pr-review/`** in the repository you share with the team. Commit `SKILL.md`, scripts, and default config; keep machine paths in **`pr-review.config.local.json`** (gitignored) on each developer machine.

### Confirm the agent can see it

- In **Agent** chat, type **`@`** and look for **pr-review** or **Pull Request Review** in the skill list, or
- Ask explicitly: *“Review this PR using the pr-review skill: &lt;PR URL&gt;”*

The skill’s YAML **`description`** tells Cursor when to apply it automatically (e.g. when you ask for a PR review and provide a URL). Naming the skill in the prompt avoids ambiguity if several skills match.

### Paths in prompts and setup

`SKILL.md` refers to **“this skill’s directory”**—the folder that contains `SKILL.md`. After install, that is your `pr-review` skills path, for example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\skills\pr-review\setup-pr-review.ps1" -RepoPath "D:\projects\your-repo"
```

If you keep the repo elsewhere, always pass the **full path to `setup-pr-review.ps1`** inside your installed `pr-review` folder.

## Before you start (recommended)

1. **Clone or locate** the repository on disk.
2. **Open that folder in Cursor** (*File → Open Folder*) so it is the workspace root—or open a PR worktree folder.
3. Run setup from that context (see [Setup](#setup)).
4. If setup creates `.cursor/mcp.json`, restart Cursor or your agent editor, then rerun `/pr-review`.
5. Start a **new Agent chat** with the **PR URL**.

Opening the repo first avoids path guessing when clones live in different directories. The skill uses the workspace first, then config maps, then search roots, then asks you.

## What it does

When invoked with a **PR URL**, the agent:

1. Runs **`setup-pr-review.ps1`** with `-RepoPath` pointing at the opened repo (MCP, local Git exclude entry, CLI markers, output folder).
2. **Detects host** — Bitbucket or GitHub (incl. Enterprise via `githubHost`).
3. Reads **`pr-review.config.json`**.
4. Gathers **metadata**, **diff**, and **comments** via `bb` or `gh`.
5. **Resolves clone path** (workspace → `repoPaths` → `reposRoots` search → ask) if local sync is needed.
6. Fetches **Jira**, runs the checklist, generates one HTML review via **`Write-PrReviewHtml.ps1`**, opens it in your default browser.

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
| **`prOutputLocation`** | Where review `.html` files are written |
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
| **Node.js** | Renders markdown to HTML in `Write-PrReviewHtml.ps1` |
| **PowerShell** | Setup and HTML generator scripts |
| **Default browser** | Opens the review HTML (automatic via script) |

## Setup

With the **target repo folder open in Cursor**, run (adjust paths):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\skills\pr-review\setup-pr-review.ps1" -RepoPath "D:\path\to\that-repo"
```

(Use your actual install path if the skill folder is not under `.cursor\skills\pr-review`.)

`-RepoPath` should be the workspace root you opened—not the skill folder.

The script syncs **`mcp.json`**, verifies **`bb`** / **`gh`** when on PATH, and ensures **`prOutputLocation`** exists. When `<repo>\.cursor\mcp.json` exists, it adds `.cursor/mcp.json` to that repo’s **`.git/info/exclude`** instead of editing `.gitignore`, so the local MCP file stays uncommitted without dirtying the shared repo files.

If setup creates `.cursor/mcp.json`, restart Cursor or your agent editor, then rerun `/pr-review`. Cursor loads MCP configuration at startup, so the first run stops there on purpose.

After MCP is loaded, the agent probes Jira access via **`getAccessibleAtlassianResources`**. If OAuth is not granted, it asks you to authorize under **Settings → MCP → Atlassian-MCP-Server**; you can reply **done** and the **same** chat continues — no second skill invocation unless MCP config was newly created.

## Run a review

New Agent chat in the **opened repo workspace**. Example:

```
Review this PR using the pr-review skill: https://github.com/owner/repo/pull/42
```

Flow: open repo → setup → restart/rerun if MCP was newly created → PR URL → detect host → `bb`/`gh` → resolve clone (usually workspace) → Jira → deliverable.

## Local sync and worktrees

The setup-created `.cursor/mcp.json` is ignored via `.git/info/exclude`, so it should not force a worktree. If the target repo is still dirty because of real local work, the skill uses a timestamped worktree created from the PR base branch, never `--no-checkout`.

If provider checkout fails, for example Bitbucket CLI cannot recognize a non-standard Bitbucket remote URL, the skill keeps the populated worktree and fetches the PR source branch directly with `git fetch origin <source>:refs/heads/<review-branch>`.

## Review output

`<prOutputLocation>\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.html`

- No Jira key: `NOJIRA_<slug>_<timestamp>.html`
- Re-review: append `## Re-review <date>` to markdown content before calling `Write-PrReviewHtml.ps1` unless you request overwrite
- Prior reviews: agent reads existing `*.html` in the folder and extracts embedded markdown from `#review-source` to avoid re-raising settled findings

### Commenting on reviews

The HTML page is self-contained (no CDN). In the browser:

1. **Select text** in the review body → click **Add comment**
2. Edit your note in the **Comments** sidebar
3. **Copy all** (or copy individual comments) — formatted for pasting into Bitbucket/GitHub review threads
4. **Save** — embeds comments in the HTML file (use the save dialog or download and replace the original)

Comments travel with the file when shared.

## Files in this repo

| File | Purpose |
|------|--------|
| **`SKILL.md`** | Full agent workflow |
| **`Write-PrReviewHtml.ps1`** | Generates self-contained HTML from review markdown |
| **`assets/`** | Vendored marked.js, page CSS/JS (inlined into output) |
| **`pr-review.config.json`** | Output path, clone maps, GitHub host |
| **`Install-PrReviewSkill.ps1`** | Install skill into `%USERPROFILE%\.cursor\skills\pr-review` (Link / Clone / Copy) |
| **`setup-pr-review.ps1`** | MCP sync, local Git exclude entry, CLI markers (run per repo under review) |
| **`pr-review.config.local.json.example`** | Template for per-machine config |
| **`mcp.json`** | Atlassian MCP template |
| **`readme.md`** | This file |

## Notes

- **`.bb-cli-verified` / `.gh-cli-verified`:** Delete and re-run setup if a CLI breaks.
- **`.cursor/mcp.json`:** Written into the reviewed repo and ignored through `.git/info/exclude`, not `.gitignore`.
- **No local tree:** If clone path cannot be resolved, review can still proceed from diff/API only (called out in the write-up).
- **GHE:** Set `githubHost`; agent uses `GH_HOST` / `gh --hostname`.
