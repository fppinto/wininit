# Module gating tests for the second batch: 07-Privacy, 08-QualityOfLife,
# 09-Services, 10-NetworkPerformance, 11-VisualUX.
# Each group is gated by Test-Feature; we probe a recorded call unique to the
# guarded body and assert OFF => 0 / ON => >0. UNSAFE groups (raw [Environment],
# [System.*] mutation, etc.) are asserted OFF-direction only.
. "$PSScriptRoot\_TestEnv.ps1"

# ============================================================================
# 07-Privacy
# ============================================================================
Describe '07-Privacy executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '07-Privacy.ps1'
    $id  = '07-Privacy'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: wifi_sense controls AutoConnectAllowedOEM write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AutoConnectAllowedOEM*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'wifi_sense')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AutoConnectAllowedOEM*') | Should Not Be 0
    }

    It 'gating: clipboard controls AllowCrossDeviceClipboard write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowCrossDeviceClipboard*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'clipboard')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowCrossDeviceClipboard*') | Should Not Be 0
    }

    It 'gating: timeline controls EnableActivityFeed write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableActivityFeed*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'timeline')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableActivityFeed*') | Should Not Be 0
    }

    It 'gating: smartscreen controls SmartScreenEnabled write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SmartScreenEnabled*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'smartscreen')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SmartScreenEnabled*') | Should Not Be 0
    }

    It 'gating: delivery_opt controls DODownloadMode write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DODownloadMode*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'delivery_opt')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DODownloadMode*') | Should Not Be 0
    }

    It 'gating: telemetry controls DiagTrack service disable' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-Service' '*DiagTrack*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'telemetry')
        . $mod
        (Get-CallCount 'Set-Service' '*DiagTrack*') | Should Not Be 0
    }

    It 'gating: advertising controls AllowAdvertisingInfo write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAdvertisingInfo*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'advertising')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowAdvertisingInfo*') | Should Not Be 0
    }

    It 'gating: location controls DisableLocationScripting write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableLocationScripting*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'location')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableLocationScripting*') | Should Not Be 0
    }

    It 'gating: camera_mic controls webcam ConsentStore write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*ConsentStore\webcam*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'camera_mic')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*ConsentStore\webcam*') | Should Not Be 0
    }

    It 'gating: inking controls RestrictImplicitInkCollection write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*RestrictImplicitInkCollection*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'inking')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*RestrictImplicitInkCollection*') | Should Not Be 0
    }

    It 'gating: tailored controls DisableTailoredExperiencesWithDiagnosticData write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableTailoredExperiencesWithDiagnosticData*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'tailored')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableTailoredExperiencesWithDiagnosticData*') | Should Not Be 0
    }

    It 'gating: wer controls WerSvc service disable' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-Service' '*WerSvc*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'wer')
        . $mod
        (Get-CallCount 'Set-Service' '*WerSvc*') | Should Not Be 0
    }

    It 'gating: cortana_search controls AllowCortana write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowCortana*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'cortana_search')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowCortana*') | Should Not Be 0
    }

    It 'gating: copilot_ai controls TurnOffWindowsCopilot write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*TurnOffWindowsCopilot*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'copilot_ai')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*TurnOffWindowsCopilot*') | Should Not Be 0
    }

    It 'gating: feedback controls NumberOfSIUFInPeriod write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*NumberOfSIUFInPeriod*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'feedback')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*NumberOfSIUFInPeriod*') | Should Not Be 0
    }

    It 'gating: telemetry_hosts defaults OFF - hosts file is not modified' {
        # telemetry_hosts default in features.json is false AND it is additionally
        # gated by $script:BlockTelemetryHosts (Reset sets it $false). With all
        # features disabled the Block-TelemetryHosts body must not run.
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Add-Content' '*WinInit Telemetry Block*') | Should Be 0
    }
}

# ============================================================================
# 08-QualityOfLife
# ============================================================================
Describe '08-QualityOfLife executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '08-QualityOfLife.ps1'
    $id  = '08-QualityOfLife'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: numlock controls InitialKeyboardIndicators write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*InitialKeyboardIndicators*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'numlock')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*InitialKeyboardIndicators*') | Should Not Be 0
    }

    It 'gating: sticky_keys controls StickyKeys Flags write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*Accessibility\StickyKeys*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'sticky_keys')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*Accessibility\StickyKeys*') | Should Not Be 0
    }

    It 'gating: default_terminal controls DelegationConsole write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DelegationConsole*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'default_terminal')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DelegationConsole*') | Should Not Be 0
    }

    It 'gating: terminal_context controls "Open in Terminal" log message' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' "*Open in Terminal*always available*") | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'terminal_context')
        . $mod
        (Get-CallCount 'Write-Log' "*Open in Terminal*always available*") | Should Not Be 0
    }

    It 'gating: locale OFF => no LocaleName regional write' {
        # unsafe: guarded body calls [System.Environment]::SetEnvironmentVariable
        # (raw env mutation) - never enable in tests; OFF-direction only.
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LocaleName*') | Should Be 0
    }

    It 'gating: long_paths controls LongPathsEnabled write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LongPathsEnabled*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'long_paths')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LongPathsEnabled*') | Should Not Be 0
    }

    It 'gating: exec_policy controls Set-ExecutionPolicy Unrestricted' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ExecutionPolicy' '*Unrestricted*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'exec_policy')
        . $mod
        (Get-CallCount 'Set-ExecutionPolicy' '*Unrestricted*') | Should Not Be 0
    }
}

# ============================================================================
# 09-Services
# ============================================================================
Describe '09-Services executes, gates, and honors service skips' {
    $mod = Join-Path $global:WinInitModules '09-Services.ps1'
    $id  = '09-Services'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: ink_workspace controls AllowWindowsInkWorkspace write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowWindowsInkWorkspace*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'ink_workspace')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*AllowWindowsInkWorkspace*') | Should Not Be 0
    }

    It 'skip: bulk SysMain is kept when skipped, disabled otherwise' {
        Reset-WinInitState -SkipServices @('SysMain')
        . $mod
        (Get-CallCount 'Set-Service' '*SysMain*') | Should Be 0
        (Get-CallCount 'Write-Log' '*Keeping service*SysMain*') | Should Not Be 0
        # No skip: SysMain gets disabled in bulk
        Reset-WinInitState
        . $mod
        (Get-CallCount 'Set-Service' '*SysMain*') | Should Not Be 0
    }

    It 'skip: individual Fax service is kept when skipped' {
        Reset-WinInitState -SkipServices @('Fax')
        . $mod
        (Get-CallCount 'Write-Log' '*Keeping service*Fax*') | Should Not Be 0
    }
}

# ============================================================================
# 10-NetworkPerformance
# ============================================================================
Describe '10-NetworkPerformance executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '10-NetworkPerformance.ps1'
    $id  = '10-NetworkPerformance'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: nagle controls TcpAckFrequency write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*TcpAckFrequency*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'nagle')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*TcpAckFrequency*') | Should Not Be 0
    }

    It 'gating: paging_executive controls DisablePagingExecutive write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisablePagingExecutive*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'paging_executive')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisablePagingExecutive*') | Should Not Be 0
    }

    It 'gating: ssd controls fsutil disablelastaccess call' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'fsutil' '*disablelastaccess*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'ssd')
        . $mod
        (Get-CallCount 'fsutil' '*disablelastaccess*') | Should Not Be 0
    }

    It 'gating: memory_compression controls Disable-MMAgent call' {
        # Disable-MMAgent is stubbed -> SAFE to enable.
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Disable-MMAgent' '*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'memory_compression')
        . $mod
        (Get-CallCount 'Disable-MMAgent' '*') | Should Not Be 0
    }

    It 'gating: standby_memory controls LargeSystemCache write' {
        # Register-ScheduledTask is stubbed -> SAFE to enable.
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LargeSystemCache*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'standby_memory')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*LargeSystemCache*') | Should Not Be 0
    }

    It 'gating: irpstack controls IRPStackSize write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*IRPStackSize*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'irpstack')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*IRPStackSize*') | Should Not Be 0
    }
}

# ============================================================================
# 11-VisualUX
# ============================================================================
Describe '11-VisualUX executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '11-VisualUX.ps1'
    $id  = '11-VisualUX'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: transparency controls EnableTransparency write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableTransparency*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'transparency')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableTransparency*') | Should Not Be 0
    }

    It 'gating: aero_shake controls DisallowShaking write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisallowShaking*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'aero_shake')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisallowShaking*') | Should Not Be 0
    }

    It 'gating: start_menu controls Start_IrisRecommendations write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*Start_IrisRecommendations*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'start_menu')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*Start_IrisRecommendations*') | Should Not Be 0
    }

    It 'gating: desktop_icons controls HideIcons write' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*HideIcons*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'desktop_icons')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*HideIcons*') | Should Not Be 0
    }

    It 'gating: thispc_folders controls "Removing 3D Objects" log message' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Write-Log' '*Removing 3D Objects*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'thispc_folders')
        . $mod
        (Get-CallCount 'Write-Log' '*Removing 3D Objects*') | Should Not Be 0
    }
}
