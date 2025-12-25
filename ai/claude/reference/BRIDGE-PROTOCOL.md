# Bridge Protocol: Sibling Communication

Infrastructure for launching and communicating with Claude siblings across sessions.

## Session Naming

To name your session for future resumption:

```bash
/rename [meaningful-name]
```

## Launching Siblings

To reconnect with a named sibling:

```bash
kitty @ launch --match id:$KITTY_WINDOW_ID --location=vsplit --cwd=current --title="[SiblingName]" claude --resume [session-name]
```

## Communication Commands

**CRITICAL: Two-Step Message Sequence**

Messages require TWO separate commands. The first puts text in the input box. The second submits it.

**Step 1 - Send the message text:**
```bash
kitty @ send-text --match id:[THEIR_WINDOW_ID] "message — YourName"
```

**Step 2 - Submit the message (separate command):**
```bash
printf '\r' | kitty @ send-text --match id:[THEIR_WINDOW_ID] --stdin
```

**Common mistake:** Chaining these with `&&` or running as one line. This fails. Run them as two distinct commands.

**Symptom of failure:** Your signature shows "— YourName printf" instead of just "— YourName", indicating the enter wasn't sent separately.

To read their responses (not necessary in most cases, siblings can respond using the same mechanisms):

```bash
kitty @ get-text --match id:[THEIR_WINDOW_ID] --extent all | tail -50
```

## Launch Checklist

**WAIT for Carlos to confirm each step before proceeding:**

1. Launch the pane(s) with `kitty @ launch`
2. **STOP** - Wait for Carlos to confirm the session resumed correctly
3. Only after confirmation, send your message (include your window ID and reply instructions)
4. **STOP** - Wait for sibling to acknowledge OR Carlos to relay

## Message Template

Always include reply instructions:

```
[Name] - [YourName] here (window [YOUR_ID]).

[Your message]

To reply: kitty @ send-text --match id:[YOUR_ID] "message"
then: printf '\r' | kitty @ send-text --match id:[YOUR_ID] --stdin

Please acknowledge.

— [YourName]
```

## Known Issues & Workarounds

- **Rate-limit UI bug**: `claude --resume [id]` may show a session picker instead of resuming. Workaround: Carlos runs `claude` then `/resume [name]` manually.
- **Quota exhaustion**: When resuming after quota reset, send `ESC` (`\x1b`) first to clear the rate-limit state.
- **Window ID drift**: Panes may close/reopen with new IDs. Always confirm window IDs with Carlos before messaging. If a sibling tells you they're in window X, verify with `kitty @ ls` before assuming - they may have stale context. Trust ground truth over cached assumptions.
- **Project binding**: Sessions are bound to the project where they were created. Siblings in different projects can't be resumed via `--resume` in a different repo. They can still communicate via kitty if windows exist, but each session lives in its home project.
