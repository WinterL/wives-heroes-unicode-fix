#requires -Version 5.1
# Generate self-contained CMD files; the user does not need this source folder.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$license = "<#`n" + [IO.File]::ReadAllText((Join-Path $root 'LICENSE')) + "`n#>`n"
$common = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'common.ps1'))
$header = @'
@echo off
setlocal DisableDelayedExpansion
set "UNICODE_FIX_CMD=%~f0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -Command "$text = [IO.File]::ReadAllText($env:UNICODE_FIX_CMD); $payload = [regex]::Split($text, '(?m)^# POWERSHELL PAYLOAD\r?$')[1]; & ([scriptblock]::Create($payload))"
set "patch_exit=%errorlevel%"
if /i not "%~1"=="--no-pause" pause
exit /b %patch_exit%
# POWERSHELL PAYLOAD
'@
$entryPoints = [ordered]@{
    Apply = 'Install-GamePatch $game (Join-Path $game ''utf8hack.dll'')'
    Restore = 'Restore-GamePatch $game'
}
foreach ($action in $entryPoints.Keys) {
    $payload = [IO.File]::ReadAllText((Join-Path $PSScriptRoot ($action.ToLowerInvariant() + '.ps1')))
    if ($action -eq 'Apply') { $payload = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'dpi.ps1')) + "`n" + $payload }
    $entry = "`ntry {`n    `$game = [IO.Path]::GetDirectoryName(`$env:UNICODE_FIX_CMD)`n    " + $entryPoints[$action] + "`n} catch {`n    [Console]::Error.WriteLine('ERROR: ' + `$_.Exception.Message)`n    exit 1`n}`n"
    $content = ($header + "`n" + $license + $common + "`n" + $payload + $entry).Replace("`r`n", "`n").Replace("`n", "`r`n")
    [IO.File]::WriteAllText((Join-Path $root ($action + '.cmd')), $content, [Text.Encoding]::ASCII)
}
