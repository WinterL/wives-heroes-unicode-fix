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
        $currentBytes = Read-OptionalFile (Join-Path $game $name)
        $current = if ($null -ne $currentBytes) { Get-BytesHash $currentBytes } else { $null }
        if ($current -ne $expected -and $current -ne $manifest.after.$name) { throw ('File changed after installation; restore stopped to preserve it: ' + $name) }
        $originals[$name] = $data
    }
    foreach ($name in $script:FileNames) {
        Write-AtomicFile (Join-Path $game $name) $originals[$name]
    }
    return 'Original files restored. Backup retained; savedata was not modified.'
}
