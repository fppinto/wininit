# Tests for the pure / config functions in lib\common.ps1.
# Dot-source the real library directly (NOT _TestEnv.ps1) so that Install-App's
# real skip logic and the real TOML/profile parsers are exercised.
. "$PSScriptRoot\..\lib\common.ps1"

# ---------------------------------------------------------------------------
# 1. Test-Feature
# ---------------------------------------------------------------------------
Describe 'Test-Feature' {

    It 'defaults to ON when there is no [features] section' {
        $script:Config = @{}
        (Test-Feature 'x.y') | Should Be $true
    }

    It 'honors the supplied default when the key is absent' {
        $script:Config = @{}
        (Test-Feature 'x.y' $false) | Should Be $false
    }

    It 'returns an explicit real boolean true' {
        $script:Config = @{ features = @{ 'a.b' = $false; 'a.c' = 'false'; 'a.d' = $true } }
        (Test-Feature 'a.d') | Should Be $true
    }

    It 'returns an explicit real boolean false' {
        $script:Config = @{ features = @{ 'a.b' = $false; 'a.c' = 'false'; 'a.d' = $true } }
        (Test-Feature 'a.b') | Should Be $false
    }

    It 'coerces the string "false" to $false' {
        $script:Config = @{ features = @{ 'a.b' = $false; 'a.c' = 'false'; 'a.d' = $true } }
        (Test-Feature 'a.c') | Should Be $false
    }

    It 'coerces falsey strings (false / 0 / no) to $false' {
        $script:Config = @{ features = @{ k = 'false' } }
        (Test-Feature 'k') | Should Be $false
        $script:Config = @{ features = @{ k = '0' } }
        (Test-Feature 'k') | Should Be $false
        $script:Config = @{ features = @{ k = 'no' } }
        (Test-Feature 'k') | Should Be $false
    }

    It 'coerces truthy strings (true / 1 / yes) to $true' {
        $script:Config = @{ features = @{ k = 'true' } }
        (Test-Feature 'k') | Should Be $true
        $script:Config = @{ features = @{ k = '1' } }
        (Test-Feature 'k') | Should Be $true
        $script:Config = @{ features = @{ k = 'yes' } }
        (Test-Feature 'k') | Should Be $true
    }

    It 'returns the supplied default for an unrecognized string' {
        $script:Config = @{ features = @{ k = 'maybe' } }
        (Test-Feature 'k' $true)  | Should Be $true
        $script:Config = @{ features = @{ k = 'maybe' } }
        (Test-Feature 'k' $false) | Should Be $false
    }
}

# ---------------------------------------------------------------------------
# 2. Read-TomlConfig + ConvertFrom-TomlValue
# ---------------------------------------------------------------------------
Describe 'Read-TomlConfig / ConvertFrom-TomlValue' {

    $script:tomlPath = Join-Path $env:TEMP ("wininit_test_{0}.toml" -f ([guid]::NewGuid().ToString('N')))

    $tomlText = @'
# full-line comment that must be ignored
[demo]
"01-X" = true            # inline comment after a bool
count = 42
ratio = 3.14
title = "hello world"    # inline comment after a string
skip = []
keep = ["A", "B"]
'@
    Set-Content -Path $script:tomlPath -Value $tomlText -Encoding ASCII

    $cfg = Read-TomlConfig $script:tomlPath

    It 'parses a [section] into a nested hashtable' {
        $cfg.ContainsKey('demo') | Should Be $true
    }

    It 'parses a quoted key with a real boolean value' {
        $cfg['demo']['01-X'] | Should Be $true
        ($cfg['demo']['01-X'] -is [bool]) | Should Be $true
    }

    It 'parses an integer as [int]' {
        $cfg['demo']['count'] | Should Be 42
        ($cfg['demo']['count'] -is [int]) | Should Be $true
    }

    It 'parses a float as [double]' {
        ($cfg['demo']['ratio'] -is [double]) | Should Be $true
        ($cfg['demo']['ratio'] -gt 3.1) | Should Be $true
        ($cfg['demo']['ratio'] -lt 3.2) | Should Be $true
    }

    It 'parses a quoted string and strips the quotes' {
        $cfg['demo']['title'] | Should Be 'hello world'
        ($cfg['demo']['title'] -is [string]) | Should Be $true
    }

    It 'strips inline comments from the string value' {
        $cfg['demo']['title'] | Should Not Match '#'
    }

    It 'parses an empty array as an empty array' {
        @($cfg['demo']['skip']).Count | Should Be 0
    }

    It 'round-trips a populated array to a 2-element array' {
        @($cfg['demo']['keep']).Count | Should Be 2
        $cfg['demo']['keep'][0] | Should Be 'A'
        $cfg['demo']['keep'][1] | Should Be 'B'
    }

    It 'returns an empty hashtable for a missing file' {
        $missing = Join-Path $env:TEMP ("wininit_nope_{0}.toml" -f ([guid]::NewGuid().ToString('N')))
        $r = Read-TomlConfig $missing
        $r.Count | Should Be 0
    }

    # ConvertFrom-TomlValue direct cases
    It 'ConvertFrom-TomlValue coerces a bare true/false' {
        (ConvertFrom-TomlValue 'true')  | Should Be $true
        (ConvertFrom-TomlValue 'false') | Should Be $false
    }
}

# ---------------------------------------------------------------------------
# 3. Read-ProfileConfig (against the real profiles/ directory)
# ---------------------------------------------------------------------------
Describe 'Read-ProfileConfig' {

    $script:profilesDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'profiles'

    It 'loads the developer profile with .modules and .privacy_level' {
        $p = Read-ProfileConfig -ProfileName 'developer' -ProfilesDir $script:profilesDir
        $p | Should Not BeNullOrEmpty
        $p.modules       | Should Not BeNullOrEmpty
        $p.privacy_level | Should Not BeNullOrEmpty
    }

    It 'returns $null for a non-existent profile name' {
        $p = Read-ProfileConfig -ProfileName 'does-not-exist-xyz' -ProfilesDir $script:profilesDir
        $p | Should Be $null
    }
}

# ---------------------------------------------------------------------------
# 4. Install-App apps-skip logic (real Install-App, stubbed externals)
# ---------------------------------------------------------------------------
Describe 'Install-App apps-skip logic' {

    Context 'with Google.Chrome in the skip list' {

        # No-op the UI / logging helpers that common.ps1 defines.
        function Start-Spinner { }
        function Stop-Spinner { }
        function Update-SpinnerMessage { }
        function Write-Log { }

        # Recording stubs for the package managers. Install-App resolves the
        # executable via Get-Command and then runs it through Invoke-Silent, so
        # we both (a) expose winget/choco/scoop as commands and (b) record the
        # actual install attempt inside an Invoke-Silent stub.
        function winget { $script:wingetCalls++ }
        function choco  { $script:wingetCalls++ }
        function scoop  { $script:wingetCalls++ }

        function Invoke-Silent {
            param([string]$Exe, [string]$Args, [int]$TimeoutSeconds = 1600)
            $script:wingetCalls++
            return @{ ExitCode = 0; Output = "successfully installed" }
        }
        function Invoke-InProcess {
            param([string]$Cmd)
            $script:wingetCalls++
            return @{ ExitCode = 0; Output = "successfully installed" }
        }

        $script:AppsSkip    = @('Google.Chrome')
        $script:DryRunMode  = $false
        $script:SpinnerSync = @{ Active = $false; Total = 0; Progress = 0; Message = '' }

        It 'does NOT invoke any installer for a skipped app' {
            $script:wingetCalls = 0
            Install-App -Name 'Chrome' -WingetId 'Google.Chrome'
            $script:wingetCalls | Should Be 0
        }

        It 'DOES attempt an install for a non-skipped app' {
            $script:wingetCalls = 0
            Install-App -Name 'Other' -WingetId 'Some.Other'
            ($script:wingetCalls -gt 0) | Should Be $true
        }
    }
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
if ($script:tomlPath -and (Test-Path $script:tomlPath)) {
    Remove-Item $script:tomlPath -Force -ErrorAction SilentlyContinue
}
