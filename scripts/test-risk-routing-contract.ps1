#requires -Version 5
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    else {
        throw 'Cannot determine repository root. Re-run with -RepoRoot <path>.'
    }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected=[$Expected] Actual=[$Actual]" }
}

function Assert-Contains {
    param($Collection, $Expected, [string]$Message)
    if ($Collection -notcontains $Expected) { throw "$Message Missing=[$Expected]" }
}

$policyPath = Join-Path $RepoRoot '.controlled\reverse-skill-policy.json'
$routingPath = Join-Path $RepoRoot '.controlled\model-routing.json'
$schemaPath = Join-Path $RepoRoot '.controlled\work-order.schema.json'
$configPath = Join-Path $RepoRoot '.codex\config.toml'

$policyRaw = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
$policy = $policyRaw | ConvertFrom-Json
$routing = Get-Content -LiteralPath $routingPath -Raw -Encoding UTF8 | ConvertFrom-Json
$schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8

Assert-Equal $policy.schema_version 2 'Policy schema version drifted.'
Assert-Equal $policy.default_mode 'risk_managed' 'Policy default mode drifted.'
Assert-True (-not ($policyRaw -match '(?i)gpt-[0-9]')) 'Safety policy must not pin concrete model names.'

$requiredRoles = @('PRIMARY_REASONER','LOW_COST_EXECUTION_WORKER','READ_ONLY_VERIFIER','ESCALATION_REVIEWER')
foreach ($role in $requiredRoles) {
    Assert-Contains $policy.logical_roles $role 'Policy logical role set drifted.'
    Assert-True ($null -ne $routing.roles.$role) "Routing is missing role $role."
}

$l0 = $policy.risk_levels.L0_READ_ONLY
$l1 = $policy.risk_levels.L1_LOW_REVERSIBLE
$l2 = $policy.risk_levels.L2_REVIEWED_AUTO
$l3 = $policy.risk_levels.L3_CONSEQUENTIAL
Assert-True ($null -ne $l0 -and $null -ne $l1 -and $null -ne $l2 -and $null -ne $l3) 'One or more risk levels are missing.'
Assert-True ([bool]$l0.auto_approve -and -not [bool]$l0.review_required) 'L0 must remain auto-approved and read-only.'
Assert-True ([bool]$l1.auto_approve -and -not [bool]$l1.review_required) 'L1 must remain auto-approved after requirements pass.'
Assert-Equal $l1.execution_role 'LOW_COST_EXECUTION_WORKER' 'L1 execution role drifted.'
Assert-True (-not [bool]$l2.auto_approve -and [bool]$l2.review_required -and [bool]$l2.execute_after_pass_without_user_prompt) 'L2 reviewed-auto semantics drifted.'
Assert-Equal $l2.review_role 'READ_ONLY_VERIFIER' 'L2 review role drifted.'
Assert-Equal $l2.uncertainty_escalation_role 'ESCALATION_REVIEWER' 'L2 escalation role drifted.'
Assert-Equal $l2.execution_role 'LOW_COST_EXECUTION_WORKER' 'L2 execution role drifted.'
Assert-True (-not [bool]$l3.auto_approve -and [bool]$l3.review_required) 'L3 must remain consequential and non-auto-approved.'
Assert-Equal $l3.review_role 'PRIMARY_REASONER' 'L3 review role drifted.'
Assert-True ($policy.never_auto_execute.Count -gt 0) 'never_auto_execute must not be empty.'

$lowModel = [string]$routing.roles.LOW_COST_EXECUTION_WORKER.model
$verifyModel = [string]$routing.roles.READ_ONLY_VERIFIER.model
$escalationModel = [string]$routing.roles.ESCALATION_REVIEWER.model
Assert-True (-not [string]::IsNullOrWhiteSpace($lowModel)) 'Low-cost worker model is missing.'
Assert-True (-not [string]::IsNullOrWhiteSpace($verifyModel)) 'Verifier model is missing.'
Assert-True (-not [string]::IsNullOrWhiteSpace($escalationModel)) 'Escalation model is missing.'

$expectedConfigModel = [regex]::Escape($lowModel)
Assert-True ($config -match '(?m)^enabled\s*=\s*true\s*$') 'Codex subagents must remain enabled.'
$configModelPattern = '(?m)^default_subagent_model\s*=\s*"{0}"\s*$' -f $expectedConfigModel
Assert-True ($config -match $configModelPattern) 'Default subagent model does not match routing.'

$agents = @(
    @{ Path = '.codex\agents\luna_capability_worker.toml'; Name = 'luna_capability_worker'; Model = $lowModel; Sandbox = 'workspace-write' },
    @{ Path = '.codex\agents\luna_verifier.toml'; Name = 'luna_verifier'; Model = $verifyModel; Sandbox = 'read-only' },
    @{ Path = '.codex\agents\terra_security_reviewer.toml'; Name = 'terra_security_reviewer'; Model = $escalationModel; Sandbox = 'read-only' }
)
foreach ($agent in $agents) {
    $path = Join-Path $RepoRoot $agent.Path
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing custom agent file: $($agent.Path)"
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $namePattern = [regex]::Escape([string]$agent.Name)
    $modelPattern = [regex]::Escape([string]$agent.Model)
    $sandboxPattern = [regex]::Escape([string]$agent.Sandbox)
    $nameLine = '(?m)^name\s*=\s*"{0}"\s*$' -f $namePattern
    $modelLine = '(?m)^model\s*=\s*"{0}"\s*$' -f $modelPattern
    $sandboxLine = '(?m)^sandbox_mode\s*=\s*"{0}"\s*$' -f $sandboxPattern
    Assert-True ($text -match $nameLine) "Agent name mismatch: $($agent.Path)"
    Assert-True ($text -match $modelLine) "Agent model mismatch: $($agent.Path)"
    Assert-True ($text -match $sandboxLine) "Agent sandbox mismatch: $($agent.Path)"
}

$requiredWorkOrderFields = @(
    'work_order_id','goal','risk_level','review_status','capability','allowed_actions','allowed_paths',
    'network_boundary','package_or_tool_identity','expected_host_changes','persistence','pre_state',
    'verify','cleanup','retention','rollback','stop_conditions'
)
foreach ($field in $requiredWorkOrderFields) {
    Assert-Contains $schema.required $field 'Work-order schema required fields drifted.'
}
Assert-Contains $schema.properties.risk_level.enum 'L1_LOW_REVERSIBLE' 'Work-order schema must allow L1.'
Assert-Contains $schema.properties.risk_level.enum 'L2_REVIEWED_AUTO' 'Work-order schema must allow L2.'
Assert-True ($schema.properties.risk_level.enum -notcontains 'L3_CONSEQUENTIAL') 'Execution work orders must never authorize L3 directly.'

Write-Output 'RISK_ROUTING_CONTRACT=PASS'
Write-Output "LOW_COST_EXECUTION_WORKER_MODEL=$lowModel"
Write-Output "READ_ONLY_VERIFIER_MODEL=$verifyModel"
Write-Output "ESCALATION_REVIEWER_MODEL=$escalationModel"
