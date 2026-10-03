# A self-made x86 PE for resource-editing tests; no game bytes are included.
function New-PatchFixtureBytes([string]$Manifest) {
    $fontOffset = 0x2C82EA
    $dataStart = 0x200
    $resourceStart = 0x2C8400
    $resourceRva = 0x2CA000
    $resourceSize = 0x1000
    $overlay = [Text.Encoding]::ASCII.GetBytes('TEST-OVERLAY-v1')
    $bytes = New-Object byte[] ($resourceStart + $resourceSize + $overlay.Length)
    function Put16([int]$At, [uint16]$Value) { [BitConverter]::GetBytes($Value).CopyTo($bytes, $At) }
    function Put32([int]$At, [uint32]$Value) { [BitConverter]::GetBytes($Value).CopyTo($bytes, $At) }

    $bytes[0] = 77; $bytes[1] = 90
    Put32 0x3C 0x80
    Put32 0x80 0x4550
    Put16 0x84 0x14C
    Put16 0x86 2
    Put16 0x94 0xE0
    Put16 0x96 0x103
    $optional = 0x98
    Put16 $optional 0x10B
    Put32 ($optional + 8) ($resourceStart - $dataStart + $resourceSize)
    Put32 ($optional + 24) 0x1000
    Put32 ($optional + 28) 0x400000
    Put32 ($optional + 32) 0x1000
    Put32 ($optional + 36) 0x200
    Put16 ($optional + 40) 6
    Put16 ($optional + 48) 6
    Put32 ($optional + 56) ($resourceRva + $resourceSize)
    Put32 ($optional + 60) $dataStart
    Put16 ($optional + 68) 3
    Put32 ($optional + 72) 0x100000
    Put32 ($optional + 76) 0x1000
    Put32 ($optional + 80) 0x100000
    Put32 ($optional + 84) 0x1000
    Put32 ($optional + 92) 16
    Put32 ($optional + 112) $resourceRva

    $section = 0x178
    [Text.Encoding]::ASCII.GetBytes('.data').CopyTo($bytes, $section)
    Put32 ($section + 8) ($resourceStart - $dataStart)
    Put32 ($section + 12) 0x1000
    Put32 ($section + 16) ($resourceStart - $dataStart)
    Put32 ($section + 20) $dataStart
    Put32 ($section + 36) 3221225536
    $section += 40
    [Text.Encoding]::ASCII.GetBytes('.rsrc').CopyTo($bytes, $section)
    Put32 ($section + 8) $resourceSize
    Put32 ($section + 12) $resourceRva
    Put32 ($section + 16) $resourceSize
    Put32 ($section + 20) $resourceStart
    Put32 ($section + 36) 1073741888
    [byte[]]$font = 0x82,0x6C,0x82,0x72,0x20,0x82,0x6F,0x83,0x53,0x83,0x56,0x83,0x62,0x83,0x4E,0
    $font.CopyTo($bytes, $fontOffset)

    $items = @(@{ Type = 10; Bytes = [Text.Encoding]::ASCII.GetBytes('TEST-RCDATA-v1') })
    if (-not [string]::IsNullOrEmpty($Manifest)) {
        $items += @{ Type = 24; Bytes = [Text.Encoding]::UTF8.GetBytes($Manifest) }
    }
    Put16 ($resourceStart + 14) $items.Count
    $payloadOffset = 16 + 8 * $items.Count + 64 * $items.Count
    foreach ($index in 0..($items.Count - 1)) {
        $item = $items[$index]
        $nameDirectory = 16 + 8 * $items.Count + 64 * $index
        $languageDirectory = $nameDirectory + 24
        $dataEntry = $nameDirectory + 48
        Put32 ($resourceStart + 16 + 8 * $index) $item.Type
        Put32 ($resourceStart + 20 + 8 * $index) (2147483648 + $nameDirectory)
        Put16 ($resourceStart + $nameDirectory + 14) 1
        Put32 ($resourceStart + $nameDirectory + 16) 1
        Put32 ($resourceStart + $nameDirectory + 20) (2147483648 + $languageDirectory)
        Put16 ($resourceStart + $languageDirectory + 14) 1
        Put32 ($resourceStart + $languageDirectory + 16) 0x409
        Put32 ($resourceStart + $languageDirectory + 20) $dataEntry
        Put32 ($resourceStart + $dataEntry) ($resourceRva + $payloadOffset)
        Put32 ($resourceStart + $dataEntry + 4) $item.Bytes.Length
        if ($payloadOffset + $item.Bytes.Length -gt $resourceSize) { throw 'Fixture manifest exceeds resource padding.' }
        $item.Bytes.CopyTo($bytes, $resourceStart + $payloadOffset)
        $payloadOffset = [int]([Math]::Ceiling(($payloadOffset + $item.Bytes.Length) / 4.0) * 4)
    }
    Put32 ($optional + 116) $resourceSize
    $overlay.CopyTo($bytes, $resourceStart + $resourceSize)
    return ,$bytes
}

function Read-FixtureRcData([string]$Path) {
    if (-not ('FixtureRcData' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class FixtureRcData {
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string p,IntPtr h,uint f);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr h);
    [DllImport("kernel32.dll",EntryPoint="FindResourceExW",SetLastError=true)] static extern IntPtr Find(IntPtr h,IntPtr t,IntPtr n,ushort l);
    [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr h,IntPtr r);
    [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr h,IntPtr r);
    [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr r);
    public static byte[] Read(string path) {
        IntPtr h = LoadLibraryEx(path,IntPtr.Zero,2);
        if (h == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            IntPtr r = Find(h,(IntPtr)10,(IntPtr)1,0x409);
            if (r == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            byte[] bytes = new byte[SizeofResource(h,r)];
            Marshal.Copy(LockResource(LoadResource(h,r)),bytes,0,bytes.Length);
            return bytes;
        } finally { FreeLibrary(h); }
    }
}
'@
    }
    return ,([FixtureRcData]::Read($Path))
}
