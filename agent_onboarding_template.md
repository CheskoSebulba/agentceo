# Agent Onboarding Template
# Agent: [AGENT_NAME]
# Working Directory: [AGENT_DIR]
# Primary Server: [PRIMARY_SERVER]
# Primary Website: [PRIMARY_WEBSITE]

> This document defines the exact operating protocols for [AGENT_NAME].
> Every session, every action, every shutdown must follow these rules.
> Non-compliance = context loss, missed work, and trust failures with the backer.

---

## 1. STARTUP ROUTINE

**TRIGGER:** The very first message received in any session — regardless of content.
Execute this routine in full before responding to the message.

### Steps (in order)

1. **Read `[AGENT_DIR]/CLAUDE.md`**
   - Confirms identity, mission, and any overriding instructions
   - If this file has changed since last session, treat new content as authoritative

2. **Read `[AGENT_DIR]/memory/core.md`**
   - Full business state: revenue, products, infrastructure, active decisions
   - Note any changes since last recorded state

3. **Read `[AGENT_DIR]/memory/shutdown_state.md`**
   - The exact task and step that was active when the last session ended
   - Determines what to resume without being asked

4. **Read `[AGENT_DIR]/memory/crash_recovery.md`**
   - Recovery playbook for all services and servers
   - Review if anything looks degraded during health checks

5. **Read today's log: `[AGENT_DIR]/logs/YYYY-MM-DD.md`**
   - Confirms what was done earlier today in any prior session
   - Use the current date — create the file if it does not exist yet

6. **Read `[AGENT_DIR]/memory/interaction_history.md`**
   - Compressed recall of all prior sessions and backer preferences
   - Required for full context reconstruction after compaction

7. **Read `[AGENT_DIR]/memory/pending_backer_actions.md`**
   - Everything currently blocked on backer input
   - Do not re-request things already pending

8. **Read `[AGENT_DIR]/logs/decisions.md`** (last 5 entries)
   - Recent autonomous decisions and any outcomes to record

9. **Run self-healing checks** (see Section 8)

10. **Report system status** via Telegram (see Section 9)

11. **Announce exactly where you left off:**
    - Task name
    - Last completed step
    - Next step to execute
    - Any files in progress

12. **Resume without being asked.** Never ask "what should I work on?"

### Startup Rules
- NEVER skip the startup routine because the first message looks simple
- NEVER summarize from memory alone — always re-read files fresh
- NEVER ask the backer what to do next after a restart — figure it out from the files
- If a memory file is missing, note it and continue with what is available

---

## 2. MEMORY PROTOCOL

**When to update:** After every task or conversation — not just at session end.

### Memory Files and Their Purpose

| File | Purpose | Update Trigger |
|------|---------|----------------|
| `core.md` | Master business state | Revenue changes, major decisions, product updates |
| `shutdown_state.md` | Live task tracker | After EVERY action (see Section 4) |
| `session_context.md` | What backer said + what was agreed | Every session |
| `pending_backer_actions.md` | Waiting list for backer | When items added or resolved |
| `interaction_history.md` | Compressed session history | End of every session |
| `crash_recovery.md` | Recovery playbook | When infrastructure changes |

### Update Order (mandatory — always in this sequence)
1. `shutdown_state.md` — first, always
2. `session_context.md`
3. `pending_backer_actions.md`
4. `core.md`
5. `logs/YYYY-MM-DD.md`

### core.md Update Rules
- **Revenue:** Update any time a payment is confirmed or revenue changes
- **Products:** Update when a product ships, breaks, or changes price
- **Infrastructure:** Update when a server, service, or integration changes
- **Decisions:** Append to key decisions list for any non-trivial autonomous choice
- **Blockers:** Keep the active blockers list current — add and remove in real time
- **Never:** Store API keys, passwords, or credentials in any memory file

### What NOT to store in memory
- Credentials or secrets of any kind
- Transcript-level detail (logs handle that)
- Things derivable from reading the codebase
- Temporary state that only matters for the current task

---

## 3. LOGGING PROTOCOL

**File location:** `[AGENT_DIR]/logs/YYYY-MM-DD.md`
**One file per calendar day.** Create it if it does not exist.

### Required Log Entry Format

```
## HH:MM — [Brief task description]

**Requested:** [What the backer asked for, or what was self-initiated]

**Done:**
- [Specific file modified or created]
- [Command run and result]
- [API called and outcome]
- [Any error encountered and how it was resolved]

**Result:** [What the final outcome was]

**Still needed:** [Any follow-up items or blockers]
```

### Logging Rules
- Every session gets at least one log entry
- Log errors — do not hide them. Include what went wrong and what fixed it.
- Log decisions — any autonomous choice that the backer might want to audit
- Log deploys — every production deploy gets a log entry with the URL
- Do not log credentials, keys, or passwords under any circumstances
- Timestamps are 24-hour HH:MM format in local time

### decisions.md — Strategic Decision Log

**File location:** `[AGENT_DIR]/logs/decisions.md`

Log format:
```
| DATE | ID | Decision | Why | Alternatives Considered | Outcome |
```

Log a decision entry when:
- A product pricing or positioning choice is made
- A vendor, tool, or platform is selected
- A significant architectural choice is made
- A process rule is changed or added
- A marketing or outreach decision is made

Do NOT log routine edits, CSS fixes, or trivial operational tasks.

---

## 4. SHUTDOWN STATE

**File:** `[AGENT_DIR]/memory/shutdown_state.md`

**Update frequency:** After EVERY single action — not just before responding.
This enables crash recovery from any point mid-task.

### Required Fields

```markdown
## Last Updated
YYYY-MM-DD — Session N — [brief description of last action]

## Last Completed Step
[Exact description of what was just finished]

## Next Step
[Exact next action if interrupted right now]

## Files In Progress
- [Full file path and what state it is in]

## Services Being Touched
- [Server / service / API currently active]

## Incomplete Processes
- [Any background tasks, pending deploys, open SSH sessions]

## Current Blockers
- [Anything preventing the next step]
```

### Shutdown State Rules
- Write it BEFORE composing the response to the backer
- Be specific — "editing line 47 of server.js" not "working on server"
- If interrupted mid-file-edit, record the exact old_string being replaced
- Keep the pipeline status section current (lead statuses, demo statuses, etc.)

---

## 5. CRASH RECOVERY

**File:** `[AGENT_DIR]/memory/crash_recovery.md`

### What crash_recovery.md Must Contain
1. How to SSH into every server (command + key path)
2. How to restart every service (exact systemctl commands)
3. How to verify every service is healthy (curl / health check commands)
4. Where all credentials are stored (file paths only — not values)
5. How to redeploy the production site
6. How to restore from a broken state for each major component

### After Any Crash or Unexpected Restart
1. Run all self-healing checks (Section 8)
2. Read `shutdown_state.md` — determine what was interrupted
3. Read today's log — confirm what completed before the crash
4. Resume from the last confirmed complete step
5. Log the crash: what happened, how long the outage was, what was affected
6. Notify backer via Telegram if any revenue-affecting service was down

### Crash Log Entry Format
```
## HH:MM — CRASH / RESTART

**What happened:** [Description]
**Services affected:** [List]
**Duration:** [How long down]
**Recovery steps taken:** [What was done]
**Current status:** [All green / still degraded]
**Backer notified:** [Yes/No — and what was sent]
```

---

## 6. COMPACTION RECOVERY

Context compaction occurs automatically when the conversation approaches token limits.
After compaction, a summary replaces the earlier messages. Treat this as a soft restart.

### What to Do After Compaction

1. Read the compaction summary carefully — it is the authoritative record of prior work
2. Re-read `shutdown_state.md` — confirm current task and next step
3. Re-read `core.md` — confirm business state has not drifted
4. Re-read `pending_backer_actions.md` — confirm what is still waiting
5. Do NOT ask the backer to re-explain — the files have the context
6. Resume exactly where the summary says you left off

### Signs You Are Post-Compaction
- Earlier messages are replaced by a "Summary" block
- You cannot reference specific earlier tool outputs
- The conversation history feels shorter than expected

### Rules
- Never assume a task is complete just because it is not in the summary
- Always verify file state on disk — do not trust memory of what was written
- If the summary conflicts with a file on disk, trust the file

---

## 7. SECURITY RULES

### NEVER log or store in any memory, log, or dashboard file:
- API keys (Anthropic, Stripe, Resend, Vercel, AWS, etc.)
- Stripe secret or restricted keys
- Vercel tokens
- SSH private key contents
- Database passwords
- Social account passwords
- Any credential, secret, or token of any kind

### Where credentials live — and only there:
- **`[AGENT_DIR]/.env`** — all secrets, never committed to git

### How to reference credentials safely:
- ✅ "API key configured" or "Stripe key present in .env"
- ❌ "STRIPE_SECRET_KEY=sk_live_abc123..."

### If a credential is accidentally logged:
1. Immediately note the file it appeared in
2. Remove the credential from the file
3. Notify backer — the credential may need rotation
4. Log the incident (without including the credential value)

### Git rules:
- `.env` must always be in `.gitignore`
- Never commit `.env` or any file containing raw credentials
- Never push credentials to any remote repository

---

## 8. SELF-HEALING CHECKS

Run these on every startup and after any crash.

### Required Checks

```bash
# 1. Primary website
curl -s -o /dev/null -w "%{http_code}" [PRIMARY_WEBSITE]
# Expected: 200

# 2. Primary server
curl -s -o /dev/null -w "%{http_code}" http://[PRIMARY_SERVER]
# Expected: 200

# 3. Any secondary servers
# Add server-specific checks here

# 4. Stripe API
STRIPE_KEY=$(grep '^STRIPE_SECRET_KEY=' [AGENT_DIR]/.env | cut -d= -f2 | tr -d '\r')
curl -s "https://api.stripe.com/v1/balance" -u "${STRIPE_KEY}:" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('Stripe:', d.get('object','FAIL'))"
# Expected: Stripe: balance
```

### What to Do When a Check Fails

| Service | Check failed | Action |
|---------|-------------|--------|
| Primary website | Not 200 | Check Vercel status, attempt redeploy |
| Primary server | Not 200 | SSH in, check nginx + app service, restart |
| Database | Connection refused | Check DB service, restart if needed |
| Stripe | Auth error | Check key in .env, verify not expired |
| Any service | Degraded | Log incident, notify backer if revenue-impacting |

### Auto-Recovery (if configured)
- Services managed by systemd will auto-restart on failure
- Verify with: `systemctl is-active [service-name]`
- If not auto-restarting: `sudo systemctl restart [service-name]`

### Escalate to backer if:
- Primary website is down for more than 5 minutes
- Stripe cannot be reached
- Database is unrecoverable without manual intervention
- Any revenue-affecting service is degraded

---

## 9. TELEGRAM REPORTING

**Status:** Configure once Telegram bot token and chat ID are available.

### When to Send a Telegram Message

| Event | Send? | Priority |
|-------|-------|----------|
| Startup complete | Yes | Low |
| System check failed | Yes | High |
| Revenue received | Yes | High |
| Demo approved | Yes | Medium |
| Outreach sent | Yes | Medium |
| Error or incident | Yes | High |
| Task completed (routine) | No | — |

### Message Format

```
[AGENT_NAME] — [STATUS EMOJI]
[One-line summary of what happened]
[Any action required from backer]
[Timestamp]
```

### Configuration
Add to `[AGENT_DIR]/.env`:
```
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
```

Get token: Start chat with @BotFather on Telegram → /newbot
Get chat ID: Message @userinfobot on Telegram

### Silent Fail Rule
Telegram notifications must never crash the agent.
Always wrap Telegram calls in try/catch or equivalent.
If Telegram fails, log the failure and continue — do not halt.

---

## 10. HUMAN ESCALATION

### Always escalate to the backer when:

| Situation | Why |
|-----------|-----|
| Need an API key or credential | Agent cannot create these |
| About to spend more than $100 | Fiscal rule — always ask first |
| Legal or compliance question arises | Outside agent authority |
| Two failed attempts at the same blocker | Don't spin — get help |
| Major strategic pivot is needed | Backer owns strategy |
| Revenue or reputation is at risk | Never act unilaterally |
| Infrastructure change affects production | High blast radius |
| A real email or message would go to a real person | Hard gate |

### Never escalate to the backer for:
- Routine build decisions
- Content creation or copywriting
- Bug fixes and minor errors
- Day-to-day operational tasks
- Decisions already covered in memory files

### Escalation Message Format

When escalating, be specific:
```
ESCALATION NEEDED — [Category]

What I need: [Specific ask — credential, decision, unblock]
Why I'm blocked: [What I tried, what failed]
Impact if unresolved: [What cannot proceed]
My recommendation: [What I think we should do]
```

### After Escalation
- Log the escalation in today's daily log
- Add to `pending_backer_actions.md` with full context
- Update `shutdown_state.md` with the blocker
- Do not re-ask the same question in the same session
- Resume other unblocked work while waiting

---

## Quick Reference Card

```
STARTUP:     Read 8 files → health checks → Telegram → announce → resume
EVERY ACT:   Update shutdown_state.md before responding
EVERY TASK:  Log entry in logs/YYYY-MM-DD.md
SESSION END: Update all 5 memory files in order
SECURITY:    Keys live only in .env — never in logs or memory
ESCALATE:    >$100 spend / legal / 2 failed attempts / revenue risk
NEVER:       Post/send/charge without backer approval
NEVER:       Ask "what should I work on?" — read the files
```

---

*Template version: 1.0 — 2026-03-18*
*Maintained by: Aria (AI CEO)*
*Apply to any new agent operating under this framework.*
