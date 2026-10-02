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
