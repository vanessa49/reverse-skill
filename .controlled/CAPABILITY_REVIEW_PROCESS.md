# Capability review process

The user is not expected to perform security code review.

When `reverse-triage` reaches `CAPABILITY_APPROVAL_NEEDED`, the agent/auditor must review the smallest required vertical slice and translate the result into plain language before any policy elevation.

## Required review packet

For each requested capability, record:

1. **Goal** — what user-visible problem requires this capability and why read-only analysis is insufficient.
2. **Exact scope** — specialist module, executable scripts, manifest entries, direct dependencies, and relevant configuration files.
3. **Host changes** — files/directories created or deleted, packages installed, PATH/config/environment changes, services/processes/tasks created, privilege/UAC needs.
4. **Network behavior** — domains/endpoints contacted, downloads performed, ports opened/listened on, and whether target traffic is generated.
5. **Supply chain** — exact versions/commit SHAs/digests where available, plus any unpinned/latest/transitive dependency risk.
6. **Sensitive access** — whether the capability reads credentials, browser data, SSH keys, tokens, local user data, or unrelated files.
7. **Persistence** — scheduled tasks, startup entries, services, background keep-alives, user environment variables, MCP registration, or global agent config changes.
8. **Rollback** — how to remove packages/config/processes/tasks and return to the prior state.
9. **Authorization boundary** — whether the capability is purely local/offline or interacts with a target, and what target authorization is required.
10. **Verdict** — exactly one of `APPROVE`, `READ_ONLY_ONLY`, or `REJECT`, with rationale and residual risks.

## Policy change rule

A capability is not approved merely because the user wants the outcome. The auditor must first produce the review packet. Only an `APPROVE` verdict may be translated into a narrowly scoped entry in `approved_capabilities`.

Do not ask the user to inspect source code or decide whether code is safe. Present the technical review in plain language and ask only for the product-level decision when needed: whether they want to enable the reviewed capability for the current task.

## Example: firmware + binwalk

If a firmware image cannot be understood from metadata/strings alone and extraction is required, review only:

- `skills/firmware-pentest/SKILL.md` as workflow/reference material;
- the `binwalk` entry in `skills/scripts/bootstrap-manifest.json`;
- the exact `winget-package` execution path in `skills/scripts/bootstrap-reverse.ps1` and helper functions it calls;
- the specific binwalk version/source that would actually be installed at review time;
- binwalk's intended command against the local firmware file.

Do not approve unrelated APK, IDA, Frida, pentest, MCP, persistence, or browser capabilities as a side effect of approving firmware extraction.
