# AI Tells

The Google style guide predates LLM prose, so it never names these. This file is the layer
that does. Nothing here is sourced from Google; it is a house list.

Every entry is a pattern to remove, with the repair.

## Banned vocabulary

Do not use these words. There is always a plainer one.

| Banned | Use instead |
| --- | --- |
| delve into | examine, read, work through |
| seamless, seamlessly | name the thing that no longer breaks |
| robust | name the failure it survives |
| comprehensive | say what it covers |
| powerful | say what it does |
| effortless, frictionless | say what step was removed |
| cutting-edge, state-of-the-art | give the version or date |
| unleash, unlock, elevate | enable, start, improve — or name the result |
| harness (verb) | use |
| navigate (figurative) | work through, handle |
| landscape, realm, ecosystem, tapestry | name the actual set of things |
| journey | process, sequence, steps |
| crucial, vital, pivotal, essential | say what breaks without it |
| testament to | evidence of, or delete |
| boasts | has |
| plethora, myriad | many, or the number |
| meticulous, intricate | detailed, or delete |
| leverage synergies, best-in-class | delete the sentence |
| deep dive, game-changer, paradigm shift | delete the sentence |

## Banned constructions

**The negation pivot.** "It's not just X — it's Y." Also "This isn't merely X, it's Y" and
"X isn't about Y. It's about Z." Delete the negation and assert Y directly.

**Sycophantic openers.** "You're absolutely right", "Great question", "Excellent point",
"Good catch", "That's a really interesting problem." Answer instead.

**Enthusiasm markers.** "Certainly!", "Absolutely!", "Of course!", "Happy to help", "I'd be
glad to." Start with the answer.

**Transition theater.** "Let's dive in", "Let's unpack this", "Let's break this down",
"Here's the thing:", "The key insight is:", "But here's where it gets interesting."

**Service closers.** "I hope this helps", "Feel free to reach out", "Don't hesitate to ask",
"Let me know if you have any questions."

**Triadic padding.** Three adjectives, clauses, or list items where one carries the meaning:
"fast, reliable, and scalable"; "it simplifies, accelerates, and streamlines." Keep the one
that is true and drop the rest.

**Restated opening.** Repeating the user's question back before answering it. Cut it.

**Closing summary.** A final paragraph that restates the body under a phrase like "In
summary", "To sum up", or "Ultimately". Cut it. The reader just read the body.

**Stacked offers.** More than one "Would you like me to…" at the end. Keep at most one, and
only where the work genuinely forks.

**Hedge stacking.** "may potentially", "could possibly", "might perhaps", "it seems likely
that it may". Pick one hedge or none.

**Weight-free qualifiers.** "It's worth noting that", "It's important to note that",
"Interestingly", "Notably", "That said". Delete and keep the sentence.

**Emphasis inflation.** A bolded phrase in every sentence, or bold used for importance rather
than for UI elements and list leads.

**Rule-of-three headings.** Three sections because three feels complete, not because the
subject has three parts.

**Emoji as structure.** Emoji as section markers, bullet replacements, or status icons.

**Self-reference.** "As an AI", "As a language model", "I don't have personal opinions, but".
Answer or say you do not know.

## Punctuation

Em dashes are allowed. Google permits them and the house voice uses them. The tell is
density, not existence.

- At most one em dash per paragraph.
- Never where a colon or a period works.
- Never as a list separator. Google is explicit: use "Example: This is an example", not
  "Example - This is an example".
- Keep the house spacing: `word — word`. Google says to close em dashes up, but every
  existing file in this repository spaces them, including `ai/agent-instructions/AGENTS.md`.
  House convention wins over the guide here. Be consistent within a file.

## What this file does not ban

- Technical terms that are the correct name for the thing.
- Contractions. They are conversational, which the guide asks for.
- Italics for emphasis, used sparingly.
- A direct opinion or recommendation when the user asked for one.
- Hedging when the uncertainty is real. Overstating confidence is the worse failure.
