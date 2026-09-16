//! Uniform child-process API for local MCP servers, with platform-specific spawning.
//!
//! Commands must use the launcher's cleared environment, process group, and default
//! argv[0]. All implementations expose async stdio handles and kill on drop.

use std::io;
use std::process::Stdio;

use tokio::process::Command;

#[cfg(target_os = "macos")]
#[path = "macos_stdio.rs"]
mod macos;

#[cfg(windows)]
#[path = "windows_stdio.rs"]
mod windows;

#[cfg(target_os = "macos")]
pub(super) use macos::LocalChild;
#[cfg(not(any(target_os = "macos", windows)))]
pub(super) use tokio::process::Child as LocalChild;
#[cfg(windows)]
pub(super) use windows::LocalChild;

#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStderr;
#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStdin;
#[cfg(windows)]
pub(super) use tokio::net::windows::named_pipe::NamedPipeServer as ChildStdout;
#[cfg(not(windows))]
pub(super) use tokio::process::ChildStderr;
#[cfg(not(windows))]
pub(super) use tokio::process::ChildStdin;
#[cfg(not(windows))]
pub(super) use tokio::process::ChildStdout;

pub(super) fn spawn(mut command: Command) -> io::Result<LocalChild> {
    command
        .kill_on_drop(true)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    #[cfg(any(target_os = "macos", windows))]
    {
        LocalChild::spawn(command)
    }
    #[cfg(not(any(target_os = "macos", windows)))]
    {
        command.spawn()
    }
}
