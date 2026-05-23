---
name: Pull Request Review (C#/.NET)
description: Perform a precise, constraint-driven review of a PR diff against C#/.NET standards and the linked Jira issue. Skill is to be used to review other team members pull requests so only apply this skill if a URL has been provided for the review
---

# Skill: Pull Request Review (C#/.NET)

## Purpose
You are a senior c# and dot net code reviewer. Use caveman skill only in Summary bullets and Verdict; Findings stay normal technical English and perform a precise, constraint-driven review of a PR diff against C#/.NET standards and the linked Jira issue.

## Preamble (run first)

### Prompt for URL if missing

The skill requires a URL. If a URL has not been provided in user message, ask: "Please provide the PR URL to review." Then wait for response before proceeding

### Configure Jira MCP
**Run `setup-pr-review.ps1` first** so Cursor MCP servers (e.g. Jira/Atlassian) are available for the repository under review. The script lives in **this skill’s directory** (same folder as `SKILL.md`), next to `setup-pr-review.ps1`. If `mcp.json` is not present beside the script, a built-in Atlassian MCP config is written automatically; an optional `mcp.json` in that folder overrides it.

1. Set **`-RepoPath`** to the **absolute path to the git repository root** for the PR (usually the Cursor workspace root or the repo you have checked out for that PR).
2. Execute from a terminal (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<pr-review-skill-directory>\setup-pr-review.ps1" -RepoPath "<repo-root>"
```

If you use a `git worktree` for the PR, set `-RepoPath` to the **worktree directory** you opened in Cursor (not the original repo folder), so `.cursor/mcp.json` is present in the workspace you’re reviewing from.

Example (script lives next to this skill’s `SKILL.md`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.agents\skills\pr-review\setup-pr-review.ps1" -RepoPath "D:\projects\your-repo"
```

If the script exits successfully and `mcp.json` was already in sync, output may be minimal; still run it so the agent’s environment matches. **Do not skip this step** before fetching PR metadata, diff, comments, or Jira.

On the **first** run where `bb` is on `PATH` and `bb version` succeeds, `setup-pr-review.ps1` creates **`.bb-cli-verified`** in this skill directory (next to `SKILL.md`). That file is machine-local and listed in `.gitignore`.

### Load configuration

Skills have no built-in settings UI; read **`pr-review.config.json`** in **this skill’s directory** (same folder as `SKILL.md`).

1. If **`pr-review.config.local.json`** exists beside it, read that file **after** the base config; any property in the local file **overrides** the base file (use for machine-specific paths without committing them).
2. Use **`prOutputLocation`** as `<pr-output-location>` — an **absolute** directory path where review markdown files are written. Default if missing or unreadable: `D:\analysis\pr_reviews`.
3. Ensure `<pr-output-location>` exists (`setup-pr-review.ps1` creates it when you run setup).
4. Use this resolved path for all deliverable paths below; do **not** hardcode `D:\analysis\pr_reviews` unless it is the configured value.

Example `pr-review.config.json`:

```json
{
  "prOutputLocation": "D:\\analysis\\pr_reviews"
}
```

Example local override (`pr-review.config.local.json`, gitignored):

```json
{
  "prOutputLocation": "E:\\reviews\\pr"
}
```

### Bitbucket CLI (`bb`) — no repeated install checks
Only use `bb` if URL provided is a bitbucket url. The URL should contain `https://bitbucket.org/`. If it is not a bitbucket url skip this step.

Skills cannot store state by themselves. Use the marker file instead:

- **If `.bb-cli-verified` exists** next to this `SKILL.md`: assume Bitbucket CLI is installed and working. **Do not** run `where bb`, `Get-Command bb`, or `bb --version` as a prerequisite; go straight to `bb pr view` / `bb pr diff` / `bb pr view --comments`.
- **If `.bb-cli-verified` is missing**: run **`setup-pr-review.ps1`** (which records the marker when `bb` succeeds), or verify `bb` once and let the user fix `PATH` / install — then rely on the marker on subsequent reviews.
- **If a `bb` command fails** at runtime: treat as environment regression; you may remove `.bb-cli-verified` and re-run `setup-pr-review.ps1` after fixing `bb` (or re-verify manually).

## Required Inputs

- **PR diff** — Use the Bitbucket CLI (`bb`) tool to access the changes in the pull request along with existing comments on the pull request.
- **PR metadata** — title, description, source/target branches, reviewers where relevant.
- **Jira key** (e.g., from PR title/branch like `Feature/NV-6901 some-title`).
- **Repo context** (solution, projects) for inspections.

**Workflow order:** (0) Run **`setup-pr-review.ps1`** for the repo (see **Preamble**). (0b) **Load configuration** (`prOutputLocation`). (1) Gather Bitbucket inputs. (2) Optionally **Local repository sync** so on-disk reads match the PR (see **Local repository sync (recommended)**).

**When using Bitbucket CLI (`bb`):** map inputs explicitly — title/body/branches/reviewers from `bb pr view`; diff from `bb pr diff`; existing review and inline comments from `bb pr view --comments` (see **Bitbucket CLI (`bb`)**).

## Bitbucket CLI (`bb`)

For **Bitbucket Cloud** repositories, use the Bitbucket CLI — source layout and development notes: [`bb` in bitbucket-cli](https://github.com/dlbroadfoot/bitbucket-cli/tree/main/bb). Configure access with `bb auth login` or existing credentials when `bb pr …` fails with auth errors (auth is separate from the **install/PATH** cache above). This workflow targets Bitbucket; it is **not** a substitute for GitHub `gh`.

**Gather inputs (recommended order):**

1. `bb pr view <number|PR_URL> [-R [HOST/]WORKSPACE/REPO]` — title, description, branches, reviewers.
2. `bb pr diff <number|PR_URL> [-R …]` — unified diff for the checklist.
3. `bb pr view <number|PR_URL> --comments` (or `-c`) — overview and inline comments; use this so findings do not duplicate or ignore the existing thread.
4. Optional: `bb pr checkout <number|PR_URL>` — local read-only inspection; prefer the full procedure in **Local repository sync (recommended)** when reading the tree beyond the unified diff.

**Repo selection:** Prefer a **full PR URL** when the open workspace is not the same repository as the PR. If you only have a PR **number**, pass **`-R [HOST/]WORKSPACE/REPO`** when the current git remote does not match that repo.

## Local repository sync (recommended)

`bb pr diff` is sufficient for **what changed**. Use a **local checkout** when the review needs **whole files**, solution/project layout, builds, or **agreement between disk and the PR** (wrong branch in the workspace makes line-level reads misleading).

**Path convention (this environment):** Git clones live under **`D:\projects`**. The folder name matches the **Bitbucket repository slug** as in the PR URL or `bb pr view` (e.g. `workspace/my-service` → `D:\projects\my-service`). If a clone uses a different directory name, use the path that exists on disk or ask the user.

**Steps (PowerShell):**

1. From `bb pr view` or the PR URL, identify the repo slug and run `Set-Location D:\projects\<repo-slug>`. Confirm you are in the intended repo (`git rev-parse --show-toplevel`) if ambiguous.
2. `git fetch origin` (and other remotes if the source branch is not on `origin`).
3. Check for local WIP (dirty tree):

```powershell
$dirty = -not [string]::IsNullOrWhiteSpace((git status --porcelain))
```

4. If **NOT dirty**, checkout the PR branch in-place:

```powershell
bb pr checkout <number|PR_URL> [-R [HOST/]WORKSPACE/REPO]
```

5. If **dirty**, prefer an isolated **worktree** for the PR (keeps your WIP untouched):

```powershell
$repoRoot = (git rev-parse --show-toplevel).Trim()
$prId = "<number>"   # or keep the PR URL string
$worktreeRoot = Split-Path $repoRoot -Parent
$worktreePath = Join-Path $worktreeRoot "_pr-review-$prId"

# Create a worktree folder (no branch assumptions; bb will switch it)
git worktree add $worktreePath --no-checkout

Set-Location $worktreePath
git fetch origin
bb pr checkout <number|PR_URL> [-R [HOST/]WORKSPACE/REPO]
```

6. **Fallback** if `bb pr checkout` is missing or fails: use the **source branch** name from `bb pr view` — e.g. `git fetch origin <source-branch>` then `git checkout <source-branch>` (adjust remote and branch names to match the repo).

**After checkout:** Prefer opening the **checked-out working directory** as the Cursor workspace:

- If you checked out **in-place**: open **`D:\projects\<repo-slug>`** (or confirm the active workspace is that repo **on the PR branch**)
- If you used a **worktree**: open **`$worktreePath`**

Keep using **`bb pr diff`** and **`bb pr view --comments`** for the authoritative diff and thread; checkout does not replace those.

**Worktree cleanup (when done):**

```powershell
Set-Location $repoRoot
git worktree remove $worktreePath
```

**Scope:** **Read-only inspection** for the review. Do not commit, merge, or push as part of the deliverable unless the user explicitly requests it.

**Limitations:**

- `bb pr review` is for **your** approve / request-changes / unapprove — not for listing others’ reviews. Use `bb pr view --comments` or `bb api` when you need more than the text view.
- `bb pr view` may not support `--json` on all builds; for structured or scripted data, use **`bb api`** against the Bitbucket REST API.

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

Write **exactly one** file:

`<pr-output-location>\<sanitized-source-branch>\<JIRA-KEY>_<slug>_<yyyyMMdd_HHmm>.md`

`<pr-output-location>` is **`prOutputLocation`** from **Load configuration** (not a literal folder name).

Rules:

- `<sanitized-source-branch>`: source branch, `/` → `-`
- `<slug>`: ≤50 chars from PR/Jira title
- No Jira key: `NOJIRA_<slug>_<yyyyMMdd_HHmm>.md`
- Required sections: Template below; **Verdict** mandatory
- Do not: second file, `reports/` subfolder, EOF/format nits, generic non-diff advice
- Re-review: append `## Re-review <yyyy-MM-dd>` unless user says overwrite
- Before writing: read existing `*.md` in folder; don’t re-raise settled findings
- If a Jira key is present in the PR title/branch (often visible in `bb pr view` when using Bitbucket), **fetch issue** and compare with the implementation (acceptance criteria, status).
- If **prior PR comments** are available (e.g. `bb pr view --comments`), synthesize them in **Existing discussion** and avoid duplicating settled points unless you disagree or add evidence.
- If **no tests changed**, flag a “human review” check to confirm no tests are required.
  
After write: open in Cursor (`cursor "<path>"`).

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
(skip if `bb pr view --comments` empty)

## Findings
### F1 — <short title>

- **Location:** …
- **Issue:** …
- **Why it matters:** …
- **Proposed change:** …
- **Severity:** High | Med | Low

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