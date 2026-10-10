---
name: aae-identity-atlas-and-auth
description: How Atlas Agent Engine projects and orgs relate to Atlas ones, the Atlas service account that atlas setup needs, MongoDB as a hard runtime requirement, and service-account roles.
---

# Identity, Atlas linkage and auth

- [Summary](#summary)
- [Is an AAE project the same thing as an Atlas project?](#is-an-aae-project-the-same-thing-as-an-atlas-project)
- [Which org ID do I pass where?](#which-org-id-do-i-pass-where)
- [Does `atlas setup` need an Atlas service account?](#does-atlas-setup-need-an-atlas-service-account)
- [Must the database be Atlas, or just MongoDB?](#must-the-database-be-atlas-or-just-mongodb)
- [Which role should a service account get?](#which-role-should-a-service-account-get)

## Summary

- **One project ID, shared.** Atlas owns membership, roles and clusters; AAE keeps its own
  record keyed by the same ID.
- **Orgs can show two different IDs** for what is one logical org. Use the AAE one for
  `agentengine --org-id` and the Atlas one for the Atlas UI and API.
- `agentengine atlas …` commands need an **Atlas service account** with Project Owner when run
  non-interactively.
- **MongoDB is a hard runtime requirement.** Whether it must be Atlas is not established.

## Is an AAE project the same thing as an Atlas project?

Yes, by ID. Verified 2026-10-06 (CLI 0.1.118):

- `~/.agentengine/contexts.json`, `agentengine project get <project_id>` and the `atlas` block
  of `.agentengine/state.json` all carry the **same project ID**, and the Atlas UI opens that
  ID as an ordinary Atlas project.
- `project get` adds AAE-only fields (Sharing Policy, Allow Member Invites).
- The roles page: Project Owner "on the Atlas project that contains the agent"; login reads
  role assignments from Atlas.

The model to teach: **one project ID; Atlas owns membership, roles and clusters; AAE keeps
its own record keyed by the same ID.** The misunderstanding to head off: "AAE has its own,
separate projects."

## Which org ID do I pass where?

Observed 2026-10-06: AAE surfaces (`contexts.json`, `project get`, `atlas status`) report one
org ID, while the `atlas` block in `state.json` and the Atlas UI report a **different** org ID
for the same project, and both carry the same org name.

- Use the **AAE** org ID for `agentengine --org-id`.
- Use the **Atlas** org ID for the Atlas UI, Atlas Admin API and support cases.
- Teach it as one logical org with two records. A one-to-one mapping is not proven.
- Rule: check `contexts.json` and `project get` before asserting identity relationships. A
  mismatch between two records is a question, not a conclusion.

## Does `atlas setup` need an Atlas service account?

The docs say yes. Get-started (verified 2026-10-06): *"The CLI supports Atlas service account
credentials only"*. Create one in Atlas (Project Identity & Access → Applications) with
**Project Owner**, and enter its client ID and secret at the `atlas setup` prompt.

- `atlas setup --help` (0.1.118) also mentions a "delegated setup" mode, so docs and CLI
  disagree on whether it is strictly required for interactive use.
- Observed: an interactive `atlas setup` succeeded with no Atlas profile configured, while a
  later non-interactive run failed with `Atlas service account profile "default" is not configured`.
- **Keep the Atlas service account.** Non-interactive `agentengine atlas …` commands demand it.
  Do not conclude from a missing `~/.agentengine/atlas.json` that it is unused.

## Must the database be Atlas, or just MongoDB?

MongoDB is required. Atlas specifically is **not established**. Verified 2026-10-06.

- `/deploy/provision-secrets.md`: `MONGODB_URI` is the "connection string for your MongoDB
  deployment", required for **every** deploy, even with memory off. "If your MONGODB_URI
  points to an Atlas cluster, run atlas setup" implies non-Atlas MongoDB is allowed.
- The checkpointer is MongoDB-backed. No other database is mentioned anywhere.
- The Orchestration Engine exits at startup without `MONGODB_URI` (a fatal
  "MONGODB_URI is required" log line), and it **creates indexes** on its own collections, so
  the DB user needs `createIndex`, not just connect and read/write.
- Conflicts: get-started says AAE "requires an Atlas cluster"; `deploy --help` says a URI that
  does not match a live cluster in the linked Atlas project "is reported" (block vs warning
  unknown).
- **Memory needs Atlas Search and Vector Search**, so memory does need Atlas, Flex or larger.
  The CLI refuses free/shared tiers for deployment.
- Untested: deploying against a self-managed MongoDB.

## Which role should a service account get?

As of 2026-10-10 (CLI 0.1.118), project roles are `PROJECT_OWNER`, `PROJECT_READ_ONLY` and
`AGENT_DEVELOPER`; org roles `ORG_GROUP_CREATOR` and `ORG_READ_ONLY`. Detail in
[DRIFT_LOG.md](DRIFT_LOG.md#2026-10-10--new-service-account-role-agent_developer).

- `AGENT_DEVELOPER` can invoke, build and deploy. There is no invoke-only role, so a client
  that only invokes still receives build and deploy rights. Say so.
- Agent management needs an **explicit** Project Owner assignment; Organization Owner alone
  does not grant it in AAE. (Atlas model API keys are the exception: there Organization Owner
  works. See [VERIFIED_DETAILS.md](VERIFIED_DETAILS.md#where-does-the-voyage-key-for-memory-come-from).)
- Tokens from `POST /api/v1/oauth/token` last 1 hour and do not refresh; the client re-mints
  them. Calling the token endpoint too often returns 429.
