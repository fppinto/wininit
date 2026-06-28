# ============================================================================
# 02-UIConfig.Tests.ps1
# Tests the config read/write logic and window construction of WinInit-UI.ps1.
#
# Does NOT use _TestEnv.ps1: that harness stubs file-mutating cmdlets, which
# would block the real Set-Content that Save-WinInitConfig performs. Instead we
# load the UI's helper functions in NOGUI mode (it returns before building the
# window) and exercise Save/Read against unique temp copies of config.toml.
#
# Note: WinInit-UI.ps1 must be dot-sourced directly inside each Describe block
# (not via a wrapper function) so its helper functions land in the Describe
# scope where Pester's It blocks can see them. Save-WinInitConfig /
# Read-WinInitConfig operate on the script-scoped $ConfigFile, which is set from
# the -ConfigFile parameter at dot-source time.
# ============================================================================

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$UiScript   = Join-Path $RepoRoot 'WinInit-UI.ps1'
$RealConfig = Join-Path $RepoRoot 'config.toml'
$CommonLib  = Join-Path $RepoRoot 'lib\common.ps1'

# Track temp files so we can clean them all up at the end.
$script:TempFiles = New-Object System.Collections.Generic.List[string]

function New-TempConfig {
    # Copy the real config.toml to a unique temp path and return that path.
    param([string]$Src, [System.Collections.Generic.List[string]]$Sink)
    $p = Join-Path $env:TEMP ("wininit-uitest-{0}.toml" -f ([guid]::NewGuid().ToString('N')))
    Copy-Item -Path $Src -Destination $p -Force
    $Sink.Add($p)
    return $p
}

# --------------------------------------------------------------------------
# Pure helpers: parsing/formatting (no config file needed)
# --------------------------------------------------------------------------
Describe 'WinInit-UI parsing helpers' {
    $cfg = New-TempConfig $RealConfig $script:TempFiles
    $env:WININIT_UI_NOGUI = '1'
    . $UiScript -ConfigFile $cfg

    Context 'Split-TomlComment' {
        It 'splits trailing comment from value' {
            $r = Split-TomlComment 'foo = "bar"  # c'
            $r[0] | Should Be 'foo = "bar"'
            $r[1] | Should Be '# c'
        }
        It 'does not treat a # inside quotes as a comment' {
            $r = Split-TomlComment 'k = "a#b"'
            $r[0] | Should Be 'k = "a#b"'
            $r[1] | Should Be ''
        }
        It 'returns empty comment when there is none' {
            $r = Split-TomlComment 'profile = "developer"'
            $r[0] | Should Be 'profile = "developer"'
            $r[1] | Should Be ''
        }
    }

    Context 'Parse-TomlArray' {
        It 'parses a two-item array' {
            $r = @(Parse-TomlArray '["A", "B"]')
            $r.Count | Should Be 2
            $r[0] | Should Be 'A'
            $r[1] | Should Be 'B'
        }
        It 'parses an empty array to zero items' {
            $r = @(Parse-TomlArray '[]')
            $r.Count | Should Be 0
        }
        It 'preserves wildcard values' {
            $r = @(Parse-TomlArray '["*Netflix*"]')
            $r.Count | Should Be 1
            $r[0] | Should Be '*Netflix*'
        }
    }

    Context 'Format-TomlArray' {
        It 'formats an empty array as []' {
            (Format-TomlArray @()) | Should Be '[]'
        }
        It 'formats a populated array with quotes and commas' {
            (Format-TomlArray @('A','B')) | Should Be '["A", "B"]'
        }
    }
}

# --------------------------------------------------------------------------
# Save / Read round-trip
# --------------------------------------------------------------------------
Describe 'Save/Read round-trip' {
    $cfg = New-TempConfig $RealConfig $script:TempFiles
    $env:WININIT_UI_NOGUI = '1'
    . $UiScript -ConfigFile $cfg

    $modState = @{
        '01-PackageManagers' = $false
        '04-OneDriveRemoval' = $false
    }
    $features = @{
        '05-Performance.gamebar'  = $false
        '07-Privacy.telemetry'    = $false
    }
    $skipApps     = @('Google.Chrome')
    $skipDebloat  = @('SpotifyAB.SpotifyMusic','*Netflix*')
    $skipServices = @('SysMain')

    Save-WinInitConfig -ModuleState $modState -Profile 'security' -DryRun $true -Privacy 'paranoid' `
        -Features $features -SkipApps $skipApps -SkipDebloat $skipDebloat -SkipServices $skipServices

    $r = Read-WinInitConfig

    It 'round-trips profile' { $r.profile | Should Be 'security' }
    It 'round-trips dry_run' { $r.dry_run | Should Be $true }
    It 'round-trips privacy level' { $r.privacy | Should Be 'paranoid' }

    It 'round-trips disabled modules' {
        $r.modules['01-PackageManagers'] | Should Be $false
        $r.modules['04-OneDriveRemoval'] | Should Be $false
    }
    It 'leaves untouched modules enabled' {
        $r.modules['05-Performance'] | Should Be $true
    }

    It 'round-trips disabled feature keys' {
        $r.features['05-Performance.gamebar'] | Should Be $false
        $r.features['07-Privacy.telemetry']   | Should Be $false
    }
    It 'leaves unset features enabled (regenerated default true)' {
        $r.features['05-Performance.sysmain'] | Should Be $true
    }

    It 'round-trips skip apps' {
        @($r.skip.apps).Count | Should Be 1
        $r.skip.apps[0] | Should Be 'Google.Chrome'
    }
    It 'round-trips skip debloat (incl. wildcard)' {
        @($r.skip.debloat).Count | Should Be 2
        ($r.skip.debloat -contains 'SpotifyAB.SpotifyMusic') | Should Be $true
        ($r.skip.debloat -contains '*Netflix*') | Should Be $true
    }
    It 'round-trips skip services' {
        @($r.skip.services).Count | Should Be 1
        $r.skip.services[0] | Should Be 'SysMain'
    }
}

# --------------------------------------------------------------------------
# Preservation of pre-existing sections / comments
# --------------------------------------------------------------------------
Describe 'Preservation of existing config content' {
    $cfg = New-TempConfig $RealConfig $script:TempFiles
    $env:WININIT_UI_NOGUI = '1'
    . $UiScript -ConfigFile $cfg

    Save-WinInitConfig -ModuleState @{} -Profile 'developer' -DryRun $false -Privacy 'strict' `
        -Features @{} -SkipApps @() -SkipDebloat @() -SkipServices @()

    $raw = Get-Content $cfg -Raw

    It 'keeps the [apps] section' { $raw | Should Match '(?m)^\[apps\]' }
    It 'keeps the [updates] section' { $raw | Should Match '(?m)^\[updates\]' }
    It 'preserves the inline profile comment' { $raw | Should Match 'developer \| security' }
    It 'preserves update_interval_days' { $raw | Should Match 'update_interval_days = 7' }
}

# --------------------------------------------------------------------------
# [features] regeneration: exactly one section, last write wins
# --------------------------------------------------------------------------
Describe '[features] regeneration' {
    $cfg = New-TempConfig $RealConfig $script:TempFiles
    $env:WININIT_UI_NOGUI = '1'
    . $UiScript -ConfigFile $cfg

    Save-WinInitConfig -ModuleState @{} -Profile 'developer' -DryRun $false -Privacy 'strict' `
        -Features @{ '05-Performance.gamebar' = $true } -SkipApps @() -SkipDebloat @() -SkipServices @()
    Save-WinInitConfig -ModuleState @{} -Profile 'developer' -DryRun $false -Privacy 'strict' `
        -Features @{ '05-Performance.gamebar' = $false } -SkipApps @() -SkipDebloat @() -SkipServices @()

    It 'contains exactly one [features] section after a second save' {
        $count = @(Get-Content $cfg | Where-Object { $_.Trim() -eq '[features]' }).Count
        $count | Should Be 1
    }
    It 'uses the second save value (false wins)' {
        $r = Read-WinInitConfig
        $r.features['05-Performance.gamebar'] | Should Be $false
    }
}

# --------------------------------------------------------------------------
# Engine consistency: the orchestrator engine reads what the UI wrote
# --------------------------------------------------------------------------
Describe 'Engine consistency with UI-written config' {
    $cfg = New-TempConfig $RealConfig $script:TempFiles
    $env:WININIT_UI_NOGUI = '1'
    . $UiScript -ConfigFile $cfg

    Save-WinInitConfig -ModuleState @{} -Profile 'developer' -DryRun $false -Privacy 'strict' `
        -Features @{ '05-Performance.gamebar' = $false } `
        -SkipApps @() -SkipDebloat @('*Netflix*') -SkipServices @('SysMain')

    # Load the real engine helpers and point its $script:Config at our temp file.
    . $CommonLib
    $script:Config = Read-TomlConfig $cfg

    It 'engine Test-Feature returns false for a UI-disabled feature' {
        (Test-Feature '05-Performance.gamebar') | Should Be $false
    }
    It 'engine Test-Feature returns true (default) for an unset feature' {
        (Test-Feature '05-Performance.sysmain') | Should Be $true
    }
    It 'engine sees the debloat skip array the UI wrote' {
        ($script:Config['debloat']['skip'] -contains '*Netflix*') | Should Be $true
    }
    It 'engine sees the services skip array the UI wrote' {
        ($script:Config['services']['skip'] -contains 'SysMain') | Should Be $true
    }
}

# --------------------------------------------------------------------------
# Window construction regression (variable-collision bug)
# --------------------------------------------------------------------------
Describe 'Window construction (BUILDONLY smoke test)' {
    It 'builds the window and constructs all controls in a fresh STA process' {
        # Clear NOGUI (inherited from this process) so the child actually builds
        # the window, and set BUILDONLY so it returns before ShowDialog.
        $code = "`$env:WININIT_UI_NOGUI=`$null; `$env:WININIT_UI_BUILDONLY='1'; . '$UiScript'; if (`$script:MasterChecks.Count -eq 18 -and `$script:Groups.Count -gt 100 -and `$script:Items.Count -gt 100) { 'OK' } else { 'BAD' }"
        $out = & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -Command $code 2>&1
        ($out -join "`n") | Should Match 'OK'
    }
}

# --------------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------------
Describe 'Cleanup temp files' {
    It 'removes all temp config files' {
        foreach ($f in $script:TempFiles) {
            if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
        }
        $remaining = @($script:TempFiles | Where-Object { Test-Path $_ }).Count
        $remaining | Should Be 0
    }
}
