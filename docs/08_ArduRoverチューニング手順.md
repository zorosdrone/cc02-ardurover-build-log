# ArduRoverチューニング手順 2026-06-11更新版

## 位置づけ

この文書は、タミヤ CC-02 + Pixhawk 6C Mini + ArduRover 構成のRoverについて、2026-06-11に実施したチューニング結果を反映した再現用手順書である。


目的は、別の作業者または将来の作業者が、同じ機体状態から同等のチューニング確認を再現できるようにすることである。

---

## 対象構成

| 項目 | 内容 |
| --- | --- |
| ベース車両 | タミヤ CC-02 |
| FC | Holybro Pixhawk 6C Mini |
| Firmware | ArduRover 4.6.3系 |
| ステアリング | `MAIN 1`, `SERVO1_FUNCTION=26` |
| スロットル / ESC | `MAIN 3`, `SERVO3_FUNCTION=70` |
| RC入力 | ステアリング `RC1`, スロットル `RC2` |
| モード切替 | `MODE_CH=5` |
| GPS / Compass | 採用M10 GPSを `GPS1` 10ピンに接続 |
| LiDAR | Benewake TF-Luna, `TELEM2`, `SERIAL2_PROTOCOL=9`, `SERIAL2_BAUD=115` |
| Raspberry Pi / MAVLink | `TELEM1`, `SERIAL1_PROTOCOL=2`, `SERIAL1_BAUD=921` |
| 電源モジュール | PM02 |
| Battery | 3S 2200mAh LiPo |

開始時の基準パラメータは以下とする。

```text
params/tuned/20260610_before_tune.param
```

このファイルは上書きしない。作業ごとに別名で保存する。

---

## 6/11実施後の到達状態

2026-06-11の作業で、以下は通過扱いとした。

| 項目 | 判断 |
| --- | --- |
| Acro割当 | 通過 |
| Manual / Hold退避 | 通過 |
| Acro低速走行 | 通過 |
| Acro S字TurnRate確認 | 通過 |
| Speed controller | 現時点で変更不要 |
| Turn Rate controller | 現時点で変更不要 |
| Guided低速移動 | 通過 |
| Auto Mission / Waypoint確認 | 通過 |
| Auto Mission Complete | 達成 |
| LiDAR静置距離確認 | 通過 |

未完または継続確認としたものは以下。

| 項目 | 状態 |
| --- | --- |
| Compass PreArm警告 | Auto後に `PreArm: Check mag field (xy diff:117>100)` が出たため、次回ARM前に再確認 |
| Battery failsafe | `BATT_LOW_VOLT` / `BATT_CRT_VOLT` / `BATT_FS_*` は未確定。長時間運用前に設定する |
| LiDAR走行中安定性 | 静置では良好。走行ログでは `RFND.Dist=0` が多い区間があった |
| Simple Object Avoidance | 2026-06-12 Acro実走で2m停止せず。未通過 |
| BendyRuler | `OA_TYPE=1` で `RangeFinder1(cm)=0.00` になったため保留 |
| RTL / SmartRTL | 未実施 |
| GCS側Auto-stop | 未実施 |

---

## ファイル命名ルール

作業単位ごとに、パラメータ、BINログ、テスト記録を同じ番号で揃える。

params/tuned/YYYYMMDD_NN_after_<内容>.param
logs/accepted/YYYYMMDD_NN_<内容>.bin
logs/test_runs/YYYYMMDD_NN_<内容>.md
```

例:

```text
params/tuned/20260611_03_acro_low_speed_check.param
logs/accepted/20260611_03_acro_low_speed_check.md.bin
logs/test_runs/20260611_03_acro_low_speed_check.md
```

`.BIN`、`.tlog`、動画ファイルはGitに直接入れず、外部保存先をMarkdownに記録する。
---

## 0. 作業前安全確認

### 0.1 必須条件

- 走行場所は歩行者、車両、障害物から十分に離れている。
- 送信機、Mission Planner、GCSのどれで止めるかを操作者が理解している。
- 異常時は、プロポ中立、HoldまたはManual、DISARM、走行用LiPo切断の順で停止する。
- 走行用LiPoを物理的にすぐ外せる。
- `ARMING_CHECK=1` のまま進める。
- `MOT_SAFE_DISARM=1` のDISARM時出力停止を確認済み。
- 屋外 / 自律系では `COMPASS_ENABLE=1` に戻す。
- GPSが `3D Fix` している。
- PreArm / EKF / Compass / GPSエラーが残っていない。
- Battery表示と実測電圧の差が大きくない。
- Manual / Hold退避先を必ず残す。
- 走行場所は歩行者、車両、障害物から十分に離れている。
- 送信機、Mission Planner、GCSのどれで止めるかを操作者が理解している。
- 異常時は、プロポ中立、HoldまたはManual、DISARM、走行用LiPo切断の順で停止する。
- 走行用LiPoを物理的にすぐ外せる。
- `ARMING_CHECK=1` のまま進める。
- `MOT_SAFE_DISARM=1` のDISARM時出力停止を確認済み。
- 屋外 / 自律系では `COMPASS_ENABLE=1` に戻す。
- GPSが `3D Fix` している。
- PreArm / EKF / Compass / GPSエラーが残っていない。
- Battery表示と実測電圧の差が大きくない。
- Manual / Hold退避先を必ず残す。

### 0.2 中止基準

以下のどれかが出たら、Auto / Guided / OA系へ進まない。

| 状態 | 判断 |
| --- | --- |
| PreArmエラーが残る | 原因解消まで走行しない |
| Compass / EKF / GPSエラーが残る | Manual低速だけに戻す |
| `COMPASS_ENABLE=0` のまま | Auto / Guided / RTL禁止 |
| Battery表示が実測と大きく違う | 電圧倍率を再確認 |
| スロットル中立で前進または後退する | ESC中立、`SERVO3_TRIM`、RCキャリブレーション確認 |
| ステアリング方向が逆または中立がずれる | `SERVO1_*` と機械リンクを確認 |
| ManualまたはHoldへ即時退避できない | 自律系へ進まない |
| LiDAR OAテスト時に `RangeFinder1(cm)=0.00` 固定 | OA走行テスト中止 |

---

## 1. Acro一時割当

### 1.1 目的

RoverのSpeed / Throttle controllerとTurn Rate controllerの確認はAcroモードで行う。ManualとHoldの退避先を残したまま、重複しているHold位置の1つをAcroへ変更する。

### 1.2 6/11採用設定

```text
params/tuned/20260611_01_after_acro_assignment.param
```

| パラメータ | 値 | モード |
| --- | ---: | --- |
| `MODE_CH` | `5` | CH5でモード切替 |
| `MODE1` | `4` | Hold |
| `MODE2` | `4` | Hold |
| `MODE3` | `0` | Manual |
| `MODE4` | `1` | Acro |
| `MODE5` | `4` | Hold |
| `MODE6` | `0` | Manual |

### 1.3 確認手順

1. Mission Planner `INITIAL SETUP -> Mandatory Hardware -> Flight Modes` を開く。
2. `MODE_CH=5` の実スイッチ位置を確認する。
3. Manual退避先が残っていることを確認する。
4. Hold退避先が残っていることを確認する。
5. 重複しているHold位置の1つをAcroに変更する。
6. タイヤを浮かせた状態で、Manual / Hold / Acroの表示を確認する。
7. 変更後の `.param` を保存する。

### 1.4 合格条件

- Manualが最低1箇所残っている。
- Holdが最低1箇所残っている。
- Acroが1箇所だけ割り当てられている。
- AcroからManualまたはHoldへ即時に戻せる。

---

## 2. Acro低速チェック

### 2.1 目的

Acroで低速直進、停止、軽い前後進を行い、Speed controllerとTurn Rate controllerの入口確認を行う。ここでは調整ではなくログ取得を目的とする。

### 2.2 推奨ログ名

```text
logs/accepted/20260611_03_acro_low_speed_check.md.bin
params/tuned/20260611_03_acro_low_speed_check.param
```

### 2.3 実施手順

1. 屋外静置でGPS / EKF / Compass / Batteryを確認する。
2. Manualで1m程度の前進、停止、後退を確認する。
3. Holdで停止できることを確認する。
4. Acroへ切り替える。
5. 低速で5〜10m程度直進する。
6. スロットル一定時の速度追従を確認する。
7. 軽く左右ステアを入れる。
8. 異常があれば即HoldまたはManualへ戻す。
9. BINログと終了時パラメータを保存する。

### 2.4 6/11実績

| 項目 | 結果 |
| --- | ---: |
| 実速度最大 | 1.57m/s |
| 実速度平均 | 0.95m/s |
| 目標速度平均 | 0.95m/s |
| Firmware target | `Pixhawk6C` |
| Firmware | ArduRover 4.6.3系 |
| ステアリング | `MAIN 1`, `SERVO1_FUNCTION=26` |
| スロットル / ESC | `MAIN 3`, `SERVO3_FUNCTION=70` |
| RC入力 | ステアリング `RC1`, スロットル `RC2` |
| モード切替 | `MODE_CH=5` |
| GPS / Compass | Rover向けに追加購入したM10 GPSを `GPS1` 10ピンに接続 |
| LiDAR | Benewake TF-Luna, `TELEM2`, `SERIAL2_PROTOCOL=9`, `SERIAL2_BAUD=115` |
| Raspberry Pi / MAVLink | `TELEM1`, `SERIAL1_PROTOCOL=2`, `SERIAL1_BAUD=921` |
| 電源モジュール | PM02 |
| Battery | 3S 2200mAh LiPo |

## 3. Acro S字TurnRateチェック

### 3.1 目的

左右旋回の対称性とTurn Rate追従を確認する。ここでも調整よりログ取得を優先する。

### 3.2 推奨ログ名

```text
logs/accepted/20260611_04_acro_s_curve_turnrate_check.bin
```

### 3.3 実施手順

1. Acroへ切り替える。
2. 低速一定で走行する。
3. 左右に軽いS字を行う。
4. 左右とも同程度の舵角を入れる。
5. 急操作はしない。
6. 異常があればHoldまたはManualへ戻す。
7. ログ保存後、TurnRate左右差を確認する。

### 3.4 6/11実績

| 項目 | 結果 |
| --- | ---: |
| 実速度範囲 | -1.28〜1.54m/s |
| 目標速度範囲 | -2.28〜1.56m/s |
| 速度追従相関 | 0.936 |
| 速度誤差RMSE | 0.328m/s |
| 目標TurnRate範囲 | -120〜+120deg/s |
| 実TurnRate範囲 | -107〜+111deg/s |
| TurnRate相関 | 0.949 |
| TurnRate誤差RMSE | 18.5deg/s |

左右差:

| 方向 | 目標平均 | 実測平均 | 差 |
| --- | ---: | ---: | ---: |
| 右旋回側 | +71.1deg/s | +54.7deg/s | 約16.4deg/s不足 |
| 左旋回側 | -72.1deg/s | -56.1deg/s | 約16.0deg/s不足 |

判断:

- 左右差は大きくない。
- 片側だけ曲がらない、片側だけ暴れる状態ではない。
- 低速Roverとしては正常範囲。
- `ATC_STR_RAT_*` は変更しない。

---

## 4. Guided低速確認

### 4.1 目的

MissionなしでGCSから近距離目標を指定し、Navigation制御が破綻しないか確認する。Autoより前の入口確認として使う。

### 4.2 注意

- GuidedはWaypoint Mission不要。
- 送信機にGuidedを割り当てる必要はない。
- Mission PlannerからGuided目標を指定する。
- 送信機側にはManualとHold退避先を残す。

### 4.3 実施手順

1. GPS / EKF / Compass正常を確認する。
2. Manualで開始位置へ移動する。
3. Holdで停止する。
4. Mission Plannerから1〜5m程度先をGuided目標として指定する。
5. Roverが低速で目標へ向かうか確認する。
6. 近づいたらHoldまたはManualへ戻す。
7. 目標点を何度も変えすぎない。評価が難しくなる。

### 4.4 6/11実績

Guided 1回目は目標更新が複数あり、追従評価は粗かった。Guided 2回目は良好。

Guided 2回目:

| 項目 | 結果 |
| --- | ---: |
| 実速度最大 | 1.76m/s |
| 速度追従相関 | 0.98 |
| WpDist | 6.51m → 0.26m |
| XTrack最大 | 0.28m |
| 位置誤差平均 | 0.37m |
| 位置誤差最大 | 0.51m |

判断:

- Guided低速1点移動として通過。

---

## 5. Auto / Waypoint確認

### 5.1 目的

短距離Waypoint Missionを実行し、Autoでの速度追従、横ずれ、Waypoint到達、Mission Completeを確認する。

### 5.2 注意

AutoはGuidedと違い、事前にWaypoint / Mission設定が必要である。

| モード | Mission設定 | 用途 |
| --- | --- | --- |
| Guided | 不要 | GCSからその場で近距離目標を指定 |
| Auto | 必要 | Mission PlannerでWaypointを書き込んで実行 |
| Manual / Acro / Hold | 不要 | 送信機操作 |

送信機にAutoを割り当てる必要はない。初回はMission PlannerからAutoへ入れ、送信機のManual / Holdで退避する。

### 5.3 Mission例

初回は短距離でよい。

```text
WP1: 現在地付近
WP2: 5〜10m先
WP3: さらに5〜10m先
WP4: 戻りまたは折り返し
```

鋭角ターン、長距離、高速、RTL、SmartRTLはまだ実施しない。

### 5.4 6/11実績

```text
logs/accepted/20260611_05_navigation_low_speed_straight_check.bin
```

ログメッセージ:

```text
Mission: 1 WP
Reached waypoint #1
Mission: 2 WP
Reached waypoint #2
Mission: 3 WP
Reached waypoint #3
Mission: 4 WP
Reached waypoint #4
Mission Complete
```

Waypoint間距離:

| 区間 | 距離 |
| --- | ---: |
| WP0 → WP1 | 約0.02m |
| WP1 → WP2 | 約8.23m |
| WP2 → WP3 | 約7.27m |
| WP3 → WP4 | 約7.58m |

Auto追従:

| 項目 | 結果 |
| --- | ---: |
| Auto時間 | 約24.5秒 |
| 実速度最大 | 2.03m/s |
| 目標速度最大 | 2.00m/s |
| 速度誤差RMSE | 0.14m/s |
| 速度追従相関 | 0.987 |
| TurnRate誤差RMSE | 20.1deg/s |
| TurnRate相関 | 0.831 |
| XTrack最大 | 1.21m |
| XTrack平均 | 0.39m |
| 位置誤差平均 | 0.59m |
| 位置誤差最大 | 1.02m |

判断:

- Auto MissionはWaypoint到達とMission Completeを確認済み。
- Waypoint Auto低速確認として十分。
- 追加のAuto低速ターンログは必須ではない。
- `ATC_SPEED_*` / `ATC_STR_RAT_*` は変更不要。

### 5.5 残課題

終了後に以下のPreArm警告が出た。

```text
PreArm: Check mag field (xy diff:117>100)
```

次回ARM前に以下を確認する。

1. GPS / Compass搭載位置が動いていないか。
2. 電源配線、バッテリー、モーター線からCompassが近すぎないか。
3. 屋外で数分静置して警告が消えるか。
4. 消えない場合はCompass Calibrationを再実施する。

---

## 6. LiDAR静置距離チェック

### 6.1 目的

TF-Lunaの距離値が、実距離に対して安定して変化するか確認する。Auto-stopやObject Avoidanceの前に必ず実施する。

### 6.2 推奨ログ名

```text
logs/accepted/20260611_06_lidar_static_distance_check.bin
```

### 6.3 Arm / Disarmとログ

LiDAR静置確認だけなら、本来はArm不要である。ただし `LOG_DISARMED=0` の場合、一度もArmしないとBINログが残らない可能性がある。

確実にBINで残す方法:

```text
方法A: LOG_DISARMED=1にしてDisarmのまま記録
方法B: タイヤを浮かせ、安全確保したうえで短時間Armして記録
方法C: Mission Plannerのtlogを保存
```

安全上は、`LOG_DISARMED=1` + Disarmのまま確認が望ましい。

### 6.4 実施手順

1. 車体を固定する、またはタイヤを浮かせる。
2. Mission Plannerへ接続する。
3. `RangeFinder1(cm)`、`sonarrange`、またはログの `RFND.Dist` を確認する。
4. LiDAR正面に板、箱、壁など平面対象を置く。
5. 0.3m / 0.5m / 1.0m / 2.0mで値が追従するか確認する。
6. 起動直後の数秒は評価対象外にする。
7. `Stat=4` になってから評価する。

### 6.5 6/11実績

| 項目 | 結果 | 判断 |
| --- | ---: | --- |
| RFNDログ数 | 3033件 | 十分 |
| RFND記録時間 | 約60.6秒 | 十分 |
| Dist最大 | 2.18m | 2m級まで確認 |
| Dist中央値 | 1.01m | 距離変化あり |
| Dist=0率 | 約1.1% | 良好 |
| `Stat=4` | 約91.7% | 良好 |
| `Quality` | 常に -1 | TF-Lunaでは異常とは限らない |

5秒ごとの中央値:

| 時間帯 | Dist中央値 | 状態 |
| ---: | ---: | --- |
| 0〜5秒 | 0.07m | 開始直後、評価対象外 |
| 5〜10秒 | 0.32m | 近距離 |
| 15〜20秒 | 0.57m | 0.5m級 |
| 25〜30秒 | 1.00m | 1m級 |
| 35〜40秒 | 2.15m | 2m級 |
| 40〜45秒 | 2.16m | 2m級で安定 |

判断:

- LiDAR静置距離チェックは通過。
- 起動直後を除けば実用的に距離変化を取れている。
- 走行ログで `Dist=0` が多かったのは、向き、対象物、反射条件、屋外環境の影響の可能性がある。

---

## 7. LiDAR / Object Avoidance切り分け

### 7.1 目的

前方LiDARを使った自動停止または障害物回避を確認する。ここではGCS側Auto-stop、ArduPilot Simple Object Avoidance、BendyRulerを混同しない。

### 7.2 機能の整理

| 目的 | 機能 | 主な対象モード | 主なパラメータ |
| --- | --- | --- | --- |
| GCS側で距離を見てSTOP送信 | rover-gcs Auto-stop | GCS実装依存 | GCS側設定、`RFND.Dist`受信 |
| 障害物前で止まる | Simple Object Avoidance | Manual以外。初回確認はAcro推奨 | `PRX1_TYPE=4`, `AVOID_ENABLE=7` |
| Auto/Guidedで経路を曲げて避ける | BendyRuler | Auto / Guided / RTL | `OA_TYPE=1`, `OA_BR_LOOKAHEAD`, `OA_MARGIN_MAX` |

6/11時点では、まずSimple Object Avoidanceを確認し、BendyRulerは保留する方針にした。

### 7.3 RangeFinder基本設定

```text
RNGFND1_TYPE     = 20
RNGFND1_ORIENT   = 0
RNGFND1_MIN_CM   = 20
RNGFND1_MAX_CM   = 700
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD     = 115
```

`RNGFND1_MAX_CM=200` はGCS側近距離STOP閾値だけを見るなら足りる場合がある。Object Avoidanceで `AVOID_MARGIN=2.0` を使う場合、検出上限2mでは短すぎるため `700` を推奨する。

### 7.4 Simple Object Avoidance初期設定

公式手順では、1番目のRangeFinderをProximity sensorとして使う場合 `PRX1_TYPE=4` を使う。ただし、この機体では2026-06-12時点で `PRX1_TYPE=4` にするとMission Plannerの距離表示が消える事象が出ている。

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2.0
AVOID_BACKUP_SPD = 0
RNGFND1_MAX_CM   = 700
```

`AVOID_MARGIN=0.5` はMission Planner上で範囲外警告が出たため採用しない。`AVOID_MARGIN=2.0` のまま確認する。

`AVOID_BACKUP_SPD=0` は、障害物前で後退し続ける挙動を避け、まず停止確認に寄せるために設定する。

2026-06-12切り分け:

```text
PRX1_TYPE = 0
→ RangeFinder距離表示あり

PRX1_TYPE = 4
→ 距離表示なし
```

このため、`PRX1_TYPE=4` 設定後は `RangeFinder1(cm)` だけでなく、Proximity ViewerとDataFlashの `PRX` を必ず確認する。Proximity Viewer / `PRX` にも前方障害物が出ない場合は、`PRX1_TYPE=0` に戻してRangeFinder単体の状態へ復旧する。

### 7.5 `OA_TYPE=1` の切り分け結果

6/11に `OA_TYPE=1` を入れたところ、Mission Plannerの `RangeFinder1(cm)` が `0.00` のまま変化しなくなった。

その後、`OA_TYPE=0` に戻したところ、距離表示が復活した。

切り分け結果:

```text
OA_TYPE = 1
→ RangeFinder1(cm) が 0.00 固定になる

OA_TYPE = 0
→ RangeFinder1(cm) の距離表示が復活する
```

このため、現時点ではBendyRuler設定がRangeFinder / Proximity表示または処理と噛み合っていない可能性がある。BendyRulerは後回しにし、まず `OA_TYPE=0` のSimple Object Avoidanceで停止確認を行う。

### 7.6 Mission Plannerで見る項目

#### リアルタイム確認

RangeFinder単体確認:

```text
Flight Data
↓
Status
↓
sonarrange / rangefinder1 / RangeFinder1(cm)
```

期待値:

| 実距離 | 表示例 |
| ---: | ---: |
| 0.5m | 50cm前後 |
| 1.0m | 100cm前後 |
| 2.0m | 200cm前後 |

Proximity化後の確認:

```text
Flight Data
↓
Ctrl-F
↓
Proximity
```

`PRX1_TYPE=4` にした後、`RangeFinder1(cm)` の表示が消えても、Proximity Viewerで前方障害物が見えていればProximity側へ変換されている可能性がある。Proximity Viewerにも出ない場合は走行テストしない。

#### ログ確認

```text
DataFlash Logs
↓
Review a Log
↓
Graph This Data
↓
RFND.Dist / RFND.Stat / RFND.Qual
```

PRX / Proximity側を見る場合:

```text
Statusで prx / prox / proximity を検索
または DataFlash Logで PRX 系メッセージを確認
```

ただし、`PRX1_TYPE=0` の状態でも `RangeFinder1(cm)=0.00` 固定なら、PRX以前にRangeFinder入力の復旧を優先する。

---

## 8. Simple Object Avoidance実走確認

### 8.1 目的

`OA_TYPE=0` の状態で、前方LiDARをProximityとして使い、Acro低速走行中に障害物前で前進が抑制されるか確認する。

### 8.2 推奨ログ名

```text
logs/accepted/20260611_08_lidar_simple_avoid_acro_stop_check.bin
params/tuned/20260611_08_after_lidar_simple_avoid_acro_stop_check.param
```

日付をまたぐ場合:

```text
logs/accepted/20260612_01_lidar_simple_avoid_acro_stop_check.bin
params/tuned/20260612_01_after_lidar_simple_avoid_acro_stop_check.param
```

### 8.3 事前設定

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2.0
AVOID_BACKUP_SPD = 0
RNGFND1_MAX_CM   = 700
```

設定後、FCを再起動する。

### 8.4 事前確認

1. `PRX1_TYPE=0` の状態でMission Planner再接続後、5〜10秒待つ。
2. LiDAR正面0.5mに板を置き、`RangeFinder1(cm)` が50前後になるか確認する。
3. 1mで100前後、2mで200前後になるか確認する。
4. `PRX1_TYPE=4` に変更してFCを再起動する。
5. `RangeFinder1(cm)` 表示が消えても、Proximity Viewerで前方障害物が見えるか確認する。
6. DataFlashログに `PRX` メッセージが出るか確認する。
7. Proximity Viewer / `PRX` に出ない場合は走行テストしない。
8. Manual / Hold退避先を確認する。

### 8.5 実走手順

1. 障害物を正面2〜3m先に置く。
2. Acroに入れる。
3. 低速で前進する。
4. 2m付近で減速または停止するか確認する。
5. 止まらない場合は即HoldまたはManualへ退避する。
6. そのまま突っ込む場合は中止し、`PRX1_TYPE` / `AVOID_ENABLE` / `RangeFinder1` 表示を再確認する。

### 8.6 期待する挙動

| 状態 | 判断 |
| --- | --- |
| 2m付近で前進が抑制される | OK |
| 2m付近で停止する | OK |
| 少し回避・旋回する | Simple Avoidanceでも起きる可能性あり |
| そのまま突っ込む | NG。即中止 |
| 障害物なしでも進まない | 周囲、地面、壁、人を拾っている可能性 |
| 後退し続ける | `AVOID_BACKUP_SPD=0` を再確認 |

### 8.7 まだやらないこと

```text
OA_TYPE=1 に戻す
AutoでBendyRuler確認
Guidedで障害物回避確認
RTL
SmartRTL
高速走行
```

### 8.8 2026-06-12 Acro実走結果

`OA_TYPE=0`、`PRX1_TYPE=4`、`AVOID_ENABLE=7`、`AVOID_MARGIN=2.0`、`AVOID_BACKUP_SPD=0` の方針でAcro低速確認を行ったが、2m付近で停止しなかった。

判断:

- Simple Object AvoidanceのAcro実走確認は未通過。
- 実走時点では `PRX1_TYPE=0` だったため、LiDARがProximity入力として有効化されていなかった可能性が高い。
- その後 `PRX1_TYPE=4` にしたところ距離表示が消えたため、Proximity Viewer / `PRX` 側に値が出るかを確認する必要がある。
- 走行再試験の前に、静置またはタイヤ浮かせ状態でProximity ViewerとDataFlashの `PRX` ログを確認する。

次の確認名:

```text
20260612_02_lidar_proximity_static_check
```

---

## 9. BendyRulerへ進む条件

BendyRulerは、Simple Object Avoidanceが通ってから行う。

### 9.1 前提条件

- `RangeFinder1(cm)` が0.5m / 1m / 2mで正常に変化する。
- `PRX1_TYPE=4` でProximity側に値が出る。
- `OA_TYPE=0` のAcro低速で障害物前停止または抑制が確認できる。
- Auto / GuidedでManualまたはHoldへ即退避できる。
- Compass / EKF / GPS / Batteryが正常。

### 9.2 BendyRuler候補設定

```text
OA_TYPE = 1
OA_BR_LOOKAHEAD = 5
OA_MARGIN_MAX = 2
```

ただし、6/11時点では `OA_TYPE=1` で `RangeFinder1(cm)=0.00` になる問題が出たため、再試験前に以下を行う。

1. `OA_TYPE=0` でRangeFinder表示が正常な状態を保存する。
2. `OA_TYPE=1` に変更する。
3. FC再起動する。
4. `RangeFinder1(cm)` が0固定にならないか確認する。
5. 0固定になるならBendyRuler試験は中止し、`OA_TYPE=0` に戻す。

---

## 10. 最終チューニング完了基準

チューニング完了として扱うには、以下を満たす。

| 項目 | 合格基準 |
| --- | --- |
| Manual | 低速で直進、旋回、停止、後退が安定 |
| 停止手段 | プロポ中立、Hold / Manual切替、Mission Planner / GCS `DISARM`、走行用LiPo切断手順が確認済み |
| Safety | `ARMING_CHECK=1` で運用。PreArmエラーなし |
| Compass / GPS | `COMPASS_ENABLE=1`、Compass Calibration済み、屋外 `3D Fix`、EKF警告なし |
| RC FS | 地上試験で検出と復帰を確認済み |
| Battery | 電圧表示が実測と合い、低電圧時の中止判断またはfailsafe方針が記録済み |
| Speed | `CRUISE_SPEED` / `CRUISE_THROTTLE` が実走行と一致 |
| Throttle | 目標速度と実速度が極端に乖離しない |
| Turn Rate | Acro旋回で目標と実旋回が概ね追従 |
| Navigation | 低速AutoでWaypoint到達とMission Completeを確認 |
| RTL | 短距離でHome方向へ戻ることを確認。未実施なら未完扱い |
| LiDAR静置 | 0.3m / 0.5m / 1m / 2mで距離が追従 |
| Simple Object Avoidance | 2026-06-12 Acro低速では2m停止せず。Proximity / PRX確認へ戻る |
| GCS Auto-stop | rover-gcs側STOPを使う場合のみ、別途確認 |
| BendyRuler | 必要な場合のみ、`OA_TYPE=1`でAuto / Guided回避を確認 |
| パラメータ | 凍結版 `.param` を `params/tuned/` に保存 |
| ログ | 受け入れ走行ログの外部保存先を記録 |

凍結パラメータ名:

```text
params/tuned/YYYYMMDD_pixhawk6c_rover_tuned_01.param
```

---

## 11. 6/11時点で変更しないパラメータ

以下は、6/11のログ解析結果から現時点では変更しない。

```text
ATC_SPEED_*
ATC_STR_RAT_*
```

理由:

- Acro低速チェックでSpeed追従が良好。
- S字TurnRateチェックで左右差が小さい。
- Guided / Autoでも速度追従とWaypoint到達が確認できた。
- いきなりゲインを変更するより、残課題であるLiDAR / OA / Compass / Battery failsafeの確認を優先する。

---

## 12. 次回の最優先作業

2026-06-12のAcro実走では2m付近で停止しなかった。実走時点では `PRX1_TYPE=0` だったため、次回は走行再試験ではなく、静置またはタイヤ浮かせ状態で `RangeFinder -> Proximity -> Avoidance` の接続確認を行う。

```text
1. Compass PreArm警告が再発しないか確認
2. PRX1_TYPE=0でRangeFinder1(cm) が0.5m / 1m / 2mで正常に出るか確認
3. PRX1_TYPE=4に変更してFC再起動
4. RangeFinder1(cm) 表示が消えるか、Proximity Viewer側へ移るか確認
5. Mission PlannerのProximity Viewerで前方障害物が出るか確認
6. DataFlashログにPRXメッセージが出ているか確認
7. PRX1_TYPE=4 / AVOID_ENABLE=7 / AVOID_MARGIN=2.0 / AVOID_BACKUP_SPD=0 が再起動後も残っているか確認
8. RNGFND1_ORIENT=0 とLiDARの前向き実装が合っているか確認
9. RCx_OPTION=40 が設定されている場合、Proximity AvoidanceがON側になっているか確認
10. Proximity Viewer / PRXに出ない場合はPRX1_TYPE=0へ戻す
11. Proximity Viewer / PRXに出た場合だけAcro低速の障害物停止を再試験する
```

推奨ログ名:

```text
20260612_02_lidar_proximity_static_check
```

推奨保存先:

```text
logs/accepted/20260612_02_lidar_proximity_static_check.bin
params/tuned/20260612_02_after_lidar_proximity_static_check.param
logs/test_runs/20260612_02_lidar_proximity_static_check.md
```

---

## 13. Rover QuikTune の扱い

RoverにはLuaによる `rover-quicktune.lua` があり、手動チューニングの補助として使える。ただし、この機体では次の条件を満たすまで後回しにする。

- Lua Scriptsを有効化できること。
- 未使用RCチャンネルを確保できること。
- 既存の安全系スイッチ、特に `RC7_OPTION=153` の意味が確定していること。
- Manual / Hold退避、Acro低速、Speed controller、Turn Rate controllerが安定していること。
- QuikTuneの開始 / 中断 / 保存のAUX操作を地上で確認済みであること。

使う場合は、公式 Rover QuikTune 手順を確認し、設定ファイル名、AUX割当、実行結果、保存前後のパラメータ差分を必ず記録する。

2026-06-12時点では、LiDARの室内確認は完了扱いにし、QuickTuneを早く行う場合はObject Avoidanceの深掘りを後回しにしてよい。ただし、次の最小ゲートを満たすまでQuikTuneは開始しない。

- Compass / GPS / EKF / BatteryにPreArm相当の問題がない。
- Manual / Hold / Disarmへ即時退避できる。
- Circle modeへ安全に入れる。
- Lua Scriptsを有効化し、`rover-quicktune.lua` をSDカードへ配置済み。
- `RTUN_ENABLE=1`。
- QuikTune開始 / 中断操作を地上で確認済み。
- 障害物回避系がQuickTune挙動へ干渉しないよう、広い場所で実施する。

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
| 2026-06-12 | `PRX1_TYPE=0` だったこと、`PRX1_TYPE=4` にすると距離表示が消えることを反映。RangeFinder単体確認とProximity Viewer / PRX確認を分ける方針に更新 |
| 2026-06-12 | Acro低速でSimple Object Avoidanceが2m停止しなかった結果を反映。次回作業を実走再試験ではなく、Proximity Viewer / PRXログ確認へ変更 |
| 2026-06-11 | 6/11実走結果を反映。Acro、S字TurnRate、Guided、Auto Mission、LiDAR静置、Object Avoidance切り分けを追記。`OA_TYPE=1` で `RangeFinder1(cm)=0.00` になる事象を反映し、まず `OA_TYPE=0` のSimple Object Avoidanceから確認する方針に更新 |
