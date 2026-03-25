# Security

## Threat model

AgentCEO creates autonomous agents that run Claude Code with broad filesystem and shell access. This is intentional — the agent needs to write code, deploy files, and run commands without stopping to ask for approval every time.

The framework takes the following security approach:

### What is protected

- **Credentials** — stored in `.env` (chmod 600), never written to logs or memory files, never committed to git
- **File permissions** — all generated files created with `umask 0077` (owner-only read/write)
- **SSH passwords** — not echoed to terminal, not passed via process arguments (uses `sshpass -e`)
- **Agent directory isolation** — each agent's `CLAUDE.md` scopes it to its own directory and staging server

### Known limitations

**`--dangerously-skip-permissions`** — every agent launcher uses this flag. It disables Claude Code's per-tool permission prompts entirely. An agent can execute bash commands, read/write files, and make network calls without human approval. This is required for autonomous operation but means a prompt-injected or misbehaving agent has broad access to the host machine.

**OS-level isolation is not enforced** — agent directory boundaries are instructions to the LLM, not OS-level controls. On a single machine with multiple agents, all agents run as the same OS user. A compromised agent session could in principle access other agents' directories.

**Passphrase-less SSH keys** — generated keys have no passphrase. On a multi-agent machine, one agent's session can technically use another agent's SSH key.

### Recommendations for production use

- Run each agent as a separate OS user with its home directory set to `700`
- Use a firewall to restrict outbound connections from the agent's user
- Regularly audit `logs/` for unexpected activity
- Rotate API keys stored in `.env` periodically
- Consider removing `--dangerously-skip-permissions` and using `settings.json` allowlists for sensitive environments

## Reporting a vulnerability

Open a GitHub issue. For credential-related disclosures, email the maintainer directly before filing a public issue.
