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

# Resource APIs are used on a temporary data file; the game is never executed.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class UnicodeFixResources {
    public class Manifest { public ushort Language; public byte[] Bytes; }
    delegate bool EnumLang(IntPtr h, IntPtr type, IntPtr name, ushort lang, IntPtr p);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool EnumResourceLanguages(IntPtr h, IntPtr type, IntPtr name, EnumLang callback, IntPtr p);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr FindResourceEx(IntPtr h, IntPtr type, IntPtr name, ushort lang);
    [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr h, IntPtr resource);
    [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr h, IntPtr resource);
    [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr BeginUpdateResource(string path, bool deleteExisting);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] bytes, uint size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool EndUpdateResource(IntPtr h, bool discard);
    static void Check(bool success) { if (!success) throw new Win32Exception(Marshal.GetLastWin32Error()); }
    public static Manifest Read(string path) {
        IntPtr h = LoadLibraryEx(path, IntPtr.Zero, 0x22);
        if (h == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            int count = 0;
            ushort language = 0;
            EnumLang callback = (m, t, n, lang, p) => { count++; language=lang; return true; };
            if (!EnumResourceLanguages(h, (IntPtr)24, (IntPtr)1, callback, IntPtr.Zero)) {
                int error = Marshal.GetLastWin32Error();
                if (error == 1813 || error == 1814) return null;
                throw new Win32Exception(error);
            }
            if (count != 1) throw new Exception("Multiple application manifest languages are unsupported.");
            IntPtr r = FindResourceEx(h, (IntPtr)24, (IntPtr)1, language);
            if (r == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            byte[] bytes = new byte[SizeofResource(h, r)];
            Marshal.Copy(LockResource(LoadResource(h, r)), bytes, 0, bytes.Length);
            return new Manifest { Language=language, Bytes=bytes };
        } finally { FreeLibrary(h); }
    }
    public static void Write(string path, ushort language, byte[] bytes) {
        IntPtr h = BeginUpdateResource(path, false);
        if (h == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            Check(UpdateResource(h, (IntPtr)24, (IntPtr)1, language, bytes, (uint)bytes.Length));
            Check(EndUpdateResource(h, false)); h = IntPtr.Zero;
        } finally { if (h != IntPtr.Zero) EndUpdateResource(h, true); }
    }
}
'@

function Get-ResourceSection([byte[]]$Bytes) {
    if ($Bytes.Length -lt 64 -or [BitConverter]::ToUInt16($Bytes,0) -ne 0x5A4D) { throw 'Unsupported EXE: invalid DOS header.' }
    $pe = [BitConverter]::ToInt32($Bytes, 0x3c)
    if ($pe -lt 64 -or $pe -gt $Bytes.Length-24 -or [BitConverter]::ToUInt32($Bytes,$pe) -ne 0x4550) { throw 'Unsupported EXE: invalid PE header.' }
    $count = [BitConverter]::ToUInt16($Bytes,$pe+6)
    $optionalSize = [BitConverter]::ToUInt16($Bytes,$pe+20)
    $optional = $pe+24
    if ($optionalSize -lt 120 -or $optional+$optionalSize -gt $Bytes.Length -or [BitConverter]::ToUInt16($Bytes,$pe+4) -ne 0x14C -or [BitConverter]::ToUInt16($Bytes,$optional) -ne 0x10B -or [BitConverter]::ToUInt32($Bytes,$optional+92) -lt 3) { throw 'Unsupported EXE: expected x86 PE32.' }
    $resourceRva = [BitConverter]::ToUInt32($Bytes,$optional+112)
    $resourceSize = [BitConverter]::ToUInt32($Bytes,$optional+116)
    $table = $optional + $optionalSize
    if ($table + $count*40 -gt $Bytes.Length) { throw 'Unsupported EXE: invalid section table.' }
    $found = @()
    for ($i=0; $i -lt $count; $i++) {
        $s = $table + $i*40
        if ([Text.Encoding]::ASCII.GetString($Bytes,$s,8).TrimEnd([char]0) -ne '.rsrc') { continue }
        $size = [BitConverter]::ToUInt32($Bytes,$s+16)
        $offset = [BitConverter]::ToUInt32($Bytes,$s+20)
        if ($offset -lt $table+$count*40 -or [long]$offset+$size -gt $Bytes.Length) { throw 'Unsupported EXE: invalid resource range.' }
        $rva = [BitConverter]::ToUInt32($Bytes,$s+12)
        if ($resourceRva -ne $rva -or $resourceSize -lt 16 -or $resourceSize -gt $size) { throw 'Unsupported EXE: invalid resource directory.' }
        $found += @{ Offset=$offset; Size=$size; RVA=$rva; DirectorySize=$resourceSize }
    }
    if ($found.Count -ne 1) { throw 'Unsupported EXE: expected one .rsrc section.' }
    return $found[0]
}

function Get-DpiAwareExecutable([byte[]]$Bytes) {
    $section = Get-ResourceSection $Bytes
    $temporary = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        $existing = [UnicodeFixResources]::Read($temporary)
        $doc = New-Object Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        $doc.XmlResolver = $null
        $language = [UInt16]0
        if ($existing) {
            $language = $existing.Language
            $stream = New-Object IO.MemoryStream(,$existing.Bytes)
            try { $doc.Load($stream) } finally { $stream.Dispose() }
        } else {
            $doc.LoadXml('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><assemblyIdentity type="win32" name="ToTheWivesWhoWereHeroes.Game" version="1.0.0.0" processorArchitecture="x86"/></assembly>')
        }
        $ns = New-Object Xml.XmlNamespaceManager($doc.NameTable)
        $ns.AddNamespace('a','urn:schemas-microsoft-com:asm.v1')
        $ns.AddNamespace('v3','urn:schemas-microsoft-com:asm.v3')
        $ns.AddNamespace('dpi','http://schemas.microsoft.com/SMI/2005/WindowsSettings')
        $ns.AddNamespace('dpi16','http://schemas.microsoft.com/SMI/2016/WindowsSettings')
        if (-not $doc.SelectSingleNode('/a:assembly',$ns)) { throw 'Unsupported application manifest root.' }
        $awareness = $doc.SelectNodes('/a:assembly/v3:application/v3:windowsSettings/dpi:dpiAware | /a:assembly/v3:application/v3:windowsSettings/dpi16:dpiAwareness',$ns)
        if ($awareness.Count -ne $doc.SelectNodes('//dpi:dpiAware | //dpi16:dpiAwareness',$ns).Count -or $doc.SelectNodes('/a:assembly/v3:application',$ns).Count -gt 1) { throw 'Unsupported DPI manifest structure.' }
        if ($awareness.Count -gt 0) {
            foreach ($node in $awareness) {
                $expected = if ($node.LocalName -eq 'dpiAware') { 'true' } else { 'system' }
                if ($node.InnerText.Trim() -ine $expected) { throw 'Existing manifest requests a different DPI mode; no files changed.' }
            }
            return ,$Bytes
        }
        $app = $doc.SelectSingleNode('/a:assembly/v3:application',$ns)
        if (-not $app) { $app=$doc.CreateElement('application','urn:schemas-microsoft-com:asm.v3'); $null=$doc.DocumentElement.AppendChild($app) }
        $settings = $app.SelectSingleNode('v3:windowsSettings',$ns)
        if (-not $settings) { $settings=$doc.CreateElement('windowsSettings','urn:schemas-microsoft-com:asm.v3'); $null=$app.AppendChild($settings) }
        $dpi = $doc.CreateElement('dpiAware','http://schemas.microsoft.com/SMI/2005/WindowsSettings')
        $dpi.InnerText = 'true'
        $null = $settings.AppendChild($dpi)
        $stream = New-Object IO.MemoryStream
        try { $doc.Save($stream); $xml=$stream.ToArray() } finally { $stream.Dispose() }
        [UnicodeFixResources]::Write($temporary,$language,$xml)
        $updated = [IO.File]::ReadAllBytes($temporary)
        $newSection = Get-ResourceSection $updated
        if ($newSection.RVA -ne $section.RVA -or $newSection.Size -gt $section.Size -or $newSection.DirectorySize -gt $section.DirectorySize) { throw 'Updated resources do not fit the original EXE; no files changed.' }
        # Windows resource updates discard KiriKiri's trailing XOPT options.
        # Copy only .rsrc back, retaining every other byte and original offset.
        $result = [byte[]]$Bytes.Clone()
        [Array]::Copy($updated,$newSection.Offset,$result,$section.Offset,$newSection.Size)
        return ,$result
    } finally { [IO.File]::Delete($temporary) }
}

$script:Reference = @{
    exe_original_sha256 = '2c7a2231df58d82d9eba7b80038641ad716918f3159540c1f3d1a128d2e361f8'
    exe_legacy_sha256 = 'c5bf3867b8617280f2c91c1b7f4ac183202923a200fcff0e414d36c6adb07847'
    exe_patched_sha256 = '1206454d5c5daae496b5a2eb619c04dd392865706b1b7b6ddede650c2f107a4a'
    plugin = @{ dll_sha256 = 'e9bd9a1f354b906b16201a24732d8ffd186cadc30e803dcf33281e297671ea69' }
}
$script:Offset = 0x2C82EA
$script:OldBytes = [byte[]](0x82,0x6C,0x82,0x72,0x20,0x82,0x6F,0x83,0x53,0x83,0x56,0x83,0x62,0x83,0x4E,0x00)
# The original literal is 16 bytes including its terminating zero.
$script:NewBytes = New-Object byte[] $script:OldBytes.Length
[Text.Encoding]::ASCII.GetBytes('MS PGothic').CopyTo($script:NewBytes, 0)

function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    return [Convert]::ToBase64String($Left) -ceq [Convert]::ToBase64String($Right)
}

function Test-ReferenceHash([byte[]]$Bytes, [string[]]$Expected, [string]$Label) {
    if ($Expected -notcontains (Get-BytesHash $Bytes)) {
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
    $settings = [ordered]@{
        readencoding = '\x53\x68\x69\x66\x74\x5F\x4A\x49\x53'
        fsres = '\x6E\x6F\x63\x68\x61\x6E\x67\x65'
        fszoom = '\x69\x6E\x6E\x65\x72'
    }
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    foreach ($name in $settings.Keys) {
        $setting = $name + '="' + $settings[$name] + '"'
        $pattern = '(?m)^[ \t]*' + $name + '[ \t]*=[^\r\n]*'
        if ([regex]::IsMatch($text, $pattern)) { $text = [regex]::Replace($text, $pattern, $setting) }
        else {
            if ($text.Length -gt 0 -and -not ($text.EndsWith("`n") -or $text.EndsWith("`r"))) { $text += $newline }
            $text += $setting + $newline
        }
    }
    $payload = $encoding.GetBytes($text)
    $result = New-Object byte[] ($bomLength + $payload.Length)
    if ($bomLength -gt 0) { [Array]::Copy($Bytes, 0, $result, 0, $bomLength) }
    $payload.CopyTo($result, $bomLength)
    return ,$result
}

function Install-GamePatch([string]$Folder, [string]$Plugin) {
    $game = Get-GameDirectory $Folder
    $before = @{}
    foreach ($name in $script:FileNames) { $before[$name] = Read-OptionalFile (Join-Path $game $name) }
    $exe = [byte[]]$before['yuusyatsuma.eXe'].Clone()
    $upgrade = (Get-ExecutableState $exe) -eq 'patched'
    $backup = Join-Path $game $script:BackupName
    if (-not $upgrade -and (Test-Path -LiteralPath $backup)) { throw 'A backup already exists. Restore it before installing again.' }
    $pluginBytes = Read-OptionalFile $Plugin
    if ($null -eq $pluginBytes -and $upgrade) { $pluginBytes = $before['utf8hack.tpm'] }
    if ($null -eq $pluginBytes) { throw 'Missing utf8hack.dll. Put it beside Apply.cmd in the game folder.' }
    Test-ReferenceHash $pluginBytes $script:Reference.plugin.dll_sha256 'Plugin'
    if ($null -ne $before['utf8hack.tpm'] -and -not (Test-BytesEqual $before['utf8hack.tpm'] $pluginBytes)) {
        Write-Warning 'The existing utf8hack.tpm differs from the selected plugin; it will be backed up and replaced.'
    }
    $expectedHashes = if ($upgrade) { @($script:Reference.exe_legacy_sha256,$script:Reference.exe_patched_sha256) } else { $script:Reference.exe_original_sha256 }
    Test-ReferenceHash $exe $expectedHashes 'EXE'
    $script:NewBytes.CopyTo($exe, $script:Offset)
    $after = @{
        'yuusyatsuma.eXe' = Get-DpiAwareExecutable $exe
        'yuusyatsuma.cf' = Get-PatchedConfig $before['yuusyatsuma.cf']
        'utf8hack.tpm' = $pluginBytes
    }
    $changed = @($script:FileNames | Where-Object {
        $null -eq $before[$_] -or -not (Test-BytesEqual $after[$_] $before[$_])
    })
    if ($changed.Count -eq 0) { return 'Patch is already installed. No files changed.' }
    $manifestPath = Join-Path $backup 'manifest.json'
    if ($upgrade) {
        if (-not (Test-Path -LiteralPath $backup)) { throw 'The original backup is required to upgrade this patch.' }
        $saved = Read-PatchBackup $game
        $manifest = $saved.Manifest
        foreach ($name in $script:FileNames) {
            if ($null -eq $before[$name] -or (Get-BytesHash $before[$name]) -ne $manifest.after.$name) { throw ('File changed after installation; upgrade stopped to preserve it: ' + $name) }
        }
    } else {
        $null = New-Item -ItemType Directory -Path $backup
        $manifest = @{ format=1; before=@{}; after=@{} }
        foreach ($name in $script:FileNames) {
            if ($null -ne $before[$name]) {
                Write-AtomicFile (Join-Path $backup $name) $before[$name]
                $manifest.before[$name] = Get-BytesHash $before[$name]
            } else { $manifest.before[$name] = $null }
        }
    }
    foreach ($name in $script:FileNames) { $manifest.after.$name = Get-BytesHash $after[$name] }
    $manifestBytes = [Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 4))
    if (-not $upgrade) { Write-AtomicFile $manifestPath $manifestBytes }
    $written = New-Object 'System.Collections.Generic.List[string]'
    $manifestWritten = $false
    try {
        foreach ($name in $changed) {
            Write-AtomicFile (Join-Path $game $name) $after[$name]
            $written.Add($name)
        }
        foreach ($name in $script:FileNames) {
            if (-not (Test-BytesEqual ([IO.File]::ReadAllBytes((Join-Path $game $name))) $after[$name])) { throw ('Written file verification failed: ' + $name) }
        }
        if ($upgrade) {
            Write-AtomicFile $manifestPath $manifestBytes
            $manifestWritten = $true
            if (-not (Test-BytesEqual ([IO.File]::ReadAllBytes($manifestPath)) $manifestBytes)) { throw 'Updated backup manifest verification failed.' }
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
        if ($manifestWritten) {
            try { Write-AtomicFile $manifestPath $saved.Bytes }
            catch { $failures.Add('backup manifest') }
        }
        if ($failures.Count -gt 0) { throw ('Install failed. Backup retained; manual recovery required for: ' + ($failures -join ', ')) }
        throw ('Install failed. Completed writes were rolled back; backup retained. Reason: ' + $failureReason)
    }
    return ('Patch installed. Original files are in ' + $script:BackupName + '. Launch the game normally.')
}

try {
    $game = [IO.Path]::GetDirectoryName($env:UNICODE_FIX_CMD)
    Install-GamePatch $game (Join-Path $game 'utf8hack.dll')
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 1
}
