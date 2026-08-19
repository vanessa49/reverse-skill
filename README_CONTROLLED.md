# Controlled reverse-skill fork

This overlay converts upstream `zhaoxuya520/reverse-skill` into a risk-managed toolbox for Codex.

## Security baseline

- Upstream repository: `zhaoxuya520/reverse-skill`
- Audited upstream commit: `a9ed8d04ad58894a16c3b9ae918ccecb8131d23e`
- Upstream imperative instructions are reference material, not execution authority.
- Safety policy: `.controlled/reverse-skill-policy.json`
- Current role-to-model mapping: `.controlled/model-routing.json` + `.codex/`

The original first-generation overlay was read-only by default. The current design allows proportionate system operations through four risk levels:

- `L0_READ_ONLY` - automatic.
- `L1_LOW_REVERSIBLE` - automatic when every low-risk requirement is clearly met.
- `L2_REVIEWED_AUTO` - compact read-only review first; PASS executes automatically without a user implementation prompt.
- `L3_CONSEQUENTIAL` - primary reasoning; ask the user only for genuine consequential product-level choices.

This means Codex may install or run a low-risk bounded dependency when it is genuinely needed, while unnecessary persistence, credentials, firmware writes, kernel/driver changes, destructive operations, and intrusive third-party production actions remain outside automatic execution.

## Current multi-agent mapping

The safety policy uses logical roles rather than model names. The current project mapping is intentionally replaceable:

```text
PRIMARY_REASONER          -> parent session (currently expected Sol)
LOW_COST_EXECUTION_WORKER -> luna_capability_worker (GPT-5.6 Luna)
READ_ONLY_VERIFIER        -> luna_verifier (GPT-5.6 Luna)
ESCALATION_REVIEWER       -> terra_security_reviewer (GPT-5.6 Terra)
```

Current Codex supports project-scoped custom agents under `.codex/agents/*.toml` with explicit `model`, `model_reasoning_effort`, and sandbox settings. If Codex or the available model family changes later, update `.controlled/model-routing.json` and `.codex/`; do not rewrite the risk policy merely because model names changed.

Revalidate routing only when a configured model/config schema changes, the project smoke test fails, a model is deprecated/unavailable, a clearly better replacement appears, or measured quality regresses.

## Token/context strategy

Consequential decisions stay in the primary thread. Narrow reviews, mechanical checks, bounded execution, verification, cleanup, and rollback use project-scoped workers when available.

Execution workers receive a compact `.controlled/WORK_ORDER_CONTRACT.md` work order instead of the full audit transcript. They return a concise receipt instead of raw install/test logs. This keeps the primary context focused on requirements and decisions.

## Local use

```powershell
git clone https://github.com/vanessa49/reverse-skill.git C:\projects\tooling\reverse-skill
cd C:\projects\tooling\reverse-skill

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-controlled-state.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-reverse-triage.ps1
```

The `reverse-triage` installer only copies the controlled triage skill and records the repository path. It does not run upstream bootstrap scripts or install reverse-engineering tools by itself.

Project-scoped `.codex/` routing is loaded only when the local Codex client accepts the project configuration. If Codex reports that the project is not trusted, add the exact clone path to the local trusted-project configuration using the then-current Codex configuration format, restart Codex, and run a one-time read-only subagent smoke test. Do not blindly copy an old global config format if Codex has changed.

## How future capabilities work

The user describes the goal. `reverse-triage` decides whether reverse engineering is needed, selects the narrowest specialist material, identifies the smallest missing capability, and classifies it.

- L0/L1 do not require a full security-audit conversation.
- L2 uses the low-cost verifier first and escalates only when evidence is materially uncertain.
- L3 stays with the primary reasoner.
- The user is not expected to inspect source code or decide which system-level implementation is technically safe.

Temporary state is cleaned after use. Trusted reusable dependencies may remain installed when residual risk is low, no secret/persistence is retained, and uninstall/rollback is known.

## Updating from upstream

Do not blindly sync upstream into the controlled branch. Any change to the audited critical upstream surface must fail the controlled safety gate until the new upstream commit is reviewed and `.controlled/upstream-lock.json` is deliberately updated.
