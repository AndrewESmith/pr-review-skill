# Pull Request Review (C#/.NET)

Cursor Agent Skill for constraint-driven reviews of team PRs: Bitbucket metadata and diff via `bb`, Jira context via Atlassian MCP, C#/.NET checklist, and a single markdown deliverable under a **configurable output root**.

## What it does

When invoked with a **PR URL**, the agent:

1. Runs **`setup-pr-review.ps1`** for the target repo (Jira/Atlassian MCP in `.cursor/mcp.json`, optional `bb` verification marker, ensures output folder exists).
2. Reads **`pr-review.config.json`** (and optional local override) for **`prOutputLocation`**.
3. Gathers **PR metadata**, **unified diff**, and **existing comments** from Bitbucket when the URL is Bitbucket Cloud.
4. Optionally **syncs a local checkout** under `D:\projects\<repo-slug>` (or a worktree) for whole-file / solution context.
5. Fetches the **linked Jira issue** and checks alignment with acceptance criteria.
6. Reviews the diff against the skill checklist and writes **one** review file under `<prOutputLocation>`, then opens it in Cursor.

The skill does **not** commit, merge, push, or apply patches. Summary bullets and **Verdict** use caveman voice; **Findings** stay normal technical English.

## Configuration

Skills are configurable via JSON files in **this skill directory** (next to `SKILL.md`). The agent reads them at runtime; there is no separate Cursor settings panel for these values.

| File | Committed | Purpose |
|------|-----------|---------|
| **`pr-review.config.json`** | Yes (default) | Shared settings for the team |
| **`pr-review.config.local.json`** | No (gitignored) | Per-machine overrides |

**`prOutputLocation`** — absolute path where review markdown files are written. Local file overrides the base file when both set the same key.

Default in repo:

```json
{
  "prOutputLocation": "D:\\analysis\\pr_reviews"
}
```

Example machine override (`pr-review.config.local.json`):

```json
{
  "prOutputLocation": "E:\\reviews\\pr"
}
```

`setup-pr-review.ps1` reads the same config and creates **`prOutputLocation`** if it does not exist.

## Prerequisites

| Requirement | Purpose |
|-------------|---------|
| **Cursor** with Agent + this skill installed | Runs `SKILL.md` workflow |
| **PR URL** (required input) | Skill asks and stops if missing |
| **[Bitbucket CLI](https://github.com/dlbroadfoot/bitbucket-cli/tree/main/bb)** (`bb`) | Bitbucket PR view/diff/comments (`bb auth login` when needed) |
| **Git** clones under `D:\projects\<repo-slug>` | Recommended local sync path in the skill |
| **PowerShell** | `setup-pr-review.ps1` |
| **`cursor` on PATH** | Open the output `.md` after write |

Jira: global Atlassian MCP in Cursor settings, **or** repo `.cursor/mcp.json` copied by setup from this folder’s `mcp.json`.

## One-time / per-repo setup

From PowerShell, point **`-RepoPath`** at the **git root** you review (or the **worktree** folder if you use one):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\analysis\pr-review-skill\setup-pr-review.ps1" -RepoPath "D:\projects\your-repo"
```

The script:

- Copies **`mcp.json`** into `<repo>\.cursor\mcp.json` when missing or different.
- Adds `.cursor/mcp.json` to the repo **`.gitignore`** when first created locally.
- Verifies **`bb`** once and writes **`.bb-cli-verified`** when successful.
- Ensures **`prOutputLocation`** from config exists on disk.

Install the skill where Cursor loads skills (e.g. copy this folder or link to `SKILL.md` per your skills layout). Edit **`pr-review.config.json`** (or add a local override) before your first review if the default output path is wrong for your machine.

## Run a review

Start a **new Agent chat**. Provide the PR URL and ask for a review using this skill:

```
Review this PR using the pr-review skill: https://bitbucket.org/workspace/repo/pull-requests/123
```

The agent follows **`SKILL.md`** (setup → config → `bb` inputs → optional local checkout → Jira → write deliverable).

For **non-Bitbucket** URLs, Bitbucket/`bb` steps are skipped when the URL is not `https://bitbucket.org/…`.

## Review output

**Path pattern** (`<pr-output-location>` = `prOutputLocation` from config):

`<pr-output-location>\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.md`

Example with default config: `D:\analysis\pr_reviews\feature-NV-6901-title\NV-6901_add-feature_20260523_1430.md`

- Branch folder: `/` → `-` in the branch segment.
- No Jira key: `NOJIRA_<slug>_<timestamp>.md`.
- **Re-review:** appends `## Re-review <date>` unless you ask to overwrite.
- Reads existing `*.md` in that branch folder to avoid re-raising settled points.

**Sections:** PR Summary, Risks & Impact, Jira alignment, Existing discussion (if comments exist), Findings (F1…), Test coverage, Framework notes (optional, ≤5 bullets), **Verdict** (Approve | Request changes | Blocked).

## Files in this repo

| File | Purpose |
|------|--------|
| **`SKILL.md`** | Agent skill: workflow, config, `bb`/Jira, checklist, template |
| **`pr-review.config.json`** | Default `prOutputLocation` and other shared settings |
| **`pr-review.config.local.json`** | Optional gitignored per-machine overrides |
| **`setup-pr-review.ps1`** | Sync MCP, verify `bb`, ensure output folder exists |
| **`mcp.json`** | Default Atlassian MCP config copied into repos |
| **`Setup and Docs/PR Review prompt.md`** | Older standalone prompt (superseded by `SKILL.md`) |
| **`readme.md`** | This file |

## Notes

- **Bitbucket only for CLI:** `bb` is not a GitHub `gh` replacement.
- **Local clones:** Skill assumes repos live at `D:\projects\<slug>`; adjust in skill or your layout as needed.
- **`.bb-cli-verified`:** Machine-local marker; delete and re-run setup if `bb` breaks.
