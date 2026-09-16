// Modified by miroqaan: Windows MCP IOCP stdio patch, 2026-09-15.
//! IOCP-backed parent stdio for local Windows MCP processes.
//!
//! Tokio's Windows child stdio wraps synchronous anonymous pipes in blocking
//! tasks. Idle MCP readers can exhaust that shared thread pool. Named pipes let
//! the parent use overlapped I/O while the child retains synchronous stdio.

use std::collections::hash_map::RandomState;
use std::fs::OpenOptions;
use std::hash::BuildHasher;
use std::io;
use std::os::windows::fs::OpenOptionsExt;
use std::process::ExitStatus;
use std::process::Stdio;
use std::sync::atomic::AtomicU64;
use std::sync::atomic::Ordering;

use futures::FutureExt;
use tokio::net::windows::named_pipe::NamedPipeServer;
use tokio::net::windows::named_pipe::ServerOptions;
use tokio::process::Child;
use tokio::process::Command;
use windows_sys::Win32::Storage::FileSystem::SECURITY_ANONYMOUS;
use windows_sys::Win32::Storage::FileSystem::SECURITY_SQOS_PRESENT;

pub(crate) struct LocalChild {
    inner: Child,
    pub(crate) stdin: Option<NamedPipeServer>,
    pub(crate) stdout: Option<NamedPipeServer>,
    pub(crate) stderr: Option<NamedPipeServer>,
}

impl LocalChild {
    pub(crate) fn spawn(mut command: Command) -> io::Result<Self> {
        let (stdin, child_stdin) = pipe_pair(ParentEnd::Write)?;
        let (stdout, child_stdout) = pipe_pair(ParentEnd::Read)?;
        let (stderr, child_stderr) = pipe_pair(ParentEnd::Read)?;
        command
            .stdin(child_stdin)
            .stdout(child_stdout)
            .stderr(child_stderr);
        // Preserve the launcher's creation flags, environment and Job Object
        // setup. Tokio still owns process waiting and kill-on-drop.
        let inner = command.spawn()?;
        Ok(Self {
            inner,
            stdin: Some(stdin),
            stdout: Some(stdout),
            stderr: Some(stderr),
        })
    }

    pub(crate) fn id(&self) -> Option<u32> {
        self.inner.id()
    }

    pub(crate) async fn wait(&mut self) -> io::Result<ExitStatus> {
        self.stdin.take();
        self.inner.wait().await
    }

    pub(crate) async fn kill(&mut self) -> io::Result<()> {
        self.stdin.take();
        self.inner.kill().await
    }
}

enum ParentEnd {
    Read,
    Write,
}

fn pipe_pair(parent_end: ParentEnd) -> io::Result<(NamedPipeServer, Stdio)> {
    static NEXT_PIPE: AtomicU64 = AtomicU64::new(0);
    let sequence = NEXT_PIPE.fetch_add(1, Ordering::Relaxed);
    let process_id = std::process::id();
    let nonce = RandomState::new().hash_one((process_id, sequence));
    let name = format!(r"\\.\pipe\codex-mcp-{process_id}-{sequence}-{nonce:016x}");
    let parent_reads = matches!(parent_end, ParentEnd::Read);
    let server = ServerOptions::new()
        .first_pipe_instance(true)
        .max_instances(1)
        .reject_remote_clients(true)
        .access_inbound(parent_reads)
        .access_outbound(!parent_reads)
        .create(&name)?;

    // Do not set FILE_FLAG_OVERLAPPED on the child end: ordinary subprocesses
    // expect synchronous standard handles. Command makes inheritable duplicates
    // of these handles for the child; the originals remain non-inheritable.
    let client = OpenOptions::new()
        .read(!parent_reads)
        .write(parent_reads)
        .security_qos_flags(SECURITY_SQOS_PRESENT | SECURITY_ANONYMOUS)
        .open(&name)?;

    // Opening the client above completes the connection synchronously. Accept
    // it before spawning (the launcher may create the child suspended). Never
    // block an executor thread waiting for a connection that should exist.
    server
        .connect()
        .now_or_never()
        .ok_or_else(|| io::Error::other("MCP stdio pipe connection was not ready"))??;
    Ok((server, Stdio::from(client)))
}
