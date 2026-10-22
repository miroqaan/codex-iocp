# Windows MCP IOCP patch for Codex 0.163.0

This is an unofficial modified OpenAI Codex engine, based on upstream
`rust-v0.163.0`, commit `83086188ae0614bd882818ff1aa23f3194962012`.
The Apache-2.0 LICENSE and NOTICE are retained.

## Changes

Local Windows MCP stdin, stdout and stderr use IOCP-backed named pipes on the
parent side. The child receives ordinary synchronous standard handles. Idle MCP
reads therefore do not occupy Tokio's shared blocking worker pool.

The earlier patch from `miroqaan/codex-iocp` is adapted to the upstream shared
`codex-utils-pty::Command` launcher. The new Windows-only `spawn_with_stdio`
method preserves the environment, creation flags, suspended Job Object setup,
and kill-on-drop behavior. Only local MCP calls opt in; other process launchers
and non-Windows transports retain their existing behavior.

Modified production modules:

- `codex-rs/utils/pty/src/child_command.rs`
- `codex-rs/rmcp-client/src/lib.rs`
- `codex-rs/rmcp-client/src/local_child.rs` (added)
- `codex-rs/rmcp-client/src/windows_stdio.rs` (added)
- `codex-rs/rmcp-client/src/local_stdio_transport.rs`
- `codex-rs/rmcp-client/src/bounded_stdio_transport.rs`
- `codex-rs/rmcp-client/src/stdio_server_launcher.rs`

`Cargo.lock` aligns the 160 workspace package versions with the release tag's
`0.163.0`; external dependencies retain their pinned versions.

## Verification

The existing process-level `stdio_message_limits` regression includes four idle
MCP servers, both supported framing modes, eight blocking workers, a separate
blocking task, and subsequent tool-list requests. It also covers message-size
handling and descendant termination. Build and verification results are recorded
with the release artifacts; this source description alone does not assert that
those checks have passed.

Build with the pinned Rust 1.95.0 MSVC toolchain and Visual C++ Build Tools:

```powershell
cargo build --manifest-path codex-rs/Cargo.toml --locked --release -p codex-cli --bin codex -j 2
```

This patch addresses the identified idle-pipe exhaustion path, not every possible
cause of an MCP timeout or hang. It does not modify authentication or sandbox policy.
