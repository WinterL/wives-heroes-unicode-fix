#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'patch.ps1') -ImportOnly
$originalReference = $script:Reference
$originalHashes = @($script:OriginalHash,$script:PatchedHash,$script:PluginHash)
$script:TestCount = 0

function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw ('Assertion failed: ' + $Message) }
}
function Assert-Throws([scriptblock]$Operation, [string]$Pattern) {
    $caught = $false
    try { & $Operation | Out-Null }
    catch { $caught = $true; Assert-True ($_.Exception.Message -match $Pattern) $_.Exception.Message }
    Assert-True $caught ('Expected error: ' + $Pattern)
}
function Invoke-TestCase([string]$TestName, [scriptblock]$Body) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('unicode-fix-test-' + [Guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $temp
    $script:TestGame = Join-Path $temp 'Game folder'
    $null = New-Item -ItemType Directory -Path $script:TestGame
    $script:FixtureOriginal = New-Object byte[] ($script:Offset + $script:OldBytes.Length + 10)
    $script:FixtureOriginal[0] = 77
    $script:FixtureOriginal[1] = 90
    $script:OldBytes.CopyTo($script:FixtureOriginal, $script:Offset)
    $script:FixtureExpected = [byte[]]$script:FixtureOriginal.Clone()
    $script:NewBytes.CopyTo($script:FixtureExpected, $script:Offset)
    $script:FixtureConfig = [Text.Encoding]::ASCII.GetBytes("; keep settings`r`nfszoom=`"\x6E\x6F`"`r`n")
    $script:FixturePlugin = [Text.Encoding]::ASCII.GetBytes('synthetic test plugin')
    $script:TestPlugin = Join-Path $temp 'utf8hack.dll'
    [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe'), $script:FixtureOriginal)
    [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.cf'), $script:FixtureConfig)
    [IO.File]::WriteAllBytes($script:TestPlugin, $script:FixturePlugin)
    $null = New-Item -ItemType Directory -Path (Join-Path $script:TestGame 'savedata')
    [IO.File]::WriteAllText((Join-Path $script:TestGame 'savedata\save.txt'), 'preserve save')
    $archiveHashes = @{}
    foreach ($name in @('data.xp3','patch_1.xp3','patch_2.xp3')) {
        $bytes = [Text.Encoding]::ASCII.GetBytes('synthetic ' + $name)
        [IO.File]::WriteAllBytes((Join-Path $script:TestGame $name), $bytes)
        $archiveHashes[$name] = Get-BytesHash $bytes
    }
    $script:Reference = [pscustomobject]@{ archives_sha256 = [pscustomobject]$archiveHashes }
    $script:OriginalHash = Get-BytesHash $script:FixtureOriginal
    $script:PatchedHash = Get-BytesHash $script:FixtureExpected
    $script:PluginHash = Get-BytesHash $script:FixturePlugin
    $script:Notices.Clear()
    try {
        & $Body | Out-Null
        $script:TestCount++
        Write-Output ('PASS ' + $TestName)
    } finally {
        $resolved = [IO.Path]::GetFullPath($temp)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($resolved)).StartsWith('unicode-fix-test-')) {
            throw 'Temporary cleanup target is outside the test directory.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

try {
    Invoke-TestCase 'exact byte edit and unchanged length' {
        $result = Get-PatchedExecutable $script:FixtureOriginal
        Assert-True (Test-BytesEqual $result $script:FixtureExpected) 'Unexpected EXE bytes'
        Assert-True ($result.Length -eq $script:FixtureOriginal.Length) 'Changed length'
    }
    Invoke-TestCase 'different EXE hash warns and remains idempotent' {
        $different = [byte[]]$script:FixtureOriginal.Clone()
        $different[$different.Length - 1] = 42
        [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe'), $different)
        Install-GamePatch $script:TestGame $script:TestPlugin
        Assert-True ($script:Notices.Count -gt 0) 'Expected warning'
        $first = [IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe'))
        Install-GamePatch $script:TestGame $script:TestPlugin
        Assert-True (Test-BytesEqual $first ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe')))) 'Repeat install changed EXE'
        Restore-GamePatch $script:TestGame
        Assert-True (Test-BytesEqual $different ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe')))) 'Variant restore failed'
    }
    Invoke-TestCase 'unrecognized offset is refused before writes' {
        [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe'), [byte[]](77,90))
        Assert-Throws { Install-GamePatch $script:TestGame $script:TestPlugin } 'patch offset'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:TestGame $script:BackupName))) 'Backup should not exist'
    }
    Invoke-TestCase 'archive and plugin differences are warnings' {
        [IO.File]::WriteAllText((Join-Path $script:TestGame 'patch_2.xp3'), 'different archive')
        [IO.File]::WriteAllText($script:TestPlugin, 'different plugin')
        Install-GamePatch $script:TestGame $script:TestPlugin
        Assert-True ($script:Notices.Count -ge 2) 'Expected archive and plugin warnings'
        Assert-True (Test-BytesEqual ([IO.File]::ReadAllBytes($script:TestPlugin)) ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'utf8hack.tpm')))) 'Plugin not installed'
    }
    Invoke-TestCase 'config encoding BOM and newline preservation' {
        foreach ($encoding in @((New-Object Text.UTF8Encoding($false)), (New-Object Text.UTF8Encoding($true)), [Text.Encoding]::Unicode, [Text.Encoding]::BigEndianUnicode)) {
            $before = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes("; preserve`r`nother=`"value`"`r`n"))
            $after = Get-PatchedConfig $before
            Assert-True (Test-BytesEqual $before ([byte[]]$after[0..($before.Length - 1)])) 'Encoding or existing lines changed'
            Assert-True (Test-BytesEqual $after (Get-PatchedConfig $after)) 'Config not idempotent'
        }
        $before = [Text.Encoding]::ASCII.GetBytes("; readencoding=comment`nreadencoding=`"old`"`nother=`"keep`"")
        $after = [Text.Encoding]::ASCII.GetString((Get-PatchedConfig $before))
        Assert-True ($after.StartsWith("; readencoding=comment`n")) 'Comment changed'
        Assert-True ($after.EndsWith('other="keep"')) 'Last line changed'
    }
    Invoke-TestCase 'install backup restore and savedata preservation' {
        Install-GamePatch $script:TestGame $script:TestPlugin
        Get-PatchStatus $script:TestGame
        Restore-GamePatch $script:TestGame
        Restore-GamePatch $script:TestGame
        Assert-True (Test-BytesEqual $script:FixtureOriginal ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe')))) 'EXE restore failed'
        Assert-True (Test-BytesEqual $script:FixtureConfig ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.cf')))) 'Config restore failed'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:TestGame 'utf8hack.tpm'))) 'New plugin remained'
        Assert-True ([IO.File]::ReadAllText((Join-Path $script:TestGame 'savedata\save.txt')) -eq 'preserve save') 'Save changed'
        $manifest = [IO.File]::ReadAllText((Join-Path $script:TestGame '.unicode-fix-backup\manifest.json'))
        Assert-True (-not $manifest.Contains($script:TestGame)) 'Personal path recorded'
    }
    Invoke-TestCase 'existing different plugin is backed up and restored' {
        $bytes = [Text.Encoding]::ASCII.GetBytes('existing plugin')
        [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'utf8hack.tpm'), $bytes)
        Install-GamePatch $script:TestGame $script:TestPlugin
        Restore-GamePatch $script:TestGame
        Assert-True (Test-BytesEqual $bytes ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'utf8hack.tpm')))) 'Old plugin not restored'
    }
    Invoke-TestCase 'existing backup is preserved' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:TestGame $script:BackupName)
        Assert-Throws { Install-GamePatch $script:TestGame $script:TestPlugin } 'backup already exists'
    }
    Invoke-TestCase 'restore refuses changed files' {
        Install-GamePatch $script:TestGame $script:TestPlugin
        [IO.File]::AppendAllText((Join-Path $script:TestGame 'yuusyatsuma.cf'), '; later change')
        Assert-Throws { Restore-GamePatch $script:TestGame } 'changed after installation'
    }
    Invoke-TestCase 'restore refuses corrupt backups' {
        Install-GamePatch $script:TestGame $script:TestPlugin
        [IO.File]::WriteAllText((Join-Path $script:TestGame '.unicode-fix-backup\yuusyatsuma.eXe'), 'corrupt')
        Assert-Throws { Restore-GamePatch $script:TestGame } 'Backup checksum mismatch'
    }
    Invoke-TestCase 'failed install rolls back previous writes' {
        $locked = [IO.File]::Open((Join-Path $script:TestGame 'yuusyatsuma.cf'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { Assert-Throws { Install-GamePatch $script:TestGame $script:TestPlugin } 'rolled back' }
        finally { $locked.Dispose() }
        Assert-True (Test-BytesEqual $script:FixtureOriginal ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe')))) 'Partial EXE edit remained'
    }
    Invoke-TestCase 'status is read only' {
        Get-PatchStatus $script:TestGame
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:TestGame $script:BackupName))) 'Check created backup'
    }
    if ($env:PATCH_TEST_GAME_DIR -and $env:PATCH_TEST_PLUGIN) {
        Invoke-TestCase 'real EXE patch and restore in temporary copy' {
            $script:Reference = $originalReference
            $script:OriginalHash,$script:PatchedHash,$script:PluginHash = $originalHashes
            Test-GameArchives $env:PATCH_TEST_GAME_DIR
            $exe = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.eXe'))
            $config = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.cf'))
            [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe'), $exe)
            [IO.File]::WriteAllBytes((Join-Path $script:TestGame 'yuusyatsuma.cf'), $config)
            Install-GamePatch $script:TestGame $env:PATCH_TEST_PLUGIN
            Assert-True ((Get-FileHash -LiteralPath (Join-Path $script:TestGame 'yuusyatsuma.eXe')).Hash.ToLowerInvariant() -eq $script:PatchedHash) 'Real patched EXE differs from startup-tested version'
            Restore-GamePatch $script:TestGame
            Assert-True (Test-BytesEqual $exe ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.eXe')))) 'Real EXE restoration differs'
            Assert-True (Test-BytesEqual $config ([IO.File]::ReadAllBytes((Join-Path $script:TestGame 'yuusyatsuma.cf')))) 'Real config restoration differs'
        }
    }
    Write-Output ('All ' + $script:TestCount + ' native PowerShell tests passed.')
} finally {
    $script:Reference = $originalReference
    $script:OriginalHash,$script:PatchedHash,$script:PluginHash = $originalHashes
}
