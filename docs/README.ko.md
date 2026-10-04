# To the Wives Who Were Heroes — 실행·전체 화면·음성 패치

[English](../README.md) · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · 한국어

- **실행 오류**: ANSI → Unicode 변환 오류를 수정합니다. 시스템 로캘을 일본어로 바꾸지 않고 기존 로캘과 UTF-8 설정을 유지할 수 있습니다.
- **전체 화면 전환 시 검은 화면**: 높은 DPI 배율에서 해상도를 잘못 인식하는 문제를 수정하고, 화면 비율을 유지하며 바탕 화면 크기에 맞춥니다. 다른 창으로 전환했다 돌아와도 정상적으로 조작할 수 있습니다.
- **음성 및 대사 기록 재생 누락**: 일본어 시나리오와 대조하여 영어·번체 중국어·간체 중국어·한국어 시나리오의 일본어 음성과 대사 기록 재생을 수정합니다.

이 패치는 비공식입니다. [Steam 공식 설명](https://store.steampowered.com/app/4358140/)은 일본어 시스템 로캘을 요구합니다. [공식 문제 해결 안내](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 설치

### 실행 및 전체 화면

1. [Apply.cmd](../Apply.cmd) 파일 페이지 오른쪽 위의 다운로드 버튼을 누릅니다. [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0)에서 `utf8hack.intel32.clang.7z`를 받아 압축을 풀고 `utf8hack.dll`을 꺼냅니다.
2. Steam에서 게임 우클릭 → **관리 → 로컬 파일 보기**를 선택합니다. 열린 폴더에 `Apply.cmd`와 `utf8hack.dll`을 넣습니다.
3. 게임을 종료하고 **Apply.cmd**를 더블 클릭합니다. 완료되면 Steam에서 실행합니다.

### 음성 및 대사 기록 재생

1. 게임을 종료하고 [patch_3.xp3](../patch_3.xp3) 파일 페이지 오른쪽 위의 다운로드 버튼을 누릅니다. Steam에서 게임 우클릭 → **관리 → 로컬 파일 보기**를 선택하고, `yuusyatsuma.eXe`와 같은 폴더에 넣습니다.
2. 기존 `patch_1.xp3`와 `patch_2.xp3`는 그대로 둡니다. `patch_3.xp3`가 이미 있다면 게임 폴더 밖에 백업하고 출처를 확인한 뒤 교체 여부를 결정하세요. 같은 이름의 다른 패치와 충돌할 수 있습니다.
3. Steam에서 게임을 다시 실행하고 해당 장면에 다시 진입합니다. 기존 대사 기록에 없던 재생 링크가 자동으로 추가되지는 않습니다.

음성 패치는 독립적으로 설치할 수 있습니다. 음성만 수정할 경우 `Apply.cmd`나 `utf8hack.dll`은 필요하지 않습니다.

## 작동 원리

| 파일 | 변경 내용 |
|---|---|
| `utf8hack.tpm` | `utf8hack.dll`을 복사하여 엔진이 플러그인으로 불러오는 이름으로 바꿉니다. |
| `yuusyatsuma.cf` | 스크립트를 `Shift_JIS`(CP932)로 읽고, 전체 화면을 현재 바탕 화면 해상도에 맞춰 비율을 유지하며 자동 확대·축소합니다. 16:9가 아닌 화면에는 검은 여백이 생깁니다. |
| `yuusyatsuma.eXe` | `ＭＳ Ｐゴシック`을 ASCII `MS PGothic`으로 바꾸고 DPI-aware 선언을 추가해 인코딩 오류와 전체 화면 해상도 오인식을 방지합니다. |
| `patch_3.xp3` | 시나리오 54개를 우선 로드하여 음성 명령·음성 ID·대사 기록 재생을 수정하고, 번체·간체 중국어에서 빠진 자막과 대기를 각각 한 곳씩 보완합니다. |

일본어 시나리오의 대응 대사와 음성 명령을 기준으로 대조했습니다. 스크립트 54개에서 985줄을 수정했으며, 서로 다른 대사 985개를 의미하지 않습니다. 기존 일본어 음성을 사용하며 새 녹음은 추가하지 않았습니다. 구체적인 변경 내용은 [음성 패치 보고서](VOICE_PATCH_REPORT.txt)를 참고하세요.

## 테스트 범위

Steam build **25049578**: 본편 **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. 테스트 환경: Windows **11 Pro 25H2 (26200.9457), x64**, 시스템 로캘 **zh-TW**, 코드 페이지 **UTF-8 (65001)**. 화면 **3840×2160, 배율 225%**.

일반 Steam 실행, 창 모드 메인 메뉴와 음악, 전체 화면 표시, 클릭 및 Alt+Tab을 확인했습니다. 전체 플레이, 저장/불러오기 및 다른 환경은 미검증입니다. EXE／플러그인 해시 불일치는 경고만 표시합니다. [테스트 상세](TESTING.md)

음성 패치는 전체 시나리오의 언어별 대조를 완료하고, 원래 엔진의 파서로 음성·재생 명령 호출을 검증했습니다. 스크립트 수준의 검증이며, 모든 루트를 실제 플레이하거나 대사를 하나씩 청취한 것은 아닙니다. [범위 및 변경 내용](VOICE_PATCH_REPORT.txt)

## 복원 및 라이선스

실행·전체 화면 수정을 되돌리려면 [Restore.cmd](../Restore.cmd)를 게임 폴더에 넣고 게임 종료 후 실행합니다. 복원에 성공하면 백업이 삭제되며 두 수정을 바로 다시 적용할 수 있습니다. `Restore.cmd`는 음성 패치를 제거하지 않습니다.

음성 패치를 되돌리려면 게임을 종료하고 이 프로젝트의 `patch_3.xp3`만 삭제하거나 이름을 `patch_3.xp3.disabled`로 바꿉니다. 이전에 다른 `patch_3.xp3`를 백업했다면 복원하세요.

플러그인: [utf8hack](https://github.com/uyjulian/utf8hack), 원작자 **miahmie** ([원본 소스](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). 프로젝트 코드와 문서는 [MIT](../LICENSE)를 따릅니다. 타사 라이선스는 [제3자 고지](THIRD_PARTY_NOTICES.md)를 참고하세요. 문의나 삭제 요청은 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues)로 보내 주세요.

`patch_3.xp3`에 포함된 게임 시나리오 내용의 권리는 각 권리자에게 있으며, 이 프로젝트의 MIT 라이선스가 적용되지 않습니다.
