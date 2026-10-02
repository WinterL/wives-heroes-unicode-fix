# To the Wives Who Were Heroes — 실행 오류 패치

[English](../README.md) · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · 한국어

Windows에서 UTF-8을 켰을 때 게임 실행 중 발생하는 ANSI → Unicode 변환 오류를 수정하는 비공식 패치입니다. [Steam](https://store.steampowered.com/app/4358140/) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## 설치

1. [Apply.cmd](../Apply.cmd) 파일 페이지 오른쪽 위의 다운로드 버튼을 누릅니다. [utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0)에서 `utf8hack.intel32.clang.7z`를 받아 압축을 풀고 `utf8hack.dll`을 꺼냅니다.
2. Steam에서 게임 우클릭 → **관리 → 로컬 파일 보기**를 선택합니다. 열린 폴더에 `Apply.cmd`와 `utf8hack.dll`을 넣습니다.
3. 게임을 종료하고 **Apply.cmd**를 더블 클릭합니다. 완료되면 Steam에서 실행합니다.

## 작동 원리

| 파일 | 변경 내용 |
|---|---|
| `utf8hack.tpm` | `utf8hack.dll`을 복사하여 엔진이 플러그인으로 불러오는 이름으로 바꿉니다. |
| `yuusyatsuma.cf` | `Shift_JIS`를 지정하여 플러그인이 스크립트를 CP932로 읽도록 합니다. |
| `yuusyatsuma.eXe` | 글꼴 이름을 `ＭＳ Ｐゴシック`에서 `MS PGothic`으로 바꿔 또 다른 인코딩 오류를 피합니다. |

## 테스트 범위

Steam build **25049578**: 본편 **0.26.6.22**, Patch 1 **1.26.6.12**, Patch 2 **2.26.7.23**. 테스트 환경: Windows **11 Pro 25H2 (26200.9457), x64**, 시스템 로캘 **zh-TW**, 코드 페이지 **UTF-8 (65001)**.

창 모드 메인 메뉴와 음악은 정상입니다. **전체 화면은 여전히 검게 나옵니다**. 전체 플레이와 저장/불러오기는 미검증입니다. EXE／플러그인 해시 불일치는 경고만 표시합니다. [테스트 상세](TESTING.md)

## 복원 및 라이선스

[Restore.cmd](../Restore.cmd)를 게임 폴더에 넣고 게임 종료 후 실행합니다. `.unicode-fix-backup`은 보관하세요. 복원 후 다시 적용하려면 먼저 이 백업을 게임 폴더 밖으로 옮깁니다.

플러그인: [utf8hack](https://github.com/uyjulian/utf8hack), 원작자 **miahmie** ([원본 소스](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)). 프로젝트 코드와 문서는 [MIT](../LICENSE)를 따릅니다. 타사 라이선스는 [제3자 고지](THIRD_PARTY_NOTICES.md)를 참고하세요. 문의나 삭제 요청은 [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues)로 보내 주세요.
