# ArduRoverパラメータ

## 管理方針

大きなハードウェア変更やチューニング変更の前後では、必ずパラメータを書き出します。`.param` ファイルは日付が分かる名前で `params/` 配下に保存します。

推奨ファイル名:

```text
YYYY-MM-DD_機体状態_短い説明.param
```

例:

```text
params/before_fc_replace/20260607_before_fc_replace.param
params/after_fc_replace/20260608_pixhawk6c_ardurover_initial.param
params/after_fc_replace/20260608_pixhawk6c_bench_ok.param
params/tuned/20260608_pixhawk6c_tuned_01.param
```

## パラメータスナップショット

| 日付 | ファイル | 機体状態 | 概要 |
| --- | --- | --- | --- |
| 2026-06-07 | `params/before_fc_replace/20260607_before_fc_replace.param` | Pixhawk 2.4.8Pro / 換装前 | 換装前の正本。旧FC設定の参照用であり、6C Miniへ丸コピーしない。 |

## Pixhawk 6C Mini 初期設定候補

| 分野 | パラメータ | 候補値 | 理由 / 注意 |
| --- | --- | --- | --- |
| Firmware target | `Pixhawk6C` | Mission PlannerでRoverを書き込み | Pixhawk 6C MiniはPixhawk 6Cと同じFirmware Targetを使う。 |
| PM02 | `BATT_MONITOR` | `4` | Analog Voltage and Current。 |
| PM02 | `BATT_VOLT_PIN` | `8` | Pixhawk 6C / 6C Mini Power Monitor 1候補。 |
| PM02 | `BATT_CURR_PIN` | `4` | Pixhawk 6C / 6C Mini Power Monitor 1候補。 |
| PM02 | `BATT_VOLT_MULT` | `18.182` | 2026-06-09、スモークストッパーなしで実測12.40V / MP表示12.44V。差分+0.04V、約+0.3%のため、この値を採用。 |
| PM02 | `BATT_AMP_PERVLT` | `36.364` | 電流表示は実負荷で再確認。 |
| Raspberry Pi / MAVLink | `SERIAL1_PROTOCOL` / `SERIAL1_BAUD` | `2` / `921` | `TELEM1`で動作確認OK。 |
| LiDAR / RangeFinder | `SERIAL2_PROTOCOL` / `SERIAL2_BAUD` | `9` / `115` | `TELEM2`へ移す候補。現行`SERIAL4`から移す。 |
| M8N GPS | `SERIAL4_PROTOCOL` / `SERIAL4_BAUD` | `5` / `230` | 6C Miniでは`SERIAL4`が物理`GPS2`。旧M8N流用は保留。 |
| 暫定M10 GPS | `GPS1_TYPE` | `1` | 2026-06-09、`GPS1` 10ピン接続で屋内`Not Fix`、屋外`3D Fix`確認済み。 |
| LiDAR / RangeFinder | `RNGFND1_TYPE` | `20` | 現行TF-Luna設定を維持候補。 |
| LiDAR / RangeFinder | `RNGFND1_MIN_CM` | `20` | 現行値を維持候補。 |
| LiDAR / RangeFinder | `RNGFND1_MAX_CM` | `200` | 現行値を踏襲。rover-gcsのAuto-stop最大閾値`100cm`を十分カバーする。`700`は必要時の一時確認値。 |
| LiDAR / RangeFinder | `RNGFND1_SCALING` | `3` | 現行値を維持候補。 |
| ステアリング | `SERVO1_FUNCTION` | `26` | `MAIN 1`、Ground Steering。 |
| ESC / スロットル | `SERVO3_FUNCTION` | `70` | `MAIN 3`、Throttle。 |
| モード | `MODE_CH` | `8` | 現行モードチャンネルを維持候補。 |
| RC入力 | `RCMAP_THROTTLE` | `2` | 2026-06-09、前進/後進入力をCh2へ変更。Manual走行確認済み。 |
| Compass | `COMPASS_ENABLE` | `0` | 室内Manual走行テスト用の一時設定。屋外/自律系確認前に`1`へ戻す。 |
| 補助スイッチ | `RC7_OPTION` | `153` | 現行値。実機スイッチで再確認。 |
| ARM必須 | `ARMING_REQUIRE` | `1` | 起動直後に走行しないため必須。 |
| PreArmチェック | `ARMING_CHECK` | `1`候補 | 現行は`0`だが、換装後は安全側へ見直す。 |
| Safety Buttonなし | `BRD_SAFETY_DEFLT` | `0`候補 | Safety Buttonを移植しない方針。 |
| DISARM時出力 | `MOT_SAFE_DISARM` | `1`候補 | ESC挙動を見て最終判断。 |

## 重点確認パラメータ

| 分野 | パラメータ | 現在値 / 期待値 | メモ |
| --- | --- | --- | --- |
| ボード向き | `AHRS_ORIENTATION` | | |
| フライトモードチャンネル | `MODE_CH` | `8`候補 | Roverのモードチャンネル。現行値を維持候補。 |
| RCフェイルセーフ | `FS_THR_ENABLE` | | |
| バッテリーモニタ | `BATT_MONITOR` | PM02接続後に確認 | 旧FCの値を丸コピーせず、6C Mini + PM02構成で確認する。 |
| 電圧ピン | `BATT_VOLT_PIN` | PM02接続後に確認 | Pixhawk 2.4.8Pro時代の値は参考値扱い。 |
| 電流ピン | `BATT_CURR_PIN` | PM02接続後に確認 | Pixhawk 2.4.8Pro時代の値は参考値扱い。 |
| 電圧倍率 | `BATT_VOLT_MULT` | 現在`18.182` | 2026-06-09にスモークストッパーなしで再測定済み。実測12.40V / MP表示12.44Vで差分+0.04Vのため、追加補正なし。 |
| Raspberry Pi / MAVLink | `SERIAL1_PROTOCOL` / `SERIAL1_BAUD` | `2` / `921` | 6C Mini `TELEM1`で動作確認OK。 |
| LiDAR / RangeFinder | `SERIAL2_PROTOCOL` / `SERIAL2_BAUD` | `9` / `115`候補 | 6C MiniでLiDARを`TELEM2`へ接続する場合の候補。現行`SERIAL4_PROTOCOL=9`, `SERIAL4_BAUD=115`から移す。 |
| GPS2 | `SERIAL4_PROTOCOL` | `5`候補 | 6C Miniでは`SERIAL4`が物理`GPS2`。現行M8N GPS用に使うため、RangeFinder設定を丸コピーしない。 |
| GPS1 | `GPS1_TYPE` | `1` | 暫定M10 GPSを`GPS1` 10ピンへ接続し、屋外`3D Fix`確認済み。 |
| RangeFinder最大距離 | `RNGFND1_MAX_CM` | `200`候補 | 現行値を踏襲。Auto-stop運用では`40 / 60 / 80 / 100cm`を監視するため、`200cm`で足りる。 |
| ステアリング出力 | `SERVO1_FUNCTION` | `26` | `MAIN 1`。 |
| スロットル出力 | `SERVO3_FUNCTION` | `70` | `MAIN 3`。 |
| スロットル入力 | `RCMAP_THROTTLE` | `2` | 前進/後進はCh2。出力先は引き続き`MAIN 3` / `SERVO3_FUNCTION=70`。 |
| コンパス有効化 | `COMPASS_ENABLE` | `0` | 室内Manual走行テスト用。屋外/Auto/Guided/RTL/SmartRTL確認前は`1`へ戻し、Compass Calibrationを行う。 |
| 速度制御 | | | |
| ナビゲーション調整 | | | |

## 変更履歴

| 日付 | パラメータ | 変更前 | 変更後 | 理由 | 結果 |
| --- | --- | --- | --- | --- | --- |
| 2026-06-09 | `SERIAL1_PROTOCOL` / `SERIAL1_BAUD` | 現行`SERIAL2_PROTOCOL=2`, `SERIAL2_BAUD=921` | `2` / `921` | Raspberry Pi / MAVLinkを6C Mini `TELEM1`へ移すため | 動作確認OK |
| 2026-06-08 | `SERIAL2_PROTOCOL` / `SERIAL2_BAUD` | 現行LiDARは`SERIAL4_PROTOCOL=9`, `SERIAL4_BAUD=115` | `9` / `115`候補 | LiDARを6C Mini `TELEM2`へ移すため | 未実施 |
| 2026-06-08 | `SERIAL4_PROTOCOL` / `SERIAL4_BAUD` | 現行LiDAR設定 | `5` / `230`候補 | 6C Miniでは`SERIAL4`が物理`GPS2`のため、M8N GPS用に使う | 未実施 |
| 2026-06-09 | 暫定M10 GPS / `GPS1_TYPE` | 旧M8N `GPS2`流用で`No GPS` | `GPS1_TYPE=1` | 別プロジェクトのM10 GPSを`GPS1` 10ピンへ接続して切り分け | 屋内`Not Fix`、屋外`3D Fix`確認済み |
| 2026-06-09 | PM02電圧表示 / `BATT_VOLT_MULT` | 未記録 | `18.182` | PM02電圧倍率として実機へ暫定設定 | スモークストッパー使用時の測定値だったため参考値扱い。通常給電で再測定する |
| 2026-06-09 | PM02電圧表示確認 | `BATT_VOLT_MULT=18.182` | 変更なし | 設定後の画面確認 | Mission Planner表示`12.37V`。ただしスモークストッパー使用時の可能性があるため校正根拠にしない |
| 2026-06-09 | PM02電圧表示再確認 | `BATT_VOLT_MULT=18.182` | 変更なし | スモークストッパーなしで再測定 | 実測12.40V、Mission Planner表示12.44V。差分+0.04V、約+0.3%のため追加補正なし |
| 2026-06-09 | `RCMAP_THROTTLE` | `3` | `2` | 前進/後進入力をCh2へ変更 | Manual走行確認済み。出力は`MAIN 3`のまま |
| 2026-06-09 | `COMPASS_ENABLE` | `1` | `0` | 室内Manual走行テストでコンパス磁気エラーを避けるため | Manual走行確認用の一時設定。屋外/自律系確認前に`1`へ戻す |
| 2026-06-08 | `RNGFND1_MAX_CM` | `200` | `200`候補 | rover-gcsのAuto-stop最大閾値`100cm`を十分カバーするため現行値を踏襲。`700`は必要時の一時確認値 | 未実施 |

## 復元メモ

- 復元元パラメータ: `params/before_fc_replace/20260607_before_fc_replace.param`
- 対象FC: Holybro Pixhawk 6C Mini
- ファームウェアバージョン: ArduRover書き込み後に記録
- 意図的に復元しなかったパラメータ: `SERIALx_*`, `BATT_*`, `BRD_SAFETY_*`, `ARMING_CHECK`, `MOT_SAFE_DISARM`
- 復元後に再実施したキャリブレーション:
