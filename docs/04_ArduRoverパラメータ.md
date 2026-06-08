# ArduRoverパラメータ

## 管理方針

大きなハードウェア変更やチューニング変更の前後では、必ずパラメータを書き出します。`.param` ファイルは日付が分かる名前で `params/` 配下に保存します。

推奨ファイル名:

```text
YYYY-MM-DD_機体状態_短い説明.param
```

例:

```text
params/before_fc_replace/2026-06-07_pixhawk248_original.param
params/after_fc_replace/2026-06-07_pixhawk6c_initial.param
params/tuned/2026-06-07_pixhawk6c_tuned_01.param
```

## パラメータスナップショット

| 日付 | ファイル | 機体状態 | 概要 |
| --- | --- | --- | --- |
| | | | |

## 重点確認パラメータ

| 分野 | パラメータ | 現在値 / 期待値 | メモ |
| --- | --- | --- | --- |
| ボード向き | `AHRS_ORIENTATION` | | |
| フライトモードチャンネル | `FLTMODE_CH` | | |
| RCフェイルセーフ | `FS_THR_ENABLE` | | |
| バッテリーモニタ | `BATT_MONITOR` | PM02接続後に確認 | 旧FCの値を丸コピーせず、6C Mini + PM02構成で確認する。 |
| 電圧ピン | `BATT_VOLT_PIN` | PM02接続後に確認 | Pixhawk 2.4.8Pro時代の値は参考値扱い。 |
| 電流ピン | `BATT_CURR_PIN` | PM02接続後に確認 | Pixhawk 2.4.8Pro時代の値は参考値扱い。 |
| 電圧倍率 | `BATT_VOLT_MULT` | PM02接続後に確認 | 実測電圧とMission Planner表示を比較して必要なら調整する。 |
| Raspberry Pi / MAVLink | `SERIAL1_PROTOCOL` / `SERIAL1_BAUD` | `2` / `921`候補 | 6C MiniでRaspberry Piを`TELEM1`へ移す場合の候補。実ポート確認後に設定する。 |
| LiDAR / RangeFinder | `SERIAL2_PROTOCOL` / `SERIAL2_BAUD` | `9` / `115`候補 | 6C MiniでLiDARを`TELEM2`へ接続する場合の候補。現行`SERIAL4_PROTOCOL=9`, `SERIAL4_BAUD=115`から移す。 |
| GPS2 | `SERIAL4_PROTOCOL` | `5`候補 | 6C Miniでは`SERIAL4`が物理`GPS2`。現行M8N GPS用に使うため、RangeFinder設定を丸コピーしない。 |
| ステアリング出力 | | | |
| スロットル出力 | | | |
| 速度制御 | | | |
| ナビゲーション調整 | | | |

## 変更履歴

| 日付 | パラメータ | 変更前 | 変更後 | 理由 | 結果 |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## 復元メモ

- 復元元パラメータ:
- 対象FC:
- ファームウェアバージョン:
- 意図的に復元しなかったパラメータ:
- 復元後に再実施したキャリブレーション:
