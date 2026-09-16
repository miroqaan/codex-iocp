[CmdletBinding()]
param([switch]$NoDialog, [switch]$CheckOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
try {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'disabled')) { throw 'This patch is disabled. Use the official Codex shortcut.' }
    $manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($scriptName in @('Launch.ps1', 'Compatibility.ps1')) {
        $entry=@($manifest.scripts | Where-Object {$_.name -ceq $scriptName})
        $scriptPath=Join-Path $PSScriptRoot $scriptName
        if ($entry.Count -ne 1 -or $entry[0].sha256 -notmatch '^[0-9a-fA-F]{64}$' -or (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash -ne $entry[0].sha256) { throw "Script missing or changed: $scriptName" }
    }
    . (Join-Path $PSScriptRoot 'Compatibility.ps1')
    $packages=@(Get-AppxPackage -Name OpenAI.Codex)
    if ($packages.Count -ne 1) { throw 'Exactly one installed Codex package is required.' }
    $combination=Get-ApprovedCombination $manifest $packages[0].PackageFullName
    Assert-CombinationFiles $combination (Join-Path $packages[0].InstallLocation 'app\resources')
    $app=Join-Path $packages[0].InstallLocation 'app\ChatGPT.exe'
    if (-not (Test-Path -LiteralPath $app -PathType Leaf)) { throw 'Official Codex desktop executable is missing.' }
    $names=@('codex-code-mode-host.exe','codex-command-runner.exe','codex-windows-sandbox-setup.exe')
    $artifacts=@([pscustomobject]@{name='codex.exe';sha256=$manifest.patchedSha256})
    foreach ($name in $names) {
        $entry=@($combination.officialArtifacts | Where-Object {$_.name -eq $name})
        if ($entry.Count -ne 1) { throw 'Invalid helper manifest.' }
        $artifacts += $entry[0]
    }
    foreach ($artifact in $artifacts) {
        $path=Join-Path $PSScriptRoot $artifact.name
        if ($artifact.sha256 -notmatch '^[0-9a-fA-F]{64}$' -or -not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $artifact.sha256) { throw "Patch file missing or changed: $($artifact.name)" }
    }
    if ($CheckOnly) { Write-Output 'PASS: approved app/engine combination, installed files and launch scripts verified. No processes started.'; return }
    $running=@(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" | Where-Object { -not $_.ExecutablePath -or $_.ExecutablePath -eq $app -or $_.ExecutablePath -match '\\OpenAI\.Codex_[^\\]+\\app\\ChatGPT\.exe$' })
    if ($running.Count -gt 0) { throw 'Codex desktop is still running. Exit it fully first. No processes were stopped.' }
    $previous=[Environment]::GetEnvironmentVariable('CODEX_CLI_PATH','Process')
    try {
        [Environment]::SetEnvironmentVariable('CODEX_CLI_PATH',(Join-Path $PSScriptRoot 'codex.exe'),'Process')
        Start-Process -FilePath $app -WorkingDirectory (Split-Path -Parent $app)
    } finally { [Environment]::SetEnvironmentVariable('CODEX_CLI_PATH',$previous,'Process') }
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'launch-error.txt') -Encoding UTF8
    if (-not $NoDialog) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("Could not launch patched Codex.`n`n$($_.Exception.Message)`n`nYou can use the official Codex shortcut.",'Codex IOCP Patch') | Out-Null
    }
    throw
}
