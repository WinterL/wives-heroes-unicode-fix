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
