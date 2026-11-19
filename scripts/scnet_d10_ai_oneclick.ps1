param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [Parameter(Mandatory = $true)]
    [string]$NamePrefix,

    [string]$StartupScript = "",

    [string]$StartupScriptFile = "",

    [double]$WallHours = 1.0,
    [double]$ExpectedCardHours = 0.5,
    [double]$WorstCardHours = 0.0,

    [string[]]$InputPaths = @(),
    [string[]]$OutputPaths = @(),
    [string[]]$StopConditions = @(),

    [string]$BaseConfig = "configs/scnet_d10_ai_oneclick_template.json",
    [string]$Python = "python",

    [switch]$CheckConfig,
    [switch]$DryRun,
    [switch]$Submit
)

$ErrorActionPreference = "Stop"

if ($StartupScript -and $StartupScriptFile) {
    throw "Use either -StartupScript or -StartupScriptFile, not both."
}
if ($StartupScriptFile) {
    $resolvedStartupFile = (Resolve-Path -LiteralPath $StartupScriptFile).Path
    $StartupScript = [IO.File]::ReadAllText(
        $resolvedStartupFile,
        [Text.Encoding]::UTF8
    ).Trim()
}
if (-not $StartupScript) {
    throw "Provide -StartupScript or -StartupScriptFile."
}

$root = Split-Path -Parent $PSScriptRoot
$baseConfigPath = Join-Path $root $BaseConfig
if (-not (Test-Path -LiteralPath $baseConfigPath)) {
    throw "Missing base config: $baseConfigPath"
}

if ($WorstCardHours -le 0) {
    $WorstCardHours = $WallHours
}
if ($StopConditions.Count -eq 0) {
    $StopConditions = @(
        "300 second tiny-matmul watchdog fails",
        "non-finite loss",
        "10 minutes without progress",
        "storage or input path error",
        "wall clock limit reached"
    )
}

$configText = [IO.File]::ReadAllText($baseConfigPath, [Text.Encoding]::UTF8)
$config = $configText | ConvertFrom-Json
$config.dry_run = -not $Submit
$config.max_tasks_per_run = 1
$config.tasks = @(
    [pscustomobject]@{
        id = $TaskId
        enabled = $true
        submit = $true
        status = "oneclick_generated"
        name = "${NamePrefix}_{timestamp}"
        account = "a094f4d10"
        cards = 1
        instances = 1
        wall_hours = $WallHours
        expected_card_hours = $ExpectedCardHours
        worst_card_hours = $WorstCardHours
        input_paths = @($InputPaths)
        output_paths = @($OutputPaths)
        stop_conditions = @($StopConditions)
        startup_script = $StartupScript
    }
)

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$generatedDir = Join-Path $root "artifacts/scnet_submissions"
New-Item -ItemType Directory -Force -Path $generatedDir | Out-Null
$generatedPath = Join-Path $generatedDir "$TaskId`_$stamp.json"
$rendered = $config | ConvertTo-Json -Depth 40
[IO.File]::WriteAllText(
    $generatedPath,
    ($rendered -replace "`r`n", "`n") + "`n",
    (New-Object System.Text.UTF8Encoding($false))
)

$pythonArgs = @(
    "scripts/scnet_browser_tasks.py",
    "--config", $generatedPath,
    "--task", $TaskId
)

if ($CheckConfig) {
    $pythonArgs += "--check-config"
} else {
    if ($DryRun -and $Submit) {
        throw "Use either -DryRun or -Submit, not both."
    }

    $accountsPath = Join-Path $HOME ".scnet/accounts.json"
    if (-not (Test-Path -LiteralPath $accountsPath)) {
        throw "Missing credential store: $accountsPath"
    }
    $accounts = (Get-Content -Raw -LiteralPath $accountsPath | ConvertFrom-Json).accounts
    $entry = $accounts | Where-Object { $_.account -eq "a094f4d10" } | Select-Object -First 1
    if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.password)) {
        throw "No stored password for a094f4d10 in $accountsPath"
    }

    $passwordEnv = "SCNET_PASSWORD_A094F4D10"
    $previousPassword = [Environment]::GetEnvironmentVariable($passwordEnv, "Process")
    [Environment]::SetEnvironmentVariable($passwordEnv, [string]$entry.password, "Process")
    try {
        $pythonArgs += @("--headless", "--no-prompt")
        if ($Submit) {
            $pythonArgs += "--submit"
        } else {
            $pythonArgs += "--dry-run"
        }
        & $Python @pythonArgs
        $exitCode = $LASTEXITCODE
        if ($Submit) {
            $latestRun = Get-ChildItem -LiteralPath (Join-Path $root "runs/scnet_browser_submissions") -Directory |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            $submittedId = $null
            if ($null -ne $latestRun) {
                $resultsPath = Join-Path $latestRun.FullName "results.json"
                if (Test-Path -LiteralPath $resultsPath) {
                    [string]$resultsText = ""
                    try {
                        # SCNet writes UTF-8 status text even under Windows
                        # PowerShell 5.1, whose Get-Content default is ANSI.
                        $resultsText = [IO.File]::ReadAllText(
                            $resultsPath,
                            [Text.Encoding]::UTF8
                        )
                        $results = $resultsText | ConvertFrom-Json
                        $submittedId = [string](
                            $results | Select-Object -First 1
                        ).task_id
                    } catch {
                        # Submission already happened. Never turn metadata
                        # parsing into a false failed-submission exit.
                        $match = [regex]::Match(
                            $resultsText,
                            '"task_id"\s*:\s*"([^"]+)"'
                        )
                        if ($match.Success) {
                            $submittedId = $match.Groups[1].Value
                        }
                    }
                }
            }
            $config.tasks[0].submit = $false
            $config.tasks[0].status = if ($exitCode -eq 0) {
                "submitted_by_oneclick_pending_observation"
            } else {
                "submission_attempt_failed"
            }
            if (-not [string]::IsNullOrWhiteSpace($submittedId)) {
                $config.tasks[0] | Add-Member `
                    -NotePropertyName submitted_task_id `
                    -NotePropertyValue $submittedId `
                    -Force
            }
            [IO.File]::WriteAllText(
                $generatedPath,
                (($config | ConvertTo-Json -Depth 40) -replace "`r`n", "`n") + "`n",
                (New-Object System.Text.UTF8Encoding($false))
            )
        }
        exit $exitCode
    } finally {
        [Environment]::SetEnvironmentVariable($passwordEnv, $previousPassword, "Process")
    }
}

& $Python @pythonArgs
exit $LASTEXITCODE
