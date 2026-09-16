# Maintaining the launcher package

The binary is intentionally not stored in Git. Place the previously verified
engine in `payload/codex.exe`; its SHA-256 must equal `manifest.json`'s
`patchedSha256`. The package's source directory describes the existing build.

`approvedCombinations` matches the exact installed package identity, engine
version and engine hash. Each entry also pins all four official resource
executables. Installation copies the three matching helpers; launch validates
both the installed official files and the deployed engine/helpers.

Do not add an app version solely because its version number is newer. Test the
app with the selected engine and helpers on a separate installation first,
including model responses, MCP operations, process cleanup and the IOCP
regression. Record the tested date and artifact hashes. Different helper hashes
require a deployment with those verified helpers; changing the manifest alone
does not replace them.

After editing scripts, refresh the four `scripts` hashes in the manifest, then
run `Test-Allowlist.ps1` on a Windows x64 PC with the approved official package.
The test uses a temporary installation and leaves it disabled for inspection.
It never restarts the running Codex desktop. Its synthetic second list entry is
only a lookup test and is never an approval for an actual app release.

Package the files with the verified payload, exclude `Test-Allowlist.ps1` and
this maintainer note from the end-user ZIP if desired, test ZIP integrity and
run `Install.ps1 -CheckOnly` from a fresh extraction. Publish the ZIP SHA-256.
The manifest detects accidental file mismatches; it is not a digital signature
against someone replacing both the manifest and its files.

This launcher does not disable Microsoft Store updates or fetch updates itself.
Only the already tested 26.908.4834.0 / 0.154.0-alpha.6.2 combination is currently
approved. The engine was not rebuilt for this launcher change.

2026-09-15 validation: 13 checks passed, including isolated installation,
launch preflight, rejection cases and uninstall. Fresh ZIP extraction preflight
also passed. The current desktop session was not restarted.
