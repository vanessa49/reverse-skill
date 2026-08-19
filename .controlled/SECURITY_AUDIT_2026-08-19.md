# Independent static security audit - reverse-skill

## Scope

Upstream: `zhaoxuya520/reverse-skill`

Pinned commit: `a9ed8d04ad58894a16c3b9ae918ccecb8131d23e`

Audit date: 2026-08-19 (Asia/Taipei)

Method: read-only GitHub inspection of the pinned repository, targeted dangerous-pattern searches, and manual review of the core router/scope/bootstrap/config/persistence surfaces. No upstream repository script was executed on the user's computer during this audit.

## Verdict

`READ_ONLY_APPROVED`

The pinned upstream snapshot is suitable to retain as a read-only knowledge/toolbox dependency behind a controlled wrapper. The snapshot is **not** approved for blanket execution, automatic bootstrap, MCP registration, persistence, or unrestricted active security operations.

This is not a claim that the repository is formally proven malware-free. It is a risk-scoped static review.

## Positive findings

1. The repository has a real scope contract and a case guard intended to block active target interaction before authorization and network scope are established.
2. The core bootstrap supply-chain helper requires pinned commits for git-clone capabilities and verifies the checkout is clean before using it.
3. Several release assets are pinned to fixed versions and SHA-256 hashes; other GitHub releases can use API-provided digests.
4. CI covers routing coherence, supply-chain regression, force-gate bypass tests, shell/PowerShell parsing, JSON validity, leak scanning, and Windows PowerShell 5.1 compatibility.
5. Targeted searches did not locate `Get-Credential` usage, executable `New-Service` usage, or executable registry `Set-ItemProperty` persistence in the reviewed baseline. `Invoke-Expression`, `EncodedCommand`, and `FromBase64String` hits were in security documentation/reference material rather than the core executable path reviewed.
6. The upstream package security audit reports no discovered embedded backdoor/destructive disk-format logic/curl-pipe-shell pattern on its audited executable surface. This was treated as supporting evidence, not as independent proof.

## Material risks requiring the controlled wrapper

### 1. Prompt-supply-chain / automatic side-effect pressure - HIGH if loaded as authority

Upstream `RULES.md` explicitly instructs an agent to execute immediately, install missing tools, perform actual side effects, and not wait at deterministic steps. Specialist skills use similar `ACTION REQUIRED` language.

This behavior is useful for an autonomous security lab, but it is not appropriate as a global default for this user's general Codex environment. The controlled fork therefore replaces root `AGENTS.md` with a read-only authority boundary and treats upstream prompts as data.

### 2. Bootstrap changes the host - HIGH without per-capability approval

`skills/scripts/bootstrap-reverse.ps1` can install Node.js, Python, Java, Visual Studio Build Tools, Android tools and other capabilities through package managers. It can install pip/npm/go dependencies and clone third-party repositories.

The controlled default blocks the entire upstream bootstrap path.

### 3. Global agent configuration and credential persistence - HIGH without explicit approval

The bootstrap contains code that can edit Codex MCP configuration, edit Claude MCP configuration, create Anything Analyzer MCP config, and persist an `ANYTHING_ANALYZER_MCP_TOKEN` user environment variable when those capabilities are selected.

The controlled default blocks all MCP registration/global-agent-config/persistent-token changes.

### 4. Background and persistence behavior exists - HIGH without explicit approval

Anything Analyzer may be launched as a hidden background process. The IDA module contains `install-autostart.ps1`, which registers a hidden Windows Scheduled Task that checks the local MCP service every minute for a very long repetition window.

No persistence capability is approved by default.

### 5. Supply-chain pinning is partial - MEDIUM

Some capabilities are strongly pinned by fixed hashes or git commit SHAs. Others intentionally use `winget-latest`; some GitHub release flows validate the downloaded asset against the GitHub API digest but do not pin a pre-reviewed expected asset digest/version; npm/pip/go/docker ecosystems still have their normal dependency and install-hook risks.

Each executable capability should be reviewed separately before it is added to `approved_capabilities`.

### 6. Scope gate is a workflow control, not an OS sandbox - MEDIUM

The upstream scope contract and `case-guard` are substantive controls, but they do not mediate every host command at the operating-system level. An agent that ignores the workflow could still directly invoke other commands. The controlled wrapper therefore blocks upstream execution by policy rather than relying on the scope gate alone.

### 7. Offensive reference corpus - CONTEXTUAL

The repository intentionally contains exploitation, evasion, credential, persistence, payload, and red-team reference material. Those files are not by themselves evidence of malware, but they should not be preloaded into unrelated Codex work. The `reverse-triage` skill loads only one relevant module on demand.

## Approved now

- Store/clone the pinned repository snapshot.
- Read routing metadata and specialist documentation on demand.
- Use the controlled `reverse-triage` skill to decide whether reverse engineering is needed.
- Run the controlled fork's local integrity verifier.
- Produce read-only analysis/plans without executing upstream tooling.

## Not approved now

- Any upstream executable script.
- Any upstream bootstrap capability.
- Any package installation or update.
- MCP server registration or agent-global config edits.
- Persistent environment variables/tokens.
- Scheduled tasks, startup persistence, or hidden background services.
- Active network scanning, traffic interception, hooking, exploitation, credential attacks, persistence, or evasion.
- Automatic field-journal writeback or upstream contribution.

## Future capability elevation

When a real task requires a tool, review only that vertical slice. Example for firmware work: review the `firmware-pentest` module plus the exact `binwalk`/extraction tool bootstrap and side effects. If acceptable, add only that capability to the controlled policy. Do not approve the whole toolbox merely because one module is needed.

The user is not expected to perform the security review. The agent/auditor follows `.controlled/CAPABILITY_REVIEW_PROCESS.md`, produces a plain-language review packet, and only then proposes a narrow policy change.

## Audit limitations

- Static repository review is not a formal proof of absence of malicious behavior.
- Third-party dependency source trees and every transitive package were not exhaustively audited in this pass.
- No malware sandbox/dynamic detonation was performed.
- Future upstream commits are outside this approval until separately reviewed.
