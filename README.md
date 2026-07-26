# CC-02 ArduRover 実機ビルドログ

このリポジトリは、タミヤ CC-02 ベースの ArduRover 実機について、FC換装、配線変更、ArduRoverパラメータ、チューニング、走行試験、トラブルシュートを記録するための作業ログです。

## 現在の状態

2026-06-13時点で、Pixhawk 6C Mini換装後の屋外低速チューニングは一通り完了しています。

- 通常運用向け終了版: `params/tuned/20260613_pixhawk6c_rover_tuned_01.param`
- QuikTune直後版: `params/tuned/20260613_06_after_quiktune.param`
- BendyRuler実験版: `params/tuned/20260613_08_oa_type1_bendyruler_test.param`
- Rover QuikTune完了: `RTun: Tuning DONE` / `RTun: tuning gains saved`
- Battery failsafe確認済み: Low=RTL、Critical=Hold
- Simple Object Avoidance確認済み: Acro低速停止、Guided中の障害物停止
- RTL / SmartRTL確認済み。ただしRTL / SmartRTL中のLiDARは停止保証として扱わない

詳細は [現在状況](docs/01_現在状況.md) と [チューニングログ](docs/02_チューニング/09_チューニングログ.md) を参照してください。`Lua障害物回避`は、実機ファームウェアに合わせたArduRover 4.6.3 SITL手順を基準に、前方Rangefinderと仮想ポスト表示の検証を進めています。

## 目的

- FC換装作業を記録する
- 配線とハードウェア変更を追跡する
- ArduRoverパラメータの履歴を保存する
- チューニング内容と結果を記録する
- 走行試験の条件、結果、課題を残す
- 再解析価値の高い代表ログをGit LFSで保存する
- 公開用の走行・チューニング動画をGit LFSで保存する
- 実機用小物部品のOpenSCAD設計元とSTL出力を保存する
- トラブルシュートの経緯を再利用できる形で保存する

## 関連リポジトリ

GCSアプリ本体は別リポジトリで管理します。

- `rover-gcs`

`rover-gcs` に含まれるハードウェア資料は、初期プロトタイプ時点の記録としてそのまま残します。今後の最新実機構成、FC換装、配線、パラメータ、チューニング、走行試験記録は、この `cc02-ardurover-build-log` 側に積み上げます。

## リポジトリ構成

- `docs/` - 実機構成、換装計画、配線、チューニングなどの本文資料
- `params/` - Mission Planner などから書き出した ArduRover パラメータ
- `logs/` - 走行試験メモと代表DataFlashログ。代表ログ本体は `logs/accepted/` に置き、Git LFSで管理
- `videos/` - 公開用の走行・チューニング動画。動画本体は Git LFS で管理
- `photos/` - 配線、FC固定、現地走行、機体状態の写真
- `cad/` - Codexで作成したOpenSCADコードと、3Dプリント用にエクスポートしたSTL
- `diagrams/` - 配線図、構成図、信号系統図
- `notes/` - 未整理メモ、一時メモ、判断メモ
- `参考資料/` - パーツメーカー公式Doc、ピン配列、配線図、CADなどの保存資料

## 管理方針

このリポジトリには、実機の整備記録として必要なものだけを入れます。

入れるもの:

- FC換装記録
- 配線写真
- ArduRoverパラメータ
- チューニングログ
- 走行試験記録
- 再解析価値の高い代表 `.bin` ログ
- 公開用動画
- 部品リスト
- 実機用小物部品のCAD設計元とSTL出力
- トラブルシュート

入れないもの:

- Reactコード
- FastAPIコード
- GCSのUI改修
- Webアプリの実装

## 大容量ファイルとGit LFS

代表ログと公開用動画はGit LFSで管理します。

Git LFS対象:

- `logs/accepted/**/*.bin`
- `logs/accepted/**/*.BIN`
- `logs/accepted/**/*.ulg`
- `logs/accepted/**/*.tlog`
- `videos/**/*.mp4`
- `videos/**/*.mov`

方針:

- すべての生ログを入れるのではなく、再解析価値が高い代表ログだけを `logs/accepted/` に置く。
- GPS位置、Home位置、走行軌跡を含むログは、公開リポジトリに置く前に公開可否を確認する。
- 日々の試験記録は `logs/test_runs/` のMarkdownに残す。
- 公開用動画は `videos/` に置く。
- 写真はGitHubで閲覧しやすいサイズへ縮小してから `photos/` に置く。

代表ログと動画の一覧:

- [ログ管理](logs/ログ管理.md)
- [動画管理](videos/動画管理.md)
- [写真管理](photos/写真管理.md)

## 主要ドキュメント

番号順が、実機作業の流れです。

### 全体把握

- [概要](docs/00_概要.md)
- [現在状況](docs/01_現在状況.md)

### FC換装

- [FC換装計画](docs/01_FC換装/02_FC換装計画.md)
- [Pixhawk 6C mini換装メモ](docs/01_FC換装/03_Pixhawk6Cmini換装メモ.md)
- [配線](docs/01_FC換装/04_配線.md)
- [ArduRoverインストール設定手順](docs/01_FC換装/05_ArduRoverインストール設定手順.md)

### 換装後確認

- [ArduRoverパラメータ](docs/01_FC換装/06_ArduRoverパラメータ.md)
- [走行試験](docs/01_FC換装/07_走行試験.md)

### チューニング

- [ArduRoverチューニング手順](docs/02_チューニング/08_ArduRoverチューニング手順.md)
- [チューニングログ](docs/02_チューニング/09_チューニングログ.md)

### 障害物回避 / Lua

- [Lua障害物回避プロジェクト概要](docs/03_Lua障害物回避/README.md)
- [Rover SITL前方Rangefinder / 標準OA / Lua設定手順](docs/03_Lua障害物回避/01_RoverSITL前方Rangefinder設定手順.md)
- [開発検討: LuaとC++独自モードの実装判断](docs/03_Lua障害物回避/今後の開発検討/LuaとC++の実装判断.md)
- [開発検討: Guided位置指定対応Lua障害物回避仕様書](docs/03_Lua障害物回避/今後の開発検討/Guided位置指定対応Lua障害物回避仕様書.md)
- [SITL Luaサンプルスクリプト](docs/03_Lua障害物回避/05_SITL_Luaサンプルスクリプト.md)
- [最低限Guided回避Lua解説](docs/03_Lua障害物回避/06_MinGuided回避Lua解説.md)
- [Lua障害物回避 実機テスト手順](docs/03_Lua障害物回避/07_実機テスト手順.md)
- [SITLから実機移行で起きた問題と再発防止](docs/03_Lua障害物回避/08_SITLから実機移行で起きた問題と再発防止.md)
- [仮想ポストKML表示補助](docs/03_Lua障害物回避/補助機能/10_MP_仮想ポストKML表示補助.md)

### 参照

- [トラブルシュート](docs/10_トラブルシュート.md)
- [部品リスト](docs/11_部品リスト.md)
- [DigitalOcean運用メモ](docs/13_DigitalOcean運用メモ.md)
- [ハードウェア判断ルール](docs/hardware-assumptions.md)
- [CADフォルダ説明](cad/README.md)
