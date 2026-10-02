$script:Reference = @{
    exe_original_sha256 = '2c7a2231df58d82d9eba7b80038641ad716918f3159540c1f3d1a128d2e361f8'
    exe_patched_sha256 = 'c5bf3867b8617280f2c91c1b7f4ac183202923a200fcff0e414d36c6adb07847'
    plugin = @{ dll_sha256 = 'e9bd9a1f354b906b16201a24732d8ffd186cadc30e803dcf33281e297671ea69' }
}
$script:Offset = 0x2C82EA
$script:OldBytes = [byte[]](0x82,0x6C,0x82,0x72,0x20,0x82,0x6F,0x83,0x53,0x83,0x56,0x83,0x62,0x83,0x4E,0x00)
# The original literal is 16 bytes including its terminating zero.
$script:NewBytes = New-Object byte[] $script:OldBytes.Length
[Text.Encoding]::ASCII.GetBytes('MS PGothic').CopyTo($script:NewBytes, 0)

function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($i = 0; $i -lt $Left.Length; $i++) { if ($Left[$i] -ne $Right[$i]) { return $false } }
    return $true
}

function Test-ReferenceHash([byte[]]$Bytes, [string]$Expected, [string]$Label) {
    if ((Get-BytesHash $Bytes) -ne $Expected) {
        Write-Warning ($Label + ' differs from the tested build. Continuing; compatibility is unverified.')
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

function Install-GamePatch([string]$Folder, [string]$Plugin) {
    $game = Get-GameDirectory $Folder
    $exe = [IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.eXe'))
    if ((Get-ExecutableState $exe) -eq 'patched') {
        Test-ReferenceHash $exe $script:Reference.exe_patched_sha256 'Already-patched EXE'
        $installedPlugin = Read-OptionalFile (Join-Path $game 'utf8hack.tpm')
        if ($null -eq $installedPlugin) { throw 'EXE is patched, but utf8hack.tpm is missing.' }
        Test-ReferenceHash $installedPlugin $script:Reference.plugin.dll_sha256 'Installed plugin'
        $config = [IO.File]::ReadAllBytes((Join-Path $game 'yuusyatsuma.cf'))
        if (-not (Test-BytesEqual (Get-PatchedConfig $config) $config)) { throw 'EXE is patched, but readencoding is not configured.' }
        return 'Patch is already installed. No files changed.'
    }
    $backup = Join-Path $game $script:BackupName
    if (Test-Path -LiteralPath $backup) { throw 'A backup already exists. It will not be overwritten; restore or inspect it before installing again.' }
    if (-not [IO.File]::Exists($Plugin)) { throw 'Missing utf8hack.dll. Put it beside Apply.cmd in the game folder.' }
    $pluginBytes = [IO.File]::ReadAllBytes($Plugin)
    Test-ReferenceHash $pluginBytes $script:Reference.plugin.dll_sha256 'Selected plugin'
    $before = @{}
    foreach ($name in $script:FileNames) {
        $before[$name] = Read-OptionalFile (Join-Path $game $name)
    }
    if ($null -ne $before['utf8hack.tpm'] -and -not (Test-BytesEqual $before['utf8hack.tpm'] $pluginBytes)) {
        Write-Warning 'The existing utf8hack.tpm differs from the selected plugin; it will be backed up and replaced.'
    }
    Test-ReferenceHash $exe $script:Reference.exe_original_sha256 'Original EXE'
    $script:NewBytes.CopyTo($exe, $script:Offset)
    $after = @{
        'yuusyatsuma.eXe' = $exe
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
                Write-AtomicFile (Join-Path $game $name) $before[$name]
            } catch { $failures.Add($name) }
        }
        if ($failures.Count -gt 0) { throw ('Install failed. Backup retained; manual recovery required for: ' + ($failures -join ', ')) }
        throw ('Install failed. Completed writes were rolled back; backup retained. Reason: ' + $failureReason)
    }
    return ('Patch installed. Original files are in ' + $script:BackupName + '. Launch the game normally.')
}
