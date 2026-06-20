# ArduRoverパラメータ

## 管理方針

大きなハードウェア変更、屋外試験、チューニング変更の前後では、必ずパラメータを書き出す。`.param` ファイルは日付と状態が分かる名前で `params/` 配下に保存する。

推奨ファイル名:

```text
YYYYMMDD_機体状態_短い説明.param
```

例:

```text
params/before_fc_replace/20260607_before_fc_replace.param
params/after_fc_replace/20260608_pixhawk6c_ardurover_initial.param
params/tuned/20260610_before_tune.param
params/tuned/20260610_after_manual_hold_fs_check.param
params/tuned/20260610_after_acro_speed_check.param
```

## 現在の正本

| 日付 | ファイル | 機体状態 | 概要 |
| --- | --- | --- | --- |
| 2026-06-13 | `params/tuned/20260613_pixhawk6c_rover_tuned_01.param` | 2026-06-13チューニング終了版 | QuikTune後、通常運用向け。`OA_TYPE=0`。 |
| 2026-06-13 | `params/tuned/20260613_08_oa_type1_bendyruler_test.param` | BendyRuler実験版 | `OA_TYPE=1`、小回り回避実験用。通常運用正本とは分ける。 |
| 2026-06-13 | `params/tuned/20260613_06_after_quiktune.param` | QuikTune直後 | `RTun: Tuning DONE` / `tuning gains saved` 後。 |
| 2026-06-10 | `params/tuned/20260610_before_tune.param` | Pixhawk 6C Mini換装後 / チューニング前 | 現在のチューニング前ベースライン。このファイルは上書きしない。 |
| 2026-06-09 | `params/after_fc_replace/20260609_pixhawk6c_indoor_manual_ch2_ch5_ok.param` | 屋内Manual確認時 | 2026-06-10版の直前参照。 |
| 2026-06-08 | `params/after_fc_replace/20260608__pixhawk6c_ardurover_initial.param` | ArduRover初期書き込み後 | 初期状態の参照。 |
| 2026-06-07 | `params/before_fc_replace/20260607_before_fc_replace.param` | Pixhawk 2.4.8Pro / 換装前 | 換装前の正本。6C Miniへ丸コピーしない。 |

## 2026-06-13 終了時採用値

`params/tuned/20260613_pixhawk6c_rover_tuned_01.param` から抜粋。

| 分野 | パラメータ | 値 | 記録 / 判断 |
| --- | --- | --- | --- |
| Arming | `ARMING_CHECK` / `ARMING_MAGTHRESH` | `1` / `100` | PreArm維持。磁場警告の一時緩和候補は`150`。 |
| Compass | `COMPASS_ENABLE` / `COMPASS_EXTERNAL` / `COMPASS_ORIENT` | `1` / `1` / `6` | M10 IST8310。`Yaw270`。 |
| Battery FS | `BATT_LOW_VOLT` / `BATT_CRT_VOLT` | `10.8` / `10.2` | 動作確認成功。 |
| Battery FS | `BATT_FS_LOW_ACT` / `BATT_FS_CRT_ACT` | `1` / `2` | Low=RTL、Critical=Hold。 |
| RC map | `RCMAP_ROLL` / `RCMAP_THROTTLE` | `4` / `2` | 左スティック左右をステアリング入力に変更。 |
| Mode | `MODE1/2/5` | `4` | Hold。 |
| Mode | `MODE3/4` | `0` | Manual。 |
| Mode | `MODE6` | `1` | Acro。 |
| Speed | `CRUISE_SPEED` / `CRUISE_THROTTLE` | `0.9776623` / `45` | QuikTune後。 |
| Speed | `ATC_SPEED_P/I/D/FF` | `0.4604364 / 0.4604364 / 0 / 0` | QuikTune後。 |
| Steering tune | `ATC_STR_RAT_FF/P/I/D` | `0.3646377 / 0.1823188 / 0.1823188 / 0` | QuikTune後。 |
| Simple OA | `OA_TYPE` / `PRX1_TYPE` / `AVOID_ENABLE` | `0` / `4` / `7` | 通常運用。Guided中の障害物停止を確認済み。 |
| Simple OA | `AVOID_MARGIN` / `AVOID_BACKUP_SPD` | `2` / `0` | 停止重視。バックは未採用。 |
| QuikTune | `SCR_ENABLE` / `RTUN_ENABLE` | `1` / `1` | 再実行しない時は`Scripting1=Low`。 |

## 2026-06-10 ベースライン値

`params/tuned/20260610_before_tune.param` から抜粋。

| 分野 | パラメータ | 現在値 | 記録 / 判断 |
| --- | --- | --- | --- |
| Arming | `ARMING_CHECK` | `1` | 屋外前にPreArmエラーを解消する。 |
| Motor | `MOT_SAFE_DISARM` | `1` | DISARM時出力をタイヤ浮かせで再確認する。 |
| Motor | `MOT_SLEWRATE` | `100` | 初期値維持。発進が急すぎる場合に検討。 |
| Steering | `SERVO1_FUNCTION` | `26` | Ground Steering。 |
| Steering | `SERVO1_MIN / TRIM / MAX` | `1100 / 1500 / 1900` | 実車の左右限界と中立で確認する。 |
| Throttle | `SERVO3_FUNCTION` | `70` | Throttle。 |
| Throttle | `SERVO3_MIN / TRIM / MAX` | `1350 / 1500 / 1750` | 中立、前進、後退、DISARM時挙動を確認する。 |
| RC map | `RCMAP_ROLL` / `RCMAP_THROTTLE` | `1` / `2` | ステアリングRC1、前後進RC2。 |
| Mode | `MODE_CH` | `5` | 旧記録の`8`ではない。 |
| Mode | `MODE1/2/5/6` | `4` | Hold。重複しているためAcro一時割当候補。 |
| Mode | `MODE3/4` | `0` | Manual。必ず退避先として残す。 |
| Aux | `RC7_OPTION` | `153` | 意味が確定するまで変更しない。 |
| GPS | `GPS1_TYPE` / `GPS2_TYPE` | `1` / `0` | Rover向けに追加購入した採用M10 GPS 1台。旧M8N GPS2流用は中止。 |
| Compass | `COMPASS_ENABLE` | `0` | 屋内Manualテスト用。屋外/自律系前に`1`へ戻す。 |
| Compass | `COMPASS_ORIENT` | `6` | M10 GPS/Compass搭載向きと一致するか確認する。 |
| Compass | `COMPASS_OFS_X/Y/Z` | `16.68246 / -197.9356 / 107.2597` | キャリブレーション値あり。マスト長変更後は再実施する。 |
| Battery | `BATT_MONITOR` | `4` | PM02。 |
| Battery | `BATT_VOLT_PIN` / `BATT_CURR_PIN` | `8` / `4` | Pixhawk 6C Mini + PM02。 |
| Battery | `BATT_VOLT_MULT` | `18.62` | 過去文書の`18.182`と差分あり。走行前に実測で再確認する。 |
| Battery | `BATT_AMP_PERVLT` | `36.36` | 電流表示は実負荷で確認する。 |
| Battery | `BATT_CAPACITY` | `2200` | 3S 2200mAh。 |
| Battery FS | `BATT_LOW_VOLT` / `BATT_CRT_VOLT` | `10.8` / `10.2` | 3S LiPo用。2026-06-13に動作確認成功。 |
| Battery FS | `BATT_FS_LOW_ACT` / `BATT_FS_CRT_ACT` | `1` / `2` | Low=RTL、Critical=Hold。SmartRTLは障害物停止保証として扱わないため不採用。 |
| RC FS | `FS_THR_ENABLE` / `FS_THR_VALUE` | `1` / `910` | タイヤ浮かせで検出と復帰を確認する。 |
| GCS FS | `FS_GCS_ENABLE` | `0` | GCS依存運用なら要検討。 |
| Speed | `CRUISE_SPEED` / `CRUISE_THROTTLE` | `2` / `50` | 初回屋外では速い可能性。低速確認を優先。 |
| Speed | `ATC_SPEED_P/I/D/FF` | `0.2 / 0.2 / 0 / 0` | まずログで追従確認。 |
| Accel | `ATC_ACCEL_MAX` / `ATC_DECEL_MAX` | `1` / `0` | 発進・停止距離を見て判断。 |
| Steering tune | `ACRO_TURN_RATE` | `180` | Acro未割当のため未評価。 |
| Steering tune | `ATC_STR_RAT_FF/P/I/D` | `0.2 / 0.2 / 0.2 / 0` | まず実測ログを取る。 |
| Steering tune | `ATC_STR_RAT_MAX` | `120` | Acro / Manualで安全確認後に評価。 |
| Navigation | `WP_SPEED` / `WP_RADIUS` | `2` / `2` | Auto/Guided前に低速化を検討。 |
| Navigation | `TURN_RADIUS` / `ATC_TURN_MAX_G` | `0.9` / `0.6` | 実測旋回半径と横滑りで判断。 |
| RangeFinder | `RNGFND1_TYPE` | `20` | TF-Luna。 |
| RangeFinder | `RNGFND1_MIN_CM / MAX_CM` | `20 / 700` | Auto-stop最大閾値100cmなら`200`でも足りる。実測・GCS表示で決める。 |
| MAVLink | `SERIAL1_PROTOCOL / BAUD` | `2 / 921` | `TELEM1`。 |
| RangeFinder serial | `SERIAL2_PROTOCOL / BAUD` | `9 / 115` | `TELEM2`。 |

## 矛盾 / 差分メモ

| 項目 | 旧記録 | 現在値 | 対応 |
| --- | --- | --- | --- |
| `MODE_CH` | `8`候補 / 旧FC値 | `5` | 現在値を正とする。実スイッチ位置を記録する。 |
| `BATT_VOLT_MULT` | `18.182`採用記録 | `18.62` | 屋外前に通常給電で実測し、どちらを採用するか記録する。 |
| `RNGFND1_MAX_CM` | `200`候補 | `700` | GCS表示、Auto-stop閾値、屋外反射条件で決める。 |
| Compass | `Compass not calibrated`記録あり | キャリブレーション値あり、`COMPASS_ENABLE=0` | 屋内用一時無効。屋外搭載状態で有効化しPreArm確認する。 |
| Compass mast | マスト長変更前の校正値 | マスト長変更後の校正未実施 | `20260610_before_compass_mast_cal.param` と `20260610_after_compass_mast_cal.param` を保存する。 |
| Battery failsafe | 旧FCは低電圧値あり | `10.8` / `10.2`, Low=RTL, Critical=Hold | 2026-06-13に設定・動作確認成功。 |
| Acro | 手順上必要 | 未割当 | 重複Hold位置へ一時割当する。 |

## 次に保存するパラメータ

| タイミング | 保存先 | 必ず記録する差分 |
| --- | --- | --- |
| マスト長変更後Compass校正前 | `params/tuned/20260610_before_compass_mast_cal.param` | 変更前後マスト長、`COMPASS_ENABLE`、`COMPASS_USE*`、`GPS1_TYPE` |
| マスト長変更後Compass校正後 | `params/tuned/20260610_after_compass_mast_cal.param` | `COMPASS_OFS_*`、`COMPASS_DIA_*`、`COMPASS_ODI_*`、`COMPASS_SCALE`、`COMPASS_ORIENT`、`COMPASS_EXTERNAL`、PreArm結果 |
| 屋外前安全確認後 | `params/tuned/20260610_after_preoutdoor_check.param` | `COMPASS_ENABLE`、Battery値、Mode割当、RC7確認 |
| Manual / Hold / RC FS確認後 | `params/tuned/20260610_after_manual_hold_fs_check.param` | `MODE*`、`FS_*`、`SERVO*`、`BATT_*` |
| Acro割当後 | `params/tuned/20260610_after_acro_assignment.param` | 変更した`MODE*`のみ。Manual / Holdの退避先を明記 |
| Speed確認後 | `params/tuned/20260610_after_acro_speed_check.param` | `CRUISE_*`、`ATC_SPEED_*`、`ATC_ACCEL_MAX` |
| Turn Rate確認後 | `params/tuned/20260610_after_turn_rate_check.param` | `ACRO_TURN_RATE`、`ATC_STR_RAT_*`、`ATC_TURN_MAX_G` |
| 初回Auto/Guided確認後 | `params/tuned/20260610_after_guided_auto_check.param` | `WP_SPEED`、`WP_RADIUS`、`PSC_*`、Compass/GPS関連 |
| 2026-06-13チューニング終了版 | `params/tuned/20260613_pixhawk6c_rover_tuned_01.param` | QuikTune後の通常運用向け。`OA_TYPE=0` |
| BendyRuler実験版 | `params/tuned/20260613_08_oa_type1_bendyruler_test.param` | `OA_TYPE=1`。通常運用版とは分ける |

## 記録ルール

- `.param` を保存したら、このファイルの「現在の正本」または変更履歴へ追記する。
- 変更内容と実走行結果は [チューニングログ](../02_チューニング/09_チューニングログ.md) に記録する。
- 走行場所、路面、天候、ログ保存先は [走行試験](07_走行試験.md) に記録する。
- 旧FCの値、候補値、実機現在値を混ぜない。現在値は `params/tuned/20260610_before_tune.param` 以降のファイルを正とする。

## 変更履歴

| 日付 | 内容 |
| --- | --- |
| 2026-06-13 | QuikTune完了後の通常運用向け終了版 `params/tuned/20260613_pixhawk6c_rover_tuned_01.param` と、`OA_TYPE=1` 実験版を追記。 |
| 2026-06-10 | `params/tuned/20260610_before_tune.param` を現在正本として整理。旧候補値との矛盾、次に保存するパラメータ、記録項目を追加。 |
