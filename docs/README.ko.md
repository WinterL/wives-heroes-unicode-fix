# To the Wives Who Were Heroes — 실행 및 전체 화면 패치

[English](../README.md) · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · 한국어

- **실행 오류**: ANSI → Unicode 변환 오류를 수정합니다. 시스템 로캘을 일본어로 바꾸지 않고 기존 로캘과 UTF-8 설정을 유지할 수 있습니다.
- **전체 화면 전환 시 검은 화면**: 높은 DPI 배율에서 해상도를 잘못 인식하는 문제를 수정하고, 화면 비율을 유지하며 바탕 화면 크기에 맞춥니다. 다른 창으로 전환했다 돌아와도 정상적으로 조작할 수 있습니다.

이 패치는 비공식입니다. [Steam 공식 설명](https://store.steampowered.com/app/4358140/)은 일본어 시스템 로캘을 요구합니다. [공식 문제 해결 안내](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 설치

1. [Apply.cmd](../Apply.cmd) 파일 페이지 오른쪽 위의 다운로드 버튼을 누릅니다. [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0)에서 `utf8hack.intel32.clang.7z`를 받아 압축을 풀고 `utf8hack.dll`을 꺼냅니다.
2. Steam에서 게임 우클릭 → **관리 → 로컬 파일 보기**를 선택합니다. 열린 폴더에 `Apply.cmd`와 `utf8hack.dll`을 넣습니다.
3. 게임을 종료하고 **Apply.cmd**를 더블 클릭합니다. 완료되면 Steam에서 실행합니다.

## 작동 원리

| 파일 | 변경 내용 |
|---|---|
| `utf8hack.tpm` | `utf8hack.dll`을 복사하여 엔진이 플러그인으로 불러오는 이름으로 바꿉니다. |
| `yuusyatsuma.cf` | 스크립트를 `Shift_JIS`(CP932)로 읽고, 전체 화면을 현재 바탕 화면 해상도에 맞춰 비율을 유지하며 자동 확대·축소합니다. 16:9가 아닌 화면에는 검은 여백이 생깁니다. |
| `yuusyatsuma.eXe` | `ＭＳ Ｐゴシック`을 ASCII `MS PGothic`으로 바꾸고 DPI-aware 선언을 추가해 인코딩 오류와 전체 화면 해상도 오인식을 방지합니다. |

## 테스트 범위

Steam build **25049578**: 본편 **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. 테스트 환경: Windows **11 Pro 25H2 (26200.9457), x64**, 시스템 로캘 **zh-TW**, 코드 페이지 **UTF-8 (65001)**. 화면 **3840×2160, 배율 225%**.

일반 Steam 실행, 창 모드 메인 메뉴와 음악, 전체 화면 표시, 클릭 및 Alt+Tab을 확인했습니다. 전체 플레이, 저장/불러오기 및 다른 환경은 미검증입니다. EXE／플러그인 해시 불일치는 경고만 표시합니다. [테스트 상세](TESTING.md)

## 복원 및 라이선스

[Restore.cmd](../Restore.cmd)를 게임 폴더에 넣고 게임 종료 후 실행합니다. 복원에 성공하면 백업이 삭제되며 패치를 바로 다시 적용할 수 있습니다.

플러그인: [utf8hack](https://github.com/uyjulian/utf8hack), 원작자 **miahmie** ([원본 소스](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). 프로젝트 코드와 문서는 [MIT](../LICENSE)를 따릅니다. 타사 라이선스는 [제3자 고지](THIRD_PARTY_NOTICES.md)를 참고하세요. 문의나 삭제 요청은 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues)로 보내 주세요.
