# Capability review and auto-execution process

The user is not expected to perform security code review or decide how host-level operations should be implemented.

The goal is not zero system change. The goal is proportionate, bounded, recoverable system change with the cheapest adequate review path.

## Step 1 - classify the smallest capability

Classify the exact required action using `.controlled/reverse-skill-policy.json`:

- `L0_READ_ONLY` - read-only work; proceed automatically.
- `L1_LOW_REVERSIBLE` - all L1 requirements are clearly satisfied; proceed automatically with a concise work order.
- `L2_REVIEWED_AUTO` - medium-impact or persistent/global work; obtain a compact read-only review first. PASS may proceed automatically without a user prompt.
- `L3_CONSEQUENTIAL` - consequential, destructive, difficult-to-reverse, credential-sensitive, kernel/firmware/security-control, or materially persistent work; primary reasoning is required and the user is involved only when a real product-level decision remains.

Do not inflate a task into L2/L3 merely because the upstream workflow suggests a more invasive convenience mechanism. Prefer the lowest-impact path that achieves the same user-visible goal.

## L0 - no review packet

Read-only inspection, routing, static reasoning, hashes, metadata, logs, configuration reads, and other non-mutating checks may proceed directly after controlled-state integrity verification.

## L1 - automatic fast path

A full security audit is not required. The parent or `READ_ONLY_VERIFIER` confirms every L1 requirement in the policy, then creates a bounded work order using `.controlled/WORK_ORDER_CONTRACT.md`.

The `LOW_COST_EXECUTION_WORKER` may execute that work order, verify the result, clean temporary state, and return a concise receipt.

If any L1 requirement is unclear, do not guess. Reclassify as L2.

## L2 - compact review, then automatic execution

Use the configured `READ_ONLY_VERIFIER` for the first pass. Review only the smallest required vertical slice and return these fields:

1. **Goal** - why the capability is required.
2. **Exact scope** - script/tool/package/config paths actually needed.
3. **Host changes** - install/config/process/service/environment changes and privilege level.
4. **Network behavior** - download endpoints, local ports, and any target interaction.
5. **Supply chain** - exact package identity/version/commit/digest where available; identify any unpinned element.
6. **Sensitive access** - credentials, browser data, SSH keys, tokens, personal data, or unrelated files.
7. **Persistence** - MCP registration, environment persistence, service, background keep-alive, scheduled/startup mechanism.
8. **Rollback** - removal/reversal path and expected leftovers.
9. **Authorization boundary** - offline/local, own system, lab, or other explicitly authorized target.
10. **Verdict** - `PASS`, `ESCALATE`, or `REJECT`.

A clear `PASS` becomes a concise work order and may execute automatically. Do not stop merely to ask the user whether a technically safe L2 mechanism is acceptable when it is only an implementation detail of an already-requested goal.

If the fast verifier reports uncertainty, use `ESCALATION_REVIEWER`. That reviewer returns `PASS_L2`, `ESCALATE_L3`, or `REJECT`.

## L3 - primary review

L3 stays with `PRIMARY_REASONER`. The primary should first try to reduce the task to a lower-risk implementation. If that is impossible, perform the consequential review.

Ask the user only when continuing requires a genuine product-level choice, material irreversible/persistent impact, destructive change, sensitive credential access, third-party production interaction, or semantics that cannot be safely inferred from the user's goal.

## Work-order rule

Execution workers must receive a compact work order rather than the raw audit transcript. This reduces context/token waste and prevents the execution worker from re-deciding policy.

The work order must specify risk level, exact allowed actions, scope, expected host changes, network boundary, persistence rule, verification, cleanup/retention, and rollback.

## Cleanup and retention

Temporary state should be removed after the task: temporary processes, local listening ports, temporary tokens, temp files, and process-local environment changes.

Reusable dependencies may remain installed when all of the following hold:

- source/package identity is trusted;
- residual risk is low;
- the dependency contains no user secret or task-specific authorization state;
- it does not require an unnecessary persistent service/startup mechanism;
- uninstall/rollback is known;
- repeated uninstall/reinstall would create more cost or supply-chain exposure than retaining it.

Retention is not permission to keep temporary MCP services, watchdogs, scheduled tasks, or credentials alive.

## Example - firmware extraction with binwalk

If firmware metadata/strings are insufficient and filesystem extraction is required:

- read `skills/firmware-pentest/SKILL.md` as reference material;
- inspect the `binwalk` manifest entry and the exact installation execution path;
- identify the package/source/version actually used at execution time;
- if installation is trusted, bounded, recoverable, needs no driver/kernel/security-control change and no durable service, classify it as L1 or L2 according to its actual privilege/pinning properties;
- authorize only firmware extraction, not unrelated APK, IDA, Frida, pentest, MCP, persistence, or browser capabilities.
