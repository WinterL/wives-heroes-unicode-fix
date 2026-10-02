#requires -Version 5.1
# Standalone behavior tests; no Pester or installed game is required.
$ErrorActionPreference = 'Stop'
foreach ($module in @('common','apply','restore')) { . (Join-Path $PSScriptRoot ('..\scripts\' + $module + '.ps1')) }
$originalReference = $script:Reference
$repoRoot = Split-Path -Parent $PSScriptRoot
$script:TestCount = 0

function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw ('Assertion failed: ' + $Message) }
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
        if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Packaged command timed out.' }
        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        Assert-True ($process.ExitCode -eq $ExpectedExit) $output
        return $output
    } finally { $process.Dispose() }
}
function Invoke-TestCase([string]$TestName, [scriptblock]$Body) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('unicode-fix-test-' + [Guid]::NewGuid().ToString('N'))
    $script:Game = Join-Path $temp ("Game & O'Brien ! " + [char]0x904A + [char]0x6232)
    $null = New-Item -ItemType Directory -Path $script:Game
    $script:ExePath = Join-Path $script:Game 'yuusyatsuma.eXe'
    $script:ConfigPath = Join-Path $script:Game 'yuusyatsuma.cf'
    $script:Plugin = Join-Path $script:Game 'utf8hack.dll'
    $script:Original = New-Object byte[] ($script:Offset + 32)
    $script:OldBytes.CopyTo($script:Original, $script:Offset)
    $script:Config = [Text.Encoding]::ASCII.GetBytes("; keep settings`r`nfszoom=`"\x6E\x6F`"`r`n")
    [IO.File]::WriteAllBytes($script:ExePath, $script:Original)
    [IO.File]::WriteAllBytes($script:ConfigPath, $script:Config)
    [IO.File]::WriteAllText($script:Plugin, 'synthetic plugin')
    $null = New-Item -ItemType Directory -Path (Join-Path $script:Game 'savedata')
    [IO.File]::WriteAllText((Join-Path $script:Game 'savedata\save.txt'), 'preserve save')
    $script:Reference = [pscustomobject]@{
        exe_original_sha256 = Get-BytesHash $script:Original
        exe_patched_sha256 = $null
        plugin = [pscustomobject]@{ dll_sha256 = (Get-FileHash -LiteralPath $script:Plugin).Hash }
    }
    try { & $Body | Out-Null; $script:TestCount++; Write-Output ('PASS ' + $TestName) }
    finally {
        $resolved = [IO.Path]::GetFullPath($temp)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($resolved)).StartsWith('unicode-fix-test-')) { throw 'Unsafe test cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $script:Reference = $originalReference
    }
}

foreach ($existingPlugin in @($false, $true)) {
    Invoke-TestCase ('install/restore round trip; existing plugin=' + $existingPlugin) {
        $targetPlugin = Join-Path $script:Game 'utf8hack.tpm'
        if ($existingPlugin) { [IO.File]::WriteAllText($targetPlugin, 'old plugin') }
        Install-GamePatch $script:Game $script:Plugin
        $patched = [IO.File]::ReadAllBytes($script:ExePath)
        Assert-True ($patched.Length -eq $script:Original.Length) 'EXE size changed'
        Assert-True ([Text.Encoding]::ASCII.GetString($patched, $script:Offset, 10) -eq 'MS PGothic') 'Font literal was not patched'
        $script:Reference.exe_patched_sha256 = Get-BytesHash $patched
        Install-GamePatch $script:Game $script:Plugin
        Restore-GamePatch $script:Game
        Restore-GamePatch $script:Game
        Assert-True (Test-BytesEqual $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'EXE restoration differs'
        Assert-True (Test-BytesEqual $script:Config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Config restoration differs'
        if ($existingPlugin) { Assert-True ([IO.File]::ReadAllText($targetPlugin) -eq 'old plugin') 'Old plugin lost' }
        else { Assert-True (-not (Test-Path -LiteralPath $targetPlugin)) 'New plugin remained' }
        Assert-True ([IO.File]::ReadAllText((Join-Path $script:Game 'savedata\save.txt')) -eq 'preserve save') 'Save changed'
    }
}
Invoke-TestCase 'different EXE and plugin hashes warn but install and restore' {
    $script:Original[$script:Original.Length - 1] = 42
    [IO.File]::WriteAllBytes($script:ExePath, $script:Original)
    [IO.File]::WriteAllText($script:Plugin, 'different plugin')
    $warnings = @(Install-GamePatch $script:Game $script:Plugin 3>&1 | Where-Object { $_ -is [Management.Automation.WarningRecord] })
    Assert-True ($warnings.Count -eq 2) 'Expected EXE and plugin compatibility warnings'
    Restore-GamePatch $script:Game
    Assert-True (Test-BytesEqual $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Variant restore differs'
}
Invoke-TestCase 'configuration preserves encoding, BOM, unrelated lines and newline style' {
    foreach ($encoding in @((New-Object Text.UTF8Encoding($false)), (New-Object Text.UTF8Encoding($true)), [Text.Encoding]::Unicode, [Text.Encoding]::BigEndianUnicode)) {
        $before = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes("; preserve`r`nother=`"value`"`r`n"))
        $after = Get-PatchedConfig $before
        Assert-True (Test-BytesEqual $before ([byte[]]$after[0..($before.Length - 1)])) 'Existing bytes changed'
        Assert-True (Test-BytesEqual $after (Get-PatchedConfig $after)) 'Config not idempotent'
    }
    $after = [Text.Encoding]::ASCII.GetString((Get-PatchedConfig ([Text.Encoding]::ASCII.GetBytes("; comment`nreadencoding=`"old`"`nother=`"keep`""))))
    Assert-True ($after -eq "; comment`nreadencoding=`"\x53\x68\x69\x66\x74\x5F\x4A\x49\x53`"`nother=`"keep`"") 'Setting replacement changed unrelated text'
}
Invoke-TestCase 'unsafe marker and existing backup are refused before writes' {
    [IO.File]::WriteAllBytes($script:ExePath, [byte[]](77,90))
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'patch offset'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Invalid EXE created backup'
    [IO.File]::WriteAllBytes($script:ExePath, $script:Original)
    $null = New-Item -ItemType Directory -Path (Join-Path $script:Game $script:BackupName)
    Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'backup already exists'
}
Invoke-TestCase 'restore preserves later edits and refuses corrupt backups before writes' {
    Install-GamePatch $script:Game $script:Plugin
    $patched = [IO.File]::ReadAllBytes($script:ExePath)
    $patchedConfig = [IO.File]::ReadAllBytes($script:ConfigPath)
    [IO.File]::AppendAllText($script:ConfigPath, '; later change')
    Assert-Throws { Restore-GamePatch $script:Game } 'changed after installation'
    Assert-True (Test-BytesEqual $patched ([IO.File]::ReadAllBytes($script:ExePath))) 'Partial restore occurred'
    [IO.File]::WriteAllBytes($script:ConfigPath, $patchedConfig)
    [IO.File]::WriteAllText((Join-Path $script:Game '.unicode-fix-backup\yuusyatsuma.eXe'), 'corrupt')
    Assert-Throws { Restore-GamePatch $script:Game } 'Backup checksum mismatch'
    Assert-True (Test-BytesEqual $patched ([IO.File]::ReadAllBytes($script:ExePath))) 'Corrupt backup changed EXE'
}
Invoke-TestCase 'write failure rolls back earlier changes' {
    $locked = [IO.File]::Open($script:ConfigPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { Assert-Throws { Install-GamePatch $script:Game $script:Plugin } 'rolled back' }
    finally { $locked.Dispose() }
    Assert-True (Test-BytesEqual $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Partial EXE edit remained'
}
if ($env:PATCH_TEST_GAME_DIR -and $env:PATCH_TEST_PLUGIN) {
    Invoke-TestCase 'real EXE produces the startup-tested bytes and restores exactly' {
        $script:Reference = $originalReference
        $exe = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.eXe'))
        $config = [IO.File]::ReadAllBytes((Join-Path $env:PATCH_TEST_GAME_DIR 'yuusyatsuma.cf'))
        [IO.File]::WriteAllBytes($script:ExePath, $exe)
        [IO.File]::WriteAllBytes($script:ConfigPath, $config)
        Copy-Item -LiteralPath $env:PATCH_TEST_PLUGIN -Destination $script:Plugin
        Invoke-Packaged Apply
        Assert-True ((Get-FileHash -LiteralPath $script:ExePath).Hash -eq $originalReference.exe_patched_sha256) 'Real patched EXE differs'
        Invoke-Packaged Restore
        Assert-True (Test-BytesEqual $exe ([IO.File]::ReadAllBytes($script:ExePath))) 'Real EXE restoration differs'
        Assert-True (Test-BytesEqual $config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Real config restoration differs'
    }
}
Invoke-TestCase 'standalone CMD applies, repeats and restores from a different working directory' {
    Assert-True ((Invoke-Packaged Apply) -match 'Patch installed') 'Packaged apply did not complete'
    Assert-True ((Invoke-Packaged Apply) -match 'already installed') 'Repeat apply was not idempotent'
    Invoke-Packaged Restore
    Assert-True (Test-BytesEqual $script:Original ([IO.File]::ReadAllBytes($script:ExePath))) 'Packaged restore differs'
    Assert-True (Test-BytesEqual $script:Config ([IO.File]::ReadAllBytes($script:ConfigPath))) 'Packaged config restore differs'
}
Invoke-TestCase 'standalone CMD reports a missing DLL and wrong folder without making a backup' {
    Remove-Item -LiteralPath $script:Plugin
    Assert-True ((Invoke-Packaged Apply 1) -match 'Missing utf8hack.dll') 'Missing DLL message unclear'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Missing DLL created backup'
    Remove-Item -LiteralPath $script:ExePath
    Assert-True ((Invoke-Packaged Apply 1) -match 'Missing yuusyatsuma.eXe') 'Wrong-folder message unclear'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:Game $script:BackupName))) 'Wrong folder created backup'
}
Write-Output ('All ' + $script:TestCount + ' native PowerShell tests passed.')
