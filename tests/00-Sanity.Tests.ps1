# Sanity test: validates the shared harness can sandbox-execute modules and that
# Test-Feature gating is observable. This is the TEMPLATE other module tests follow.
. "$PSScriptRoot\_TestEnv.ps1"

Describe 'Harness: Test-Feature reads script Config' {
    It 'returns true by default and false when disabled' {
        Reset-WinInitState -Features @{ '05-Performance.gamebar' = $false }
        (Test-Feature '05-Performance.sysmain') | Should Be $true
        (Test-Feature '05-Performance.gamebar') | Should Be $false
    }
}

Describe '05-Performance executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '05-Performance.ps1'

    It 'dot-sources with no terminating error (all features on)' {
        Reset-WinInitState
        { . $mod } | Should Not Throw
    }

    It 'does NOT touch Game Bar registry when gamebar is disabled' {
        Reset-WinInitState -Features @{ '05-Performance.gamebar' = $false }
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAutoGameMode*') | Should Be 0
    }

    It 'DOES touch Game Bar registry when gamebar is enabled' {
        Reset-WinInitState -Features @{ '05-Performance.gamebar' = $true }
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAutoGameMode*') | Should Not Be 0
    }
}

Describe '03-DesktopEnvironment (large) executes under sandbox' {
    $mod = Join-Path $global:WinInitModules '03-DesktopEnvironment.ps1'
    $id  = '03-DesktopEnvironment'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: darkmode (registry-only group) controls AppsUseLightTheme writes' {
        # OFF (all disabled) => no write
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AppsUseLightTheme*') | Should Be 0
        # ON (only darkmode enabled) => write happens
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'darkmode')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AppsUseLightTheme*') | Should Not Be 0
    }

    It 'gating: telemetry OFF => no takeown on CompatTelRunner' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'takeown' '*CompatTelRunner*') | Should Be 0
    }
}
