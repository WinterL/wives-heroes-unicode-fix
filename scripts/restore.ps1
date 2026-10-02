function Restore-GamePatch([string]$Folder) {
    $game = Get-GameDirectory $Folder
    $backup = Join-Path $game $script:BackupName
    if (-not (Test-Path -LiteralPath $backup)) { return 'No backup found. Nothing to restore.' }
    $backupItem = Get-Item -LiteralPath $backup
    if (-not $backupItem.PSIsContainer -or $backupItem.FullName -ne $backup -or ($backupItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Backup must be a normal directory directly inside the game folder.' }
    $entries = @(Get-ChildItem -LiteralPath $backup -Force)
    foreach ($entry in $entries) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Backup contains a directory or symbolic link; no files changed.' }
    }
    $manifestPath = Join-Path $backup 'manifest.json'
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
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
    $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
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
    foreach ($name in $script:FileNames) {
        $bytes = Read-OptionalFile (Join-Path $game $name)
        $actual = if ($null -ne $bytes) { Get-BytesHash $bytes } else { $null }
        if ($actual -ne $manifest.before.$name) { throw ('Restored file verification failed; backup retained: ' + $name) }
    }
    try {
        foreach ($name in $ownedNames) { [IO.File]::Delete((Join-Path $backup $name)) }
        [IO.Directory]::Delete($backup, $false)
    } catch {
        # If cleanup stopped halfway, replace only the backup files already removed.
        try {
            foreach ($name in $ownedNames) {
                $path = Join-Path $backup $name
                if (-not [IO.File]::Exists($path)) {
                    $bytes = if ($name -eq 'manifest.json') { $manifestBytes } else { $originals[$name] }
                    Write-AtomicFile $path $bytes
                }
            }
        } catch { throw 'Original files restored, but backup cleanup is incomplete. Keep the restored game files; backup repair failed.' }
        throw 'Original files restored; backup retained because cleanup failed. Close programs using the backup and run Restore.cmd again.'
    }
    return 'Original files restored and backup removed. You can run Apply.cmd again.'
}
