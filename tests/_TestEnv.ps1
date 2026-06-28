# ============================================================================
# Shared test environment for the WinInit test suite (Pester 3.4 + custom stubs).
#
# Modules call provider cmdlets (Set-ItemProperty -Type DWord ...) whose dynamic
# parameters Pester 3.4 cannot mock. So instead of Pester Mock we install
# permissive *recording shadow functions* (capture everything via $args) for
# every mutating cmdlet, native exe, and side-effecting helper. Modules then
# dot-source and fully execute without touching the real system, and every call
# is recorded in $global:WinInitCalls for assertions.
#
# Dot-source this at the top of a *.Tests.ps1 file, then per test:
#   Reset-WinInitState [-Features @{...}] [-SkipApps ...] ...   # clears call log + sets config
#   . $modulePath                                               # execute the module
#   (Get-CallCount 'Set-ItemProperty' '*AllowAutoGameMode*') | Should Be 0
#
# Helpers:
#   Get-CallCount <Cmd> [<ArgWildcard>]  -> [int] matching recorded calls
#   Get-Calls     <Cmd>                  -> the recorded call objects
#   Test-Feature is the REAL function from common.ps1 (not stubbed).
# ============================================================================

$global:WinInitRoot    = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$global:WinInitModules = Join-Path $global:WinInitRoot "modules"
$global:WinInitCalls   = New-Object System.Collections.Generic.List[object]
$global:WinInitStubReturns = @{}

# --- Load the real shared library (Test-Feature, Read-TomlConfig, parsers, etc.) ---
. (Join-Path $global:WinInitRoot "lib\common.ps1")

# --- Commands that need a non-null RETURN value (callers inspect the result) ---
$global:WinInitStubReturns = @{
    'Get-AppxPackage'            = { @() }
    'Get-AppxProvisionedPackage' = { @() }
    'Get-WindowsOptionalFeature' = { [pscustomobject]@{ State = 'Disabled'; FeatureName = 'x' } }
    'Get-ScheduledTask'          = { @() }
    'Get-CimInstance'            = { @() }
    'Get-Service'                = { $null }
    'Get-Process'                = { @() }
    'Get-GitHubReleaseUrl'       = { 'https://example.invalid/tool.zip' }
    'Install-PortableApp'        = { $true }
    'Install-PortableBin'        = { $true }
    'Invoke-Npm'                 = { '' }
    'Receive-Job'                = { '' }
    'Wait-Job'                   = { $null }
    'Start-Job'                  = { [pscustomobject]@{ Id = 1; State = 'Completed' } }
    'Invoke-WebRequest'          = { [pscustomobject]@{ StatusCode = 200; Content = ''; Headers = @{} } }
    'Invoke-RestMethod'          = { @{} }
    'Invoke-Silent'              = { [pscustomobject]@{ ExitCode = 0; Output = ''; Success = $true } }
}

# --- Void recording stubs: mutating cmdlets + side-effecting common.ps1 helpers ---
$voidStubs = @(
    'Set-ItemProperty','New-Item','Remove-Item','Remove-ItemProperty','New-ItemProperty','Get-ItemProperty',
    'Stop-Service','Set-Service','Start-Service','Restart-Service',
    'Remove-AppxPackage','Remove-AppxProvisionedPackage','Add-AppxPackage',
    'Disable-WindowsOptionalFeature','Enable-WindowsOptionalFeature',
    'Disable-ScheduledTask','Enable-ScheduledTask','Register-ScheduledTask','Unregister-ScheduledTask',
    'Set-CimInstance','Invoke-CimMethod','Checkpoint-Computer','Enable-ComputerRestore',
    'Set-MpPreference','Add-MpPreference','Set-ExecutionPolicy',
    'Set-WinUserLanguageList','Set-Culture','Set-WinSystemLocale','Set-WinHomeLocation','Set-WinUILanguageOverride',
    'Copy-Item','Move-Item','Set-Content','Add-Content','Out-File','Expand-Archive','Rename-Item','Clear-Content',
    'Start-Process','New-NetFirewallRule','Stop-Process','Disable-MMAgent','Enable-MMAgent',
    'Set-SmbServerConfiguration','Add-AppxProvisionedPackage','Set-NetFirewallProfile','Set-NetConnectionProfile',
    'Set-TimeZone','Restart-Computer','Set-PhysicalDisk','Optimize-Volume',
    # side-effecting common.ps1 helpers
    'Write-Log','Write-Section','Write-ModuleStart','Start-Spinner','Stop-Spinner','Write-Blank','Write-Rule',
    'Install-App','Write-RiskLog','Set-RegistryValue',
    'Add-ToSystemPath','Set-MachineEnvVar','Set-UserEnvVar','Write-SubStep'
)

# --- Native executables the modules shell out to ---
$nativeExes = @(
    'reg','schtasks','fsutil','powercfg','takeown','icacls','bcdedit','dism','DISM',
    'winget','wsl','choco','scoop','pip','pip3','npm','npx','cargo','rustup','go','git',
    'code','cmd','label','wevtutil','sdkmanager','adb','fastboot','setx','nvcc','java',
    'cygcheck','perl','cpan','7z','ffmpeg','pwsh','gradle','mvn','dotnet'
)

# --- Install all stubs in the CURRENT (test-file script) scope, not global,
#     so Pester's own internals are unaffected. ---
function _Install-Stub {
    param([string]$Name, [bool]$HasReturn)
    $body = "`$global:WinInitCalls.Add([pscustomobject]@{ Cmd = '$Name'; Args = @(`$args) }) | Out-Null;"
    if ($HasReturn) { $body += " if (`$global:WinInitStubReturns.ContainsKey('$Name')) { & `$global:WinInitStubReturns['$Name'] }" }
    Set-Item -Path "function:script:$Name" -Value ([scriptblock]::Create($body)) -Force
}
foreach ($n in $voidStubs) { _Install-Stub -Name $n -HasReturn $false }
foreach ($n in $global:WinInitStubReturns.Keys) { _Install-Stub -Name $n -HasReturn $true }
foreach ($n in $nativeExes) {
    Set-Item -Path "function:script:$n" -Value ([scriptblock]::Create(
        "`$global:WinInitCalls.Add([pscustomobject]@{ Cmd = '$n'; Args = @(`$args) }) | Out-Null; `$global:LASTEXITCODE = 0; return ''")) -Force
}

# --- State reset (sets the $script:* vars modules + Test-Feature read) ---
function Reset-WinInitState {
    param(
        [hashtable]$Features = @{},
        [string[]]$SkipApps = @(),
        [string[]]$SkipDebloat = @(),
        [string[]]$SkipServices = @(),
        [string]$PrivacyLevel = 'strict',
        [bool]$BlockTelemetryHosts = $false
    )
    $global:WinInitCalls.Clear()
    Set-Variable -Name Config              -Scope Script -Value @{ features = $Features }
    Set-Variable -Name DryRunMode          -Scope Script -Value $false
    Set-Variable -Name AppsSkip            -Scope Script -Value $SkipApps
    Set-Variable -Name DebloatSkip         -Scope Script -Value $SkipDebloat
    Set-Variable -Name ServicesSkip        -Scope Script -Value $SkipServices
    Set-Variable -Name PrivacyLevel        -Scope Script -Value $PrivacyLevel
    Set-Variable -Name BlockTelemetryHosts -Scope Script -Value $BlockTelemetryHosts
    if (-not (Get-Variable -Name SpinnerSync -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name SpinnerSync -Scope Script -Value @{ Message=''; Progress=0; Total=0; Active=$false }
    }
    if (-not (Get-Variable -Name DryRunStats -Scope Script -ErrorAction SilentlyContinue)) {
        Set-Variable -Name DryRunStats -Scope Script -Value @{ Apps=0; Registry=0; Services=0; Features=0; Downloads=0 }
    }
}

# --- Manifest helpers (isolate one feature group at a time) ---
$global:WinInitManifest = Get-Content (Join-Path $global:WinInitRoot 'features.json') -Raw | ConvertFrom-Json
function Get-ModuleFeatureKeys {
    param([string]$Id)
    $m = $global:WinInitManifest.modules | Where-Object { $_.id -eq $Id }
    if (-not $m -or -not $m.groups) { return @() }
    @($m.groups | ForEach-Object { "$Id.$($_.key)" })
}
function Disable-AllFeatures {
    param([string]$Id)
    $h = @{}; foreach ($k in (Get-ModuleFeatureKeys $Id)) { $h[$k] = $false }; $h
}
function Enable-OnlyFeature {
    param([string]$Id, [string]$Key)
    $h = Disable-AllFeatures $Id; $h["$Id.$Key"] = $true; $h
}

# --- Assertion helpers over the recorded call log ---
function Get-Calls { param([string]$Cmd) @($global:WinInitCalls | Where-Object { $_.Cmd -eq $Cmd }) }
function Get-CallCount {
    param([string]$Cmd, [string]$ArgWildcard = '*')
    @($global:WinInitCalls | Where-Object {
        $_.Cmd -eq $Cmd -and ((($_.Args | ForEach-Object { "$_" }) -join ' ') -like $ArgWildcard)
    }).Count
}
