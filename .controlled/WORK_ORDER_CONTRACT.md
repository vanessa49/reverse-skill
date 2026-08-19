# Controlled execution work-order contract

A work order is the small handoff from reasoning/review to the low-cost execution worker. It is intentionally concise so the worker does not need the full audit context.

The machine-readable authority is `.controlled/work-order.schema.json`. Prefer passing the worker a JSON object that validates against that schema. The text form below is a human-readable rendering of the same fields.

## Required fields

```text
WORK_ORDER_ID: <stable local id>
GOAL: <user-visible outcome>
RISK_LEVEL: L1_LOW_REVERSIBLE | L2_REVIEWED_AUTO
REVIEW_STATUS: L1_REQUIREMENTS_PASS | L2_PASS | L2_PASS_AFTER_ESCALATION
CAPABILITY: <exact tool/script/operation>

ALLOWED_ACTIONS:
- <exact bounded actions>

ALLOWED_PATHS:
- <paths the worker may create/read/write/delete>

NETWORK_BOUNDARY:
- <none | package-download-only | localhost-only | explicit authorized target(s)>

PACKAGE_OR_TOOL_IDENTITY:
- source: <vendor/package/repository>
- version_or_commit: <exact value when available>
- digest: <exact value when available or NOT_AVAILABLE>

EXPECTED_HOST_CHANGES:
- <install/config/process/environment changes>

PERSISTENCE:
- <none | exact reviewed persistence>

PRE_STATE:
- <minimal facts needed to verify/rollback>

VERIFY:
- <success checks>

CLEANUP:
- <temporary state to remove>

RETENTION:
- <nothing | exact reusable dependency allowed to remain and why>

ROLLBACK:
- <safe reversal steps>

STOP_CONDITIONS:
- actual action differs materially from this order
- unexpected privilege/elevation is required
- unrelated sensitive data would be accessed
- unexpected persistence or external target interaction appears
- verification fails and rollback is not clearly safe
```

## Execution boundary

- An execution work order may authorize only `L1_LOW_REVERSIBLE` or a reviewed `L2_REVIEWED_AUTO` action.
- `L3_CONSEQUENTIAL` must never be translated directly into an execution work order. It returns to the primary reasoner and, when the policy requires it, the user.
- L1 requires `L1_REQUIREMENTS_PASS`. L2 requires `L2_PASS` or `L2_PASS_AFTER_ESCALATION` before the execution worker may mutate the host.
- The worker must stop rather than improvise if the real action exceeds the recorded paths, commands, privilege, persistence, network, or sensitive-data boundary.

## Execution receipt

Return only the decision-relevant result to the parent:

```text
WORK_ORDER_ID: ...
STATUS: PASS | ROLLED_BACK | PARTIAL | ESCALATE
CHANGES: <concise actual changes>
VERIFICATION: <concise evidence>
CLEANUP: <what was removed/stopped>
RETAINED: <what remains installed/configured>
ROLLBACK_STATE: <not-needed | complete | incomplete>
RESIDUAL_RISK: <none/low/material + explanation>
```

Do not paste long install logs, test logs, or raw command output into the parent thread unless a failure requires specific evidence.
