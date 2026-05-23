# Pull Request Review (C#/.NET)

Cursor Agent Skill for constraint-driven reviews of team PRs: Bitbucket metadata and diff via `bb`, Jira context via Atlassian MCP, C#/.NET checklist, and a single markdown deliverable under `D:\analysis\pr_reviews\`.

## What it does

When invoked with a **PR URL**, the agent:

1. Runs **`setup-pr-review.ps1`** for the target repo (Jira/Atlassian MCP in `.cursor/mcp.json`, optional `bb` verification marker).
2. Gathers **PR metadata**, **unified diff**, and **existing comments** from Bitbucket (`bb pr view`, `bb pr diff`, `bb pr view --comments`) when the URL is Bitbucket Cloud.
3. Optionally **syncs a local checkout** under `D:\projects\<repo-slug>` (or a worktree) for whole-file / solution context.
4. Fetches the **linked Jira issue** (key from branch/title, e.g. `NV-6901`) and checks alignment with acceptance criteria.
5. Reviews the diff against the skill checklist (correctness, security, performance, EF/API, framework notes, tests).
6. Writes **one** review file and opens it in Cursor.

The skill does **not** commit, merge, push, or apply patches. Summary bullets and **Verdict** use caveman voice; **Findings** stay normal technical English.

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

- Copies **`mcp.json`** from this skill directory into `<repo>\.cursor\mcp.json` when missing or different (built-in Atlassian URL if `mcp.json` is absent here).
- Adds `.cursor/mcp.json` to the repo **`.gitignore`** when the file is first created locally.
- On first successful **`bb version`**, writes **`.bb-cli-verified`** next to `SKILL.md` so later reviews skip redundant `bb` install checks.

Install the skill where Cursor loads skills (e.g. copy this folder or link to `SKILL.md` per your skills layout).

## Run a review

Start a **new Agent chat** (keeps context clean). Provide the Bitbucket PR URL and ask for a review using this skill, for example:

```
Review this PR using the pr-review skill: https://bitbucket.org/workspace/repo/pull-requests/123
```

The agent follows **`SKILL.md`** end to end (setup → `bb` inputs → optional local checkout → Jira → write deliverable).

For **non-Bitbucket** URLs, the skill still applies; Bitbucket/`bb` steps are skipped where the URL is not `https://bitbucket.org/…`.

## Review output

**Path pattern:**

`D:\analysis\pr_reviews\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.md`

- Branch: `/` → `-` in the folder name.
- No Jira key: `NOJIRA_<slug>_<timestamp>.md`.
- **Re-review:** appends `## Re-review <date>` unless you ask to overwrite.
- Reads existing `*.md` in that folder to avoid re-raising settled points.

**Sections:** PR Summary, Risks & Impact, Jira alignment, Existing discussion (if comments exist), Findings (F1…), Test coverage, Framework notes (optional, ≤5 bullets), **Verdict** (Approve | Request changes | Blocked).

## Files in this repo

| File | Purpose |
|------|--------|
| **`SKILL.md`** | Agent skill: workflow, `bb`/Jira, checklist, template, deliverable rules |
| **`setup-pr-review.ps1`** | Sync MCP into target repo; verify `bb` once |
| **`mcp.json`** | Default Atlassian MCP config copied into repos |
| **`Setup and Docs/PR Review prompt.md`** | Older standalone prompt (superseded by `SKILL.md` for Agent use) |
| **`readme.md`** | This file |

## Notes

- **Bitbucket only for CLI:** `bb` is not a GitHub `gh` replacement.
- **Local clones:** Skill assumes repos live at `D:\projects\<slug>` matching the Bitbucket repo slug; adjust if your layout differs.
- **`.bb-cli-verified`:** Machine-local marker beside `SKILL.md`; delete it if `bb` breaks and re-run setup after fixing PATH/auth.
