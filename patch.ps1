#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('apply','check','restore')][string]$Action = 'apply',
    [string]$GameDirectory,
    [string]$PluginPath,
    [switch]$ImportOnly
)

$ErrorActionPreference = 'Stop'
$script:Reference = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'supported_versions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:OriginalHash = $script:Reference.exe_original_sha256
$script:PatchedHash = $script:Reference.exe_patched_sha256
$script:PluginHash = $script:Reference.plugin.dll_sha256
$script:Offset = 0x2C82EA
$script:OldBytes = [byte[]](0x82,0x6C,0x82,0x72,0x20,0x82,0x6F,0x83,0x53,0x83,0x56,0x83,0x62,0x83,0x4E,0x00)
# The original literal is 16 bytes including its terminating zero.
$script:NewBytes = New-Object byte[] $script:OldBytes.Length
[Text.Encoding]::ASCII.GetBytes('MS PGothic').CopyTo($script:NewBytes, 0)
$script:FileNames = @('yuusyatsuma.eXe','yuusyatsuma.cf','utf8hack.tpm')
$script:BackupName = '.unicode-fix-backup'
$script:Notices = New-Object 'System.Collections.Generic.List[string]'

function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($i = 0; $i -lt $Left.Length; $i++) { if ($Left[$i] -ne $Right[$i]) { return $false } }
    return $true
}

function Get-BytesHash([byte[]]$Bytes) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Add-CompatibilityWarning([string]$Message) {
    if (-not $script:Notices.Contains($Message)) { $script:Notices.Add($Message) }
    Write-Warning $Message
}

function Test-ReferenceHash([byte[]]$Bytes, [string]$Expected, [string]$Label) {
    if ((Get-BytesHash $Bytes) -ne $Expected) {
        Add-CompatibilityWarning ($Label + ' SHA-256 differs from the tested build. Continuing; compatibility is unverified.')
    }
}

function Get-ExecutableState([byte[]]$Bytes) {
    if ($Bytes.Length -ge ($script:Offset + $script:OldBytes.Length)) {
        $marker = [byte[]]$Bytes[$script:Offset..($script:Offset + $script:OldBytes.Length - 1)]
        if (Test-BytesEqual $marker $script:OldBytes) { return 'original' }
        if (Test-BytesEqual $marker $script:NewBytes) { return 'patched' }
    }
    throw 'Font bytes at the patch offset do not match either known state; cannot locate a safe edit.'
}

function Get-PatchedExecutable([byte[]]$Bytes) {
    if ((Get-ExecutableState $Bytes) -eq 'patched') {
        Test-ReferenceHash $Bytes $script:PatchedHash 'Already-patched EXE'
        return ,$Bytes
    }
    Test-ReferenceHash $Bytes $script:OriginalHash 'Original EXE'
    $result = [byte[]]$Bytes.Clone()
    $script:NewBytes.CopyTo($result, $script:Offset)
    return ,$result
}

function Get-PatchedConfig([byte[]]$Bytes) {
    $bomLength = 0
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 255 -and $Bytes[1] -eq 254) {
        $bomLength = 2
        $encoding = New-Object Text.UnicodeEncoding($false, $false, $true)
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 254 -and $Bytes[1] -eq 255) {
        $bomLength = 2
        $encoding = New-Object Text.UnicodeEncoding($true, $false, $true)
    } elseif ($Bytes.Length -ge 3 -and $Bytes[0] -eq 239 -and $Bytes[1] -eq 187 -and $Bytes[2] -eq 191) {
        $bomLength = 3
    }
    try { $text = $encoding.GetString($Bytes, $bomLength, $Bytes.Length - $bomLength) }
    catch { throw 'Unsupported configuration encoding; no files changed.' }
    $setting = 'readencoding="\x53\x68\x69\x66\x74\x5F\x4A\x49\x53"'
    if ([regex]::IsMatch($text, '(?m)^[ \t]*readencoding[ \t]*=')) {
        $text = [regex]::Replace($text, '(?m)^[ \t]*readencoding[ \t]*=[^\r\n]*', $setting)
    } else {
        $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
        if ($text.Length -gt 0 -and -not ($text.EndsWith("`n") -or $text.EndsWith("`r"))) { $text += $newline }
        $text += $setting + $newline
    }
    $payload = $encoding.GetBytes($text)
    $result = New-Object byte[] ($bomLength + $payload.Length)
    if ($bomLength -gt 0) { [Array]::Copy($Bytes, 0, $result, 0, $bomLength) }
    $payload.CopyTo($result, $bomLength)
    return ,$result
}

function Write-AtomicFile([string]$Path, [byte[]]$Bytes) {
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.unicode-fix-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Get-GameDirectory([string]$Path) {
    $directory = Get-Item -LiteralPath $Path
    if (-not $directory.PSIsContainer) { throw 'Select a game folder.' }
    foreach ($name in $script:FileNames) {
        $target = Join-Path $directory.FullName $name
        if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw ('Symbolic links are not supported for target files: ' + $name)
        }
    }
    foreach ($name in @('yuusyatsuma.eXe','yuusyatsuma.cf','data.xp3','patch_1.xp3','patch_2.xp3')) {
        if (-not [IO.File]::Exists((Join-Path $directory.FullName $name))) { throw ('Missing required game file: ' + $name) }
    }
    return $directory.FullName
}

function Test-GameArchives([string]$Game) {
    foreach ($property in $script:Reference.archives_sha256.PSObject.Properties) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $Game $property.Name) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $property.Value) { Add-CompatibilityWarning ($property.Name + ' SHA-256 differs from the tested Steam build. Continuing; compatibility is unverified.') }
    }
}

function Get-PatchStatus([string]$Folder) {
    $game = Get-GameDirectory $Folder
    Test-GameArchives $game
    $bytes = [IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.eXe'))
    if ((Get-ExecutableState $bytes) -eq 'original') {
        Test-ReferenceHash $bytes $script:OriginalHash 'Original EXE'
        $null = Get-PatchedConfig ([IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.cf')))
        return 'Patch location recognized. No files changed. Hash differences are warnings only.'
    }
    Test-ReferenceHash $bytes $script:PatchedHash 'Already-patched EXE'
    $plugin = Join-Path $game 'utf8hack.tpm'
    if (-not [IO.File]::Exists($plugin)) { throw 'EXE is patched, but the plugin is missing.' }
    Test-ReferenceHash ([IO.File]::ReadAllBytes($plugin)) $script:PluginHash 'Installed plugin'
    $config = [IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.cf'))
    if (-not (Test-BytesEqual (Get-PatchedConfig $config) $config)) { throw 'EXE is patched, but readencoding is not configured.' }
    return 'Patched font bytes, plugin, and configuration are present. Gameplay is not verified by this check.'
}

function Install-GamePatch([string]$Folder, [string]$Plugin) {
    $game = Get-GameDirectory $Folder
    $exe = [IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.eXe'))
    if ((Get-ExecutableState $exe) -eq 'patched') { return Get-PatchStatus $game }
    Test-GameArchives $game
    $backup = Join-Path $game $script:BackupName
    if (Test-Path -LiteralPath $backup) { throw 'A backup already exists. It will not be overwritten; restore or inspect it before installing again.' }
    $pluginBytes = [IO.File]::ReadAllBytes((Get-Item -LiteralPath $Plugin).FullName)
    Test-ReferenceHash $pluginBytes $script:PluginHash 'Selected plugin'
    $before = @{}
    foreach ($name in $script:FileNames) {
        $target = Join-Path $game $name
        $before[$name] = if ([IO.File]::Exists($target)) { [IO.File]::ReadAllBytes($target) } else { $null }
    }
    if ($null -ne $before['utf8hack.tpm'] -and -not (Test-BytesEqual $before['utf8hack.tpm'] $pluginBytes)) {
        Add-CompatibilityWarning 'The existing utf8hack.tpm differs from the selected plugin; it will be backed up and replaced.'
    }
    $after = @{
        'yuusyatsuma.eXe' = Get-PatchedExecutable $before['yuusyatsuma.eXe']
        'yuusyatsuma.cf' = Get-PatchedConfig $before['yuusyatsuma.cf']
        'utf8hack.tpm' = $pluginBytes
    }
    $null = New-Item -ItemType Directory -Path $backup
    $manifest = @{ format = 1; before = @{}; after = @{} }
    foreach ($name in $script:FileNames) {
        if ($null -ne $before[$name]) {
            Write-AtomicFile (Join-Path $backup $name) $before[$name]
            $manifest.before[$name] = Get-BytesHash $before[$name]
        } else { $manifest.before[$name] = $null }
        $manifest.after[$name] = Get-BytesHash $after[$name]
    }
    Write-AtomicFile (Join-Path $backup 'manifest.json') ([Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 4)))
    $written = New-Object 'System.Collections.Generic.List[string]'
    try {
        foreach ($name in $script:FileNames) {
            Write-AtomicFile (Join-Path $game $name) $after[$name]
            $written.Add($name)
        }
        foreach ($name in $script:FileNames) {
            if (-not (Test-BytesEqual ([IO.File]::ReadAllBytes((Join-Path $game $name))) $after[$name])) { throw ('Written file verification failed: ' + $name) }
        }
    } catch {
        $failureReason = $_.Exception.Message
        $failures = New-Object 'System.Collections.Generic.List[string]'
        for ($i = $written.Count - 1; $i -ge 0; $i--) {
            $name = $written[$i]
            try {
                if ($null -eq $before[$name]) { [IO.File]::Delete((Join-Path $game $name)) }
                else { Write-AtomicFile (Join-Path $game $name) $before[$name] }
            } catch { $failures.Add($name) }
        }
        if ($failures.Count -gt 0) { throw ('Install failed. Backup retained; manual recovery required for: ' + ($failures -join ', ')) }
        throw ('Install failed. Completed writes were rolled back; backup retained. Reason: ' + $failureReason)
    }
    return ('Patch installed. Original files are in ' + $script:BackupName + '. Clear old Steam launcher overrides, then launch normally.')
}

function Restore-GamePatch([string]$Folder) {
    $game = Get-GameDirectory $Folder
    $backup = Join-Path $game $script:BackupName
    $backupItem = Get-Item -LiteralPath $backup
    if ($backupItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Backup must not be a symbolic link.' }
    try {
        $manifest = Get-Content -LiteralPath (Join-Path $backup 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.format -ne 1) { throw 'Invalid format' }
        foreach ($section in @('before','after')) {
            $names = @($manifest.$section.PSObject.Properties.Name | Sort-Object)
            if (($names -join '|') -ne (($script:FileNames | Sort-Object) -join '|')) { throw 'Invalid file list' }
        }
    } catch { throw 'A valid backup manifest is required.' }
    $originals = @{}
    foreach ($name in $script:FileNames) {
        $expected = $manifest.before.$name
        $data = if ($null -ne $expected) { [IO.File]::ReadAllBytes((Join-Path $backup $name)) } else { $null }
        if ($null -ne $data -and (Get-BytesHash $data) -ne $expected) { throw ('Backup checksum mismatch: ' + $name) }
        $target = Join-Path $game $name
        $current = if ([IO.File]::Exists($target)) { Get-BytesHash ([IO.File]::ReadAllBytes($target)) } else { $null }
        if ($current -ne $expected -and $current -ne $manifest.after.$name) { throw ('File changed after installation; restore stopped to preserve it: ' + $name) }
        $originals[$name] = $data
    }
    foreach ($name in $script:FileNames) {
        if ($null -eq $originals[$name]) { [IO.File]::Delete((Join-Path $game $name)) }
        else { Write-AtomicFile (Join-Path $game $name) $originals[$name] }
    }
    return 'Original files restored. Backup retained; savedata was not modified.'
}

if ($ImportOnly) { return }
$interactive = [string]::IsNullOrWhiteSpace($GameDirectory)
try {
    if ($interactive) {
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description = 'Select the game folder (contains yuusyatsuma.eXe)'
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
        $GameDirectory = $picker.SelectedPath
        $picker.Dispose()
        if ($Action -eq 'apply') {
            $filePicker = New-Object Windows.Forms.OpenFileDialog
            $filePicker.Title = 'Select utf8hack.dll from upstream v1.2.0 intel32 clang'
            $filePicker.Filter = 'Plugin (*.dll;*.tpm)|*.dll;*.tpm'
            if ($filePicker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
            $PluginPath = $filePicker.FileName
            $filePicker.Dispose()
        }
        if ($Action -ne 'check') {
            $answer = [Windows.Forms.MessageBox]::Show('Close the game first. Continue with ' + $Action + '?', 'Unicode startup fix', [Windows.Forms.MessageBoxButtons]::YesNo)
            if ($answer -ne [Windows.Forms.DialogResult]::Yes) { exit 0 }
        }
    }
    $result = switch ($Action) {
        'check' { Get-PatchStatus $GameDirectory }
        'restore' { Restore-GamePatch $GameDirectory }
        'apply' {
            if ([string]::IsNullOrWhiteSpace($PluginPath)) { throw 'apply requires -PluginPath.' }
            Install-GamePatch $GameDirectory $PluginPath
        }
    }
    Write-Output $result
    if ($interactive) {
        if ($script:Notices.Count -gt 0) {
            $null = [Windows.Forms.MessageBox]::Show($result + "`r`n`r`n" + ($script:Notices -join "`r`n`r`n"), 'Completed with warnings', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning)
        } else { $null = [Windows.Forms.MessageBox]::Show($result, 'Unicode startup fix') }
    }
} catch {
    if ($interactive) { $null = [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Patch stopped') }
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
