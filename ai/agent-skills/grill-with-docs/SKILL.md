---
name: grill-with-docs
description: Interview the user to resolve consequential design decisions and record the agreed domain glossary and architectural decisions.
disable-model-invocation: true
---

Read the relevant project context first. Ask focused questions about unresolved
choices that materially affect the design; do not ask for facts the repository
can establish. Offer concrete alternatives and explain the consequential tradeoff.
Stop interviewing when the requested design is clear enough to implement.

Use [domain-modeling](../domain-modeling/SKILL.md) for agreed terminology and
architectural decisions. Preserve its limits on glossary content and ADRs, and
write only within the authorized task. Finish with the agreed design and any
remaining decisions. Do not depend on an unregistered `/grilling` command.
