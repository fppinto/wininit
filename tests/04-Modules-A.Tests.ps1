# Module group tests for the "A" batch: 01-PackageManagers, 02-Applications,
# 04-OneDriveRemoval, 05-Performance, 06-Debloat.
# Follows the 00-Sanity.Tests.ps1 pattern: sandbox-execute each module and assert
# per-group feature gating against the recorded call log.
. "$PSScriptRoot\_TestEnv.ps1"

# Some module bodies, under Set-StrictMode, hit a property read on a value a
# sandbox stub returns as $null (e.g. $r.ExitCode where Invoke-Silent is a void
# stub). That throw happens AFTER the recorded probe call we care about, so we
# dot-source through this helper which swallows the late terminating error while
# leaving the call log intact for the assertion.
function Invoke-Module {
    param([string]$Path)
    try { . $Path } catch {}
}

Describe '01-PackageManagers gates each package manager' {
    $mod = Join-Path $global:WinInitModules '01-PackageManagers.ps1'
    $id  = '01-PackageManagers'

    It 'loads clean with all features disabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # SAFE: winget/scoop/choco commands exist as sandbox stubs, so the "already
    # available" branch runs and the unsafe [System.*] installer paths are skipped.
    It 'gating: winget controls the winget check' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Checking winget*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'winget')
        . $mod
        (Get-CallCount 'Write-Log' '*Checking winget*') | Should Not Be 0
    }

    It 'gating: scoop controls the scoop check' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Checking scoop*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'scoop')
        . $mod
        (Get-CallCount 'Write-Log' '*Checking scoop*') | Should Not Be 0
    }

    It 'gating: choco controls the Chocolatey check' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Checking Chocolatey*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'choco')
        . $mod
        (Get-CallCount 'Write-Log' '*Checking Chocolatey*') | Should Not Be 0
    }
}

Describe '02-Applications loads and installs apps' {
    $mod = Join-Path $global:WinInitModules '02-Applications.ps1'

    # 02 has no feature groups; it just runs Install-App (a stubbed recorder).
    # A later $r.ExitCode read on a void-stub result throws under StrictMode,
    # which is swallowed by Invoke-Module; the Install-App calls fire first.
    It 'executes and invokes Install-App' {
        Reset-WinInitState
        Invoke-Module $mod
        (Get-CallCount 'Install-App' '*') | Should Not Be 0
    }
}

Describe '04-OneDriveRemoval gates each removal group' {
    $mod = Join-Path $global:WinInitModules '04-OneDriveRemoval.ps1'
    $id  = '04-OneDriveRemoval'

    It 'loads clean with all features disabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # SAFE: kill/uninstall path uses stubbed Get-Process / Invoke-Silent only.
    It 'gating: uninstall controls process-kill log' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Killing OneDrive*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'uninstall')
        Invoke-Module $mod
        (Get-CallCount 'Write-Log' '*Killing OneDrive*') | Should Not Be 0
    }

    # SAFE: registry-only prevention policy.
    It 'gating: prevent_reinstall controls DisableFileSyncNGSC policy' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableFileSyncNGSC*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'prevent_reinstall')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableFileSyncNGSC*') | Should Not Be 0
    }

    # SAFE: explorer integration uses reg.exe (recorded native stub).
    It 'gating: explorer_integration controls reg CLSID writes' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'reg' '*018D5C66*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'explorer_integration')
        Invoke-Module $mod
        (Get-CallCount 'reg' '*018D5C66*') | Should Not Be 0
    }

    # unsafe: cleanup body contains raw [System.Environment]::Get/SetEnvironmentVariable
    # static calls; only assert the OFF direction so we never run real env mutations.
    It 'gating: cleanup does NOT run leftover-folder removal when disabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Removing OneDrive leftover folders*') | Should Be 0
    }
}

Describe '05-Performance gates each tweak group' {
    $mod = Join-Path $global:WinInitModules '05-Performance.ps1'
    $id  = '05-Performance'

    It 'loads clean with all features disabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # SAFE: service + registry only.
    It 'gating: sysmain controls SysMain service disable' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-Service' '*SysMain*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'sysmain')
        . $mod
        (Get-CallCount 'Set-Service' '*SysMain*') | Should Not Be 0
    }

    # SAFE: registry only.
    It 'gating: gamebar controls Game Bar registry writes' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAutoGameMode*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'gamebar')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAutoGameMode*') | Should Not Be 0
    }

    # SAFE: powercfg (recorded native stub).
    It 'gating: hibernation controls powercfg /hibernate off' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'powercfg' '*hibernate*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'hibernation')
        . $mod
        (Get-CallCount 'powercfg' '*hibernate*') | Should Not Be 0
    }

    # SAFE: registry only.
    It 'gating: background_apps controls LetAppsRunInBackground policy' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LetAppsRunInBackground*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'background_apps')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LetAppsRunInBackground*') | Should Not Be 0
    }
}

Describe '06-Debloat gates groups and honors skip list' {
    $mod = Join-Path $global:WinInitModules '06-Debloat.ps1'
    $id  = '06-Debloat'

    It 'loads clean with all features disabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # SAFE: service + registry only.
    It 'gating: xbox controls Xbox service disable' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-Service' '*XblAuthManager*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'xbox')
        Invoke-Module $mod
        (Get-CallCount 'Set-Service' '*XblAuthManager*') | Should Not Be 0
    }

    # SAFE: Invoke-Silent (stubbed) only.
    It 'gating: onenote controls OneNote desktop uninstall' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Removing OneNote desktop version*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'onenote')
        . $mod
        (Get-CallCount 'Write-Log' '*Removing OneNote desktop version*') | Should Not Be 0
    }

    # SAFE: registry only.
    It 'gating: disable_store_reinstall controls SilentInstalledAppsEnabled' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SilentInstalledAppsEnabled*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'disable_store_reinstall')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SilentInstalledAppsEnabled*') | Should Not Be 0
    }

    It 'skip list: a skipped package logs "Keeping" and a non-skipped one does not' {
        # Features default to enabled, so the (unrelated) xbox block runs and throws
        # late under StrictMode; the skip-loop "Keeping" log fires first regardless.
        Reset-WinInitState -SkipDebloat @('SpotifyAB.SpotifyMusic')
        Invoke-Module $mod
        (Get-CallCount 'Write-Log' '*Keeping*SpotifyAB.SpotifyMusic*') | Should Not Be 0
        (Get-CallCount 'Write-Log' '*Keeping*Microsoft.BingNews*')     | Should Be 0
    }
}
