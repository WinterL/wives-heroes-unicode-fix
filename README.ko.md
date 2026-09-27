# To the Wives Who Were Heroes: Unicode 실행 오류 패치

[English](README.md) | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

Windows Steam판 **To the Wives Who Were Heroes / かつて勇者だった妻達へ**를 위한 **비공식 실험용 호환성 패치**입니다. 번체 중국어 시스템 로캘과 UTF-8 코드 페이지를 그대로 유지하면서 키리키리 2의 ANSI → Unicode 변환 오류를 해결하기 위해 파일 세 개를 변경합니다. 일본어 시스템 로캘, Locale Emulator, 엔진 교체는 필요하지 않습니다.

**검증 범위:** 기존 실행 오류를 통과하고 게임 제목이 있는 창과 초기 설정 파일을 생성했습니다. 전체 메뉴 표시, 실제 플레이, 음성 및 저장／불러오기는 **검증하지 않았습니다**. [테스트 기록](TESTING.md)을 확인하세요.

## 게임 및 외부 프로젝트 링크

- [Steam 게임: App 4358140](https://store.steampowered.com/app/4358140/)
- [DLsite 원작: RJ01464205](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html) — 원작 식별용 링크이며, **DLsite판은 테스트 및 지원 대상이 아닙니다**.
- [사용한 utf8hack 소스 및 릴리스](https://github.com/uyjulian/utf8hack) — 상위 프로젝트 README에 명시된 원작자는 **miahmie**입니다.
- [키리키리 2 저장소의 원본 utf8hack 소스](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)

## 지원 버전과 테스트 환경

| 항목 | 테스트한 값 |
|---|---|
| Steam build | **25049578** |
| 타이틀 화면에서 사용하는 게임 버전 정보 | 본편 **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23** |
| 키리키리 2 엔진 파일 버전 | **2.32.2.426** — 게임 버전과 다릅니다 |
| Windows | **Windows 11 Pro 25H2, 26200.9457, x64** |
| 비유니코드 프로그램용 시스템 로캘／사용자 문화권 | **zh-TW／zh-TW** |
| 시스템 ANSI／OEM 코드 페이지 | **65001／65001 (UTF-8)** |
| 플러그인 | utf8hack **v1.2.0, intel32.clang** |

게임 버전은 타이틀 화면 스크립트가 사용하는 로컬 버전 데이터에서 확인했습니다. 타이틀 화면 스크린샷으로 확인했다는 뜻은 아닙니다. 도구는 [supported_versions.json](supported_versions.json)의 EXE 및 게임 데이터 묶음 세 개의 SHA-256을 참고용으로 비교합니다. 불일치는 경고만 표시하고 설치를 계속하며 `--force`는 필요하지 않습니다. 단, 수정 위치의 글꼴 바이트는 알려진 상태와 일치해야 합니다. Windows 10, 한국어를 포함한 다른 로캘, 다른 판매처 버전은 검증하지 않았습니다. Windows가 64비트여도 게임은 32비트이므로 **32비트 플러그인**이 필요합니다.

## 처음 사용하는 분을 위한 설치 방법

1. 게임을 종료하고 정식으로 구입한 Steam판이 설치되어 있는지 확인하세요. [Windows용 Python 3.10 이상](https://www.python.org/downloads/windows/)이 필요합니다. 설치 시 launcher／PATH 옵션을 포함하세요. 도구는 Python 3.13.12로 테스트했습니다.
2. 이 저장소에서 **Code → Download ZIP**을 선택하고 다운로드한 파일을 우클릭하여 **모두 추출**하세요. ZIP 안에서 바로 실행하지 마세요.
3. [utf8hack v1.2.0 릴리스](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0)에서 **`utf8hack.intel32.clang.7z`**를 다운로드하세요. [7-Zip](https://www.7-zip.org/) 등으로 압축을 풀어 **`utf8hack.dll`**을 준비하세요. 플러그인 바이너리는 이 저장소에 포함하지 않습니다.
4. Steam에서 게임 우클릭 → **관리 → 로컬 파일 탐색**을 선택하세요. `yuusyatsuma.eXe`와 `data.xp3`가 있는 폴더를 확인하세요.
5. 저장소의 **`Apply.cmd`**를 더블 클릭하세요. 첫 창에서는 **게임 폴더**, 다음 창에서는 압축을 푼 **`utf8hack.dll`**을 선택하고 적용을 확인하세요. 대화상자는 영어입니다. 큰 데이터 파일의 해시 검사에는 시간이 조금 걸립니다.
6. 도구는 게임 폴더의 **`.unicode-fix-backup`**에 원본을 백업한 뒤 패치를 적용합니다. 버전이나 플러그인 해시가 다르면 경고만 표시하고 계속합니다. 기존 플러그인이 다르면 백업한 뒤 교체합니다. 백업은 보관하세요.
7. Steam 게임 **속성 → 일반 → 시작 옵션**에서 별도 테스트 복사본을 실행하는 이전 명령이 있다면 지우세요. 이 방식은 빈칸으로 두면 됩니다. 평소처럼 **플레이**를 누르세요.

Windows 언어 변경이나 재부팅은 필요하지 않습니다. 도구는 파일을 자동으로 다운로드하거나 업로드하지 않으며, 선택한 게임 폴더만 변경합니다. 기존 `savedata`는 건드리지 않습니다. 별도 테스트 복사본의 진행 상황은 자동으로 옮겨지지 않습니다.

## 변경 내용과 원리

| 파일 | 변경 내용 |
|---|---|
| `yuusyatsuma.eXe` | 오프셋 `0x2C82EA`의 CP932 글꼴 이름 `ＭＳ Ｐゴシック`을 ASCII `MS PGothic`으로 바꾸고 0으로 채워 길이를 유지합니다. 다른 EXE 바이트는 바꾸지 않습니다. |
| `yuusyatsuma.cf` | `readencoding=Shift_JIS`를 설정하고 나머지 설정, 인코딩, BOM, 줄바꿈은 보존합니다. `\xNN`은 엔진 설정 파일 문법입니다. |
| `utf8hack.tpm` | 선택한 상위 프로젝트 DLL을 `.tpm` 이름으로 복사하여 스크립트보다 먼저 로드합니다. 메모리에서 텍스트 읽기 함수를 교체하고 CP932로 스크립트를 읽습니다. |

플러그인만 적용하면 스크립트는 읽지만 네이티브 Layer 초기화에서 다시 오류가 발생했습니다. 글꼴 이름 수정은 이 두 번째 변환 오류를 해결합니다. 게임 데이터, 번역, 저장 형식, Windows 코드 페이지는 바꾸지 않습니다. 키리키리 Z는 별도 메뉴 호환성 오류가 있어 이 패치에서 사용하지 않습니다.

## 복구 및 문제 해결

- 게임을 종료한 뒤 **`Restore.cmd`**를 실행하고 같은 폴더를 선택하세요. 백업 파일을 복구하고, 원래 없었던 경우에만 추가 플러그인을 제거합니다. 저장 데이터와 백업은 유지됩니다.
- 패치 후 Steam 업데이트 등으로 파일이 변경되면 자동 복구는 덮어쓰기를 거부합니다. 백업을 보관하고 상황을 먼저 확인하세요.
- 복구 또는 설치 실패 후 다시 적용하려면 기존 `.unicode-fix-backup`을 게임 폴더 밖의 안전한 곳에 보관하세요. 기존 백업은 덮어쓰지 않습니다.
- 버전／플러그인 SHA-256 불일치는 경고만 표시하며 설치를 계속합니다. 호환성은 검증되지 않았습니다. CLI는 콘솔에, GUI는 완료 요약에도 경고를 표시합니다.
- 수정 위치의 바이트가 원본 또는 수정된 표식과 일치하지 않으면 중단합니다. 백업 무결성 검사와 복구 충돌 검사는 계속 엄격하게 적용됩니다. 이는 파일 보호이며 버전 제한이 아닙니다.
- 권한 또는 파일 잠금 오류가 나면 게임을 종료하고 폴더 쓰기 권한을 확인하세요. 설치에 실패하면 완료된 변경을 되돌리려고 시도합니다.
- Steam 업데이트나 무결성 검사는 EXE와 설정을 되돌리지만 추가 플러그인은 남길 수 있습니다. 새 빌드에 이전 패치를 무작정 적용하지 마세요.
- 실험용 런타임 플러그인입니다. 보안 프로그램이 차단하면 보호 기능을 끄지 말고 경고와 출처를 확인하세요.

## 명령줄과 테스트

```text
python patch.py check --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python patch.py apply --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes" --plugin "D:\Downloads\utf8hack.dll"
python patch.py restore --game-dir "D:\SteamLibrary\steamapps\common\To the Wives Who Were Heroes"
python -m unittest -v test_patch.py
```

경로는 예시이므로 실제 위치로 바꾸세요. `check`는 파일을 변경하지 않습니다. 테스트 범위와 선택적인 로컬 통합 테스트는 [TESTING.md](TESTING.md)에 설명되어 있습니다.

## 라이선스, 개인정보 및 삭제 요청

이 저장소에서 직접 작성한 도구, 스크립트, 테스트, 문서는 **[MIT License](LICENSE)**로 제공합니다. 게임, 엔진, utf8hack에는 원래 권리와 라이선스가 적용됩니다. MIT는 해당 파일이나 수정된 게임 EXE의 재배포 권한을 부여하지 않습니다. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참조하세요.

모든 파일명은 ASCII입니다. 개인 설치 경로, 인증 정보, 저장 데이터, 게임 리소스, 원본 사용자 로그는 포함하지 않습니다. 백업은 사용자 PC에만 남으며 manifest에는 절대 경로를 기록하지 않습니다. 개발사, 배급사, 상위 프로젝트 작성자의 공식 지원이나 승인을 받은 프로젝트가 아닙니다.

저작권, 라이선스, 표기 또는 기타 우려가 있다면 **[Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues)를 통해 관리자에게 삭제를 요청해 주세요**. 해당 파일／링크와 이유를 알려 주시면 검토 후 필요한 내용을 삭제하겠습니다. 게임 파일이나 개인정보를 첨부하지 마세요. 비공개 저장소의 Issues는 접근 권한이 있는 사람만 이용할 수 있습니다.
