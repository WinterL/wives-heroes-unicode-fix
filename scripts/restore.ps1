function Restore-GamePatch([string]$Folder) {
    $game = Get-GameDirectory $Folder
    $backup = Join-Path $game $script:BackupName
    if (-not (Test-Path -LiteralPath $backup)) { return 'No backup found. Nothing to restore.' }
    $saved = Read-PatchBackup $game
    $manifest = $saved.Manifest
    $ownedNames = $saved.Names
    $originals = $saved.Originals
    foreach ($name in $script:FileNames) {
        $expected = $manifest.before.$name
        $currentBytes = Read-OptionalFile (Join-Path $game $name)
        $current = if ($null -ne $currentBytes) { Get-BytesHash $currentBytes } else { $null }
        if ($current -ne $expected -and $current -ne $manifest.after.$name) { throw ('File changed after installation; restore stopped to preserve it: ' + $name) }
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
                    $bytes = if ($name -eq 'manifest.json') { $saved.Bytes } else { $originals[$name] }
                    Write-AtomicFile $path $bytes
                }
            }
        } catch { throw 'Original files restored, but backup cleanup is incomplete. Keep the restored game files; backup repair failed.' }
        throw 'Original files restored; backup retained because cleanup failed. Close programs using the backup and run Restore.cmd again.'
    }
    return 'Original files restored and backup removed. You can run Apply.cmd again.'
}
