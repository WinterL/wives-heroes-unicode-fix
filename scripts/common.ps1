#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$script:FileNames = @('yuusyatsuma.eXe','yuusyatsuma.cf','utf8hack.tpm')
$script:BackupName = '.unicode-fix-backup'

function Read-OptionalFile([string]$Path) {
    if ([IO.File]::Exists($Path)) { return ,[IO.File]::ReadAllBytes($Path) }
    return $null
}

function Get-BytesHash([byte[]]$Bytes) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Write-AtomicFile([string]$Path, [byte[]]$Bytes) {
    if ($null -eq $Bytes) { [IO.File]::Delete($Path); return }
    $temporary = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.unicode-fix-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        [IO.File]::Delete($temporary)
    }
}

function Get-GameDirectory([string]$Path) {
    $directory = Get-Item -LiteralPath $Path
    if (-not $directory.PSIsContainer) { throw 'Place this CMD file in the game folder.' }
    foreach ($name in $script:FileNames) {
        $target = Join-Path $directory.FullName $name
        if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw ('Symbolic links are not supported for target files: ' + $name)
        }
    }
    foreach ($name in @('yuusyatsuma.eXe','yuusyatsuma.cf')) {
        if (-not [IO.File]::Exists((Join-Path $directory.FullName $name))) { throw ('Missing ' + $name + '. Place this CMD file in the game folder.') }
    }
    return $directory.FullName
}

function Read-PatchBackup([string]$Game) {
    $backup = Join-Path $Game $script:BackupName
    $item = Get-Item -LiteralPath $backup
    if (-not $item.PSIsContainer -or $item.FullName -ne $backup -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Backup must be a normal directory directly inside the game folder.' }
    $entries = @(Get-ChildItem -LiteralPath $backup -Force)
    foreach ($entry in $entries) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Backup contains a directory or symbolic link; no files changed.' }
    }
    $manifestPath = Join-Path $backup 'manifest.json'
    try {
        $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
        $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
        if ($manifest.format -ne 1) { throw 'Invalid format' }
        foreach ($section in @('before','after')) {
            $names = @($manifest.$section.PSObject.Properties.Name | Sort-Object)
            if (($names -join '|') -ne (($script:FileNames | Sort-Object) -join '|')) { throw 'Invalid file list' }
        }
        foreach ($name in $script:FileNames) {
            if ($manifest.after.$name -isnot [string] -or $manifest.after.$name -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid installed hash' }
            if ($null -eq $manifest.before.$name -and $name -eq 'utf8hack.tpm') { continue }
            if ($manifest.before.$name -isnot [string] -or $manifest.before.$name -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid original hash' }
        }
    } catch { throw 'A valid backup manifest is required.' }
    $ownedNames = @($script:FileNames | Where-Object { $null -ne $manifest.before.$_ }) + @('manifest.json')
    if ((@($entries.Name | Sort-Object) -join '|') -ne (($ownedNames | Sort-Object) -join '|')) { throw 'Backup contains unexpected or missing files; no files changed.' }
    $originals = @{}
    foreach ($name in $script:FileNames) {
        $expected = $manifest.before.$name
        $originals[$name] = if ($null -ne $expected) { [IO.File]::ReadAllBytes((Join-Path $backup $name)) } else { $null }
        if ($null -ne $originals[$name] -and (Get-BytesHash $originals[$name]) -ne $expected) { throw ('Backup checksum mismatch: ' + $name) }
    }
    return @{ Manifest=$manifest; Bytes=$manifestBytes; Originals=$originals; Names=$ownedNames }
}
