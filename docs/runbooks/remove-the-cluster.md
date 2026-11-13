---
type: "Runbook"
title: "Remove the Cluster"
description: "Remove the Cluster playground from the Mac."
tags: [playground, cluster]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Remove the Cluster

Last updated: 2026-11-12

CAUTION: Copy any data you still need before `make down`.
The command removes the Cluster `playground` and the disks on it.
The command also stops the local port forwards.

## Remove

1. Run `make down`.
2. Run `container k8s list`.

When the list shows no Cluster named `playground`, the remove is complete.

## Create it again

1. Run `make up`.

When `make up` exits 0, Day 1 is complete.
Passwords in `.local/` stay on the Mac.
`make up` reuses those files.
