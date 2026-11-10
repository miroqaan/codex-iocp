# Windows MCP IOCP patch for Codex 0.167.0

This is an unofficial modified OpenAI Codex engine, based on upstream
`rust-v0.167.0`, commit `086ccc833bc9cf01024ad2dd6af7dbd421b6bf9a`.
The Apache-2.0 LICENSE and NOTICE are retained.

## Changes

Local Windows MCP stdin, stdout and stderr use IOCP-backed named pipes on the
parent side. The child receives ordinary synchronous standard handles. Idle MCP
reads therefore do not occupy Tokio's shared blocking worker pool.

Upstream 0.167.0 still reads local MCP stdio through `tokio::process` pipes on
Windows, which Tokio services with blocking-pool threads. This port follows the
0.163.0 patch. Since 0.166, process creation lives in
`LocalStdioServerLauncher::launch_server`, which creates the Job Object, spawns
the child suspended, assigns and resumes it, and then hands the child to
`LocalStdioTransport::new`. Both spawn calls there (the contained launch and the
uncontained retry) go through the patched launcher. The Windows-only
`codex-utils-pty::Command::spawn_with_stdio` method preserves the environment,
creation flags, suspended Job Object setup and kill-on-drop behavior. Only local
MCP calls opt in; other process launchers and non-Windows transports retain
their existing behavior.

Modified production modules:

- `codex-rs/utils/pty/src/child_command.rs`
- `codex-rs/rmcp-client/src/lib.rs`
- `codex-rs/rmcp-client/src/local_child.rs` (added)
- `codex-rs/rmcp-client/src/windows_stdio.rs` (added)
- `codex-rs/rmcp-client/src/local_stdio_transport.rs`
- `codex-rs/rmcp-client/src/bounded_stdio_transport.rs`
- `codex-rs/rmcp-client/src/stdio_server_launcher.rs`

`Cargo.lock` aligns the 171 workspace package versions with the release tag's
`0.167.0`; external dependencies retain their pinned versions.

## Verification

The process-level `stdio_message_limits` regression includes four idle MCP
servers, both supported framing modes, eight blocking workers, a separate
blocking task, and subsequent tool-list requests. It also covers message-size
handling and descendant termination. Build and verification results are recorded
with the release artifacts; this source description alone does not assert that
those checks have passed.

Build with the pinned Rust 1.95.0 MSVC toolchain and Visual C++ Build Tools:

```powershell
cargo build --manifest-path codex-rs/Cargo.toml --locked --release -p codex-cli --bin codex -j 1
```

Upstream 0.167.0 pins the `v8` crate to a git revision with Chromium
submodules. `codex.exe` does not link V8 (only `codex-code-mode-host` does),
but Cargo still reads the crate manifest, and checking out those submodules on
Windows fails on long paths. The release build therefore passes a Cargo
`--config` source replacement that points that exact locked revision at a
`git archive` of the same commit without submodules. `Cargo.lock` is unchanged
by this, and the compiled `codex.exe` does not depend on it.

This patch addresses the identified idle-pipe exhaustion path, not every possible
cause of an MCP timeout or hang. It does not modify authentication or sandbox policy.
