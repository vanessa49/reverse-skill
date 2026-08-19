# Controlled reverse-skill fork

This overlay converts the upstream repository into a read-only-by-default toolbox for Codex.

## Security baseline

- Upstream repository: `zhaoxuya520/reverse-skill`
- Audited upstream commit: `a9ed8d04ad58894a16c3b9ae918ccecb8131d23e`
- Verdict: `READ_ONLY_APPROVED`
- Upstream execution/bootstrap/MCP/persistence: blocked by default

The root `AGENTS.md` in this controlled fork intentionally overrides upstream auto-execution behavior. Upstream `RULES.md`, `README_AI.md`, and specialist skills remain available as reference material but are not execution authority.

## Local use after the controlled fork is published

```powershell
git clone https://github.com/vanessa49/reverse-skill.git C:\projects\tooling\reverse-skill
cd C:\projects\tooling\reverse-skill

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-controlled-state.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-reverse-triage.ps1
```

The installer only copies the small `reverse-triage` skill and writes the local repository path into that skill. It does not run upstream bootstrap scripts, install reverse-engineering tools, or register MCP servers.

## Updating from upstream

Do not blindly sync upstream into the controlled branch. Any change to the audited critical upstream surface must fail the controlled safety gate until the new upstream commit is reviewed and `.controlled/upstream-lock.json` is deliberately updated.

## Who performs future capability reviews?

Not the user. When a real task needs an executable capability, `reverse-triage` identifies the smallest slice and an agent/auditor reviews it using `.controlled/CAPABILITY_REVIEW_PROCESS.md`. The user only decides whether to enable a capability after receiving the plain-language review result.
