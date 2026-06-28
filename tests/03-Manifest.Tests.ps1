# ============================================================================
# Manifest consistency tests. Validates STRUCTURAL parity between
# features.json, the module .ps1 files, the profiles, and config.toml.
# Pure file/JSON/regex assertions - no module execution required.
# Pester 3.4 syntax only (| Should Be / | Should Match).
# ============================================================================

$root      = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$modulesDir = Join-Path $root "modules"
$profilesDir = Join-Path $root "profiles"

$manifest = Get-Content (Join-Path $root "features.json") -Raw | ConvertFrom-Json
$moduleIds = @($manifest.modules | ForEach-Object { $_.id })

$expectedProfiles = @('full','developer','minimal','security','creative','office')
$validPrivacy     = @('standard','strict','paranoid')

# ----------------------------------------------------------------------------
Describe 'features.json schema' {

    It 'parses as JSON and exposes a modules array' {
        $manifest | Should Not BeNullOrEmpty
        @($manifest.modules).Count | Should Be 18
    }

    It 'every module has non-empty id, name and type' {
        foreach ($m in $manifest.modules) {
            $m.id   | Should Not BeNullOrEmpty
            $m.name | Should Not BeNullOrEmpty
            $m.type | Should Not BeNullOrEmpty
        }
    }

    It 'module ids are unique' {
        ($moduleIds | Select-Object -Unique).Count | Should Be $moduleIds.Count
    }

    It 'module ids match the NN- pattern' {
        foreach ($id in $moduleIds) {
            $id | Should Match '^\d\d-'
        }
    }

    It 'list-type modules have skipSection and a non-empty items array with unique ids' {
        foreach ($listId in @('02-Applications','06-Debloat','09-Services')) {
            $m = $manifest.modules | Where-Object { $_.id -eq $listId }
            $m              | Should Not BeNullOrEmpty
            $m.skipSection  | Should Not BeNullOrEmpty
            @($m.items).Count | Should Not Be 0
            $ids = @($m.items | ForEach-Object { $_.id })
            foreach ($iid in $ids) { $iid | Should Not BeNullOrEmpty }
            ($ids | Select-Object -Unique).Count | Should Be $ids.Count
        }
    }

    It 'group modules have a non-empty groups array with unique keys, and each group has label and desc' {
        foreach ($m in $manifest.modules) {
            if (-not $m.groups) { continue }
            @($m.groups).Count | Should Not Be 0
            $keys = @($m.groups | ForEach-Object { $_.key })
            foreach ($g in $m.groups) {
                $g.key   | Should Not BeNullOrEmpty
                $g.label | Should Not BeNullOrEmpty
                $g.desc  | Should Not BeNullOrEmpty
            }
            ($keys | Select-Object -Unique).Count | Should Be $keys.Count
        }
    }
}

# ----------------------------------------------------------------------------
Describe 'Manifest <-> module guard parity' {

    foreach ($m in $manifest.modules) {
        if (-not $m.groups) { continue }
        $id = $m.id
        $manifestKeys = @($m.groups | ForEach-Object { $_.key })
        $modPath = Join-Path $modulesDir "$id.ps1"

        It "$id module file exists" {
            (Test-Path $modPath) | Should Be $true
        }

        # Build the set of Test-Feature keys actually present in the module.
        # NOTE: keys can contain digits (smbv1, utf8, infra_k8s, msys2).
        $text = Get-Content $modPath -Raw
        $guardKeys = @()
        $pattern = 'Test-Feature\s+"' + [regex]::Escape($id) + '\.([A-Za-z0-9_]+)"'
        foreach ($mt in [regex]::Matches($text, $pattern)) {
            $guardKeys += $mt.Groups[1].Value
        }
        $guardKeys = @($guardKeys | Select-Object -Unique)

        foreach ($k in $manifestKeys) {
            It "$id manifest key '$k' has a Test-Feature guard in the module" {
                ($guardKeys -contains $k) | Should Be $true
            }
        }

        foreach ($gk in $guardKeys) {
            It "$id module guard key '$gk' exists in the manifest (no orphan guard)" {
                ($manifestKeys -contains $gk) | Should Be $true
            }
        }
    }
}

# ----------------------------------------------------------------------------
Describe 'Profiles' {

    $profileFiles = Get-ChildItem -Path $profilesDir -Filter '*.json'

    It 'the 6 expected profiles exist' {
        $names = @($profileFiles | ForEach-Object { $_.BaseName })
        foreach ($p in $expectedProfiles) {
            ($names -contains $p) | Should Be $true
        }
    }

    foreach ($pf in $profileFiles) {
        $pname = $pf.BaseName
        $p = Get-Content $pf.FullName -Raw | ConvertFrom-Json

        It "$pname profile parses and has name + description" {
            $p      | Should Not BeNullOrEmpty
            $p.name        | Should Not BeNullOrEmpty
            $p.description | Should Not BeNullOrEmpty
        }

        It "$pname profile modules keys are all valid module ids with boolean values" {
            $p.modules | Should Not BeNullOrEmpty
            foreach ($prop in $p.modules.PSObject.Properties) {
                ($moduleIds -contains $prop.Name) | Should Be $true
                ($prop.Value -is [bool]) | Should Be $true
            }
        }

        It "$pname profile has a valid privacy_level" {
            ($validPrivacy -contains $p.privacy_level) | Should Be $true
        }

        It "$pname profile apps_skip (if present) is an array" {
            if ($p.PSObject.Properties.Name -contains 'apps_skip') {
                ,$p.apps_skip | Should BeOfType [System.Array]
            }
        }
    }
}

# ----------------------------------------------------------------------------
Describe 'config.toml' {

    . (Join-Path $root "lib\common.ps1")
    $cfg = Read-TomlConfig (Join-Path $root "config.toml")

    It 'parses and [modules] contains all 18 module ids' {
        $cfg.modules | Should Not BeNullOrEmpty
        foreach ($id in $moduleIds) {
            ($cfg.modules.ContainsKey($id)) | Should Be $true
        }
        $cfg.modules.Keys.Count | Should Be 18
    }

    It '[general].profile is one of the 6 profile names' {
        ($expectedProfiles -contains $cfg.general.profile) | Should Be $true
    }

    It '[privacy].level is valid' {
        ($validPrivacy -contains $cfg.privacy.level) | Should Be $true
    }
}

# ----------------------------------------------------------------------------
Describe 'List-item id reachability' {

    $debloat  = $manifest.modules | Where-Object { $_.id -eq '06-Debloat' }
    $services = $manifest.modules | Where-Object { $_.id -eq '09-Services' }
    $apps     = $manifest.modules | Where-Object { $_.id -eq '02-Applications' }

    $debloatText  = Get-Content (Join-Path $modulesDir '06-Debloat.ps1') -Raw
    $servicesText = Get-Content (Join-Path $modulesDir '09-Services.ps1') -Raw
    $appsText     = Get-Content (Join-Path $modulesDir '02-Applications.ps1') -Raw

    foreach ($item in $debloat.items) {
        $iid = $item.id
        It "06-Debloat item '$iid' appears in the module source" {
            $debloatText | Should Match ([regex]::Escape($iid))
        }
    }

    foreach ($item in $services.items) {
        $iid = $item.id
        It "09-Services item '$iid' appears in the module source" {
            $servicesText | Should Match ([regex]::Escape($iid))
        }
    }

    foreach ($item in $apps.items) {
        $iid = $item.id
        It "02-Applications item '$iid' appears in the module source" {
            $appsText | Should Match ([regex]::Escape($iid))
        }
    }
}
