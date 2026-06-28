#Requires -Version 5.1
<#
================================================================================
 WinInit Control Panel  -  Granular Feature Activation UI
--------------------------------------------------------------------------------
 Native WPF GUI. Each module expands into its individual sub-options:
   - groups  -> [features] "Module.key" = true/false   (Test-Feature in modules)
   - lists   -> [apps]/[debloat]/[services] skip arrays (per-item include/exclude)
 Plus module on/off ([modules]), profile, privacy level, dry-run.

 Reads features.json (the contract). No external dependencies.
 Run:  powershell -STA -ExecutionPolicy Bypass -File WinInit-UI.ps1
 Or double-click WinInit-UI.bat
================================================================================
#>
param([string]$ConfigFile = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$ScriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($ConfigFile)) { $ConfigFile = Join-Path $ScriptRoot "config.toml" }
$InitScript   = Join-Path $ScriptRoot "init.ps1"
$FeaturesFile = Join-Path $ScriptRoot "features.json"
$ProfilesDir  = Join-Path $ScriptRoot "profiles"

# --- Load the feature manifest (contract) ---
if (-not (Test-Path $FeaturesFile)) { throw "features.json not found next to WinInit-UI.ps1 ($FeaturesFile)" }
$Manifest = Get-Content $FeaturesFile -Raw | ConvertFrom-Json
$ModuleDefs = $Manifest.modules

# --- Per-module badge metadata (category / risk) ---
$BadgeMeta = @{
    "01-PackageManagers"=@{cat="Install";risk="Low"};    "02-Applications"=@{cat="Install";risk="Low"}
    "03-DesktopEnvironment"=@{cat="Tweaks";risk="Medium"};"04-OneDriveRemoval"=@{cat="Removal";risk="High"}
    "05-Performance"=@{cat="Tweaks";risk="Medium"};       "06-Debloat"=@{cat="Removal";risk="High"}
    "07-Privacy"=@{cat="Tweaks";risk="Medium"};           "08-QualityOfLife"=@{cat="Tweaks";risk="Low"}
    "09-Services"=@{cat="Removal";risk="High"};           "10-NetworkPerformance"=@{cat="Tweaks";risk="Medium"}
    "11-VisualUX"=@{cat="Tweaks";risk="Low"};             "12-SecurityHardening"=@{cat="Tweaks";risk="Medium"}
    "13-BrowserExtensions"=@{cat="Install";risk="Low"};   "14-DevTools"=@{cat="Dev";risk="Low"}
    "15-PortableTools"=@{cat="Dev";risk="Low"};           "16-UnixEnvironment"=@{cat="Dev";risk="Low"}
    "17-VSCodeSetup"=@{cat="Dev";risk="Low"};             "18-FinalConfig"=@{cat="Tweaks";risk="Medium"}
}
$riskColors = @{ Low="#FF3FB950"; Medium="#FFD9A300"; High="#FFE5534B" }
$catColors  = @{ Install="#FF3A7AFE"; Tweaks="#FF8A63D2"; Removal="#FFE5534B"; Dev="#FF1F9C9C" }

$PrivacyLevels = @("standard","strict","paranoid")

# ============================================================================
# Profile presets (read real profiles/*.json; fall back to all-on)
# ============================================================================
$AllIds = $ModuleDefs | ForEach-Object { $_.id }
$ProfilePresets = @{}
if (Test-Path $ProfilesDir) {
    foreach ($pf in (Get-ChildItem (Join-Path $ProfilesDir "*.json") -ErrorAction SilentlyContinue)) {
        try {
            $j = Get-Content $pf.FullName -Raw | ConvertFrom-Json
            $ids = @($j.modules.PSObject.Properties | Where-Object { $_.Value } | ForEach-Object { $_.Name })
            $ProfilePresets[$j.name] = @{ ids = $ids; privacy = $j.privacy_level }
        } catch {}
    }
}
if (-not $ProfilePresets.ContainsKey("full")) { $ProfilePresets["full"] = @{ ids = $AllIds; privacy = "strict" } }
$preferredOrder = @("full","developer","minimal","security","creative","office")
$ProfileNames = @($preferredOrder | Where-Object { $ProfilePresets.ContainsKey($_) }) +
                @($ProfilePresets.Keys | Where-Object { $preferredOrder -notcontains $_ } | Sort-Object)
if ($ProfileNames.Count -eq 0) { $ProfileNames = @("full") }

# ============================================================================
# config.toml read / write (quote- & comment-aware)
# ============================================================================
function Split-TomlComment {
    param([string]$Raw)
    $inQ=$false; $qc=$null
    for ($i=0; $i -lt $Raw.Length; $i++) {
        $ch=$Raw[$i]
        if ($inQ) { if ($ch -eq $qc) { $inQ=$false } }
        elseif ($ch -eq '"' -or $ch -eq "'") { $inQ=$true; $qc=$ch }
        elseif ($ch -eq '#') { return @($Raw.Substring(0,$i).TrimEnd(), $Raw.Substring($i)) }
    }
    return @($Raw,'')
}
function Parse-TomlArray {
    param([string]$Raw)   # e.g.  ["A", "B"]
    $v = (Split-TomlComment $Raw)[0].Trim()
    if ($v -notmatch '^\[') { return @() }
    $v = $v.Trim('[',']')
    $items=@(); $cur=''; $inQ=$false; $qc=$null
    foreach ($ch in $v.ToCharArray()) {
        if ($inQ) { if ($ch -eq $qc) { $inQ=$false } else { $cur+=$ch } }
        elseif ($ch -eq '"' -or $ch -eq "'") { $inQ=$true; $qc=$ch }
        elseif ($ch -eq ',') { if ($cur.Trim()) { $items+=$cur.Trim() }; $cur='' }
        elseif ($ch -notmatch '\s') { $cur+=$ch }
    }
    if ($cur.Trim()) { $items+=$cur.Trim() }
    return @($items)
}
function Format-TomlArray {
    param([string[]]$Items)
    if (-not $Items -or $Items.Count -eq 0) { return '[]' }
    '[' + (($Items | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ']'
}

function Read-WinInitConfig {
    $r = @{ profile=$null; dry_run=$false; privacy=$null; modules=@{}; features=@{}; skip=@{ apps=@(); debloat=@(); services=@() } }
    if (-not (Test-Path $ConfigFile)) { return $r }
    $section=''
    foreach ($line in (Get-Content $ConfigFile)) {
        $t=$line.Trim()
        if ($t -match '^\[([^\]]+)\]$') { $section=$Matches[1].Trim(); continue }
        if ($t -match '^\s*#') { continue }
        if ($t -match '^("?[^"=]+"?)\s*=\s*(.+)$') {
            $key=$Matches[1].Trim().Trim('"').Trim("'")
            $valPart=(Split-TomlComment $Matches[2])[0].Trim()
            switch ($section) {
                'general'  { if ($key -eq 'profile') { $r.profile=$valPart.Trim('"').Trim("'") }
                             if ($key -eq 'dry_run') { $r.dry_run=($valPart -eq 'true') } }
                'privacy'  { if ($key -eq 'level')   { $r.privacy=$valPart.Trim('"').Trim("'") } }
                'modules'  { $r.modules[$key]=($valPart -eq 'true') }
                'features' { $r.features[$key]=($valPart -eq 'true') }
                'apps'     { if ($key -eq 'skip') { $r.skip.apps=@(Parse-TomlArray $Matches[2]) } }
                'debloat'  { if ($key -eq 'skip') { $r.skip.debloat=@(Parse-TomlArray $Matches[2]) } }
                'services' { if ($key -eq 'skip') { $r.skip.services=@(Parse-TomlArray $Matches[2]) } }
            }
        }
    }
    return $r
}

function Save-WinInitConfig {
    param(
        [hashtable]$ModuleState, [string]$Profile, [bool]$DryRun, [string]$Privacy,
        [hashtable]$Features, [string[]]$SkipApps, [string[]]$SkipDebloat, [string[]]$SkipServices
    )
    $lines = if (Test-Path $ConfigFile) { @(Get-Content $ConfigFile) } else { @() }
    $out = New-Object System.Collections.Generic.List[string]
    $section=''; $inFeatures=$false
    $handledModules=@{}
    $seen=@{ genProfile=$false; genDry=$false; privLevel=$false; appsSkip=$false; debloatSkip=$false; servicesSkip=$false }
    $haveSec=@{ general=$false; privacy=$false; modules=$false; apps=$false; debloat=$false; services=$false }

    function _kv([string]$lead,[string]$k,[string]$v,[string]$c){ $l="$lead$k = $v"; if ($c){ $l+="    $c" }; $l }

    foreach ($line in $lines) {
        $t=$line.Trim(); $lead=''
        if ($line -match '^(\s*)') { $lead=$Matches[1] }
        if ($t -match '^\[([^\]]+)\]$') {
            $section=$Matches[1].Trim()
            if ($section -eq 'features') { $inFeatures=$true; continue }   # drop old [features] entirely
            $inFeatures=$false
            if ($haveSec.ContainsKey($section)) { $haveSec[$section]=$true }
            $out.Add($line); continue
        }
        if ($inFeatures) { continue }
        if ($t -match '^\s*#' -or [string]::IsNullOrWhiteSpace($t)) { $out.Add($line); continue }
        if ($t -match '^("?[^"=]+"?)\s*=\s*(.+)$') {
            $rawKey=$Matches[1].Trim(); $key=$rawKey.Trim('"').Trim("'"); $comment=(Split-TomlComment $Matches[2])[1]
            if ($section -eq 'general' -and $key -eq 'profile') { $out.Add((_kv $lead $rawKey ('"'+$Profile+'"') $comment)); $seen.genProfile=$true; continue }
            if ($section -eq 'general' -and $key -eq 'dry_run') { $out.Add((_kv $lead $rawKey ($(if($DryRun){'true'}else{'false'})) $comment)); $seen.genDry=$true; continue }
            if ($section -eq 'privacy' -and $key -eq 'level')   { $out.Add((_kv $lead $rawKey ('"'+$Privacy+'"') $comment)); $seen.privLevel=$true; continue }
            if ($section -eq 'modules' -and $ModuleState.ContainsKey($key)) { $out.Add((_kv $lead $rawKey ($(if($ModuleState[$key]){'true'}else{'false'})) $comment)); $handledModules[$key]=$true; continue }
            if ($section -eq 'apps' -and $key -eq 'skip')     { $out.Add((_kv $lead $rawKey (Format-TomlArray $SkipApps) $comment)); $seen.appsSkip=$true; continue }
            if ($section -eq 'debloat' -and $key -eq 'skip')  { $out.Add((_kv $lead $rawKey (Format-TomlArray $SkipDebloat) $comment)); $seen.debloatSkip=$true; continue }
            if ($section -eq 'services' -and $key -eq 'skip') { $out.Add((_kv $lead $rawKey (Format-TomlArray $SkipServices) $comment)); $seen.servicesSkip=$true; continue }
        }
        $out.Add($line)
    }

    # Append any module rows not present
    $missing = $ModuleDefs | Where-Object { -not $handledModules.ContainsKey($_.id) }
    if ($missing) {
        if (-not $haveSec.modules) { $out.Add(''); $out.Add('[modules]') }
        foreach ($m in $missing) { $out.Add(('"{0}" = {1}' -f $m.id, $(if($ModuleState[$m.id]){'true'}else{'false'}))) }
    }
    if (-not $haveSec.general)  { $out.Add(''); $out.Add('[general]') }
    if (-not $seen.genProfile)  { $out.Add('profile = "'+$Profile+'"') }
    if (-not $seen.genDry)      { $out.Add('dry_run = '+$(if($DryRun){'true'}else{'false'})) }
    if (-not $haveSec.privacy)  { $out.Add(''); $out.Add('[privacy]') }
    if (-not $seen.privLevel)   { $out.Add('level = "'+$Privacy+'"') }

    # Skip sections (apps already exists in stock config; debloat/services usually need appending)
    if (-not $seen.appsSkip)     { $out.Add(''); if (-not $haveSec.apps){ $out.Add('[apps]') }; $out.Add('skip = '+(Format-TomlArray $SkipApps)) }
    if (-not $seen.debloatSkip)  { $out.Add(''); $out.Add('[debloat]'); $out.Add('# Bloatware to KEEP (exclude from removal)'); $out.Add('skip = '+(Format-TomlArray $SkipDebloat)) }
    if (-not $seen.servicesSkip) { $out.Add(''); $out.Add('[services]'); $out.Add('# Services to KEEP (exclude from disabling)'); $out.Add('skip = '+(Format-TomlArray $SkipServices)) }

    # Regenerate [features] at the end
    $out.Add(''); $out.Add('[features]')
    $out.Add('# Per-feature toggles: "Module.group" = true (run) / false (skip). Read by Test-Feature.')
    foreach ($m in $ModuleDefs) {
        if (-not $m.groups) { continue }
        foreach ($g in $m.groups) {
            $k = "$($m.id).$($g.key)"
            $v = if ($Features.ContainsKey($k)) { $Features[$k] } else { $true }
            $out.Add(('"{0}" = {1}' -f $k, $(if($v){'true'}else{'false'})))
        }
    }
    Set-Content -Path $ConfigFile -Value $out -Encoding UTF8
}

if ($env:WININIT_UI_NOGUI -eq '1') { return }   # test hook: dot-source helpers without a window

# ============================================================================
# Window chrome
# ============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinInit Control Panel" Height="820" Width="940"
        WindowStartupLocation="CenterScreen" Background="#FF1B1B1F" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#FF111114" Padding="18,12">
      <StackPanel>
        <TextBlock Text="WinInit Control Panel" Foreground="#FFE6E6EA" FontSize="21" FontWeight="SemiBold"/>
        <TextBlock Text="Expand any module to activate or deactivate its individual features." Foreground="#FF9A9AA6" FontSize="12" Margin="0,2,0,0"/>
        <Border x:Name="WarnBanner" Background="#33D98A00" BorderBrush="#FFD98A00" BorderThickness="1" CornerRadius="4" Padding="10,6" Margin="0,10,0,0" Visibility="Collapsed">
          <TextBlock x:Name="WarnText" Foreground="#FFFFCF70" FontSize="12" TextWrapping="Wrap"/>
        </Border>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Background="#FF202026" Padding="18,9">
      <WrapPanel>
        <TextBlock Text="Profile" Foreground="#FFC8C8D0" VerticalAlignment="Center" Margin="0,0,6,0"/>
        <ComboBox x:Name="ProfileBox" Width="130" Margin="0,0,16,0"/>
        <TextBlock Text="Privacy" Foreground="#FFC8C8D0" VerticalAlignment="Center" Margin="0,0,6,0"/>
        <ComboBox x:Name="PrivacyBox" Width="110" Margin="0,0,16,0"/>
        <CheckBox x:Name="DryRunBox" Content="Dry run" Foreground="#FFC8C8D0" VerticalAlignment="Center" Margin="0,0,16,0"/>
        <Button x:Name="ExpandBtn"   Content="Expand all"   Margin="0,0,6,0" Padding="9,3"/>
        <Button x:Name="CollapseBtn" Content="Collapse all" Margin="0,0,16,0" Padding="9,3"/>
        <Button x:Name="ResetBtn" Content="Reset to profile" Padding="9,3"/>
      </WrapPanel>
    </Border>

    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="10,8">
      <StackPanel x:Name="ModulePanel" Margin="8,0"/>
    </ScrollViewer>

    <Border Grid.Row="3" Background="#FF111114" Padding="18,12">
      <Grid>
        <TextBlock x:Name="StatusText" Foreground="#FF9A9AA6" VerticalAlignment="Center" FontSize="12"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="SaveBtn" Content="Save config.toml" Padding="14,6" Margin="0,0,10,0"/>
          <Button x:Name="LaunchBtn" Content="Save &amp; Launch (Admin)" Padding="14,6" Background="#FF3A7AFE" Foreground="White" FontWeight="SemiBold"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
foreach ($n in 'ProfileBox','PrivacyBox','DryRunBox','ExpandBtn','CollapseBtn','ResetBtn','ModulePanel','StatusText','SaveBtn','LaunchBtn','WarnBanner','WarnText') {
    Set-Variable -Name $n -Value $window.FindName($n)
}
$ProfileNames  | ForEach-Object { [void]$ProfileBox.Items.Add($_) }
$PrivacyLevels | ForEach-Object { [void]$PrivacyBox.Items.Add($_) }

# State maps
$script:MasterChecks   = @{}   # id -> master CheckBox  ([modules])
$script:Groups   = @{}   # "id.key" -> CheckBox   ([features])
$script:Items    = @{}   # "section|itemId" -> CheckBox (skip lists)
$script:Bodies   = @()   # collapsible body panels (for expand/collapse all)
$script:GroupDefault = @{}  # "id.key" -> default bool

function New-Badge([string]$text,[string]$color) {
    $b=New-Object System.Windows.Controls.Border
    $b.Background=$color; $b.CornerRadius=9; $b.Padding="8,2"; $b.Margin="6,0,0,0"; $b.VerticalAlignment="Center"
    $tb=New-Object System.Windows.Controls.TextBlock
    $tb.Text=$text; $tb.Foreground="White"; $tb.FontSize=11; $tb.FontWeight="SemiBold"
    $b.Child=$tb; $b
}
function New-LabeledCheck([string]$label,[string]$desc) {
    $cb=New-Object System.Windows.Controls.CheckBox
    $cb.Margin="0,3,0,3"; $cb.VerticalContentAlignment="Center"
    $sp=New-Object System.Windows.Controls.StackPanel
    $t1=New-Object System.Windows.Controls.TextBlock
    $t1.Text=$label; $t1.Foreground="#FFE0E0E6"; $t1.FontSize=13
    [void]$sp.Children.Add($t1)
    if ($desc) {
        $t2=New-Object System.Windows.Controls.TextBlock
        $t2.Text=$desc; $t2.Foreground="#FF8C8C98"; $t2.FontSize=11; $t2.TextWrapping="Wrap"
        [void]$sp.Children.Add($t2)
    }
    $cb.Content=$sp
    return $cb
}

# ============================================================================
# Build a card per module
# ============================================================================
foreach ($m in $ModuleDefs) {
    $meta = $BadgeMeta[$m.id]
    $card = New-Object System.Windows.Controls.Border
    $card.Background="#FF26262E"; $card.CornerRadius=6; $card.Padding="12,9"; $card.Margin="0,0,0,8"
    $stack = New-Object System.Windows.Controls.StackPanel

    # --- Header row ---
    $hdr = New-Object System.Windows.Controls.Grid
    foreach ($w in 'Auto','*','Auto','Auto') { $c=New-Object System.Windows.Controls.ColumnDefinition; $c.Width=$w; $hdr.ColumnDefinitions.Add($c) }

    $master = New-Object System.Windows.Controls.CheckBox
    $master.VerticalAlignment="Center"; $master.Margin="0,0,10,0"
    [System.Windows.Controls.Grid]::SetColumn($master,0); $hdr.Children.Add($master)
    $script:MasterChecks[$m.id]=$master

    $titleSp=New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($titleSp,1)
    $title=New-Object System.Windows.Controls.TextBlock
    $nOpts = (@($m.groups).Count + @($m.items).Count)
    $title.Text=("{0}   {1}" -f $m.id.Split('-')[0], $m.name)
    $title.Foreground="#FFE6E6EA"; $title.FontSize=14; $title.FontWeight="SemiBold"
    $sub=New-Object System.Windows.Controls.TextBlock
    $sub.Text=("{0} option(s)" -f $nOpts); $sub.Foreground="#FF8C8C98"; $sub.FontSize=11
    $titleSp.Children.Add($title); $titleSp.Children.Add($sub); $hdr.Children.Add($titleSp)

    $badges=New-Object System.Windows.Controls.StackPanel
    $badges.Orientation="Horizontal"; $badges.VerticalAlignment="Center"
    [System.Windows.Controls.Grid]::SetColumn($badges,2)
    $badges.Children.Add((New-Badge $meta.cat $catColors[$meta.cat]))
    $badges.Children.Add((New-Badge ("Risk: "+$meta.risk) $riskColors[$meta.risk]))
    $hdr.Children.Add($badges)

    $toggle=New-Object System.Windows.Controls.Primitives.ToggleButton
    $toggle.Content="Details  v"; $toggle.Padding="8,3"; $toggle.Margin="10,0,0,0"; $toggle.VerticalAlignment="Center"
    [System.Windows.Controls.Grid]::SetColumn($toggle,3); $hdr.Children.Add($toggle)
    $stack.Children.Add($hdr)

    # --- Body (collapsible) ---
    $body=New-Object System.Windows.Controls.StackPanel
    $body.Margin="34,8,0,2"; $body.Visibility="Collapsed"
    $script:Bodies += $body

    # groups
    if ($m.groups) {
        foreach ($g in $m.groups) {
            $def = $true
            if ($g.PSObject.Properties.Name -contains 'default') { $def=[bool]$g.default }
            $script:GroupDefault["$($m.id).$($g.key)"]=$def
            $cb = New-LabeledCheck $g.label $g.desc
            $cb.IsChecked=$def
            $script:Groups["$($m.id).$($g.key)"]=$cb
            $body.Children.Add($cb)
        }
    }
    # list items (wrap, optionally grouped by cat)
    if ($m.items) {
        if ($m.groups) {
            $hdr2=New-Object System.Windows.Controls.TextBlock
            $hdr2.Text="Individual items:"; $hdr2.Foreground="#FFB0B0BC"; $hdr2.FontSize=12; $hdr2.FontWeight="SemiBold"; $hdr2.Margin="0,8,0,2"
            $body.Children.Add($hdr2)
        }
        $section=$m.skipSection
        $cats = @($m.items | ForEach-Object { if ($_.PSObject.Properties.Name -contains 'cat') { $_.cat } else { '' } } | Select-Object -Unique)
        foreach ($cat in $cats) {
            if ($cat) {
                $ch=New-Object System.Windows.Controls.TextBlock
                $ch.Text=$cat; $ch.Foreground="#FF7A7A86"; $ch.FontSize=11; $ch.Margin="0,6,0,1"
                $body.Children.Add($ch)
            }
            $wrap=New-Object System.Windows.Controls.WrapPanel
            $wrap.Orientation="Horizontal"
            foreach ($it in ($m.items | Where-Object { (($_.PSObject.Properties.Name -contains 'cat') -and $_.cat -eq $cat) -or ((-not ($_.PSObject.Properties.Name -contains 'cat')) -and $cat -eq '') })) {
                $cb=New-Object System.Windows.Controls.CheckBox
                $cb.Content=$it.name; $cb.Foreground="#FFE0E0E6"; $cb.FontSize=12
                $cb.Width=288; $cb.Margin="0,2,0,2"; $cb.IsChecked=$true; $cb.ToolTip=$it.id
                $script:Items["$section|$($it.id)"]=$cb
                $wrap.Children.Add($cb)
            }
            $body.Children.Add($wrap)
        }
    }
    $stack.Children.Add($body)
    $card.Child=$stack
    [void]$ModulePanel.Children.Add($card)

    # interactions
    $toggle.Add_Checked({  param($s,$e) $s.Content="Details  ^"; $s.Tag.Visibility="Visible" })
    $toggle.Add_Unchecked({param($s,$e) $s.Content="Details  v"; $s.Tag.Visibility="Collapsed" })
    $toggle.Tag=$body
    # master greys out the body
    $master.Tag=$body
    $master.Add_Checked({  param($s,$e) $s.Tag.IsEnabled=$true })
    $master.Add_Unchecked({param($s,$e) $s.Tag.IsEnabled=$false })
}

# ============================================================================
# State helpers
# ============================================================================
function Set-Status([string]$msg,[string]$color="#FF9A9AA6"){ $StatusText.Text=$msg; $StatusText.Foreground=$color }

function Apply-Profile([string]$profile) {
    if (-not $ProfilePresets.ContainsKey($profile)) { return }
    $preset=$ProfilePresets[$profile]
    foreach ($m in $ModuleDefs) {
        $on = ($preset.ids -contains $m.id)
        $script:MasterChecks[$m.id].IsChecked=$on
        $script:MasterChecks[$m.id].Tag.IsEnabled=$on
    }
    if ($preset.privacy) { $PrivacyBox.SelectedItem=$preset.privacy }
}
function Reset-Defaults {
    foreach ($k in $script:Groups.Keys) { $script:Groups[$k].IsChecked=$script:GroupDefault[$k] }
    foreach ($k in $script:Items.Keys)  { $script:Items[$k].IsChecked=$true }
    Apply-Profile $ProfileBox.SelectedItem
}
function Collect-State {
    $modState=@{}; foreach ($m in $ModuleDefs){ $modState[$m.id]=[bool]$script:MasterChecks[$m.id].IsChecked }
    $feat=@{};     foreach ($k in $script:Groups.Keys){ $feat[$k]=[bool]$script:Groups[$k].IsChecked }
    $skip=@{ apps=@(); debloat=@(); services=@() }
    foreach ($k in $script:Items.Keys) {
        if (-not $script:Items[$k].IsChecked) {           # unchecked = exclude = skip
            $parts=$k.Split('|',2); $skip[$parts[0]] += $parts[1]
        }
    }
    @{ modules=$modState; features=$feat; skip=$skip }
}
function Do-Save {
    $st=Collect-State
    Save-WinInitConfig -ModuleState $st.modules -Profile $ProfileBox.SelectedItem -DryRun ([bool]$DryRunBox.IsChecked) `
        -Privacy $PrivacyBox.SelectedItem -Features $st.features `
        -SkipApps $st.skip.apps -SkipDebloat $st.skip.debloat -SkipServices $st.skip.services
    return $st
}

# ============================================================================
# Seed from existing config.toml
# ============================================================================
$existing = Read-WinInitConfig
$startProfile = if ($existing.profile -and ($ProfileNames -contains $existing.profile)) { $existing.profile } else { "full" }
$ProfileBox.SelectedItem = $startProfile
$PrivacyBox.SelectedItem = if ($existing.privacy -and ($PrivacyLevels -contains $existing.privacy)) { $existing.privacy } else { "strict" }
$DryRunBox.IsChecked = [bool]$existing.dry_run

Apply-Profile $startProfile
foreach ($m in $ModuleDefs) { if ($existing.modules.ContainsKey($m.id)) { $script:MasterChecks[$m.id].IsChecked=[bool]$existing.modules[$m.id]; $script:MasterChecks[$m.id].Tag.IsEnabled=[bool]$existing.modules[$m.id] } }
foreach ($k in $script:Groups.Keys) { if ($existing.features.ContainsKey($k)) { $script:Groups[$k].IsChecked=[bool]$existing.features[$k] } }
foreach ($sec in 'apps','debloat','services') {
    foreach ($skipId in $existing.skip[$sec]) { $key="$sec|$skipId"; if ($script:Items.ContainsKey($key)) { $script:Items[$key].IsChecked=$false } }
}

# Warn if orchestrator can't launch
$missingLibs=@()
if (-not (Test-Path (Join-Path $ScriptRoot "lib\safety.ps1"))) { $missingLibs+="lib\safety.ps1" }
if (-not (Test-Path $InitScript)) { $missingLibs+="init.ps1" }
if ($missingLibs.Count -gt 0) {
    $WarnBanner.Visibility="Visible"
    $WarnText.Text="Heads-up: missing $($missingLibs -join ', '). Saving config.toml works, but 'Launch' will fail until restored."
}

# ============================================================================
# Events
# ============================================================================
$ProfileBox.Add_SelectionChanged({ Apply-Profile $ProfileBox.SelectedItem; Set-Status "Applied '$($ProfileBox.SelectedItem)' profile." })
$ResetBtn.Add_Click({ Reset-Defaults; Set-Status "Reset all toggles to '$($ProfileBox.SelectedItem)' defaults." })
$ExpandBtn.Add_Click({   foreach ($b in $script:Bodies){ $b.Visibility="Visible" } })
$CollapseBtn.Add_Click({ foreach ($b in $script:Bodies){ $b.Visibility="Collapsed" } })

$SaveBtn.Add_Click({
    try {
        $st=Do-Save
        $nm=@($st.modules.Values | Where-Object { $_ }).Count
        $sk=$st.skip.apps.Count + $st.skip.debloat.Count + $st.skip.services.Count
        Set-Status "Saved $ConfigFile  -  $nm/$($ModuleDefs.Count) modules on, $sk item(s) excluded." "#FF3FB950"
    } catch { Set-Status "Save failed: $($_.Exception.Message)" "#FFE5534B" }
})
$LaunchBtn.Add_Click({
    try { [void](Do-Save) } catch { Set-Status "Save failed, not launching: $($_.Exception.Message)" "#FFE5534B"; return }
    if (-not (Test-Path $InitScript)) { Set-Status "init.ps1 not found - cannot launch." "#FFE5534B"; return }
    $dry = if ($DryRunBox.IsChecked) { " (dry run)" } else { "" }
    $c=[System.Windows.MessageBox]::Show("Saved. Launch init.ps1 as Administrator now?$dry`n`nA UAC prompt will appear.","WinInit",[System.Windows.MessageBoxButton]::OKCancel,[System.Windows.MessageBoxImage]::Question)
    if ($c -ne [System.Windows.MessageBoxResult]::OK) { Set-Status "Launch cancelled (config saved)."; return }
    try {
        $args=@("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$InitScript`"")
        if ($DryRunBox.IsChecked) { $args+="-DryRun" }
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs -WorkingDirectory $ScriptRoot
        Set-Status "Launched init.ps1 (elevated). You can close this window."
    } catch { Set-Status "Launch failed: $($_.Exception.Message)" "#FFE5534B" }
})

Set-Status "Loaded $ConfigFile  -  $($ModuleDefs.Count) modules, $($script:Groups.Count) feature toggles, $($script:Items.Count) items."
if ($env:WININIT_UI_BUILDONLY -eq '1') { return }   # smoke-test hook: build window without showing it
[void]$window.ShowDialog()
