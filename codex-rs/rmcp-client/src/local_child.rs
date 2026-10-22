// Modified by miroqaan: Windows MCP IOCP transport for Codex 0.163.0.
//! Platform-specific pipe handles for local MCP servers.

#[cfg(windows)]
#[path = "windows_stdio.rs"]
mod windows;

#[cfg(not(windows))]
pub(super) use codex_utils_pty::Child as LocalChild;
#[cfg(windows)]
pub(super) use windows::LocalChild;

#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStderr;
#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStdin;
#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStdout;
#[cfg(not(windows))]
pub(super) use tokio::process::{ChildStderr, ChildStdin, ChildStdout};

pub(super) fn spawn(command: codex_utils_pty::Command) -> std::io::Result<LocalChild> {
    #[cfg(windows)]
    {
        LocalChild::spawn(command)
    }
    #[cfg(not(windows))]
    {
        command.spawn()
    }
}
