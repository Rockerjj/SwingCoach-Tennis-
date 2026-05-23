# Codex / Tennique Shared Workflow

This repo uses GitHub as the shared state layer for Hermes on the Mac mini, Codex CLI on a MacBook Pro, Codex mobile/cloud, and any local terminal session.

## Principles

- Do not sync live working directories between machines.
- Do all meaningful work on named branches.
- Push branches early so another device or agent can pick them up.
- Use pull requests as the durable handoff and review layer.
- Do not merge without Josh's explicit approval.
- Keep Tennique work siloed from Trilogy/day-job work and from paused ventures.

## Canonical repo

- GitHub remote: `git@github.com:Rockerjj/SwingCoach-Tennis-.git`
- Mac mini / Hermes path: `/Users/joshrockers/.openclaw/workspace/tennique`
- Recommended MacBook Pro path: `~/Code/tennique`

The local path can differ by machine. The remote, branch name, commits, and PR are the source of truth.

## Branch protocol

### Main

`main` is the clean integration branch. Do not work directly on it.

Before starting new work:

```bash
git checkout main
git pull --ff-only origin main
```

### Josh-started branches

Use this when Josh starts work locally:

```text
josh/<short-task>
```

Examples:

```text
josh/onboarding-copy-pass
josh/testflight-cleanup
```

### Agent-started branches

Use this when Hermes or Codex starts normal repo work:

```text
agent/tennique/<short-task>
```

Examples:

```text
agent/tennique/privacy-support-pages
agent/tennique/persona-copy-review
```

### Kanban worktree branches

Use this for isolated Hermes Kanban worker runs:

```text
wt/<kanban-task-id>-<short-task>
```

Example:

```text
wt/t_3f667a68-codex-shared-workflow
```

This task used:

```text
wt/codex-shared-workflow
```

## Mac mini / Hermes workflow

When Hermes starts work from Telegram or Kanban:

```bash
cd /Users/joshrockers/.openclaw/workspace/tennique
git fetch origin --prune
git checkout main
git pull --ff-only origin main
git checkout -b agent/tennique/<short-task>
```

For Kanban worktree tasks, use the assigned worktree/branch from the task context rather than creating a second workspace.

After edits:

```bash
git status --short
git diff --check
git add <changed-files>
git commit -m "docs: <short summary>"
git push -u origin HEAD
gh pr create --base main --head $(git branch --show-current) --title "docs: <short summary>" --body "<summary + test plan>"
```

If `gh` auth is unavailable, push the branch and report the exact `gh pr create` command for Josh to run.

## MacBook Pro / Codex CLI workflow

One-time setup:

```bash
npm install -g @openai/codex
codex login --device-auth
codex doctor
mkdir -p ~/Code
cd ~/Code
git clone git@github.com:Rockerjj/SwingCoach-Tennis-.git tennique
cd tennique
```

Start new work:

```bash
cd ~/Code/tennique
git fetch origin --prune
git checkout main
git pull --ff-only origin main
git checkout -b josh/<short-task>
git push -u origin HEAD
codex
```

One-shot review/audit:

```bash
codex exec "Review the TestFlight and App Store launch docs for stale TennisIQ references. Do not edit app code. Summarize findings first."
```

One-shot docs edit:

```bash
codex exec --ask-for-approval never --sandbox workspace-write "Clean safe Tennique naming drift in docs only. Do not edit Swift, project.yml, StoreKit files, or generated project files. Run git diff --check and summarize changed files."
```

## Cross-device handoff

### Josh starts on MacBook Pro, Hermes continues

Josh:

```bash
git checkout -b josh/<short-task>
git push -u origin HEAD
```

Then tell Hermes:

```text
Pick up branch josh/<short-task>. Keep changes docs-only. Do not merge.
```

Hermes:

```bash
git fetch origin
git checkout josh/<short-task>
git pull --ff-only origin josh/<short-task>
```

### Hermes starts, Josh continues on MacBook Pro

Hermes pushes the branch and PR. Josh pulls it:

```bash
cd ~/Code/tennique
git fetch origin
git checkout <branch-name>
git pull --ff-only origin <branch-name>
```

### Codex mobile / cloud continuity

Use GitHub-backed Codex tasks, branches, comments, and PRs. Do not treat the phone as a raw file editor.

## Pull request flow

Every PR should include:

- Summary: what changed.
- Scope guardrails: whether app code, project config, or generated files changed.
- Verification: commands run, or `not run` with a reason.
- Handoff notes: anything Josh must do manually.

For docs-only PRs, a sufficient test plan is usually:

```bash
git diff --check
git status --short
```

Do not merge the PR. Josh reviews and merges.

## Tennique docs-only guardrails

Safe docs-only changes:

- Brand-facing copy: `Tennis IQ` / `TennisIQ` -> `Tennique` when referring to the app brand.
- Domains and support email that should be public-facing: `tennique.app`, `support@tennique.app`.
- App Store Connect bundle ID when it reflects `project.yml`: `com.tennique.app`.
- App Store product IDs when they reflect `AppConstants.Subscription`: `tennique_pro_monthly`, `tennique_pro_annual`.

Do not change these in a docs-only sweep unless the underlying code/config is also being renamed in a separate code PR:

- Source folder: `TennisIQ/`
- Xcode project generated from current `project.yml`: `TennisIQ.xcodeproj`
- StoreKit config file path: `TennisIQ/Resources/TennisIQ.storekit`
- Swift types that still contain `TennisIQ`
- `project.yml`, Swift files, `.storekit`, generated Xcode files, or build artifacts

If a reference is both stale-looking and tied to current code/config, leave it in place and add a note rather than making a docs-only rename that would send Josh to a nonexistent path.

## Quick commands

Current branch:

```bash
git branch --show-current
```

Changed files:

```bash
git status --short
git diff --name-status main...HEAD
```

Push current branch:

```bash
git push -u origin HEAD
```

Create PR:

```bash
gh pr create --base main --head $(git branch --show-current) --title "docs: codex shared workflow and Tennique launch docs" --body-file /tmp/tennique-pr-body.md
```
