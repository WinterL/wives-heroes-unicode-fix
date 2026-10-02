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
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
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

try {
    $game = [IO.Path]::GetDirectoryName($env:UNICODE_FIX_CMD)
    Restore-GamePatch $game
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 1
}
