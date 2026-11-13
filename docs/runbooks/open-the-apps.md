---
type: "Runbook"
title: "Open the apps"
description: "The Gateway serves podinfo and the bank on port 8443."
tags: [playground, gateway]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Open the apps

Last updated: 2026-11-12

The Gateway serves podinfo and the bank on port 8443.
The Playground CA signs both certificates.
`make up` saves the CA in `.local/ca.crt`.
`make up` trusts that CA in the Mac login keychain.

If macOS asks for your login password, enter it one time.

## podinfo

1. Run this curl.

```bash
curl --fail --cacert .local/ca.crt https://podinfo.localhost:8443
```

When the response is the podinfo runtime JSON, this step is complete.
HTTP on that host redirects to HTTPS.

## Headers

1. Run this curl.

```bash
curl -sI --cacert .local/ca.crt https://podinfo.localhost:8443/
```

When the response includes `strict-transport-security` and `x-frame-options`, this step is complete.
The same headers are on `https://bank.localhost:8443`.

2. Run this curl.

```bash
curl -s --cacert .local/ca.crt https://podinfo.localhost:8443/headers
```

When the response shows `X-Forwarded-Proto: https`, this step is complete.

## Bank

1. Run this curl.

```bash
curl --fail --cacert .local/ca.crt https://bank.localhost:8443
```

When the response is the bank page, this step is complete.

2. Open `https://bank.localhost:8443` in a browser.
   When the sign-in page is on the screen, this step is complete.
3. Sign in as `testuser` with the password `bankofanthos`.
   When the page accepts that login, this step is complete.
Database passwords are in [Databases](databases.md).
