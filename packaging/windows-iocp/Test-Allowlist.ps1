$ErrorActionPreference='Stop'
$pkg=$PSScriptRoot
$scratch=Join-Path $env:TEMP ('codex-allowlist-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$results=[Collections.Generic.List[string]]::new()
function Must-Fail([string]$Name, [scriptblock]$Action, [string]$Pattern) {
    $caught=$null
    try { & $Action | Out-Null } catch { $caught=$_.Exception.Message }
    if (-not $caught -or $caught -notmatch $Pattern) { throw "Unexpected result for ${Name}: $caught" }
    $results.Add("PASS: $Name")
}
. "$pkg\Compatibility.ps1"
$manifest=Get-Content "$pkg\manifest.json" -Raw | ConvertFrom-Json
$package=Get-AppxPackage -Name OpenAI.Codex
$combo=Get-ApprovedCombination $manifest $package.PackageFullName
$results.Add('PASS: current verified combination selected')
Must-Fail 'unregistered app rejected' { Get-ApprovedCombination $manifest 'OpenAI.Codex_99.0.0.0_x64__2p2nqsd0c76g0' } 'No unique verified'
$clone=$manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$clone.patchedSha256='0'*64
Must-Fail 'different engine rejected' { Get-ApprovedCombination $clone $package.PackageFullName } 'No unique verified'
$clone=$manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$clone.approvedCombinations=@($combo,$combo)
Must-Fail 'duplicate combination rejected' { Get-ApprovedCombination $clone $package.PackageFullName } 'No unique verified'
# Synthetic fixture tests list lookup, not real-world compatibility approval.
$clone=$manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$second=$combo | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$second.packageFullName='Synthetic.TestOnly'
$clone.approvedCombinations+=@($second)
if ((Get-ApprovedCombination $clone 'Synthetic.TestOnly').packageFullName -ne 'Synthetic.TestOnly') { throw 'Second entry lookup failed' }
$results.Add('PASS: second list entry selected without script changes (synthetic fixture)')
$clone=$manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$clone.approvedCombinations[0].officialArtifacts[0].name='../invalid.exe'
Must-Fail 'invalid artifact names rejected' { Get-ApprovedCombination $clone $package.PackageFullName } 'Invalid combination artifact'
$envBefore=[Environment]::GetEnvironmentVariable('CODEX_CLI_PATH','Process')
$install=Join-Path $scratch 'installed'
$shortcuts=Join-Path $scratch 'shortcuts'
& "$pkg\Install.ps1" -InstallRoot $install -ShortcutDirectory $shortcuts
$results.Add('PASS: real isolated install and shortcut validation')
& "$install\Launch.ps1" -CheckOnly -NoDialog
$results.Add('PASS: installed launch preflight with actual official files')
if ([Environment]::GetEnvironmentVariable('CODEX_CLI_PATH','Process') -ne $envBefore) { throw 'Environment changed' }
$results.Add('PASS: check-only preserves process environment')
$manifestPath=Join-Path $install 'manifest.json'
$original=[IO.File]::ReadAllBytes($manifestPath)
$bad=$manifest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$bad.approvedCombinations[0].officialArtifacts[1].sha256='0'*64
$bad | ConvertTo-Json -Depth 20 | Set-Content $manifestPath -Encoding UTF8
Must-Fail 'official artifact mismatch rejected at launch' { & "$install\Launch.ps1" -CheckOnly -NoDialog } 'differs from verified'
[IO.File]::WriteAllBytes($manifestPath,$original)
$helper=Join-Path $install 'Compatibility.ps1'
$originalHelper=[IO.File]::ReadAllBytes($helper)
Add-Content $helper '# tampered'
Must-Fail 'modified script rejected at launch' { & "$install\Launch.ps1" -CheckOnly -NoDialog } 'Script missing or changed'
[IO.File]::WriteAllBytes($helper,$originalHelper)
$binary=Join-Path $install 'codex.exe'
$stream=[IO.File]::Open($binary,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite)
$first=$stream.ReadByte();$stream.Position=0;$stream.WriteByte($first -bxor 1);$stream.Dispose()
Must-Fail 'modified payload rejected at launch' { & "$install\Launch.ps1" -CheckOnly -NoDialog } 'Patch file missing or changed'
$stream=[IO.File]::OpenWrite($binary);$stream.WriteByte($first);$stream.Dispose()
& "$install\Launch.ps1" -CheckOnly -NoDialog
& "$install\Uninstall.ps1"
if (Test-Path (Join-Path $shortcuts 'Codex (IOCP Patch).lnk')) { throw 'Uninstall failed' }
$results.Add('PASS: uninstall disables patch and removes own shortcut')
$results | ForEach-Object { Write-Output $_ }
[ordered]@{time=(Get-Date).ToString('o'); scratch=$scratch; results=@($results)} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $scratch 'allowlist-test-results.json') -Encoding UTF8
