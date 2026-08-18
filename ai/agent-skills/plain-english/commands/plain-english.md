---
description: Rewrite prose in plain English
---

Rewrite the target in plain English, following the Google developer documentation style guide
and stripping AI tells.

Target: `$ARGUMENTS`. With no argument, review the working tree diff against the default
branch and rewrite the prose it touches — Markdown, doc comments, commit messages, and
strings meant for humans.

Read the whole target first, then flag and fix:

- Filler and substitutions from the Google word list: just, simply, easy, please, note that,
  leverage, allows you to, in order to, execute, currently
- Banned vocabulary: delve, seamless, robust, comprehensive, powerful, cutting-edge, unleash,
  elevate, landscape, realm, journey, crucial, testament, plethora, meticulous
- Banned constructions: "It's not just X — it's Y", sycophantic openers, "Let's dive in",
  "I hope this helps", "It's worth noting", triadic padding, hedge stacking
- Passive voice, first-person plural, superlatives, absolute claims, anthropomorphism
- Structural tells: restated opening, closing summary paragraph, stacked follow-up offers, a
  bolded phrase in every sentence
- Em dashes beyond one per paragraph, and spaced em dashes

Preserve meaning, technical accuracy, and reading level. Reproduce code blocks, commands,
paths, URLs, quoted user text, error output, and third-party names byte for byte. Never edit
inside a fenced block.

Report at the end with a short list of rule to count. Do not narrate the edit.
