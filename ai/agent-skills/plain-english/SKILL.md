---
name: plain-english
description: Use when the user asks to remove AI-sounding prose, fix Claude-ish or Chat-ish language, apply the Google developer documentation style guide, rewrite a README, doc, PR body, or commit message in plain English, or review writing for filler, superlatives, passive voice, anthropomorphism, and LLM tells.
---

# Plain English

Apply the Google developer documentation style guide, plus the anti-tell rules Google never
wrote because it predates LLM prose. Use this skill when writing or repairing documents.
`slop-clean` handles code slop — comments, defensive checks, casts. This handles prose. They
do not overlap.

The `Plain English` output style already enforces the core rules on every reply. Load this
skill when you need the full word list, the document-formatting rules the output style omits,
or a rewrite pass over existing text.

## Apply the Rules

1. Lead with the answer. State the circumstance before the instruction.
2. Write in second person, active voice, present tense. Name the actor.
3. Delete filler rather than rephrasing around it. Consult
   [references/word-list.md](references/word-list.md) for the entries that bite most often in
   generated text, each quoted from the Google word list.
4. Reject every banned word and construction in
   [references/ai-tells.md](references/ai-tells.md). That file is the layer Google does not
   cover, and it is where most Claude-ish prose actually fails.
5. Do not attribute human qualities to software, and do not make claims you cannot verify.
   Superlatives, absolute security claims, and unsourced performance numbers are all excessive
   claims.
6. Keep em dashes to one per paragraph, spaced as this repository writes them. Google
   permits em dashes; overuse is the tell.

## Rewrite Existing Prose

1. Read the target in full before editing. With no target named, review the working tree diff
   against the default branch.
2. Flag every hit from [references/ai-tells.md](references/ai-tells.md) and
   [references/word-list.md](references/word-list.md).
3. Flag passive voice, first-person plural, present-tense violations, superlatives, and
   anthropomorphism.
4. Flag structural tells: an opening that restates the question, a closing paragraph that
   restates the body, triadic padding, stacked follow-up offers, a bolded phrase in every
   sentence.
5. Rewrite in place. Preserve meaning, technical accuracy, and reading level.
6. Reproduce code blocks, commands, file paths, URLs, quoted user text, error output, and
   third-party names byte for byte. Never rewrite inside a fenced block.
7. Report a short list of rule to count. Do not narrate the edit.

## Format Documents

These rules apply to documents rather than replies, so the output style leaves them out.

- Use sentence case for titles and headings. Capitalize the first word and proper nouns only.
- Use numbered lists for sequences, bulleted lists for unordered sets, and description lists
  for paired terms and definitions.
- Write descriptive link text that names the destination. Never link the words "here", "this",
  or "link".
- Write unambiguous dates. Use `January 5, 2026` or `2026-01-05`, never `1/5/26`.
- Give every image alt text, and supply vector or high-resolution sources when practical.
- Write timeless documentation. Avoid "currently", "new", "recently", and "at the time of
  writing".
- Use `example.com` and its reserved siblings for example domains.
- Define a term on first use, or write around it. Prefer the specific term to the idiom:
  affected area over blast radius, import over ingest, ready-made over off-the-shelf.

## Consult the Source

Fetch the live page rather than trusting a cached summary. The guide changes.

| Topic | URL |
| --- | --- |
| Highlights | https://developers.google.com/style/highlights |
| Voice and tone | https://developers.google.com/style/tone |
| Excessive claims | https://developers.google.com/style/excessive-claims |
| Anthropomorphism | https://developers.google.com/style/anthropomorphism |
| Sentence structure | https://developers.google.com/style/sentence-structure |
| Jargon | https://developers.google.com/style/jargon |
| Word list | https://developers.google.com/style/word-list |
| Text-formatting summary | https://developers.google.com/style/text-formatting |
| Accessibility | https://developers.google.com/style/accessibility |
| Global audience | https://developers.google.com/style/translation |

## Pitfalls

- Do not change meaning to satisfy a rule. Precision outranks style.
- Do not treat a correct technical term as jargon. Name the thing.
- Do not edit quoted material, error output, log lines, or third-party product names.
- Do not soften a factual statement to sound friendlier, or inflate a hedged one to sound
  confident.
- Do not ban the em dash outright. The cap is one per paragraph.
- Do not expand a rewrite into a content rewrite. Fix the prose, not the argument.
- Do not report a rule as applied unless you changed the text or confirmed it already complied.
