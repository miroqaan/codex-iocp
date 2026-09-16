# 동일 소스에서 재빌드

필수 도구: Git, Visual Studio C++ Build Tools/Windows SDK, Rust 1.95.0 및 저장소 rust-toolchain 지정 컴포넌트, Python 3, PowerShell 7, just, cargo-nextest, dotslash. 실제 필수 버전과 규칙은 대상 태그의 AGENTS.md와 rust-toolchain.toml을 우선합니다.

```powershell
git clone --branch rust-v0.154.0-alpha.6.2 --single-branch https://github.com/openai/codex.git codex-pipe-fix
cd codex-pipe-fix
git rev-parse HEAD
# 기대값: b5bffd3ec4db487e7e3dec59663875b0ef7b72ca
git apply --check C:\path\to\source\windows-mcp-iocp.patch
git apply C:\path\to\source\windows-mcp-iocp.patch
cd codex-rs
$env:CARGO_BUILD_JOBS='4'
$env:CARGO_PROFILE_DEV_DEBUG='0'
$env:CARGO_PROFILE_TEST_DEBUG='0'
just fmt
cargo build --release -p codex-cli --bin codex
$env:CARGO_BIN_EXE_codex=(Resolve-Path target\release\codex.exe).Path
just test -p codex-rmcp-client --test-threads 4
cargo clippy -p codex-rmcp-client --all-targets
```

다른 PC에서 다시 빌드하면 경로·도구 체인·빌드 메타데이터 때문에 실행 파일 해시가 달라질 수 있습니다. 제공 manifest는 제공 바이너리와 설치 스크립트용이며, 다시 빌드한 파일에는 검증 결과와 새 해시로 별도 배포 패키지를 만들어야 합니다.

재현 원리는 runtime worker_threads=2, max_blocking_threads=8에서 유휴 MCP 4개를 초기화한 뒤 spawn_blocking 작업이 1초 이내 완료되는지 검사하는 것입니다. 원본 코드는 stdout/stderr 8개가 pool을 점유해 실패했고, 패치는 같은 조건에서 통과했습니다. 실제 운영의 agent 동시성 설정을 줄이는 테스트가 아닙니다.
