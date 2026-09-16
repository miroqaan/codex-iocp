# Personal Windows MCP IOCP patch

This is an unofficial source snapshot of OpenAI Codex, maintained privately by
miroqaan. It is not the source of the proprietary Codex desktop interface.

Upstream: https://github.com/openai/codex

Base tag: `rust-v0.154.0-alpha.6.2`

Base commit: `b5bffd3ec4db487e7e3dec59663875b0ef7b72ca`

## Change

Local Windows MCP child stdin, stdout and stderr use IOCP-backed named pipes on
the parent side. Child stdio remains synchronous. Existing process creation,
Job Object handling and kill-on-drop behavior are retained. This addresses idle
MCP pipe reads consuming Tokio's shared blocking pool without limiting agents.

Modified files are marked with a modification notice:

- `codex-rs/rmcp-client/src/bounded_stdio_transport.rs`
- `codex-rs/rmcp-client/src/local_child.rs`
- `codex-rs/rmcp-client/src/local_stdio_transport.rs`
- `codex-rs/rmcp-client/src/stdio_server_launcher.rs`
- `codex-rs/rmcp-client/src/windows_stdio.rs` (new)
- `codex-rs/rmcp-client/tests/stdio_message_limits.rs`

## Prior validation (2026-09-13)

The unpatched regression failed twice with a blocking pool of 8 and four idle
MCP servers. The patched regression passed. The rmcp-client suite passed 291
tests with 8 skipped. Formatting, Clippy and a release build succeeded; Clippy
reported an enum-size warning. A desktop launch using the patched backend was
also verified. These results apply to the previously built patch, not to a new
build of this snapshot. Only modification comments were added for this upload.

This fixes the identified pipe exhaustion path; it does not establish that all
possible hangs are fixed. The tested desktop package was `26.908.4834.0`.

## Build and verify

Follow `AGENTS.md` and the pinned Rust toolchain. Windows builds require the
Visual Studio C++ Build Tools and Windows SDK, plus the repository's tooling.

```powershell
cd codex-rs
$env:CARGO_BUILD_JOBS='4'
just fmt
cargo build --release -p codex-cli --bin codex
$env:CARGO_BIN_EXE_codex=(Resolve-Path target/release/codex.exe).Path
just test -p codex-rmcp-client --test-threads 4
cargo clippy -p codex-rmcp-client --all-targets
```

This repository contains source only. Desktop binaries, credentials, local
configuration, conversation records, diagnostic logs and SSH keys are excluded.
Upstream .github/workflows files are omitted from this source archive. GitHub Actions are also disabled; the repository is for source preservation and local builds.

## License

Launcher packaging and compatibility-list maintenance are tracked in
[`packaging/windows-iocp`](packaging/windows-iocp/MAINTAINING.md). The launcher
revision does not change or rebuild the Rust engine.

The upstream Apache-2.0 `LICENSE` and `NOTICE` are retained, together with other
upstream attribution files. The patch is provided under Apache-2.0. This project
is not an official OpenAI release and grants no rights to OpenAI trademarks.
