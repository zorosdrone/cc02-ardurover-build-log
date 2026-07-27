# サブプロジェクト

作業テーマごとに、本文資料と関連成果物を同じディレクトリで管理する。

| 番号 | プロジェクト | 主な内容 |
| --- | --- | --- |
| 01 | [FC換装](01_FC換装/README.md) | Pixhawk 6C Mini換装、配線、換装前後パラメータ、機体写真 |
| 02 | [チューニング](02_チューニング/README.md) | Roverチューニング、試験ログ、調整パラメータ、走行動画・写真 |
| 03 | [Lua障害物回避](03_Lua障害物回避/README.md) | SITL、Luaスクリプト、実機試験、画像・動画・ログ |
| 04 | [WebGCS遠隔操作](04_WebGCS遠隔操作/README.md) | RC Override、携帯回線経由の遠隔操作、関連パラメータ |
| 05 | [TELEM2 GPS検証](05_TELEM2_GPS検証/README.md) | Pixhawk 2.4.8のTELEM2 GPS接続とパススルー確認 |

## 配置方針

- プロジェクト固有の `params/`、`logs/`、`videos/`、`photos/` は各プロジェクト内に置く。
- 複数プロジェクトから参照する概要、現在状況、管理表はリポジトリ直下の `docs/` に置く。
- 採用ログと動画のGit LFS規則は、`.gitattributes` の `projects/**` パターンで管理する。
