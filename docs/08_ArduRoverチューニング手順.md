# ArduRoverチューニング手順

更新日: 2026-06-10

## 位置づけ

この手順書は、タミヤ CC-02 + Pixhawk 6C Mini 構成の ArduRover を、Manual 低速走行確認後から自律走行の受け入れ確認まで段階的にチューニングするための作業手順である。

参考にした ArduCopter 側の手順書:

- `C:\Users\ta1na\source\commondoc\10_PRJ\30_PRJ_DJ_DIYDroneBuild\40_設定チューニング\02_テストフライトとパラメータチューニング_目次.md`
- `C:\Users\ta1na\source\commondoc\10_PRJ\30_PRJ_DJ_DIYDroneBuild\40_設定チューニング\03-1_テストフライトとパラメータチューニング_前半.md`
- `C:\Users\ta1na\source\commondoc\10_PRJ\30_PRJ_DJ_DIYDroneBuild\40_設定チューニング\03-2_テストフライトとパラメータチューニング_後半_5.5以降.md`
- `C:\Users\ta1na\source\commondoc\10_PRJ\30_PRJ_DJ_DIYDroneBuild\40_設定チューニング\06_飛行日誌_20260528-20260529_チューニング結果.md`

Copter の手順から引き継ぐ考え方は、安全確認、段階試験、中止基準、パラメータ保存、ログ保存である。Rover ではホバリング、AltHold、Loiter、Copter AutoTune は使わず、Manual 確認、速度制御、旋回レート制御、ナビゲーション制御の順に進める。

## 現在の前提

この手順は、次の現状から開始する。

| 項目 | 状態 |
| --- | --- |
| 車体 | タミヤ CC-02 |
| FC | Holybro Pixhawk 6C Mini |
| Firmware | ArduRover、Pixhawk6C target |
| ステアリング | `SERVO1_FUNCTION=26`、`MAIN 1` |
| スロットル | `SERVO3_FUNCTION=70`、`MAIN 3` |
| RC入力 | ステアリング `RC1`、スロットル `RC2` |
| モード | `MODE_CH=5`。`MODE1/2/5/6=Hold`、`MODE3/4=Manual`。Acro は未割当 |
| GPS / Compass | `GPS1_TYPE=1`。Compass はキャリブレーション値が入っている。`COMPASS_ENABLE=0` は屋内 Manual テスト用の一時設定 |
| LiDAR | TF-Luna、`TELEM2`、`RNGFND1_TYPE=20` |
| Raspberry Pi / MAVLink | `TELEM1`、`SERIAL1_PROTOCOL=2`、`SERIAL1_BAUD=921` |
| Manual 走行 | 2026-06-09、室内 Manual 低速走行確認済み |
| Safety | `ARMING_CHECK=1`、`MOT_SAFE_DISARM=1` |
| Battery | `BATT_MONITOR=4`、`BATT_CAPACITY=2200`、`BATT_VOLT_MULT=18.62`。ただし `BATT_LOW_VOLT=0`、`BATT_CRT_VOLT=0`、`BATT_FS_LOW_ACT=0`、`BATT_FS_CRT_ACT=0` |
| 速度系 | `CRUISE_SPEED=2`、`CRUISE_THROTTLE=50`、`WP_SPEED=2` |
| 注意 | 屋内では `COMPASS_ENABLE=0` のまま Manual / Hold / 出力確認までに留める。屋外で Auto / Guided / RTL / SmartRTL を行う前に `COMPASS_ENABLE=1` へ戻し、PreArm / EKF / Compass を確認する |

開始時の基準パラメータ:

```text
params/tuned/20260610_before_tune.param
```

このファイルは「チューニング前ベースライン」として上書きしない。チューニング後は `params/tuned/YYYYMMDD_after_内容.param` のように別名で保存する。

注意: `docs/06_ArduRoverパラメータ.md` では PM02 電圧倍率を `BATT_VOLT_MULT=18.182` 採用として記録しているが、現在指定の `.param` では `18.62` になっている。この手順では `20260610_before_tune.param` を現在値として扱い、走行前に通常給電・スモークストッパーなし・テスター実測で再確認する。

## 2026-06-10時点の作業順

現在値に合わせると、最初にやることは PID 調整ではなく、安全側の入口確認である。

1. `params/tuned/20260610_before_tune.param` をベースラインとして保管する。
2. タイヤを浮かせた状態で Manual / Hold / Disarm / RC failsafe を確認する。
3. Battery 表示を実測と比較し、低電圧しきい値を運用前に決める。
4. 屋内テスト用に `COMPASS_ENABLE=0` にしている場合は、屋外で `COMPASS_ENABLE=1` に戻し、PreArm / EKF / GPS / Compass を確認する。
5. Acro を一時的に割り当て、Manual と Hold の退避先を残す。
6. Manual 低速走行でステアリング中立、スロットル中立、停止手段を確認する。
7. Acro で Speed / Turn Rate のログを取り、必要な分だけ調整する。
8. Auto / Guided / RTL は、Compass と Acro チューニングが通ってから低速で実施する。

## 全体フロー

```text
0. 作業前安全確認
  ↓
1. ベースライン保存
  ↓
2. 屋外 Manual 低速走行と停止手段確認
  ↓
3. ステアリング中立・最大舵角・旋回半径確認
  ↓
4. Cruise Speed / Cruise Throttle 学習
  ↓
5. Speed / Throttle controller 調整
  ↓
6. Turn Rate controller 調整
  ↓
7. Navigation controller 調整
  ↓
8. Guided / Auto / RTL / Auto-stop 受け入れ確認
  ↓
9. パラメータ凍結・ログ整理
```

各ステップは、合格するまで次へ進まない。一度に複数の挙動を変えない。

## 0. 作業前安全確認

### 0.1 必須条件

- [ ] 作業場所は屋外で、歩行者、車両、障害物から十分に離れている。
- [ ] 送信機、Mission Planner、GCS のどれで止めるかを操作者全員が理解している。
- [ ] 異常時は、プロポ中立、`DISARM`、走行用 LiPo 切断の順で停止する。
- [ ] 走行用 LiPo を物理的にすぐ外せる。
- [ ] 車体を台に載せ、タイヤを浮かせた状態でステアリングとスロットル方向を確認済み。
- [ ] Manual で意図通り前進、停止、後退できる。
- [ ] `MOT_SAFE_DISARM=1` の DISARM 時挙動を確認済み。
- [ ] `ARMING_CHECK=1` で、屋外試験前の PreArm エラーを解消済み。
- [ ] 屋外 / 自律系試験前に `COMPASS_ENABLE=1` へ戻し、Compass Calibration を実施済み。
- [ ] PM02 の電圧表示をテスター実測と比較済み。
- [ ] `BATT_LOW_VOLT` / `BATT_CRT_VOLT` / `BATT_FS_*` は、最低限「警告を見て中止できる」運用値にしている。
- [ ] RCフェイルセーフの検出と復帰を、タイヤを浮かせた地上状態で確認済み。
- [ ] Speed / Turn Rate 調整に使う Acro モードを、実際に操作できるモード位置へ割り当て済み。

### 0.2 モード割当の注意

Rover 公式の Speed / Throttle controller と Turn Rate controller の調整は Acro モードで行う。現在の `20260610_before_tune.param` は `MODE_CH=5` で、`MODE1=4`、`MODE2=4`、`MODE3=0`、`MODE4=0`、`MODE5=4`、`MODE6=4` となっており、Acro が割り当てられていない。

調整前に次を行う。

1. Mission Planner `INITIAL SETUP -> Mandatory Hardware -> Flight Modes` で、実際に切り替わるモード位置を確認する。
2. Manual と Hold の退避先を必ず残す。
3. 余っている位置に Acro を割り当てる。現在は Hold が複数あるため、実機スイッチで「緊急退避として使わない重複 Hold 位置」を Acro にする。
4. タイヤを浮かせた状態で、Manual / Hold / Acro の切替表示を確認する。
5. 変更前後の `MODE1` から `MODE6` と `MODE_CH` を記録する。
6. 調整後に運用モード割当を戻す場合は、戻した後の `.param` も保存する。

### 0.3 中止基準

次のどれかが出たら、その日の自律系チューニングは中止する。

| 状態 | 判断 |
| --- | --- |
| PreArm エラーが残る | 原因を解消するまで走らせない |
| Mission Planner HUD に原因不明の `FAILSAFE` 表示が出る | Messages とログで原因を確認する |
| Compass / EKF / GPS エラーが残る | Manual 低速だけに戻す |
| 屋内テスト用の `COMPASS_ENABLE=0` のまま | Auto / Guided / RTL は行わない。屋外で `1` に戻してから実施する |
| ステアリング方向が逆、または中立がずれる | `SERVO1_*` と機械リンクを修正する |
| スロットル中立で前進 / 後退する | ESC 中立、`SERVO3_TRIM`、RC キャリブレーションを修正する |
| 通信断時の停止手順が曖昧 | 走行しない |
| バッテリー表示が実測と大きく違う | 電圧倍率を再確認する |
| Battery failsafe が未設定のまま長時間走行する | 低速・短時間の Manual 確認だけにする |

## 1. ベースライン保存

今回のチューニング前ベースラインは、すでに次のファイルとして保存されている。

保存先:

```text
params/tuned/20260610_before_tune.param
```

このファイルは上書きしない。作業中にパラメータを変更したら、段階ごとに別名で保存する。

```text
params/tuned/20260610_after_manual_hold_fs_check.param
params/tuned/20260610_after_acro_speed_check.param
params/tuned/20260610_after_turn_rate_check.param
```

Mission Planner:

```text
CONFIG / TUNING -> Full Parameter Tree -> Save to File
```

`docs/09_チューニングログ.md` に次を記録する。特に `20260610_before_tune.param` からの差分を残す。

- 日付
- 場所
- 路面
- バッテリー
- 開始時パラメータ
- GPS / Compass 状態
- LiDAR 状態
- 操作者
- 中止基準

## 2. 屋外 Manual 低速走行

目的は、制御器のチューニングではなく、車体が安全に止まり、操作者が挙動を読めることを確認すること。

### 2.1 手順

1. 送信機 ON。
2. 制御系電源 ON。
3. Mission Planner 接続。
4. GPS、Compass、Battery、RC 入力、Mode を確認。
5. 走行用 LiPo 接続。
6. 車体を台に載せて Arm し、前進 / 後退 / 中立 / Disarm を確認。
7. 地面に下ろし、Manual で 1 m 程度だけ前進して停止。
8. 低速の直進、低速の左右旋回、停止を確認。
9. 異常がなければ 30 秒程度の Manual 低速走行ログを残す。

### 2.2 合格基準

- 中立で車体が動かない。
- 前進 / 後退がプロポ入力と一致する。
- ステアリング方向が一致する。
- 低速で明確な蛇行、異音、過熱がない。
- `DISARM` で駆動出力が止まる。
- GCS / Mission Planner / プロポの停止手順が実機で通る。

## 3. ステアリング基礎確認

### 3.1 ステアリング中立

低速直進で、プロポのステアリング中立時に車体がまっすぐ進むか確認する。

調整順:

1. まず機械リンクでタイヤ中立を合わせる。
2. 次に `SERVO1_TRIM` を微調整する。
3. `SERVO1_MIN` / `SERVO1_MAX` は、タイヤやサーボに無理が出ない範囲に制限する。

記録する値:

| 項目 | 記録 |
| --- | --- |
| `SERVO1_TRIM` | |
| `SERVO1_MIN` | |
| `SERVO1_MAX` | |
| 低速直進結果 | |

### 3.2 最小旋回半径

Manual で、低速かつ最大舵角にして円を描く。左右それぞれの旋回直径を測る。

| 項目 | 左旋回 | 右旋回 |
| --- | --- | --- |
| 旋回直径 | | |
| 路面 | | |
| スロットル目安 | | |

この結果は `TURN_RADIUS`、`ACRO_TURN_RATE`、`ATC_TURN_MAX_G` の判断材料にする。CC-02 は通常の前輪ステアリング車なので、Skid Steering 用の Pivot Turn 手順は使わない。

## 4. Cruise Speed / Cruise Throttle 学習

Rover の速度制御は、`CRUISE_SPEED` と `CRUISE_THROTTLE` の基準が合っていることが重要である。まず低速で安定して走れる値を作る。

現在の `20260610_before_tune.param` は `CRUISE_SPEED=2`、`CRUISE_THROTTLE=50`、`WP_SPEED=2` である。これは初回屋外チューニングの入口としては速い可能性があるため、最初の Manual / Acro / Auto 確認では低速運用を優先する。速度を下げて試す場合は、変更前後の値を必ず保存する。

### 4.1 前提

- Manual 低速走行が安定している。
- GPS speed が取れている。
- 路面が平坦で、直線を 20 m 以上走れる。
- いきなり高速にしない。最初は CC-02 の安全確認を優先する。

### 4.2 学習手順

1. Mission Planner で未使用 AUX に `Learn Cruise Speed` を割り当てる。
2. 既存の安全系スイッチ、特に `RC7_OPTION=153` は意味を確認するまで変更しない。
3. Manual にする。
4. 直線で 50% から 80% 程度のスロットルを使い、安定して走る。
5. `Learn Cruise Speed` を数秒 High にして戻す。
6. Messages に `Cruise Learned` 系のメッセージが出ることを確認する。
7. `CRUISE_SPEED` と `CRUISE_THROTTLE` を記録する。

Mission Planner の AUX 割当番号は、画面のドロップダウンで `Learn Cruise Speed` を選び、実際に変更された `RCx_OPTION` を記録する。番号を推測で手入力しない。

### 4.3 手動設定する場合

AUX を使わない場合は、Manual 直線走行で次を記録し、保守的に設定する。

| 項目 | 値 |
| --- | --- |
| 低速直進で安定する速度 | |
| そのときのスロットル割合 | |
| `CRUISE_SPEED` | |
| `CRUISE_THROTTLE` | |

最初は安全側として、`WP_SPEED` を `CRUISE_SPEED` 以下または同程度にする。初回 Auto / Guided 確認では、2 m/s をそのまま使う前に、より低い速度で操作者が確実に止められることを確認する。

## 5. Speed / Throttle Controller 調整

Rover 公式手順では、ステアリング制御へ進む前に速度 / スロットル制御を調整する。

現在の速度制御パラメータは、`ATC_SPEED_P=0.2`、`ATC_SPEED_I=0.2`、`ATC_SPEED_D=0`、`ATC_SPEED_FF=0`、`ATC_ACCEL_MAX=1`、`ATC_DECEL_MAX=0` である。まずログで追従を見て、必要がある場合だけ小さく変更する。

対象パラメータ:

| パラメータ | 役割 | 初期方針 |
| --- | --- | --- |
| `ATC_SPEED_P` | 速度誤差への短期応答 | まずこれを調整 |
| `ATC_SPEED_I` | 長期誤差の補正 | 通常は P より低め |
| `ATC_SPEED_D` | 短期変化の抑制 | 初期は `0` のまま |
| `ATC_SPEED_FF` | Feed Forward | Rover 公式手順では `0` 維持 |
| `ATC_ACCEL_MAX` | 加速上限 | 実測加速度に合わせる |
| `ATC_DECEL_MAX` | 減速上限 | 未設定なら `0` のままでも可 |
| `MOT_SLEWRATE` | スロットル出力変化速度 | 急変が強い場合に制限 |

### 5.1 リアルタイム確認

1. Telemetry 接続を安定させる。
2. `GCS_PID_MASK=2` にする。
3. Mission Planner `DATA` 画面で `Tuning` を有効にする。
4. グラフに `piddesired` と `pidachieved` を表示する。
5. Acro モードで低速から中速まで走り、速度追従を見る。

### 5.2 調整判断

| 症状 | 主な調整 |
| --- | --- |
| 目標速度まで上がるのが遅い | `ATC_SPEED_P` を少し上げる |
| 速度がギクシャクして不安定 | `ATC_SPEED_P` を下げる |
| 長い直線でも目標速度に届かない | `ATC_SPEED_I` を少し上げる |
| ゆっくり速すぎ / 遅すぎを繰り返す | `ATC_SPEED_I` を下げる |
| 発進が急すぎる | `ATC_ACCEL_MAX`、`MOT_SLEWRATE` を見直す |
| 減速が遅い | `ATC_DECEL_MAX` を設定して確認する |

変更は 1 回に 1 パラメータだけ行い、変更前後を `docs/09_チューニングログ.md` に記録する。

## 6. Turn Rate Controller 調整

Rover の操舵で最も重要なのは Turn Rate controller である。速度制御がある程度落ち着いてから行う。

現在の旋回制御パラメータは、`ACRO_TURN_RATE=180`、`ATC_STR_RAT_FF=0.2`、`ATC_STR_RAT_P=0.2`、`ATC_STR_RAT_I=0.2`、`ATC_STR_RAT_D=0`、`ATC_STR_RAT_MAX=120`、`ATC_TURN_MAX_G=0.6` である。最初から値を変えず、まず Acro で実測旋回レートと追従ログを取る。

対象パラメータ:

| パラメータ | 役割 | 初期方針 |
| --- | --- | --- |
| `ACRO_TURN_RATE` | Acro での操作者入力に対する目標旋回レート | 実測最大旋回レートより少し低くする |
| `ATC_STR_RAT_FF` | 目標旋回レートから操舵出力への直接成分 | 最重要。最初に調整 |
| `ATC_STR_RAT_P` | 短期誤差補正 | FF より低くする |
| `ATC_STR_RAT_I` | 長期誤差補正 | FF より低くする |
| `ATC_STR_RAT_D` | 短期変化の抑制 | 初期は `0` のまま |
| `ATC_STR_RAT_MAX` | 全モードで使う最大旋回レート | 最後に `ACRO_TURN_RATE` 近辺へ |

### 6.1 最大旋回レートの見積もり

1. Mission Planner `DATA` 画面で `Tuning` を有効にする。
2. グラフに `gz` を表示する。
3. Manual で中速、かつ安全な範囲で強めの旋回を行う。
4. 表示値を確認する。
5. 表示単位が centi-deg/sec の場合は 100 で割り、deg/sec に直す。
6. `ACRO_TURN_RATE` を実測最大値より少し低く設定する。

### 6.2 旋回レート追従確認

1. `GCS_PID_MASK=1` にする。
2. Mission Planner グラフに `piddesired` と `pidachieved` を表示する。
3. Acro で中速走行し、広い旋回と狭い旋回を行う。
4. `pidachieved` が `piddesired` にどれだけ追従するか見る。

### 6.3 調整判断

| 症状 | 主な調整 |
| --- | --- |
| 旋回反応が鈍い | `ATC_STR_RAT_FF` を少し上げる |
| 旋回が目標を越えて行きすぎる | `ATC_STR_RAT_FF` を下げる |
| 小さな誤差が残る | `ATC_STR_RAT_P` を少し上げる |
| 旋回中に振動 / 細かい蛇行 | `ATC_STR_RAT_P` を下げる |
| 長い旋回で目標に届かない | `ATC_STR_RAT_I` を少し上げる |
| ゆっくり蛇行する | `ATC_STR_RAT_I` を下げる |

`ATC_STR_RAT_P` と `ATC_STR_RAT_I` は、通常 `ATC_STR_RAT_FF` より低い値にする。

## 7. Navigation Controller 調整

Auto / Guided / RTL / SmartRTL は、速度制御と旋回レート制御が済んでから確認する。

屋内テスト用に `COMPASS_ENABLE=0` にしている間は、この章へ進まない。屋外で `COMPASS_ENABLE=1` に戻し、Compass / EKF / GPS の PreArm クリア、Acro での Speed / Turn Rate 確認が終わってから実施する。

対象パラメータ:

| パラメータ | 役割 | 初期方針 |
| --- | --- | --- |
| `WP_SPEED` | Auto / Guided の目標速度 | 初期は低速 |
| `WP_RADIUS` | Waypoint 近傍の許容半径 | 狭くしすぎない |
| `TURN_RADIUS` | 低速時の最小旋回半径目安 | 実測に合わせる |
| `ATC_TURN_MAX_G` | 旋回時の横加速度上限 | 転倒 / 横滑りしない値 |
| `PSC_POS_P` | 位置誤差から速度目標への変換 | 既定 `0.2` を基本維持 |
| `PSC_VEL_P` | 速度誤差への応答 | 必要時のみ調整 |
| `PSC_VEL_D` | 角や追従の応答性 | P の 10% 以下を目安 |
| `PSC_VEL_I` | 長期誤差補正 | P の 20% 程度を目安 |
| `PSC_VEL_FF` | Feed Forward | `0` 維持 |

### 7.1 試験コース

最初は単純なコースだけ使う。

- 直線往復
- 大きな長方形
- Waypoint 間隔は十分に広くする
- 障害物や人の近くを通さない
- `WP_SPEED` は Manual で安定確認済みの低速にする

### 7.2 Auto 走行前チェック

- [ ] `COMPASS_ENABLE=1`
- [ ] Compass Calibration 済み
- [ ] GPS `3D Fix`
- [ ] HDOP が悪すぎない
- [ ] EKF / Compass / GPS の PreArm エラーなし
- [ ] `FS_THR_ENABLE` 確認済み
- [ ] Battery 電圧表示と低電圧時の運用判断を確認済み
- [ ] GCS通信断時の方針を決めている
- [ ] `WP_SPEED` が低速
- [ ] `WP_RADIUS` が狭すぎない
- [ ] 手動で即 Manual / Hold / Disarm へ戻せる

### 7.3 調整判断

| 症状 | 主な調整 |
| --- | --- |
| 直線で左右に蛇行する | 速度を下げる。必要なら `PSC_VEL_P` を下げる |
| コーナーで曲がりきれない | `WP_SPEED` を下げる。`TURN_RADIUS`、`ATC_TURN_MAX_G`、旋回レート調整を見直す |
| Waypoint 直前で不自然に迷う | `WP_RADIUS` が狭すぎないか確認 |
| コーナーが鈍いが直線は安定 | `PSC_VEL_D` を少し上げる。ただし P の 10% 以下を目安 |
| 線へ戻る力が弱い | `PSC_VEL_P` を少し上げる |
| オーバーシュートが大きい | `WP_SPEED`、`ATC_ACCEL_MAX`、`ATC_DECEL_MAX`、`PSC_VEL_P/D` を見直す |

## 8. Guided / Auto / RTL / Auto-stop 受け入れ確認

屋内テスト用に `COMPASS_ENABLE=0` にしている間は、この章の試験は実施しない。屋外で実施するときに `COMPASS_ENABLE=1` に戻し、Compass Calibration、PreArm、EKF、GPS を確認する。

### 8.1 Guided

1. `WP_SPEED` を低速にする。
2. 近距離の目標点だけ使う。
3. 目標地点の手前で停止できるスペースを確保する。
4. Guided 開始後、すぐ Manual / Hold へ戻せる状態で操作する。

合格基準:

- 目標方向へ進む。
- 速度が過大にならない。
- 目標付近で不自然な急旋回をしない。
- Manual / Hold への切替で即座に操作者が介入できる。

### 8.2 Auto

1. 大きな長方形または直線往復ミッションを作る。
2. `WP_SPEED` は低速。
3. 1周だけ実行する。
4. 終了後、ログと現場メモを残す。

合格基準:

- Waypoint 間を安全に追従する。
- 直線で大きく蛇行しない。
- コーナーで転倒 / 横滑りしない。
- 手動介入できる。

### 8.3 RTL

RTL は GPS / Compass / EKF が安定してから、短距離で確認する。

1. Home 位置が正しく設定されていることを確認する。
2. Manual で Home から数 m 離れる。
3. RTL に切り替える。
4. 期待方向へ戻ることを確認したら、必要に応じて早めに Manual / Hold へ戻す。

合格基準:

- Home 方向が正しい。
- 速度が過大にならない。
- 手動介入できる。

### 8.4 Auto-stop / LiDAR

GCS 側 Auto-stop は ArduRover 本体のチューニングとは別だが、運用安全に直結するため受け入れ確認に含める。

確認項目:

- Mission Planner で RangeFinder 値が見える。
- rover-gcs 側で距離値が更新される。
- 閾値 `40 / 60 / 80 / 100cm` のどれを使うか記録する。
- 障害物検出時に `STOP` が送信される。
- `STOP` 後にプロポ / Mission Planner で安全に再操作できる。

`RNGFND1_MAX_CM` は現在 `.param` で `700`、`docs/06_ArduRoverパラメータ.md` では `200` 候補として記録されている。Auto-stop の最大閾値が `100cm` なら `200cm` で足りるが、実測値、GCS表示、屋外反射条件を見て決める。値を変えた場合は、rover-gcs 側の表示距離と STOP 閾値も同時に確認する。

## 9. Rover QuikTune の扱い

Rover には Lua による `rover-quicktune.lua` がある。手動チューニングの代替または補助として使えるが、この実機では次を満たすまで実施しない。

- Lua Scripts を動かせること。
- 未使用 RC チャンネルを確保できること。
- 既存の安全系スイッチ、特に `RC7_OPTION=153` を変更しないこと。
- Manual、Acro、速度制御、旋回制御が安全に確認済みであること。
- QuikTune の開始 / 中断 / 保存の AUX 操作を地上で確認済みであること。

使う場合は、公式 Rover QuikTune 手順を確認し、設定ファイル名、AUX 割当、実行結果、保存前後のパラメータ差分を必ず記録する。

現時点では、Acro 未割当かつ自律系未確認のため、QuikTune は後回しにする。Compass は屋内テスト時のみ無効化し、屋外確認時に有効化する前提とする。

## 10. ログ解析と記録

毎回の走行後に、最低限次を記録する。

保存先:

```text
logs/test_runs/YYYYMMDD_rover_tune_NN.md
```

大容量 `.BIN` / `.tlog` は Git に入れず、外部保存先だけ記録する。

記録テンプレート:

```text
### YYYY-MM-DD Rover tune NN

- 場所:
- 路面:
- 天候:
- 操作者:
- 機体状態:
- パラメータ:
- バッテリー:
- 実測電圧:
- Mission Planner表示:
- モード:
- 試験目的:
- 外部ログ保存先:

#### 変更内容

| パラメータ | 変更前 | 変更後 | 理由 |
| --- | --- | --- | --- |
| | | | |

#### 結果

- うまくいったこと:
- 問題:
- 中止判断:
- 次の対応:
```

## 11. 完了基準

チューニング完了として扱う条件:

| 項目 | 合格基準 |
| --- | --- |
| Manual | 低速で直進、旋回、停止、後退が安定 |
| 停止手段 | プロポ中立、Hold / Manual 切替、Mission Planner / GCS `DISARM`、走行用 LiPo 切断の手順が確認済み |
| Safety | `ARMING_CHECK=1` で運用。PreArm エラーなし |
| Compass / GPS | `COMPASS_ENABLE=1`、Compass Calibration 済み、屋外 `3D Fix`、EKF 警告なし |
| RC FS | 地上試験で検出と復帰を確認済み |
| Battery | 電圧表示が実測と合い、低電圧時の中止判断または failsafe 方針が記録済み |
| Speed | `CRUISE_SPEED` / `CRUISE_THROTTLE` が実走行と一致 |
| Throttle | `piddesired` と `pidachieved` が極端に乖離しない |
| Turn Rate | 中速 Acro 旋回で目標と実旋回が追従 |
| Navigation | 低速 Auto で直線往復または長方形コースを安全に完走 |
| RTL | 短距離で Home 方向へ戻ることを確認 |
| Auto-stop | GCS側 STOP が意図通り働く |
| パラメータ | 凍結版 `.param` を `params/tuned/` に保存 |
| ログ | 受け入れ走行ログの外部保存先を記録 |

凍結パラメータ名:

```text
params/tuned/YYYYMMDD_pixhawk6c_rover_tuned_01.param
```

## 参考リンク

- ArduPilot Rover Tuning Process Instructions: <https://ardupilot.org/rover/docs/rover-tuning-process.html>
- ArduPilot Rover First Drive: <https://ardupilot.org/rover/docs/rover-first-drive.html>
- ArduPilot Rover Motor and Servo Connections: <https://ardupilot.org/rover/docs/rover-motor-and-servo-connections.html>
- ArduPilot Rover Tuning Speed and Throttle: <https://ardupilot.org/rover/docs/rover-tuning-throttle-and-speed.html>
- ArduPilot Rover Tuning Turn Rate: <https://ardupilot.org/rover/docs/rover-tuning-steering-rate.html>
- ArduPilot Rover Tuning Navigation: <https://ardupilot.org/rover/docs/rover-tuning-navigation.html>
- ArduPilot Rover QuikTune: <https://ardupilot.org/rover/docs/quiktune.html>

## 改訂履歴

| 日付 | 内容 |
| --- | --- |
| 2026-06-09 | 初版作成。ArduCopter チューニング手順書の安全確認、段階試験、記録方針を引き継ぎ、ArduRover の Speed / Throttle、Turn Rate、Navigation 手順へ置き換え |
| 2026-06-10 | `params/tuned/20260610_before_tune.param` に合わせて更新。`COMPASS_ENABLE=0` は屋内テスト用の一時設定として整理し、Acro 未割当、Battery failsafe 未設定、`CRUISE_SPEED/WP_SPEED=2` を現在の入口条件として反映 |
