#requires -Version 5.1
# Standalone behavior tests; no Pester or installed game is required.
$ErrorActionPreference = 'Stop'
foreach ($module in @('common','dpi','apply','restore')) { . (Join-Path $PSScriptRoot ('..\scripts\' + $module + '.ps1')) }
. (Join-Path $PSScriptRoot 'new-fixture.ps1')
$originalReference = $script:Reference
$repoRoot = Split-Path -Parent $PSScriptRoot
$script:TestCount = 0
$suiteClock = [Diagnostics.Stopwatch]::StartNew()
$script:Fixture = New-PatchFixtureBytes
$script:FixtureHash = Get-BytesHash $script:Fixture

function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw ('Assertion failed: ' + $Message) }
}
function Test-ExpectedBytes([byte[]]$Left, [byte[]]$Right) {
    return $Left.Length -eq $Right.Length -and [Convert]::ToBase64String($Left) -ceq [Convert]::ToBase64String($Right)
}
function Assert-Throws([scriptblock]$Operation, [string]$Pattern) {
    try { & $Operation | Out-Null }
    catch { Assert-True ($_.Exception.Message -match $Pattern) $_.Exception.Message; return }
    throw ('Expected error: ' + $Pattern)
}
function Invoke-Packaged([string]$Action, [int]$ExpectedExit = 0) {
    $target = Join-Path $script:Game ($Action + '.cmd')
    Copy-Item -LiteralPath (Join-Path $repoRoot ($Action + '.cmd')) -Destination $target
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $env:ComSpec
    $start.Arguments = '/d /s /c ""' + $target + '" --no-pause"'
    $start.WorkingDirectory = [IO.Path]::GetTempPath()
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Packaged command timed out.' }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        Assert-True ($process.ExitCode -eq $ExpectedExit) $output
        return $output
    } finally { $process.Dispose() }
}
function Invoke-TestCase([string]$TestName, [scriptblock]$Body, [switch]$WithoutGame) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('unicode-fix-test-' + [Guid]::NewGuid().ToString('N'))
    $script:Game = Join-Path $temp ("Game & O'Brien ! " + [char]0x904A + [char]0x6232)
    $null = New-Item -ItemType Directory -Path $script:Game
    $script:ExePath = Join-Path $script:Game 'yuusyatsuma.eXe'
    $script:ConfigPath = Join-Path $script:Game 'yuusyatsuma.cf'
    $script:Plugin = Join-Path $script:Game 'utf8hack.dll'
    $script:Original = $script:Fixture
    $script:Config = [Text.Encoding]::ASCII.GetBytes("; keep settings`r`nfszoom=`"\x6E\x6F`"`r`n")
    if (-not $WithoutGame) {
        [IO.File]::WriteAllBytes($script:ExePath, $script:Original)
        [IO.File]::WriteAllBytes($script:ConfigPath, $script:Config)
        [IO.File]::WriteAllText($script:Plugin, 'synthetic plugin')
        $null = New-Item -ItemType Directory -Path (Join-Path $script:Game 'savedata')
        [IO.File]::WriteAllText((Join-Path $script:Game 'savedata\save.txt'), 'preserve save')
        $script:Reference = [pscustomobject]@{
            exe_original_sha256 = $script:FixtureHash
            exe_patched_sha256 = $null
            exe_legacy_sha256 = $null
            plugin = [pscustomobject]@{ dll_sha256 = (Get-FileHash -LiteralPath $script:Plugin).Hash }
        }
    }
    try { & $Body | Out-Null; $script:TestCount++; Write-Output ('PASS ' + $TestName) }
    finally {
        $resolved = [IO.Path]::GetFullPath($temp)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($resolved)).StartsWith('unicode-fix-test-')) { throw 'Unsafe test cleanup path.' }
        if (@((Get-Item -LiteralPath $resolved -Force)) + @(Get-ChildItem -LiteralPath $resolved -Recurse -Force) | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Unexpected link in test cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $script:Reference = $originalReference
    }
}

function New-LegacyInstallation {
    $backup = Join-Path $script:Game $script:BackupName
    $null = New-Item -ItemType Directory -Path $backup
    $manifest = @{ format=1; before=@{}; after=@{} }
    foreach ($name in $script:FileNames) {
        $bytes = Read-OptionalFile (Join-Path $script:Game $name)
        $manifest.before[$name] = if ($null -ne $bytes) { Get-BytesHash $bytes } else { $null }
        if ($null -ne $bytes) { [IO.File]::WriteAllBytes((Join-Path $backup $name),$bytes) }
    }
    $legacy = [IO.File]::ReadAllBytes($script:ExePath)
    $script:NewBytes.CopyTo($legacy,$script:Offset)
    [IO.File]::WriteAllBytes($script:ExePath,$legacy)
    $config = [byte[]]([IO.File]::ReadAllBytes($script:ConfigPath) + [Text.Encoding]::ASCII.GetBytes("`r`nreadencoding=`"\x53\x68\x69\x66\x74\x5F\x4A\x49\x53`"`r`n"))
    [IO.File]::WriteAllBytes($script:ConfigPath,$config)
    Copy-Item -LiteralPath $script:Plugin -Destination (Join-Path $script:Game 'utf8hack.tpm')
    foreach ($name in $script:FileNames) { $manifest.after[$name] = (Get-FileHash -LiteralPath (Join-Path $script:Game $name)).Hash }
    [IO.File]::WriteAllText((Join-Path $backup 'manifest.json'),($manifest | ConvertTo-Json -Depth 4))
}

Invoke-TestCase 'configuration preserves encoding, BOM, unrelated lines and newline style' {
    foreach ($encoding in @((New-Object Text.UTF8Encoding($false)), (New-Object Text.UTF8Encoding($true)), [Text.Encoding]::Unicode, [Text.Encoding]::BigEndianUnicode)) {
        $before = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes('; ' + [char]0x904A + " preserve`r`nother=`"value`"`r`n"))
        $after = Get-PatchedConfig $before
        Assert-True (Test-ExpectedBytes $before ([byte[]]$after[0..($before.Length - 1)])) 'Existing bytes changed'
        Assert-True (Test-ExpectedBytes $after (Get-PatchedConfig $after)) 'Config not idempotent'
    }
    $before = [Text.Encoding]::ASCII.GetBytes("; comment`nreadencoding=`"old`"`nfsres=`"old`"`nfszoom=`"old`"`nother=`"keep`"")
    $expected = [Text.Encoding]::ASCII.GetBytes("; comment`nreadencoding=`"\x53\x68\x69\x66\x74\x5F\x4A\x49\x53`"`nfsres=`"\x6E\x6F\x63\x68\x61\x6E\x67\x65`"`nfszoom=`"\x69\x6E\x6E\x65\x72`"`nother=`"keep`"")
    Assert-True (Test-ExpectedBytes $expected (Get-PatchedConfig $before)) 'Generic settings replacement changed unrelated text or line endings'
} -WithoutGame
Invoke-TestCase 'unsafe marker and existing backup are refused before writes' {
    Remove-Item -LiteralPath $script:Plugin
    Assert-True ((Invoke-Packaged Apply 1) -match 'Missing utf8hack.dll') 'Missing DLL message unclear'
    Remove-Item -LiteralPath $script:ExePath
    Assert-True ((Invoke-Packaged Apply 1) -match 'Missing yuusyatsuma.eXe') 'Wrong-folder message unclear'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Invalid location created backup'
    [IO.File]::WriteAllText($script:Plugin, 'synthetic plugin')
    $unknownMarker = [byte[]]$script:Original.Clone()
    $unknownMarker[0x2C82EA] = 0
    [IO.File]::WriteAllBytes($script:ExePath, $unknownMarker)
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'patch offset'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Invalid EXE created backup'
    $invalidPe = [byte[]]$script:Original.Clone()
    $invalidPe[0] = 0
    [IO.File]::WriteAllBytes($script:ExePath,$invalidPe)
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'invalid DOS header'
    $invalidPe = [byte[]]$script:Original.Clone()
    [BitConverter]::GetBytes([UInt32]::MaxValue).CopyTo($invalidPe,0x178+40+16)
    [IO.File]::WriteAllBytes($script:ExePath,$invalidPe)
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'invalid resource range'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Invalid PE geometry created backup'
    [IO.File]::WriteAllBytes($script:ExePath, $script:Original)
    $null = New-Item -ItemType Directory -Path (Join-Path $script:Game $script:BackupName)
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'backup already exists'
}
Invoke-TestCase 'restore preserves later edits and refuses corrupt backups before writes' {
    Install-GamePatch $script:Game $script:Plugin
    $backup = Join-Path $script:Game $script:BackupName
    $manifestPath = Join-Path $backup 'manifest.json'
    $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
    $patched = [IO.File]::ReadAllBytes($script:ExePath)
    $patchedConfig = [IO.File]::ReadAllBytes($script:ConfigPath)
    [IO.File]::AppendAllText($script:ConfigPath, '; later change')
    Assert-Throws { Restore-GamePatch $script:Game } 'changed after installation'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:Game '.unicode-fix-backup\manifest.json')) 'Conflict removed backup'
    Assert-True (Test-ExpectedBytes $patched ([IO.File]::ReadAllBytes($script:ExePath))) 'Partial restore occurred'
    [IO.File]::WriteAllBytes($script:ConfigPath, $patchedConfig)
    $extra = Join-Path $backup 'notes.txt'
    [IO.File]::WriteAllText($extra, 'user file')
    Assert-Throws { Restore-GamePatch $script:Game } 'unexpected or missing files'
    Assert-True ([IO.File]::ReadAllText($extra) -eq 'user file') 'Unexpected backup file changed'
    Remove-Item -LiteralPath $extra
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifest.before.'yuusyatsuma.eXe' = $null
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 4))
    Assert-Throws { Restore-GamePatch $script:Game } 'valid backup manifest'
    Assert-True (Test-ExpectedBytes $patched ([IO.File]::ReadAllBytes($script:ExePath))) 'Invalid manifest changed game'
    [IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
    [IO.File]::WriteAllText((Join-Path $script:Game '.unicode-fix-backup\yuusyatsuma.eXe'), 'corrupt')
    Assert-Throws { Restore-GamePatch $script:Game } 'Backup checksum mismatch'
    Assert-True (Test-Path -LiteralPath (Join-Path $script:Game '.unicode-fix-backup\manifest.json')) 'Corrupt backup was removed'
    Assert-True (Test-ExpectedBytes $patched ([IO.File]::ReadAllBytes($script:ExePath))) 'Corrupt backup changed EXE'
}
Invoke-TestCase 'failed install rolls back; interrupted backup cleanup can be retried' {
    $locked = [IO.File]::Open($script:ConfigPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'rolled back' }
    finally { $locked.Dispose() }
    Assert-True (Test-ExpectedBytes $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Partial EXE edit remained'
    Assert-True (Test-ExpectedBytes $script:Config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Failed install changed config'
    $backup = Join-Path $script:Game $script:BackupName
    $locked = [IO.File]::Open((Join-Path $backup 'yuusyatsuma.cf'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { Assert-Throws { Restore-GamePatch $script:Game } 'backup retained because cleanup failed' }
    finally { $locked.Dispose() }
    Assert-True (Test-ExpectedBytes $script:Original ([IO.File]::ReadAllBytes((Join-Path $backup 'yuusyatsuma.eXe')))) 'Cleanup failure lost original EXE backup'
    Restore-GamePatch $script:Game
    Assert-True (-not (Test-Path -LiteralPath $backup)) 'Retry did not remove backup'
}
if ($env:PATCH_TEST_GAME_DIR -and $env:PATCH_TEST_PLUGIN) {
    Invoke-TestCase 'real EXE produces the startup-tested bytes and restores exactly' {
        $script:Reference = $originalReference
        $exe = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.eXe'))
        $config = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.cf'))
        [IO.File]::WriteAllBytes($script:ExePath, $exe)
        [IO.File]::WriteAllBytes($script:ConfigPath, $config)
        Copy-Item -LiteralPath $env:PATCH_TEST_PLUGIN -Destination $script:Plugin
        foreach ($cycle in 1..2) {
            Invoke-Packaged Apply
            Assert-True ((Get-FileHash -LiteralPath $script:ExePath).Hash -eq $originalReference.exe_patched_sha256) 'Real patched EXE differs'
            Invoke-Packaged Restore
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Real restore left backup'
            Assert-True (Test-ExpectedBytes $exe ([IO.File]::ReadAllBytes($script:ExePath))) 'Real EXE restoration differs'
            Assert-True (Test-ExpectedBytes $config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Real config restoration differs'
        }
        New-LegacyInstallation
        Remove-Item -LiteralPath $script:Plugin
        Invoke-Packaged Apply
        Assert-True ((Get-FileHash -LiteralPath $script:ExePath).Hash -eq $originalReference.exe_patched_sha256) 'Real legacy upgrade differs from fresh install'
        Invoke-Packaged Restore
        Assert-True (Test-ExpectedBytes $exe ([IO.File]::ReadAllBytes($script:ExePath))) 'Real upgrade lost original EXE backup'
        Assert-True (Test-ExpectedBytes $config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Real upgrade lost original configuration'
    } -WithoutGame
}
Invoke-TestCase 'CMD lifecycle preserves saves and old plugins; advisory hashes do not block' {
    foreach ($existingPlugin in @($false, $true)) {
        $targetPlugin = Join-Path $script:Game 'utf8hack.tpm'
        if ($existingPlugin) { [IO.File]::WriteAllText($targetPlugin, 'old plugin') }
        $cycles = if ($existingPlugin) { 1 } else { 2 }
        foreach ($cycle in 1..$cycles) {
            $output = Invoke-Packaged Apply
            Assert-True ($output -match 'Patch installed') 'Packaged apply did not complete'
            Assert-True ($output -match 'Plugin differs' -and $output -match 'EXE differs') 'Untested synthetic files did not produce compatibility warnings'
            $patched = [IO.File]::ReadAllBytes($script:ExePath)
            Assert-True ($patched.Length -eq $script:Original.Length) 'EXE size changed'
            Assert-True ([Text.Encoding]::ASCII.GetString($patched, $script:Offset, 10) -eq 'MS PGothic') 'Font literal was not patched'
            if (-not $existingPlugin -and $cycle -eq 1) {
                Assert-True ((Invoke-Packaged Apply) -match 'already installed') 'Repeat apply was not idempotent'
            }
            Invoke-Packaged Restore
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Packaged restore left backup'
            Assert-True (Test-ExpectedBytes $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Packaged restore differs'
            Assert-True (Test-ExpectedBytes $script:Config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Packaged config restore differs'
            if ($existingPlugin) { Assert-True (Test-ExpectedBytes ([Text.Encoding]::UTF8.GetBytes('old plugin')) ([IO.File]::ReadAllBytes($targetPlugin))) 'Packaged restore lost original plugin bytes' }
            else { Assert-True (-not (Test-Path -LiteralPath $targetPlugin)) 'Packaged restore left new plugin' }
        }
        Assert-True ([IO.File]::ReadAllText((Join-Path $script:Game 'savedata\save.txt')) -eq 'preserve save') 'Save changed'
    }
    Assert-True ((Invoke-Packaged Restore) -match 'Nothing to restore') 'Repeat restore should do nothing'
}
Invoke-TestCase 'legacy upgrade protects edits, rolls back failures and retains original backups' {
    New-LegacyInstallation
    $legacyExe = [IO.File]::ReadAllBytes($script:ExePath)
    $legacyConfig = [IO.File]::ReadAllBytes($script:ConfigPath)
    $manifestPath = Join-Path $script:Game '.unicode-fix-backup\manifest.json'
    $oldManifest = [IO.File]::ReadAllBytes($manifestPath)
    [IO.File]::AppendAllText($script:ConfigPath,'; user edit')
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'upgrade stopped to preserve'
    Assert-True (Test-ExpectedBytes $legacyExe ([IO.File]::ReadAllBytes($script:ExePath))) 'Rejected upgrade changed EXE'
    [IO.File]::WriteAllBytes($script:ConfigPath,$legacyConfig)
    $locked = [IO.File]::Open($manifestPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try { Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'rolled back' }
    finally { $locked.Dispose() }
    Assert-True (Test-ExpectedBytes $legacyExe ([IO.File]::ReadAllBytes($script:ExePath))) 'Failed upgrade left changed EXE'
    Assert-True (Test-ExpectedBytes $legacyConfig ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Failed upgrade left changed config'
    Assert-True (Test-ExpectedBytes $oldManifest ([IO.File]::ReadAllBytes($manifestPath))) 'Failed upgrade changed backup manifest'
    $beforeManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Remove-Item -LiteralPath $script:Plugin
    Invoke-Packaged Apply
    $afterManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($name in $script:FileNames) { Assert-True ($beforeManifest.before.$name -eq $afterManifest.before.$name) 'Upgrade changed original backup metadata' }
    Invoke-Packaged Restore
    Assert-True (Test-ExpectedBytes $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Upgrade restored only to the legacy patch'
    Assert-True (Test-ExpectedBytes $script:Config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Upgrade lost original config'
}
Invoke-TestCase 'DPI manifest preserves UAC, common controls, resource data, headers and overlay' {
    $xml = '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><assemblyIdentity type="win32" name="Test.Fixture" version="1.0.0.0"/><dependency><dependentAssembly><assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" processorArchitecture="x86" publicKeyToken="6595b64144ccf1df" language="*"/></dependentAssembly></dependency><trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>'
    $before = New-PatchFixtureBytes $xml
    $after = Get-DpiAwareExecutable $before
    # These bounds belong to the test fixture, not the production PE parser.
    $outsideBefore = [byte[]]$before.Clone()
    $outsideAfter = [byte[]]$after.Clone()
    [Array]::Clear($outsideBefore, 0x2C8400, 0x1000)
    [Array]::Clear($outsideAfter, 0x2C8400, 0x1000)
    Assert-True (Test-ExpectedBytes $outsideBefore $outsideAfter) 'Headers, code/data or trailing overlay changed'
    Assert-True (Test-ExpectedBytes $after (Get-DpiAwareExecutable $after)) 'DPI update not idempotent'
    [IO.File]::WriteAllBytes($script:ExePath,$after)
    $manifest = [UnicodeFixResources]::Read($script:ExePath)
    $text = [Text.Encoding]::UTF8.GetString($manifest.Bytes)
    Assert-True ($manifest.Language -eq 0x409) 'Existing manifest language changed'
    Assert-True ($text.Contains('level="asInvoker"') -and $text.Contains('Microsoft.Windows.Common-Controls')) 'Existing manifest settings lost'
    Assert-True (Test-ExpectedBytes ([Text.Encoding]::ASCII.GetBytes('TEST-RCDATA-v1')) (Read-FixtureRcData $script:ExePath)) 'Existing resource bytes changed'
    $conflict = New-PatchFixtureBytes ($xml.Replace('</assembly>','<application xmlns="urn:schemas-microsoft-com:asm.v3"><windowsSettings><dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">false</dpiAware></windowsSettings></application></assembly>'))
    Assert-Throws { Get-DpiAwareExecutable $conflict } 'different DPI mode'
} -WithoutGame
Write-Output ('All ' + $script:TestCount + ' native PowerShell tests passed in ' + [Math]::Round($suiteClock.Elapsed.TotalSeconds, 2) + ' seconds.')
