<#
.SYNOPSIS
Runs the Save/Load test suites headless and fails like the CI Godot job does.

.DESCRIPTION
A suite fails when Godot exits non-zero, prints "SCRIPT ERROR:" or "ERROR:" (except the
known debugger shutdown line CI also ignores), or exceeds the time limit. The tests write
only under user://test_saves/ and check that the real save files did not change.

.EXAMPLE
./test/run_save_load_tests.ps1 -Godot 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe'

.EXAMPLE
$env:GODOT = 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe'; ./test/run_save_load_tests.ps1 -Import
#>
param(
    [string]$Godot = $env:GODOT,
    # Import twice first, as a clean checkout needs (see docs/project/testing.md).
    [switch]$Import,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
if (-not $Godot -or -not (Test-Path $Godot)) {
    throw 'Pass -Godot or set $env:GODOT to the Godot 4.7.2 console executable.'
}
$project = Split-Path -Parent $PSScriptRoot
$tests = @('res://test/save_load_flow_test.gd', 'res://test/save_load_edge_test.gd')
$errorPattern = 'SCRIPT ERROR:|ERROR:'
$ignoredError = '^ERROR: Plugin is not attached to debugger\.$'
$logDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'foxy_save_load_tests'
New-Item -ItemType Directory -Force $logDirectory | Out-Null

function Invoke-GodotStep([string]$Name, [string[]]$Arguments) {
    $stdout = Join-Path $logDirectory "$Name.out.log"
    $stderr = Join-Path $logDirectory "$Name.err.log"
    $allArguments = @('--headless', '--path', "`"$project`"") + $Arguments
    $process = Start-Process -FilePath $Godot -ArgumentList $allArguments -NoNewWindow `
        -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Windows PowerShell only reports ExitCode if the handle is opened while it runs.
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        throw "$Name timed out after $TimeoutSeconds s. Logs: $stdout"
    }
    $lines = @(Get-Content $stdout) + @(Get-Content $stderr)
    $lines | Where-Object { $_ -match '^(PASS|FAIL) |failures' } | ForEach-Object { $_ }
    $errors = $lines | Where-Object { $_ -match $errorPattern -and $_ -notmatch $ignoredError }
    if ($process.ExitCode -ne 0 -or $errors) {
        $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "$Name failed (exit $($process.ExitCode)). Logs: $stdout"
    }
}

if ($Import) {
    1..2 | ForEach-Object { Invoke-GodotStep "import_$_" @('--editor', '--import', '--quit') }
}
foreach ($test in $tests) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($test)
    Write-Host "Running $test"
    Invoke-GodotStep $name @('--script', $test)
}
Write-Host 'Save/Load tests passed.' -ForegroundColor Green
