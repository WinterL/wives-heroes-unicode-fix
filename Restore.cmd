@echo off
setlocal DisableDelayedExpansion
set "UNICODE_FIX_CMD=%~f0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$text = [IO.File]::ReadAllText($env:UNICODE_FIX_CMD); $payload = [regex]::Split($text, '(?m)^# POWERSHELL PAYLOAD\r?$')[1]; & ([scriptblock]::Create($payload))"
set "patch_exit=%errorlevel%"
if /i not "%~1"=="--no-pause" pause
exit /b %patch_exit%
# POWERSHELL PAYLOAD
<#
MIT License

Copyright (c) 2026 wives-heroes-unicode-fix contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

#>
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

try {
    $game = [IO.Path]::GetDirectoryName($env:UNICODE_FIX_CMD)
    Restore-GamePatch $game
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 1
}
