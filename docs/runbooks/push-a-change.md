---
type: "Runbook"
title: "Push a change"
description: "Push a file to the Git remote playground, then run make sync."
tags: [playground, git]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Push a change

Last updated: 2026-11-12

The Git remote name is `playground`.
Flux pulls from that remote.
Push to `playground`.

## Push

1. Edit a file under `./infrastructure`, `./apps`, or `./apps/app-bank`.
   When `git diff` shows that file, this step is complete.
2. If `git branch --show-current` does not print `main`, run `git switch main`.
   When `git branch --show-current` prints `main`, this step is complete.
3. Run this command with the path of that file.

```bash
git add path/to/the/file
```

When `git diff --cached --name-only` prints that path, this step is complete.
4. Run this command.

```bash
git commit -m "Describe the edit."
```

When `git log -1` shows the commit, this step is complete.
5. Run `git push playground HEAD:main`.
   When the push exits 0, this step is complete.
6. Run `make sync`.
   When `make sync` exits 0, this step is complete.

If `git push` cannot connect, run `make status`.
Then run `git push playground HEAD:main` again.

`infrastructure` reconciles `./infrastructure`.
`workloads` reconciles `./apps` and registers each `ks.yaml`.
`app-sandbox` reconciles `./apps/app-sandbox` after `infrastructure` is Ready.
Each sandbox workload reconciles its own directory after `app-sandbox` is Ready.
`app-bank` reconciles `./apps/app-bank` after `infrastructure` is Ready.
`bank-postgres` reconciles `./apps/app-bank/bank-postgres` after `app-bank` is Ready.
Each other bank workload reconciles its own directory after `bank-postgres` is Ready.
