[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$state=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'installation.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([IO.Path]::GetFullPath($PSScriptRoot) -ne $state.installRoot) { throw 'Installation directory differs from recorded location.' }
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'disabled') -Value ('Disabled '+(Get-Date).ToString('o')) -Encoding UTF8
if (Test-Path -LiteralPath $state.shortcutPath -PathType Leaf) {
    $shell=New-Object -ComObject WScript.Shell
    $link=$shell.CreateShortcut($state.shortcutPath)
    if ($link.TargetPath -eq $state.shortcutTarget -and $link.Arguments -eq $state.shortcutArguments -and $link.WorkingDirectory -eq $state.installRoot) { Remove-Item -LiteralPath $state.shortcutPath }
    else { Write-Warning 'Shortcut was changed; it has been preserved.' }
}
Write-Output 'Patch disabled and its unchanged shortcut removed. No processes were stopped. Restart using the official Codex shortcut.'
Write-Output "Patch files remain for inspection. After exiting patched Codex, you may delete this directory: $PSScriptRoot"
