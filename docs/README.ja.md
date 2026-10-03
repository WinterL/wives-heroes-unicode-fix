# かつて勇者だった妻達へ — 起動・全画面修正パッチ

[English](../README.md) · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · 日本語 · [한국어](README.ko.md)

- **起動エラー**：ANSI → Unicode 変換エラーを修正します。現在のシステムロケールと UTF-8 設定を維持でき、日本語ロケールへの変更は不要です。
- **全画面にすると真っ黒になる問題**：高 DPI 環境での解像度の誤認識を修正し、デスクトップに合わせて縦横比を保って表示します。別のウィンドウへ切り替えて戻った後も操作できます。

これは非公式パッチです。[Steam の公式説明](https://store.steampowered.com/app/4358140/)では日本語のシステムロケールが必要とされています。[公式トラブルシューティング](https://store.steampowered.com/news/app/4358140/view/717917724409331753?l=tchinese) · [DLsite](https://www.dlsite.com/maniax/work/=/product_id/RJ01464205.html)

## インストール

1. [Apply.cmd](../Apply.cmd) をファイルページ右上のボタンでダウンロードします。[utf8hack v1.2.0](https://github.com/uyjulian/utf8hack/releases/tag/v1.2.0) の `utf8hack.intel32.clang.7z` をダウンロードし、`utf8hack.dll` を展開します。
2. Steam でゲームを右クリック → **管理 → ローカルファイルを閲覧**。開いたフォルダーに `Apply.cmd` と `utf8hack.dll` を置きます。
3. ゲームを終了して **Apply.cmd** をダブルクリックし、完了後に Steam から起動します。

## 仕組み

| ファイル | 変更内容 |
|---|---|
| `utf8hack.tpm` | `utf8hack.dll` をコピーし、エンジンがプラグインとして読み込む名前にします。 |
| `yuusyatsuma.cf` | `Shift_JIS`（CP932）でスクリプトを読み込み、全画面では現在のデスクトップ解像度に合わせて縦横比を保ち自動拡大・縮小します。16:9 以外の画面では黒帯が入ります。 |
| `yuusyatsuma.eXe` | `ＭＳ Ｐゴシック` を ASCII の `MS PGothic` に変更し、DPI-aware 宣言を追加して、文字コードエラーと全画面解像度の誤認識を防ぎます。 |

## 検証範囲

Steam build **25049578**：本体 **0.26.6.22**、Patch 1 **1.26.6.12**、Patch 2 **2.26.7.23**。検証環境：Windows **11 Pro 25H2（26200.9457）、x64**、システムロケール **zh-TW**、コードページ **UTF-8（65001）**。画面 **3840×2160、拡大率 225%**。

通常の Steam 起動、ウィンドウのメインメニューと音楽、全画面表示、クリック、Alt+Tab を確認済みです。全編プレイ、セーブ／ロード、他の環境は未検証です。EXE／プラグインのハッシュ不一致は警告のみです。[テスト詳細](TESTING.md)

## 復元とライセンス

[Restore.cmd](../Restore.cmd) をゲームフォルダーに置き、ゲーム終了後に実行します。復元に成功するとバックアップが削除され、そのままパッチを再適用できます。

プラグイン：[utf8hack](https://github.com/uyjulian/utf8hack)、原作者 **miahmie**（[原ソース](https://github.com/krkrz/krkr2/tree/master/kirikiri2/trunk/kirikiri2/src/plugins/win32/utf8hack)）。本プロジェクトのコードと文書は [MIT](../LICENSE) です。第三者のライセンスは[告知](THIRD_PARTY_NOTICES.md)をご確認ください。懸念や削除依頼は [Issues](https://github.com/WinterL/wives-heroes-unicode-fix/issues) へご連絡ください。
