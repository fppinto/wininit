<#
  WinInit test runner. Runs the Pester suite in tests\ and prints a summary.
  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-Tests.ps1
          (optional)  -TestName 05*   to filter by file
#>
param([string]$Filter = "*.Tests.ps1")

Import-Module Pester -ErrorAction Stop
$ver = (Get-Module Pester).Version
Write-Host "Pester $ver" -ForegroundColor Cyan

$files = Get-ChildItem -Path $PSScriptRoot -Filter $Filter | Sort-Object Name
$result = Invoke-Pester -Path $files.FullName -PassThru

Write-Host ""
Write-Host ("Passed: {0}  Failed: {1}  Skipped: {2}  Total: {3}" -f `
    $result.PassedCount, $result.FailedCount, $result.SkippedCount, $result.TotalCount) `
    -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })

if ($result.FailedCount -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $result.TestResult | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host ("  [{0}] {1}" -f $_.Describe, $_.Name) -ForegroundColor Red
        if ($_.FailureMessage) { Write-Host ("      {0}" -f ($_.FailureMessage -split "`n")[0]) -ForegroundColor DarkGray }
    }
}
exit $result.FailedCount
