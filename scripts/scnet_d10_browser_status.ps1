param(
    [switch]$ListJobs,
    [string]$InspectJob = "",
    [string]$StopJob = "",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"

$accountsPath = Join-Path $HOME ".scnet/accounts.json"
if (-not (Test-Path -LiteralPath $accountsPath)) {
    throw "Missing credential store: $accountsPath"
}
$accounts = (Get-Content -Raw -LiteralPath $accountsPath | ConvertFrom-Json).accounts
$entry = $accounts |
    Where-Object { $_.account -eq "a094f4d10" } |
    Select-Object -First 1
if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.password)) {
    throw "No stored password for a094f4d10 in $accountsPath"
}

$root = Split-Path -Parent $PSScriptRoot
$passwordEnv = "SCNET_PASSWORD_A094F4D10"
$previousPassword = [Environment]::GetEnvironmentVariable($passwordEnv, "Process")
[Environment]::SetEnvironmentVariable($passwordEnv, [string]$entry.password, "Process")
try {
    $arguments = @(
        "scripts/scnet_browser_tasks.py",
        "--account", "a094f4d10",
        "--headless",
        "--no-prompt"
    )
    if ($ListJobs) {
        $arguments += "--list-jobs"
    }
    if (-not [string]::IsNullOrWhiteSpace($InspectJob)) {
        $arguments += @("--inspect-job", $InspectJob)
    }
    if (-not [string]::IsNullOrWhiteSpace($StopJob)) {
        $arguments += @("--stop-job", $StopJob)
    }
    if (
        -not $ListJobs -and
        [string]::IsNullOrWhiteSpace($InspectJob) -and
        [string]::IsNullOrWhiteSpace($StopJob)
    ) {
        throw "Pass -ListJobs, -InspectJob, or -StopJob."
    }
    Push-Location $root
    try {
        & $Python @arguments
        exit $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    [Environment]::SetEnvironmentVariable($passwordEnv, $previousPassword, "Process")
}
