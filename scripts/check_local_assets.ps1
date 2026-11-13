$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Check-Equal {
    param(
        [string]$Name,
        [object]$Actual,
        [object]$Expected
    )

    if ($Actual -eq $Expected) {
        Write-Host "PASS $Name = $Actual"
    }
    else {
        $message = "FAIL $Name = $Actual, expected $Expected"
        Write-Host $message
        $failures.Add($message)
    }
}

$repo = Join-Path $root "vendor\Voice-Privacy-Challenge-2024"
$head = (git -C $repo rev-parse HEAD).Trim()
Check-Equal "VPC commit" $head "7c80e86d3a4d58b81a2f3bdc01a3508c37018be4"

$dataZip = Join-Path $root "vendor\vpc2024\data.zip"
$dataInfo = Get-Item -LiteralPath $dataZip
Check-Equal "data.zip bytes" $dataInfo.Length 10119867
$dataHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dataZip).Hash
Check-Equal "data.zip SHA256" $dataHash "60C71B3F2F8FF8D7A35237CDA7D92FB2F6F5F1F2CB5C89CB91FC511A699860F7"

$toolsZip = Join-Path $root "vendor\vpc2024\data_test_tools.zip"
$toolsInfo = Get-Item -LiteralPath $toolsZip
Check-Equal "data_test_tools.zip bytes" $toolsInfo.Length 120506
$toolsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $toolsZip).Hash
Check-Equal "data_test_tools.zip SHA256" $toolsHash "6270EBA200A8986EEE96B7E4CA9828BE3000678073985C15273A5B34B3D4F304"

$dataRoot = Join-Path $root "vendor\vpc2024\data_unzipped\data"
$checks = @(
    @("libri_test_enrolls", "wav.scp", 438),
    @("libri_test_trials_f", "wav.scp", 734),
    @("libri_test_trials_f", "trials", 11744),
    @("libri_test_trials_m", "wav.scp", 762),
    @("libri_test_trials_m", "trials", 9906)
)

foreach ($check in $checks) {
    $path = Join-Path $dataRoot (Join-Path $check[0] $check[1])
    $count = (Get-Content -LiteralPath $path).Count
    Check-Equal "$($check[0])/$($check[1]) lines" $count $check[2]
}

$asvZip = Join-Path $root "vendor\vpc2024\asv_orig.zip"
if (Test-Path -LiteralPath $asvZip) {
    $asvBytes = (Get-Item -LiteralPath $asvZip).Length
    Check-Equal "asv_orig.zip bytes" $asvBytes 70464879
    $asvHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $asvZip).Hash
    Check-Equal "asv_orig.zip SHA256" $asvHash "F0ABF60E569CB60A6F945A1A0A48E1A7D1AABE973F956DC3A872A3E686A7BF5E"
}
else {
    Write-Host "PENDING asv_orig.zip is not present"
}

$asrZip = Join-Path $root "vendor\vpc2024\asr.zip"
if (Test-Path -LiteralPath $asrZip) {
    $asrBytes = (Get-Item -LiteralPath $asrZip).Length
    Check-Equal "asr.zip bytes" $asrBytes 752987942
}
else {
    Write-Host "PENDING asr.zip is not present"
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "$($failures.Count) check(s) failed."
    exit 1
}

Write-Host ""
Write-Host "All available local asset checks passed."
