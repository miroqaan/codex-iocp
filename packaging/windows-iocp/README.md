# Codex Windows MCP IOCP 패치

처음 설치한다면 [순서별 설치 안내](설치안내.md)를 먼저 읽으세요. 설치 성공 확인, 오류 대응, 원복 방법을 포함합니다.

OpenAI 공식 배포판이 아닌 로컬 수정 빌드입니다. Windows에서 유휴 MCP stdout/stderr 읽기가 Tokio blocking thread pool을 고갈시키는 경로를 수정합니다. 하위 에이전트 수를 제한하지 않습니다.

## 적용 대상

- Windows x64.
- Microsoft Store/MSIX Codex **26.908.4834.0**, 백엔드 **0.154.0-alpha.6.2**가 이미 설치된 PC.
- 현재 허용 목록에 등록된 조합은 위 버전 하나입니다. 등록되지 않은 앱·엔진 조합, ARM64, macOS/Linux, 독립 CLI 설치는 적용 대상이 아닙니다.
- 인터넷 다운로드나 Rust 빌드, 관리자 권한 없이 설치합니다. 다른 PC의 계정으로 Codex에 로그인해야 하며 이 ZIP에 계정·인증·대화·개인 설정은 들어 있지 않습니다.

## 설치

1. ZIP을 **전부 압축 해제**합니다. ZIP 내부에서 직접 실행하지 마세요.
2. Codex에서 작업을 마무리하고 앱을 완전히 종료합니다.
3. `Install.cmd`를 더블클릭합니다. 검사 결과와 완료 메시지를 확인합니다.
4. 바탕화면의 `Codex (IOCP Patch)` 바로가기로 실행합니다. 원래 Codex 바로가기는 공식 백엔드를 실행합니다.

설치 폴더는 `%LOCALAPPDATA%\CodexIocpPatch\b5bffd3e`입니다. 기존 설치 파일을 덮어쓰거나 전역 환경 변수·동시성 설정을 변경하지 않습니다. 대상 PC의 같은 버전 공식 보조 실행 파일 3개를 복사하고 SHA-256으로 확인합니다.

설치 전 검사만 하려면 압축 해제한 폴더에서 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -CheckOnly
```

`ExecutionPolicy Bypass`는 해당 실행 프로세스에만 적용됩니다. 조직의 실행 정책이나 보안 제품이 차단하면 설치 결과의 실제 오류를 확인하세요. 이 빌드에는 OpenAI 코드 서명이 없습니다.

## 원복과 업데이트

설치 폴더의 `Uninstall.ps1`을 실행한 뒤 Codex 앱을 완전히 종료하고 원래 공식 바로가기로 실행합니다. 원복은 패치 실행을 비활성화하고 해당 바로가기를 제거합니다. 실행 파일과 기록은 남깁니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CodexIocpPatch\b5bffd3e\Uninstall.ps1"
```

`manifest.json`의 `schemaVersion: 2`와 `approvedCombinations`로 검증된 앱·엔진 조합을 관리합니다. 각 조합의 정확한 `packageFullName`, `backendVersion`, `patchedSha256`, `officialArtifacts`의 SHA-256이 모두 일치해야 설치·실행을 허용합니다. 현재 승인된 앱은 `26.908.4834.0`, 패치 엔진은 `0.154.0-alpha.6.2`뿐입니다.

이 기능은 Microsoft Store 자동 업데이트를 막지 않습니다. 공식 앱이 목록에 없는 버전으로 업데이트되면 패치 실행기를 중단합니다. 공식 바로가기로는 실행할 수 있지만 IOCP 패치 엔진은 적용되지 않습니다.

새 앱에서도 기존 패치 엔진과 보조 실행 파일의 호환성을 실제로 검증한 뒤 새 조합을 추가할 수 있습니다. 이 경우 Rust 엔진 재빌드 없이 스크립트·manifest를 갱신하고 ZIP을 다시 만듭니다. 엔진 변경이 필요할 때만 새 소스에 IOCP 패치를 적용해 빌드·회귀 테스트·실제 앱 연결을 검증합니다. 검사를 지우거나 버전 문자열만 임의로 추가하거나 다른 조합의 보조 실행 파일을 섞지 마세요.

## 검증 범위

- 동일한 조건에서 원본 회귀 테스트 2회 실패, 수정 후 통과.
- MCP 클라이언트 테스트 291개 통과, 8개 제외. Legacy/2026-07-28 stdio, 메시지 크기, 자식 프로세스 종료, 원격 exec-server 경로 포함.
- release 빌드 및 clippy 성공. enum 크기 경고 1건과 기존 코드 경고는 남아 있습니다.
- 제작 PC에서 실제 데스크톱이 패치 바이너리를 실행하고 모델·MCP 상태 조회에 응답하는 것을 확인했습니다.
- 다른 물리 PC에서의 실행은 아직 확인하지 않았습니다. 설치 파일의 경로 독립성과 버전/해시 검사는 별도 검증합니다.

이 패치는 확인한 파이프 스레드 고갈 원인을 해결하며 모든 종류의 멈춤을 보증하지 않습니다.

## 소스와 변경 내역

기준 소스: https://github.com/openai/codex/tree/b5bffd3ec4db487e7e3dec59663875b0ef7b72ca

태그: `rust-v0.154.0-alpha.6.2`. 원본에서 변경한 파일은 `source/modified-files`에, 적용 가능한 unified diff는 `source/windows-mcp-iocp.patch`에 들어 있습니다. 변경한 빌드임을 이 문서와 소스 diff로 표시합니다. 원본 라이선스·고지는 `LICENSE`, `NOTICE`를 보존했습니다.

변경 파일 6개: local_child.rs, windows_stdio.rs, local_stdio_transport.rs, bounded_stdio_transport.rs, stdio_server_launcher.rs, tests/stdio_message_limits.rs. 부모 파이프만 overlapped IOCP로 바꾸고 자식의 동기 stdio와 기존 Job Object 종료 처리를 유지했습니다. 외부 라이브러리를 추가하지 않았습니다.

재빌드 절차는 `source/BUILD.md`를 참고하세요.
