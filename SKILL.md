---
name: pr-review
description: Perform a precise, constraint-driven review of a Bitbucket or GitHub PR diff against C#/.NET standards and the linked Jira issue. When complete output a HTML report for human review. Skill is to be used to review other team members pull requests so only apply this skill if a URL has been provided for the review
---

# Skill: pr-review

## Purpose

You are a senior c# and dot net code reviewer. Findings stay normal technical English and perform a precise, constraint-driven review of a PR diff against C#/.NET standards and the linked Jira issue. You will refer to AGENTS.md and associated documents should they exist and are required for context. When complete output a HTML report for human review. Skill is to be used to review other team members pull requests so only apply this skill if a URL has been provided for the review.

## Preamble (run first)

### Open the repository in your editor first (recommended)

Before invoking this skill, **open the PR repository as the workspace root** in your agent editor (e.g. **Cursor**: *File → Open Folder* on the clone, or open a PR **worktree**). Benefits:

- **`setup-pr-review.ps1 -RepoPath`** targets the real tree (MCP lands in that repo’s `.cursor/`).
- **Local repository sync** uses the workspace first—no path guessing when clones live in different parent folders.
- Solution/project reads and line-level navigation match the PR branch after checkout.

If the workspace is not the PR repo (wrong folder or skill-only workspace), the agent falls back to **`repoPaths`** / **`reposRoots`** in config, then asks you. You may also paste the clone’s absolute path in the review request.

### Prompt for URL if missing

The skill requires a URL. If a URL has not been provided in user message, ask: "Please provide the PR URL to review." Then wait for response before proceeding

### Detect PR host (provider)

From the PR URL hostname (after **Load configuration** for `githubHost`):

| Provider | Host match | CLI |
|----------|------------|-----|
| **bitbucket** | `bitbucket.org` | `bb` |
| **github** | `github.com`, or hostname equals **`githubHost`** (GitHub Enterprise) | `gh` |
| **unsupported** | anything else | — |

If **unsupported**, stop and tell the user this skill supports **Bitbucket Cloud** and **GitHub** (including Enterprise when `githubHost` is set). Do not guess a CLI.

Use **only** the workflow for the detected provider below. The review checklist, Jira fetch, config, and deliverable template are shared.

### Configure Jira MCP
**Run `setup-pr-review.ps1` first** so Cursor MCP servers (e.g. Jira/Atlassian) are available for the repository under review. The script lives in **this skill’s directory** (same folder as `SKILL.md`), next to `setup-pr-review.ps1`. If `mcp.json` is not present beside the script, a built-in Atlassian MCP config is written automatically; an optional `mcp.json` in that folder overrides it. When the target repo has `.cursor/mcp.json`, setup adds that path to the repo-local `.git/info/exclude`; it must not edit `.gitignore`.

1. Set **`-RepoPath`** to the **absolute path to the git repository root** for the PR — ideally the folder you already opened in Cursor (see **Open the repository in your editor first**).
2. Before setup, check whether `<repo-root>\.cursor\mcp.json` already exists.
3. Execute from a terminal (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<pr-review-skill-directory>\setup-pr-review.ps1" -RepoPath "<repo-root>"
```

If you use a `git worktree` for the PR, set `-RepoPath` to the **worktree directory** you opened in Cursor (not the original repo folder), so `.cursor/mcp.json` is present in the workspace you’re reviewing from.

Example (script lives next to this skill’s `SKILL.md`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\skills\pr-review\setup-pr-review.ps1" -RepoPath "D:\projects\your-repo"
```

If `<repo-root>\.cursor\mcp.json` did **not** exist before setup and the script creates it, stop the review and prompt the user: “A new `.cursor/mcp.json` was created for this repository and ignored via `.git/info/exclude`. Please restart Cursor or the agent editor you are using, then rerun `/pr-review`.” Do not fetch PR metadata, diff, comments, or Jira until the user restarts and reruns the skill.

If the script exits successfully and `mcp.json` was already in sync, output may be minimal; still run it so the agent’s environment matches. **Do not skip this step** before fetching PR metadata, diff, comments, or Jira.

On setup, `setup-pr-review.ps1` may create machine-local markers next to `SKILL.md` (listed in `.gitignore`):

- **`.bb-cli-verified`** — after first successful `bb version`
- **`.gh-cli-verified`** — after first successful `gh --version`

You only need the marker for the provider you are reviewing; setup tries both when CLIs are on `PATH`.

### Verify Atlassian MCP authorization

`setup-pr-review.ps1` only writes `.cursor/mcp.json`; it **cannot** confirm OAuth/API-token auth. After setup completes — and **after** any Cursor restart required for a **newly created** `mcp.json` — verify Jira access **before** fetching PR metadata or Jira issues.

1. Call MCP tool **`getAccessibleAtlassianResources`** on server **`Atlassian-MCP-Server`** (no arguments). Optionally confirm identity with **`atlassianUserInfo`**.
2. Treat as **authorized** when the call succeeds and at least one returned site includes **`read:jira-work`** in `scopes` (note the site `url` / `id` as `cloudId` for later Jira calls).
3. Treat as **not authorized** when the call errors, returns empty, the Atlassian server is missing from MCP, or no resource has Jira scopes.

**When not authorized**, stop and prompt the user (do not fetch Jira yet):

> Atlassian MCP is not authorized for Jira. In Cursor: **Settings → MCP → Atlassian-MCP-Server** → **Connect** / **Authorize** and complete the browser OAuth flow for your Jira site (e.g. `smokeball.atlassian.net`). If your org uses API-token auth instead, add the `Authorization` header to the skill’s `mcp.json` and re-run setup. Reply **done** when authorization is complete.

Then **retry** `getAccessibleAtlassianResources`. You may retry up to **two** times after the user confirms.

**Continue vs re-run the skill:**

| Situation | Action |
|-----------|--------|
| **New** `.cursor/mcp.json` was just created | **Stop.** User must **restart Cursor**, then **re-run** the skill (MCP config loads at startup). |
| **OAuth not yet granted** (MCP already loaded) | **Stay in this invocation.** User authorizes in Settings → MCP; you retry the probe when they reply **done**. No restart or skill re-run needed. |
| **Auth probe still fails** after retries | **Continue** the review without Jira: use PR title/description for alignment and set `*fetch failed: Atlassian MCP not authorized*` on the Jira line. |

Do **not** cache auth in a marker file — OAuth tokens can expire; probe at the start of every review.

### Load configuration

Skills have no built-in settings UI; read **`pr-review.config.json`** in **this skill’s directory** (same folder as `SKILL.md`).

1. If **`pr-review.config.local.json`** exists beside it, read that file **after** the base config; any property in the local file **overrides** the base file (use for machine-specific paths without committing them).
2. Use **`prOutputLocation`** as `<pr-output-location>` — an **absolute** directory path where review HTML files are written. Default if missing or unreadable: `D:\analysis\pr_reviews`.
3. Use **`repoPaths`** — optional map of **repository id → absolute clone path** for repos that are not under a common parent (see **Resolve local clone path**). Keys:
   - Bitbucket: `workspace/repo-slug` (from PR URL or `bb pr view`)
   - GitHub: `owner/repo` (from PR URL or `gh pr view`)
4. Use **`reposRoots`** — optional array of **absolute** parent directories to search when no `repoPaths` entry matches. Under each root, look for a subdirectory whose name equals the repo slug (last path segment), e.g. `my-service` for `workspace/my-service`. Default if omitted: `["D:\\projects"]`. Legacy **`reposRoot`** (single string) in JSON is treated as one entry in `reposRoots`.
5. Use **`githubHost`** for GitHub Enterprise (default `github.com`). Treat PR URLs whose hostname equals `githubHost` as **github** provider; set `GH_HOST` or `gh --hostname <githubHost>` when running `gh` against Enterprise.
6. Ensure `<pr-output-location>` exists (`setup-pr-review.ps1` creates it when you run setup).
7. Use these resolved values below; do **not** hardcode paths unless they match config.

Example `pr-review.config.json`:

```json
{
  "prOutputLocation": "D:\\analysis\\pr_reviews",
  "reposRoots": ["D:\\projects"],
  "repoPaths": {
    "acme/legacy-api": "E:\\client-work\\legacy-api",
    "other-org/special-repo": "D:\\git\\special-repo"
  },
  "githubHost": "github.com"
}
```

Example local override (`pr-review.config.local.json`, gitignored):

```json
{
  "prOutputLocation": "E:\\reviews\\pr",
  "repoPaths": {
    "my-workspace/only-on-this-pc": "C:\\src\\only-on-this-pc"
  }
}
```

### CLI install checks (provider-specific)

Skills cannot store state by themselves. Use marker files next to `SKILL.md`:

**Bitbucket (`bb`)** — only when provider is **bitbucket**:

- **If `.bb-cli-verified` exists:** assume `bb` works. **Do not** run `bb --version` as a prerequisite; go straight to `bb pr view` / `bb pr diff` / `bb pr view --comments`.
- **If missing:** run **`setup-pr-review.ps1`** or verify `bb` once (`bb auth login` on auth errors).
- **If `bb` fails at runtime:** remove `.bb-cli-verified` and re-run setup after fixing.

**GitHub (`gh`)** — only when provider is **github**:

- **If `.gh-cli-verified` exists:** assume `gh` works. **Do not** run `gh --version` as a prerequisite; go straight to `gh pr view` / `gh pr diff` / comments fetch.
- **If missing:** run **`setup-pr-review.ps1`** or verify `gh` once (`gh auth login` on auth errors).
- **If `gh` fails at runtime:** remove `.gh-cli-verified` and re-run setup after fixing.
- **GitHub Enterprise:** before `gh` commands, set `$env:GH_HOST = "<githubHost>"` from config (or use `gh --hostname <githubHost>` on each command if your `gh` version requires it).

## Required Inputs

- **PR diff** — unified diff from the provider CLI (`bb pr diff` or `gh pr diff`).
- **PR metadata** — title, description, source/target branches, reviewers where relevant.
- **Existing PR comments** — provider comment commands (see provider section) so findings do not duplicate the thread.
- **Jira key** — extract using this priority order:
  1. PR title: scan for first `[A-Z]+-\d+` match (e.g. `NV-6901`).
  2. Source branch: split on `/`, then scan each segment for `[A-Z]+-\d+` (e.g. `feature/NV-6659-some-title` → `NV-6659`). Do **not** require the key to be the first segment.
  3. If not found in either, use `NOJIRA`.
- **Repo context** (solution, projects) for inspections.

**Workflow order:** (0) Prefer workspace already opened in editor. (1) Run **`setup-pr-review.ps1`** with that repo’s root as `-RepoPath`. (1b) If setup created a new `.cursor/mcp.json`, stop for Cursor restart + skill re-run; otherwise **verify Atlassian MCP authorization** (see above). (2) **Detect PR host**. (3) **Load configuration**. (4) Gather provider inputs (`bb` or `gh`). (5) **Resolve local clone path** if local sync needed. (6) **Local repository sync** (optional).

## Resolve local clone path

Use this **only** when you need the tree on disk (local sync, csproj/solution reads beyond diff). Apply in order; stop at the first match. **Repository id** = Bitbucket `workspace/slug` or GitHub `owner/repo` from the PR URL / `pr view`.

1. **Cursor (or editor) workspace root** — If the workspace folder is a git repo and `git remote get-url origin` refers to the same repository id as the PR, use `git rev-parse --show-toplevel` as `<clone-path>`. This is the normal case when the user followed **Open the repository in your editor first**.
2. **`repoPaths[repository-id]`** — Exact path from config (merged base + local JSON). Verify the folder exists and origin matches; if missing on disk, go to step 4.
3. **`reposRoots` search** — For each root in order, test `<root>\<repo-slug>` where `repo-slug` is the last segment of the repository id (e.g. `my-service`). Use the first path that exists, is a git repo, and whose `origin` matches the PR repo. Do **not** assume all clones share one parent beyond this search list.
4. **User** — Ask: “Where is the local clone for `<repository-id>`? (absolute path)”. If they provide a path, use it. If they decline or unknown, **skip local sync**; state in the review that inspection used PR diff/API only (no local tree verification).
5. **Optional:** User may include `Clone path: D:\...\repo` in the initial message — treat as step 2 override for that review only.

Never invent paths. Never `cd` to a non-existent directory.

## Bitbucket CLI (`bb`)

**Provider: bitbucket only.** Bitbucket CLI: [`bb` in bitbucket-cli](https://github.com/dlbroadfoot/bitbucket-cli/tree/main/bb). Auth: `bb auth login` when `bb pr …` fails.

**Gather inputs (recommended order):**

1. `bb pr view <number|PR_URL> [-R [HOST/]WORKSPACE/REPO]` — title, description, branches, reviewers.
2. `bb pr diff <number|PR_URL> [-R …]` — unified diff for the checklist.
3. `bb pr view <number|PR_URL> --comments` (or `-c`) — overview and inline comments.
4. Optional: `bb pr checkout <number|PR_URL>` — prefer **Local repository sync** for full tree reads.

**Repo selection:** Prefer a **full PR URL** when the workspace is not the PR repo. With only a PR **number**, use **`-R [HOST/]WORKSPACE/REPO`** when the git remote does not match.

**Limitations:** `bb pr review` is for your own approve/request-changes — not others’ reviews. Use `bb pr view --comments` or `bb api` for more detail. For JSON, use **`bb api`** if `bb pr view` lacks `--json`.

## GitHub CLI (`gh`)

**Provider: github only.** [GitHub CLI](https://cli.github.com/). Auth: `gh auth login` (or `gh auth login --hostname <githubHost>` for Enterprise).

**Gather inputs (recommended order):**

1. `gh pr view <number|PR_URL> --json title,body,baseRefName,headRefName,author,reviewRequests,reviews` — metadata (add fields if needed). For Enterprise, set `GH_HOST` or `--hostname` per config.
2. `gh pr diff <number|PR_URL>` — unified diff for the checklist.
3. Comments for **Existing discussion**:
   - `gh pr view <number|PR_URL> --comments` — conversation summary when sufficient.
   - For inline review threads, also use `gh api repos/{owner}/{repo}/pulls/{number}/comments` and/or `gh api graphql` with a PR review-comments query if the summary is incomplete.
4. Optional: `gh pr checkout <number|PR_URL>` — prefer **Local repository sync** for full tree reads.

**Repo selection:** Prefer a **full PR URL** (`https://github.com/owner/repo/pull/123` or `https://<githubHost>/owner/repo/pull/123`). With only a number, run `gh` from a clone whose `origin` matches that repo, or pass `--repo owner/repo`.

**Limitations:** Review submission uses `gh pr review` (your vote only). Listing all review threads may require **`gh api`** beyond `gh pr view --comments`.

## Local repository sync (recommended)

Provider **`pr diff`** is sufficient for **what changed**. Use a **local checkout** when the review needs **whole files**, solution/project layout, builds, or **disk aligned with the PR branch**.

**Prerequisite:** Resolve **`<clone-path>`** via **Resolve local clone path** (workspace first). `Set-Location <clone-path>` before the steps below.

**Steps (PowerShell):**

1. Confirm repo: `git rev-parse --show-toplevel` and that `origin` matches the PR repository id.
2. `git fetch origin` (and other remotes if the head branch is not on `origin`).
3. Dirty tree check. Setup-created `.cursor/mcp.json` should be ignored through `.git/info/exclude`, so it should not dirty the repo and `.gitignore` should not change. If the tree is still dirty, treat it as real user or pre-existing work: never revert it, use a worktree, and do **not** use `--no-checkout`.

```powershell
$status = git status --porcelain
$dirty = -not [string]::IsNullOrWhiteSpace($status)
```

4. If **NOT dirty**, checkout in-place:

```powershell
# Bitbucket
bb pr checkout <number|PR_URL> [-R [HOST/]WORKSPACE/REPO]

# GitHub (set GH_HOST for Enterprise if needed)
gh pr checkout <number|PR_URL>
```

5. If **dirty**, use a **worktree** created from the PR target/base ref so the worktree has a populated checkout even if provider checkout fails:

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$prId = "<number>"
$baseRef = "origin/<target-branch-from-pr-view>" # example: origin/master
$worktreeRoot = Split-Path $repoRoot -Parent
$worktreePath = Join-Path $worktreeRoot "_pr-review-$prId-$(Get-Date -Format yyyyMMddHHmmss)"

git fetch origin
git worktree add $worktreePath $baseRef
Set-Location $worktreePath
# Bitbucket: bb pr checkout …
# GitHub: gh pr checkout …
```

6. **Fallback** if provider checkout fails: fetch and checkout the **head branch** from `pr view` (`headRefName` on GitHub, source branch on Bitbucket). For Bitbucket, if `bb pr checkout` says no git remotes point to a known Bitbucket host, keep the populated worktree and fetch the source branch directly:

```powershell
$sourceBranch = "<source-branch-from-pr-view>"
$reviewBranch = "_pr-review-$prId-$(Get-Date -Format yyyyMMddHHmmss)"
git fetch origin "${sourceBranch}:refs/heads/$reviewBranch"
git checkout $reviewBranch
```

If a worktree was accidentally created with `--no-checkout` and checkout/fetch fails, remove that worktree and recreate it from `$baseRef`; do not inspect or report against an empty worktree that appears as a giant delete set.

**After checkout:** Open the checked-out directory in Cursor (in-place clone or `$worktreePath`).

Keep using provider **`pr diff`** and **comments** for authoritative diff/thread; checkout does not replace them.

**Worktree cleanup:**

```powershell
Set-Location $repoRoot
git worktree remove $worktreePath
```

**Scope:** Read-only inspection. Do not commit, merge, or push unless the user explicitly requests it.

## Constraints & Style

- Be specific to the diff; **no** generic advice.
- Suggest **minimal, actionable** changes; avoid full rewrites.
- Ignore formatting/style handled by tooling.
- **Do not** commit or apply patches as part of the deliverable. Local checkout is for inspection only (see **Local repository sync (recommended)**).

## Review Scope (Checklist)
1. **Summarize PR**: 3–5 bullets covering purpose & main changes. Limit summary+risks to ~300 words.
2. **High-Risk Areas**: security, data migration, performance, API changes.
3. **Dependencies/Flags**: new packages, feature flags; note potential blast radius.
4. Items 2–3 belong under Risks & Impact in the output template.
5. **Defects & Correctness** — route to **## Findings** (F1…Fn)

   **Routing (do not duplicate across sections):**
   - **Findings:** correctness, security, reliability, API breaks, perf regressions, architecture violations **introduced or worsened by this diff**.
   - **Framework notes (item 6):** language/runtime/DI/EF/async conventions **only if** not already a Finding; ≤5 bullets; omit section if empty.
   - **Test coverage (template):** test quality and gaps — do not repeat missing-test warnings as Findings unless concrete (e.g. new public API with zero tests).
   - **Existing PR comments:** before drafting a Finding, check it against the comments/threads gathered in **Required Inputs**. If a reviewer or the author already raised the same issue (whether resolved, acknowledged, or still open), **do not** re-raise it as a new Finding with full detail — mention it once in **Existing discussion** instead. Only promote it to a Finding if you disagree with how it was addressed or have new evidence (e.g. the fix looks incomplete) — in that case say explicitly what the existing comment missed.

   **Prove from diff:** Only report if you can cite `file:line` (or hunk) in the PR diff, or a symbol **added** in the diff that is referenced but not defined (after reading the tree when needed).

   **Severity:**
   - **High:** wrong data, crash/NRE on valid input, auth bypass, compile break, silent prod regression, migration/data loss.
   - **Med:** perf/scaling at realistic load, deadlock risk, missing validation on a public boundary, untested critical path.
   - **Low:** pre-existing smell touched incidentally, optional improvement, docs-only gap.

   **Scan the diff for signals, then run the matching recipe:**

   | If diff touches… | Prioritize |
   |------------------|------------|
   | `*.Shared.cs`, `*.Server.cs`, `Initializer`, `ItemProviderIds` | Compile completeness (constants, `Save*Message` types, provider IDs), Desktop/Server registration parity |
   | `Controller` / `ViewModel` / WPF | `.Result`/`.Wait()`, service locator, `SetValue(ref …)` backing fields, wrong `INotifyPropertyChanged` property name |
   | `DbContext`, migrations, raw SQL | N+1, tracking mode, migration reversibility, index/column names vs entity model |
   | `HttpClient`, REST, message handlers | disposal, timeouts, swallowed exceptions, handler idempotency |
   | `async` / `Task` | cancellation, `async void`, fire-and-forget, `.Result` deadlock |
   | `JsonSerializer` / `JsonConvert` | deserialization risk, silent empty fallback on bad JSON |
   | Public API / SDK surface | null guards, breaking ctor/signature, interface not updated |
   | `#if DESKTOP` / partial classes | both targets compile; shared code has no Desktop-only refs |

   **Correctness & validation:** business logic, edge cases, null/empty input, off-by-one, culture/`StringComparison`, `DateTime` vs `DateTimeOffset`/`DateOnly`, money/floating-point equality, `enum`/`flags` misuse.

   **Collections & LINQ:** deferred re-enumeration, `ToDictionary` key collisions, mutation during enumeration, unnecessary `.ToList()` on hot paths.

   **Security (when diff touches auth/HTTP/SQL/serialization):** `[Authorize]`/policy on new endpoints; mass assignment; EF/SQL injection; secrets in config; unsafe JSON (`TypeNameHandling`, polymorphic deser); PII in logs; SSRF on outbound URLs.

   **Reliability:** `catch (Exception)` swallow or log-and-return-success; `Task.Run` + blocking; NServiceBus/handlers without idempotency; `ContinueWith` misuse; missing `using`/disposal (`HttpClient`, `MailMessage`, connections).

   **Performance:** big-O, allocations, N+1 queries, missing indexes, caching — for hot paths (loops, handlers, serialization), optionally apply **analyzing-dotnet-performance** scan recipes on **touched files only**; fold critical hits into Findings.

   **API contracts:** removed default parameters/overloads; label/string constant changes; major package bumps (especially test-only vs production); breaking public surface.

   **Observability:** structured logging, metrics/traces, actionable errors on new failure paths.

   **Architecture & docs:** layering/boundaries; ADR alignment (state if none applies); PR description/CHANGELOG gaps for user-visible behaviour.

6. **Framework Notes (C#/.NET)** — route to **## Framework notes** in the template

   Before writing: read changed `*.csproj` / `Directory.Build.props` for `TargetFramework`, `LangVersion`, and `<Nullable>`. Open the section with **TFM / LangVersion / nullable** (e.g. `.NET 8, C# 12, nullable enabled`). **≤5 bullets.** Do not restate issues already covered by the signal table unless framing a repo-wide pattern.” (“repo uses service locator here — consistent, not blocking”) over new defects.

   **Async / threading:** `async void` (except UI event handlers — note when OK); missing `CancellationToken` on new public async APIs; `IAsyncEnumerable` disposal; `Parallel.ForEach` with non-thread-safe state; library `ConfigureAwait` where relevant.

   **Nullable & types:** `null!` on public boundaries; `required`/`init` misuse; struct/record equality in collections.

   **DI & hosting:** captive dependency (singleton holding scoped/transient); wrong lifetime; `IOptions` vs `IOptionsMonitor` for reloadable config; `IHostedService` ignoring stopping token.

   **EF Core (only if EF in diff):** tracked vs `AsNoTracking` on reads; N+1 / missing `Include` / split query; client evaluation before filter; migration/index mismatch with entity properties.

   **ASP.NET:** validation attributes vs manual checks; status codes / ProblemDetails on new endpoints.

   **Interop & serialization:** `LibraryImport` vs `DllImport`; `JsonSerializerContext` / source gen vs reflection.

   **WPF / Desktop (when in diff):** UI-thread blocking async; `INotifyPropertyChanged` wrong property; `Configure.Instance` service locator vs ctor injection.

   Suggest language/API features **only** when supported by the detected TFM/`LangVersion` from the projects touched by the PR.

## Deliverable

Generate **exactly one** HTML file via **`Write-PrReviewHtml.ps1`** (same folder as `SKILL.md`):

`<pr-output-location>\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.html`

`<pr-output-location>` is **`prOutputLocation`** from **Load configuration** (not a literal folder name).

Rules:

- `<sanitized-source-branch>`: source branch, `/` → `-`
- `<slug>`: ≤50 chars from PR/Jira title
- No Jira key: `NOJIRA_<slug>_<yyyyMMdd_HHmm>.html`
- Required sections: Template below; **Verdict** mandatory
- Do not: second file, `reports/` subfolder, EOF/format nits, generic non-diff advice
- Re-review: append `## Re-review <yyyy-MM-dd>` to markdown content before calling the script (unless user says overwrite)
- Before writing: read existing `*.html` in folder; extract embedded markdown from `<script type="application/json" id="review-source">` in prior reviews; don’t re-raise settled findings
- If a Jira key is found (via **Jira key** extraction in **Required Inputs**), **fetch issue** and compare with the implementation (acceptance criteria, status).
- If **prior PR comments** are available (Bitbucket: `bb pr view --comments`; GitHub: `gh pr view --comments` and API as needed), synthesize them in **Existing discussion** and avoid duplicating settled points unless you disagree or add evidence. This applies to **Findings** too: if a comment thread already covers an issue, do not restate it as a new Finding — see the routing rule in Review Scope item 5.
- If **no tests changed**, flag a “human review” check to confirm no tests are required.

**Workflow:** Compose review content per the Template below (markdown), then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\Write-PrReviewHtml.ps1" `
  -OutputPath "<full-path-to-.html>" `
  -MarkdownContent @'
...markdown body per Template...
'@
```

Alternatively pass `-MarkdownPath` if content was written to a temp file. The script writes a self-contained HTML page and opens it in the default browser (use `-NoOpen` to skip).

**Do not** write a `.md` deliverable to `prOutputLocation`. Compose markdown in memory (or a temp file outside the output folder that you delete after running the script). The HTML file is the only output artifact.

### Template

Follow routing in Review Scope item 5.

``` markdown
**PR:** <url>
**Jira:** [<KEY>](url) — Status: … | *fetch failed: …*
**Branch:** `…` → `…`
**Reviewed:** <ISO date>

(Summary + Risks, use caveman voice & Impact combined ≤300 words)

# PR Summary
(3–5 bullets)

## Risks & Impact
(includes dependencies/flags — do not split into a third section unless huge)

## Jira alignment
- Summary (1–2 lines)
- AC checklist: [ ] met / [ ] partial / [ ] not in PR
- Gaps vs ticket (explicit)
- If No Jira key in branch then review against PR description only

## Existing discussion
(skip if provider comment fetch is empty)

## Findings
### F1 — <short title> — Severity: High | Med | Low

- **Location:** …
- **Issue:** …
- **Why it matters:** …
- **Proposed change:** …

## Test coverage
- Changed tests: …
- Gaps / human review: …

## Framework notes (C#/.NET)
**TFM / LangVersion / nullable:** … (from csproj)
- (≤5 bullets; no duplicate of Findings; normal technical English)
- Omit entire section if nothing to add

## Verdict
Approve | Request changes | Blocked — <one line why>
```