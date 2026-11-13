---
type: "Glossary"
title: "Glossary"
description: "Names for the Learner, the Cluster, and the Playground."
tags: [playground, glossary]
status: stable
generated: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
verified: { by: human:mason.bivens, at: 2026-11-12T00:00:00Z }
stale_after: 2027-05-11T00:00:00Z
---

# Playground

A sample Kubernetes and GitOps environment for a local workshop.

## Language

**Learner**:
A person who can use Git and a shell and has not run Kubernetes or Flux. On this project the Learner works on a Mac.
_Avoid_: user, student, new developer

**Cluster**:
The local Kubernetes cluster created and deleted only with `container k8s`.
_Avoid_: kind cluster, k3d, minikube, Docker Desktop

**Playground**:
The sample Cluster, the Git server, and the workloads Flux reconciles, used in a local workshop.
_Avoid_: tutorial, course, demo app

**Workload**:
A program the workshop runs in the Playground, such as podinfo, the Cache, or the Database.
_Avoid_: service, app

**Day 1**:
Creating a Playground.
_Avoid_: install, bootstrap, provision

**Day 2**:
Health, reconcile, and logs for a Playground that already exists.
_Avoid_: operations, ops, maintenance

**Git server**:
The Git remote inside the Cluster. The Learner pushes to it, and Flux pulls from it. Flux does not install it.
_Avoid_: GitHub, origin

**Gateway**:
The encrypted entrance to podinfo and the bank. A certificate from the Playground CA protects each hostname.
_Avoid_: ingress

**CA**:
The authority inside the Cluster that signs certificates for Playground hostnames. The Learner's Mac trusts it.
_Avoid_: Let's Encrypt, public CA

**Cache**:
The Valkey store behind podinfo's cache.
_Avoid_: Redis

**Database**:
The Postgres store in the Playground. Workshop workloads connect to it on their own.
_Avoid_: db, instance
