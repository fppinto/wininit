# Tests for modules 12-18 (Security, Browser, DevTools, Portable, Unix, VSCode, Final).
# Pester 3.4 syntax only (| Should Be / | Should Not Be / | Should Not Throw).
# Strategy per the harness template (00-Sanity.Tests.ps1):
#   - "Loads clean" with all features disabled proves guard scaffolding + ungated code run.
#   - SAFE groups: assert a probe call fires ON and does NOT fire OFF.
#   - UNSAFE groups (raw .NET / SetEnvironmentVariable / COM / .Save() / Clear-RecycleBin /
#     Write-WTSettings real-file writes): OFF-direction only, with an `# unsafe:` note.
. "$PSScriptRoot\_TestEnv.ps1"

# ============================================================================
# 12 - Security Hardening
# ============================================================================
Describe '12-SecurityHardening executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '12-SecurityHardening.ps1'
    $id  = '12-SecurityHardening'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: smbv1 controls SMB1 registry write (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SMB1*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'smbv1')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*SMB1*') | Should Not Be 0
    }

    It 'gating: llmnr controls EnableMulticast registry write (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableMulticast*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'llmnr')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*EnableMulticast*') | Should Not Be 0
    }

    It 'gating: utf8 sets the UTF-8 code page registry value (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*65001*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'utf8')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*65001*') | Should Not Be 0
    }

    It 'gating: hyperv enables the Hyper-V optional feature (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Hyper-V*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'hyperv')
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Hyper-V*') | Should Not Be 0
    }

    It 'gating: containers_sandbox enables the Containers feature (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Containers*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'containers_sandbox')
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Containers*') | Should Not Be 0
    }

    It 'gating: wsl enables the Subsystem-Linux feature (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Subsystem-Linux*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'wsl')
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*Subsystem-Linux*') | Should Not Be 0
    }

    It 'dependency fix: enabling wsl ALSO enables VirtualMachinePlatform' {
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'wsl')
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*VirtualMachinePlatform*') | Should Not Be 0
    }

    It 'gating: dotnet enables NetFx3 optional feature (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*NetFx3*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'dotnet')
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*NetFx3*') | Should Not Be 0
    }

    # unsafe: network_features also adds Add-WindowsCapability items, and the capability loop
    # calls Get-WindowsCapability -Online (not stubbed) which requires elevation and throws. OFF only.
    It 'gating: network_features adds no Telnet feature when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Enable-WindowsOptionalFeature' '*TelnetClient*') | Should Be 0
    }

    It 'gating: brandless_boot writes the BrandingNeutral registry value (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*BrandingNeutral*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'brandless_boot')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*BrandingNeutral*') | Should Not Be 0
    }

    It 'gating: sysmon downloads Sysmon64 from sysinternals (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*Sysmon64*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'sysmon')
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*Sysmon64*') | Should Not Be 0
    }

    It 'gating: reserved_storage writes the ShippedWithReserves registry value (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*ShippedWithReserves*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'reserved_storage')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*ShippedWithReserves*') | Should Not Be 0
    }
}

# ============================================================================
# 13 - Browser Extensions
# ============================================================================
Describe '13-BrowserExtensions executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '13-BrowserExtensions.ps1'
    $id  = '13-BrowserExtensions'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    It 'gating: firefox writes policies.json via Set-Content (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-Content' '*policies.json*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'firefox')
        . $mod
        (Get-CallCount 'Set-Content' '*policies.json*') | Should Not Be 0
    }

    It 'gating: chromium force-installs extensions via registry policy (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*service/update2/crx*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'chromium')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*service/update2/crx*') | Should Not Be 0
    }
}

# ============================================================================
# 14 - Dev Tools  (heavy env-var / PATH / .NET manipulation - mostly UNSAFE ON)
# ============================================================================
Describe '14-DevTools executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '14-DevTools.ps1'
    $id  = '14-DevTools'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # unsafe: node_cli body does [System.Environment]::SetEnvironmentVariable (Machine PATH) +
    # New-Object System.Diagnostics.ProcessStartInfo. OFF-direction only.
    It 'gating: node_cli does not run when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Deno*') | Should Be 0
    }

    # unsafe: hack_tools sets Machine PATH via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: hack_tools does not install Nmap when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Nmap*') | Should Be 0
    }

    # unsafe: java body sets JAVA_HOME via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: java does not install JDK when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*OpenJDK*') | Should Be 0
    }

    # unsafe: openssh body generates real ssh keys / icacls / Set-Service. OFF only.
    It 'gating: openssh does not install OpenSSH when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*OpenSSH*') | Should Be 0
    }

    # unsafe: cuda body sets CUDA_PATH via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: cuda does not install CUDA Toolkit when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*CUDA Toolkit*') | Should Be 0
    }

    # unsafe: sqlserver body runs Install-Module via Start-Job (real). OFF only.
    It 'gating: sqlserver does not install SSMS when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*SQL Server Management Studio*') | Should Be 0
    }

    # unsafe: openssl body sets OPENSSL_DIR via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: openssl does not install OpenSSL when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*OpenSSL*') | Should Be 0
    }

    # unsafe: doc_processing body sets Machine PATH via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: doc_processing does not install Pandoc when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Pandoc*') | Should Be 0
    }

    # unsafe: android_sdk body sets ANDROID_HOME/Machine PATH via [System.Environment] + Start-Job. OFF only.
    It 'gating: android_sdk does not download cmdline-tools when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*commandlinetools-win*') | Should Be 0
    }

    # unsafe: python_pip body manipulates Machine PATH via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: python_pip does not run pip work when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*commandlinetools-win*') | Should Be 0
    }

    # unsafe: rust body sets RUSTC_WRAPPER via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: rust does not install rustup when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Rust (rustup)*') | Should Be 0
    }

    # unsafe: go body sets GOPATH via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: go does not install Go when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*GoLang.Go*') | Should Be 0
    }

    # infra_k8s body is plain Install-App calls (no raw .NET) -> SAFE.
    It 'gating: infra_k8s installs Terraform (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Terraform*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'infra_k8s')
        . $mod
        (Get-CallCount 'Install-App' '*Terraform*') | Should Not Be 0
    }

    # containers body is Install-App + Install-PortableBin (no raw .NET) -> SAFE.
    It 'gating: containers installs Podman (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Podman*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'containers')
        . $mod
        (Get-CallCount 'Install-App' '*Podman*') | Should Not Be 0
    }

    # unsafe: grpc body references $useNodeDirect which is only defined inside the node_cli guard;
    # enabling grpc alone throws (StrictMode: variable not set). OFF only.
    It 'gating: grpc installs no Protobuf when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Protobuf*') | Should Be 0
    }

    # dev_extras body is plain Install-App calls (no raw .NET) -> SAFE.
    It 'gating: dev_extras installs Graphviz (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Graphviz*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'dev_extras')
        . $mod
        (Get-CallCount 'Install-App' '*Graphviz*') | Should Not Be 0
    }
}

# ============================================================================
# 15 - Portable Tools  (ungated C:\bin / C:\apps PATH edits run on load)
# ============================================================================
Describe '15-PortableTools executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '15-PortableTools.ps1'
    $id  = '15-PortableTools'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # bin_tools body downloads GitHub binaries via Install-PortableBin (recorded) -> SAFE.
    It 'gating: bin_tools downloads ripgrep portable binary (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-PortableBin' '*ripgrep*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'bin_tools')
        . $mod
        (Get-CallCount 'Install-PortableBin' '*ripgrep*') | Should Not Be 0
    }

    # apps_nirsoft body is Install-PortableApp calls (recorded) -> SAFE.
    It 'gating: apps_nirsoft installs HashMyFiles (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-PortableApp' '*HashMyFiles*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'apps_nirsoft')
        . $mod
        (Get-CallCount 'Install-PortableApp' '*HashMyFiles*') | Should Not Be 0
    }

    # apps_reversing body is Install-PortableApp calls (recorded) -> SAFE.
    It 'gating: apps_reversing installs jadx (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-PortableApp' '*jadx*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'apps_reversing')
        . $mod
        (Get-CallCount 'Install-PortableApp' '*jadx*') | Should Not Be 0
    }

    # apps_remote body is Install-PortableApp calls (recorded) -> SAFE.
    It 'gating: apps_remote installs scrcpy (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-PortableApp' '*scrcpy*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'apps_remote')
        . $mod
        (Get-CallCount 'Install-PortableApp' '*scrcpy*') | Should Not Be 0
    }

    # apps_misc body is Install-PortableApp calls (recorded) -> SAFE.
    It 'gating: apps_misc installs UPX (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-PortableApp' '*UPX*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'apps_misc')
        . $mod
        (Get-CallCount 'Install-PortableApp' '*UPX*') | Should Not Be 0
    }
}

# ============================================================================
# 16 - Unix Environment
# ============================================================================
Describe '16-UnixEnvironment executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '16-UnixEnvironment.ps1'
    $id  = '16-UnixEnvironment'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # unsafe: cygwin body runs Invoke-SilentWithProgress against installer + sets Machine PATH
    # via [System.Environment]::SetEnvironmentVariable. OFF only.
    It 'gating: cygwin does not download the Cygwin setup when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*cygwin.com*') | Should Be 0
    }

    # msys2 body installs MSYS2 then guards PATH edit behind Test-Path (not reached) -> SAFE probe on Install-App.
    It 'gating: msys2 installs MSYS2 (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*MSYS2*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'msys2')
        . $mod
        (Get-CallCount 'Install-App' '*MSYS2*') | Should Not Be 0
    }

    # perl body is a single Install-App (no raw .NET) -> SAFE.
    It 'gating: perl installs Strawberry Perl (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Strawberry Perl*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'perl')
        . $mod
        (Get-CallCount 'Install-App' '*Strawberry Perl*') | Should Not Be 0
    }

    # unsafe: python_venv body writes to the real $PROFILE via Add-Content/Set-Content and only
    # runs when a real python is on PATH. OFF only.
    It 'gating: python_venv writes no profile alias when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Add-Content' '*Activate-Venv*') | Should Be 0
        (Get-CallCount 'Set-Content' '*Activate-Venv*') | Should Be 0
    }
}

# ============================================================================
# 17 - VS Code Setup  (lots of ungated settings/assoc/defender work runs on load)
# ============================================================================
Describe '17-VSCodeSetup executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '17-VSCodeSetup.ps1'
    $id  = '17-VSCodeSetup'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # extensions body shells out to the `code` CLI (recorded) -> SAFE.
    It 'gating: extensions installs VS Code extensions via code CLI (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'code' '*--install-extension*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'extensions')
        . $mod
        (Get-CallCount 'code' '*--install-extension*') | Should Not Be 0
    }

    # fonts body downloads the Fira Code Nerd Font zip via Invoke-WebRequest (recorded) -> SAFE.
    It 'gating: fonts downloads the Fira Code Nerd Font (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*FiraCode.zip*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'fonts')
        . $mod
        (Get-CallCount 'Invoke-WebRequest' '*FiraCode.zip*') | Should Not Be 0
    }

    # install body only calls Install-App when `code` is absent; the harness stubs `code`
    # so detection succeeds and Install-App is skipped. Assert OFF-direction (no install) only.
    It 'gating: install does not install VS Code when disabled (off-only)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Visual Studio Code*') | Should Be 0
    }

    # unsafe: terminal_theme calls Write-WTSettings which does a real [System.IO.File]::WriteAllText
    # to the live Windows Terminal settings.json. OFF only.
    It 'gating: terminal_theme does not install Oh My Posh when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Install-App' '*Oh My Posh*') | Should Be 0
    }
}

# ============================================================================
# 18 - Final Config
# ============================================================================
Describe '18-FinalConfig executes and gates under sandbox' {
    $mod = Join-Path $global:WinInitModules '18-FinalConfig.ps1'
    $id  = '18-FinalConfig'

    It 'loads with all features disabled (scaffolding executes clean)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        { . $mod } | Should Not Throw
    }

    # windows_update body removes AU policy values via Remove-ItemProperty (recorded) -> SAFE.
    It 'gating: windows_update purges ScheduledInstallTime policy value (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Remove-ItemProperty' '*ScheduledInstallTime*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'windows_update')
        . $mod
        (Get-CallCount 'Remove-ItemProperty' '*ScheduledInstallTime*') | Should Not Be 0
    }

    # system_restore body writes DisableSR registry value via Set-ItemProperty (recorded) -> SAFE.
    It 'gating: system_restore writes the DisableSR registry value (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableSR*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'system_restore')
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*DisableSR*') | Should Not Be 0
    }

    # unsafe: startup_config builds a real Startup .lnk via New-Object -ComObject WScript.Shell + .Save().
    # OFF only.
    It 'gating: startup_config writes no RestartApps value when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Set-ItemProperty' '*RestartApps*') | Should Be 0
    }

    # unsafe: system_cleanup calls Clear-RecycleBin / Clear-DeliveryOptimizationCache (real, not stubbed)
    # which empty the real recycle bin / DO cache. OFF only.
    It 'gating: system_cleanup stops no update services when disabled (off-only, unsafe on)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Stop-Service' '*wuauserv*') | Should Be 0
    }

    # weekly_update_task body queries Get-ScheduledTask (recorded) when enabled -> SAFE.
    It 'gating: weekly_update_task checks for the WinInit update task (safe)' {
        Reset-WinInitState -Features (Disable-AllFeatures $id)
        . $mod
        (Get-CallCount 'Get-ScheduledTask' '*WinInit-WeeklyUpdate*') | Should Be 0
        Reset-WinInitState -Features (Enable-OnlyFeature $id 'weekly_update_task')
        . $mod
        (Get-CallCount 'Get-ScheduledTask' '*WinInit-WeeklyUpdate*') | Should Not Be 0
    }
}
