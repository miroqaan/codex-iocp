# Shared compatibility validation for installation and launch. No network updates.
function Get-ApprovedCombination($Manifest, [string]$PackageFullName) {
    if ($Manifest.schemaVersion -ne 2) { throw 'Unsupported compatibility manifest schema.' }
    $matches = @($Manifest.approvedCombinations | Where-Object {
        $_.packageFullName -ceq $PackageFullName -and
        $_.backendVersion -ceq $Manifest.backendVersion -and
        $_.patchedSha256 -ieq $Manifest.patchedSha256
    })
    if ($matches.Count -ne 1) { throw 'No unique verified app/engine combination exists. Compatibility testing is required before this version can be allowed.' }
    $combination = $matches[0]
    $names = @('codex.exe', 'codex-code-mode-host.exe', 'codex-command-runner.exe', 'codex-windows-sandbox-setup.exe')
    if (@($combination.officialArtifacts).Count -ne $names.Count) { throw 'Invalid combination artifact count.' }
    foreach ($name in $names) {
        $entries = @($combination.officialArtifacts | Where-Object { $_.name -ceq $name })
        if ($entries.Count -ne 1 -or $entries[0].sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Invalid combination artifact: $name" }
    }
    if ($Manifest.patchedSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid patched engine hash.' }
    return $combination
}

function Assert-CombinationFiles($Combination, [string]$Resources) {
    foreach ($artifact in $Combination.officialArtifacts) {
        $path = Join-Path $Resources $artifact.name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $artifact.sha256) {
            throw "Installed official artifact differs from verified combination: $($artifact.name)"
        }
    }
}
