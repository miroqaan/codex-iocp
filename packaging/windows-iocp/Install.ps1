[CmdletBinding()]
param([switch]$CheckOnly, [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexIocpPatch\b5bffd3e'), [string]$ShortcutDirectory = [Environment]::GetFolderPath('Desktop'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { throw 'Windows x64 PowerShell is required.' }
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedVersion = $manifest.backendVersion
$names = @('codex.exe', 'codex-code-mode-host.exe', 'codex-command-runner.exe', 'codex-windows-sandbox-setup.exe')
function Assert-Hash([string]$Path, [string]$Hash) {
    if ($Hash -notmatch '^[0-9a-fA-F]{64}$' -or -not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Hash) { throw "File missing or SHA256 mismatch: $Path" }
}
$payload = Join-Path $PSScriptRoot 'payload\codex.exe'
Assert-Hash $payload $manifest.patchedSha256
foreach ($name in @('Install.ps1', 'Launch.ps1', 'Uninstall.ps1', 'Compatibility.ps1')) {
    $entry = @($manifest.scripts | Where-Object { $_.name -eq $name })
    if ($entry.Count -ne 1) { throw "Invalid script manifest: $name" }
    Assert-Hash (Join-Path $PSScriptRoot $name) $entry[0].sha256
}
$packages = @(Get-AppxPackage -Name OpenAI.Codex)
if ($packages.Count -ne 1) { throw 'Exactly one installed Codex package is required.' }
. (Join-Path $PSScriptRoot 'Compatibility.ps1')
$combination = Get-ApprovedCombination $manifest $packages[0].PackageFullName
$resources = Join-Path $packages[0].InstallLocation 'app\resources'
foreach ($name in $names) {
    $entry = @($combination.officialArtifacts | Where-Object { $_.name -eq $name })
    if ($entry.Count -ne 1) { throw "Invalid official artifact entry: $name" }
    Assert-Hash (Join-Path $resources $name) $entry[0].sha256
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$ShortcutDirectory = [IO.Path]::GetFullPath($ShortcutDirectory)
$linkPath = Join-Path $ShortcutDirectory 'Codex (IOCP Patch).lnk'
if (Test-Path -LiteralPath $InstallRoot) { throw "Install directory already exists; it will not be overwritten: $InstallRoot" }
if (Test-Path -LiteralPath $linkPath) { throw "Shortcut already exists; it will not be overwritten: $linkPath" }
if ($CheckOnly) { Write-Output 'PASS: Windows x64, approved app/engine combination, official files, patch payload and scripts verified. No changes made.'; return }
New-Item -ItemType Directory -Path $InstallRoot | Out-Null
# Leave failed installations disabled and inspectable instead of deleting directories.
Set-Content -LiteralPath (Join-Path $InstallRoot 'disabled') -Value 'Installation in progress' -Encoding UTF8
Copy-Item -LiteralPath $payload -Destination (Join-Path $InstallRoot 'codex.exe')
Assert-Hash (Join-Path $InstallRoot 'codex.exe') $manifest.patchedSha256
if ((& (Join-Path $InstallRoot 'codex.exe') --version | Out-String).Trim() -ne $expectedVersion -or $LASTEXITCODE -ne 0) { throw 'Patched executable version mismatch.' }
foreach ($name in $names[1..3]) {
    Copy-Item -LiteralPath (Join-Path $resources $name) -Destination (Join-Path $InstallRoot $name)
    $entry = @($combination.officialArtifacts | Where-Object { $_.name -eq $name })
    Assert-Hash (Join-Path $InstallRoot $name) $entry[0].sha256
}
foreach ($name in @('Launch.ps1', 'Uninstall.ps1', 'Compatibility.ps1', 'manifest.json')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $InstallRoot $name) }
$pwsh = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $InstallRoot 'Launch.ps1') + '"'
[ordered]@{ installRoot=$InstallRoot; shortcutPath=$linkPath; shortcutTarget=$pwsh; shortcutArguments=$arguments; installedAt=(Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot 'installation.json') -Encoding UTF8
if (-not (Test-Path -LiteralPath $ShortcutDirectory -PathType Container)) { New-Item -ItemType Directory -Path $ShortcutDirectory | Out-Null }
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath=$pwsh; $link.Arguments=$arguments; $link.WorkingDirectory=$InstallRoot
$link.Description='Codex verified Windows MCP IOCP patch'; $link.IconLocation=(Join-Path $packages[0].InstallLocation 'app\ChatGPT.exe') + ',0'; $link.Save()
$check=$shell.CreateShortcut($linkPath)
if ($check.TargetPath -ne $pwsh -or $check.Arguments -ne $arguments -or $check.WorkingDirectory -ne $InstallRoot) { throw 'Shortcut verification failed.' }
Remove-Item -LiteralPath (Join-Path $InstallRoot 'disabled')
Write-Output "Installed: $InstallRoot"
Write-Output "Shortcut: $linkPath"
Write-Output 'Exit Codex fully, then use the IOCP Patch shortcut. The official installation and settings were preserved.'
