# 2026-06-11 Roverチューニング記録

## 概要

2026-06-11に、タミヤ CC-02 + Pixhawk 6C Mini + ArduRover 構成で、Acro割当、Acro低速走行、S字TurnRate確認、Guided / Auto / Waypoint確認、LiDAR静置確認、LiDAR Object Avoidance設定切り分けを実施した。

この日の結論は以下。

- Acro割当は成功。
- Acro低速走行は成功。
- S字TurnRate確認は成功。
- Guided / Auto / Waypoint確認は成功。
- Auto MissionはWaypoint到達とMission Completeを確認済み。
- Speed / Throttle controller、Turn Rate controllerは現時点で変更不要。
- LiDAR静置確認は成功。
- LiDARはRangeFinder単体としては正常に距離変化を取得できている。
- `OA_TYPE=1` を入れると `RangeFinder1` 表示が `0.00` になり、`OA_TYPE=0` に戻すと距離表示が復活した。
- 現時点ではBendyRulerではなく、`OA_TYPE=0` のSimple Object Avoidanceで切り分けを進める。
- `PRX1_TYPE=4`、`AVOID_ENABLE=7`、`AVOID_MARGIN=2.0`、`AVOID_BACKUP_SPD=0` の設定で、Acro低速障害物停止確認へ進む方針。
- 屋外前確認時点で `COMPASS_ENABLE=1` はすでに設定済みだった。

## 1. Acro一時割当

保存ファイル:

```text
projects/02_チューニング/params/tuned/20260611_01_after_acro_assignment.param
```

`MODE_CH=5` のモード割当のうち、重複していたManual/Hold位置の1つをAcroへ変更した。

| パラメータ | 値 | モード |
| --- | ---: | --- |
| `MODE_CH` | `5` | CH5でモード切替 |
| `MODE1` | `4` | Hold |
| `MODE2` | `4` | Hold |
| `MODE3` | `0` | Manual |
| `MODE4` | `1` | Acro |
| `MODE5` | `4` | Hold |
| `MODE6` | `0` | Manual |

判断:

- Manual退避先あり。
- Hold退避先あり。
- Acroは1箇所のみ。
- Speed / Turn Rateログ取得へ進める状態。
- Acro割当後の保存版として採用。

## 2. Acro低速チェック

保存ファイル:

```text
projects/02_チューニング/params/tuned/20260611_03_acro_low_speed_check.param
projects/02_チューニング/logs/accepted/20260611_03_acro_low_speed_check.md.bin
```

Acroモードで低速直進・低速操作を行い、Speed controllerとTurn Rate controllerの入口確認を行った。

主な区間:

| 時刻目安 | モード | 内容 |
| ---: | --- | --- |
| 0.7-5.2秒 | Acro | 実質停止 |
| 5.2-20.2秒 | Manual | ARM前後の確認 |
| 20.2-65.1秒 | Acro | メインのAcro走行 |
| 65.1-70.7秒 | Manual | 退避確認 |
| 70.7-73.5秒 | Acro | 後退系確認 |
| 73.5-75.7秒 | Hold | 停止確認 |
| 75.7-84.8秒 | Acro | 追加低速走行 |
| 84.8-89.7秒 | Manual | 退避確認 |
| 89.7秒以降 | Hold | 最終停止 |

GPS / EKF / Compass:

| 項目 | 結果 |
| --- | ---: |
| GPS Status | 3-4 |
| 衛星数 | 26-32 |
| HDop最大 | 0.59 |
| HAcc最大 | 1.0m |
| SAcc最大 | 0.2m/s |
| EKF flags | 異常なし |
| Compass Health | 内部 / 外部とも正常 |

Battery / 電源:

| 項目 | 結果 |
| --- | ---: |
| Battery電圧 | 11.663-11.801V |
| 開始電圧 | 約11.732V |
| 終了電圧 | 約11.775V |
| 最大電流 | 約2.39A |
| FC Vcc | 5.083-5.137V |
| Servo電源 | 5.923-6.150V |

電圧急落やFC電源低下は見られなかった。

Speed controller:

| 項目 | 結果 |
| --- | ---: |
| 実速度最大 | 1.57m/s |
| 実速度平均 | 0.95m/s |
| 目標速度平均 | 0.95m/s |
| 速度誤差中央値 | 0.006m/s |
| 目標速度と実速度の相関 | 0.947 |

判断:

- Speed追従は良好。
- `ATC_SPEED_*` は変更不要。

Turn Rate controller:

| 項目 | 結果 |
| --- | ---: |
| 目標TurnRate範囲 | -120-+120deg/s |
| 実TurnRate範囲 | -108-+110deg/s |
| 目標と実測の相関 | 0.954 |
| SteerOutとTurnRateの相関 | 0.936 |

判断:

- 初回Acro低速として良好。
- 大舵角では目標120deg/sに対して実測が90-110deg/s程度で、やや届いていない場面あり。
- ただし低速テストとしては正常範囲。
- `ATC_STR_RAT_*` はまだ変更不要。

Hold停止:

- 最初のHoldでは、速度約 -0.93m/s から約0.94秒で0.1m/s未満まで低下。
- Holdは退避先として使える。

LiDAR / RangeFinder:

| 項目 | 結果 |
| --- | ---: |
| RFNDサンプル数 | 8103 |
| `Dist=0.0` | 多い |
| 最大距離 | 9.0m |
| `Quality` | 常に -1 |
| Status | `2` が大半、`4` は一部 |

判断:

- 走行ログ上はLiDAR距離値が安定していない。
- Mission Plannerで一時的にSonar Rangeが見えていても、Auto-stop用途にはまだ不十分。
- LiDARは別途静置確認が必要。

採用判断:

```text
20260611_03_acro_low_speed_check
-> 採用
```

## 3. Acro S字TurnRateチェック

保存ファイル:

```text
projects/02_チューニング/logs/accepted/20260611_04_acro_s_curve_turnrate_check.bin
```

AcroモードでS字走行を行い、左右TurnRateの追従と左右差を確認した。Acroのメイン区間は約96.7秒で、暴走・制御破綻・異常なモード遷移は見られなかった。

GPS / EKF / Compass:

| 項目 | 結果 |
| --- | ---: |
| GPS Status | 3-4 |
| 衛星数 | 25-31 |
| HDop最大 | 0.59 |
| HAcc | 0.23-1.02m |
| SAcc | 0.05-0.32m/s |
| EKF variance系 | 問題なし |
| Compass Health | 問題なし |

Battery / 電源:

| 項目 | 結果 |
| --- | ---: |
| Battery電圧 | 11.43-11.78V |
| 最大電流 | 約2.91A |
| FC Vcc | 5.08-5.14V |
| Servo電源 | 5.93-6.21V |

Speed controller:

| 項目 | 結果 |
| --- | ---: |
| 実速度範囲 | -1.28-1.54m/s |
| 目標速度範囲 | -2.28-1.56m/s |
| 目標速度と実速度の相関 | 0.936 |
| 速度誤差RMSE | 0.328m/s |

Turn Rate controller:

| 項目 | 結果 |
| --- | ---: |
| 目標TurnRate範囲 | -120-+120deg/s |
| 実TurnRate範囲 | -107-+111deg/s |
| 目標と実測の相関 | 0.949 |
| TurnRate誤差RMSE | 18.5deg/s |

左右差:

| 方向 | 目標平均 | 実測平均 | 差 |
| --- | ---: | ---: | ---: |
| 右旋回側 | +71.1deg/s | +54.7deg/s | 約16.4deg/s不足 |
| 左旋回側 | -72.1deg/s | -56.1deg/s | 約16.0deg/s不足 |

判断:

- 左右どちらも似た傾向。
- 片側だけ曲がらない、片側だけ暴れる状態ではない。
- 大舵角では目標120deg/sに対して実測がやや届かないが、低速Roverでは自然。
- 現時点でゲインを上げる必要なし。

LiDAR / RangeFinder:

| 項目 | 結果 |
| --- | ---: |
| RFNDサンプル数 | 9597 |
| Dist非ゼロ率 | 約51.6% |
| Acro中のDist非ゼロ率 | 約44.1% |
| Dist中央値 | 0.13m |
| Acro中Dist中央値 | 0.0m |
| 最大Dist | 9.0m |
| Quality | 常に -1 |

採用判断:

```text
20260611_04_acro_s_curve_turnrate_check
-> 採用
```

## 4. Guided / Auto / Waypoint確認

保存ファイル:

```text
projects/02_チューニング/logs/accepted/20260611_05_navigation_low_speed_straight_check.bin
```

Guided低速移動とAuto Missionを実施。Autoでは複数Waypoint到達とMission Completeを確認した。

主要区間:

| 時刻目安 | モード | 内容 |
| ---: | --- | --- |
| 43.3-76.0秒 | Guided | Guided 1回目 |
| 115.4-126.5秒 | Guided | Guided 2回目 |
| 208.6-233.1秒 | Auto | Mission実行 |
| 233.1-243.6秒 | Acro | Auto後の退避 |
| 243.6-249.1秒 | Hold | 最終停止 |

Guided 1回目:

| 項目 | 結果 |
| --- | ---: |
| 実速度最大 | 1.66m/s |
| 速度追従相関 | 0.69 |
| 最大Waypoint距離 | 7.86m |
| XTrack最大 | 2.42m |
| 位置誤差平均 | 1.79m |
| 位置誤差最大 | 7.05m |

Guided 2回目:

| 項目 | 結果 |
| --- | ---: |
| 実速度最大 | 1.76m/s |
| 速度追従相関 | 0.98 |
| WpDist | 6.51m -> 0.26m |
| XTrack最大 | 0.28m |
| 位置誤差平均 | 0.37m |
| 位置誤差最大 | 0.51m |

判断:

- Guided 1回目は実施できたが追従は粗い。
- Guided 2回目は低速1点移動として良好。
- Guided確認は通過。

Auto Mission結果:

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

| 区間 | Waypoint間距離 |
| --- | ---: |
| WP0 -> WP1 | 約0.02m |
| WP1 -> WP2 | 約8.23m |
| WP2 -> WP3 | 約7.27m |
| WP3 -> WP4 | 約7.58m |

Auto区間のGPS移動距離は約28.7m。

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

- Autoの速度追従は良好。
- TurnRateも実用上問題なし。
- XTrack最大1.21mは小型Roverの初回Autoとして許容範囲。
- Auto MissionはWaypoint到達・Mission Completeまで確認できており、Waypoint Auto低速確認として十分。

GPS / EKF:

| 項目 | 結果 |
| --- | ---: |
| GPS Status | 3-4 |
| 衛星数 | 30-32 |
| HDop | 0.48-0.52 |
| HAcc | 0.20-0.87m |
| SAcc | 0.04-0.19m/s |

序盤に以下あり。

```text
EKF variance
EKF failsafe cleared
```

約22.4秒でEKF failsafe cleared。その後のGuided / Autoは問題なく動作。

Compass:

- 走行中のCompass HealthはOK。
- 終了後に `PreArm: Check mag field (xy diff:117>100)` が出た。
- 次回ARM前にCompass確認が必要。

Battery / 電源:

Auto区間:

| 項目 | 結果 |
| --- | ---: |
| Battery電圧 | 11.54-11.67V |
| 最大電流 | 2.27A |
| FC Vcc | 5.09-5.13V |
| Servo電源 | 5.94-6.25V |

Guided 1回目で一瞬以下あり。

| 項目 | 値 |
| --- | ---: |
| Battery最小 | 11.02V |
| 最大電流 | 7.50A |
| Servo電源最大 | 7.83V |

判断:

- 一瞬の負荷または計測スパイクの可能性。
- 即NGではないが、次回以降も同様ならESC / BEC / PM02 / サーボ負荷を確認。

採用判断:

```text
20260611_05_navigation_low_speed_straight_check
-> Guided / Auto / Waypoint確認として採用
```

## 5. LiDAR静置距離チェック

保存ファイル:

```text
projects/02_チューニング/logs/accepted/20260611_06_lidar_static_distance_check.bin
```

室内または静置状態で、TF-Luna LiDARの距離値が実距離に追従するか確認した。

解析結果:

| 項目 | 結果 | 判断 |
| --- | ---: | --- |
| RFNDログ数 | 3033件 | 十分 |
| RFND記録時間 | 約60.6秒 | 十分 |
| Dist最小 | 0.00m | 起動直後のみ |
| Dist最大 | 2.18m | 2m級まで確認 |
| Dist中央値 | 1.01m | 距離変化あり |
| Dist=0率 | 約1.1% | 良好 |
| `Stat=4` | 2782件 / 約91.7% | 良好 |
| `Stat=2` | 251件 / 約8.3% | 主に開始直後 |
| `Quality` | 常に -1 | TF-Lunaでは異常とは限らない |
| 電源 | 安定 | OK |

5秒ごとの中央値:

| 時間帯 | Dist中央値 | 状態 |
| ---: | ---: | --- |
| 0-5秒 | 0.07m | 開始直後、`Stat=2`、評価対象外 |
| 5-10秒 | 0.32m | 近距離 |
| 10-15秒 | 0.32m | 近距離 |
| 15-20秒 | 0.57m | 0.5m級 |
| 20-25秒 | 0.89m | 1m弱 |
| 25-30秒 | 1.00m | 1m級 |
| 30-35秒 | 1.66m | 1.5m級 |
| 35-40秒 | 2.15m | 2m級 |
| 40-45秒 | 2.16m | 2m級で安定 |
| 45-50秒 | 1.30m | 距離を戻した可能性 |
| 50-55秒 | 2.12m | 再び2m級 |
| 55-60秒 | 1.28m | 距離変化 |
| 60秒以降 | 0.26m | 近距離 |

判断:

- 板・壁・対象物の距離変更にLiDARが追従している。
- LiDAR静置確認は合格。
- 実運用では、LiDAR値を使う前に数秒待つか、`Stat=4` になってから使う。

LiDAR関連設定:

| パラメータ | 値 | 判断 |
| --- | ---: | --- |
| `RNGFND1_TYPE` | `20` | Benewake TF系としてOK |
| `RNGFND1_MIN_CM` | `20` | 20cm未満は信用しない設定 |
| `RNGFND1_MAX_CM` | `700` | 7m上限 |
| `RNGFND1_ORIENT` | `0` | 前向き |
| `SERIAL2_PROTOCOL` | `9` | RangeFinder |
| `SERIAL2_BAUD` | `115` | 115200相当 |
| `LOG_DISARMED` | `0` | Armしない単独ログには不向き |

採用判断:

```text
20260611_06_lidar_static_distance_check
-> 採用
```

## 6. LiDAR Object Avoidance設定検討

初期方針:

```text
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_BACKUP_SPD = 0
AVOID_MARGIN     = 0.5
RNGFND1_MAX_CM   = 700
```

Mission Plannerで `AVOID_MARGIN=0.5` を設定しようとすると `Out of range` 警告が出た。そのため、`AVOID_MARGIN=0.5` は採用せず、初期値の `2.0` を維持する方針にした。

```text
AVOID_MARGIN = 0.5
-> Mission Planner上で範囲外
-> 採用しない

AVOID_MARGIN = 2.0
-> 採用
```

BendyRuler設定:

```text
OA_TYPE = 1
```

保存ファイル:

```text
projects/02_チューニング/params/tuned/20260611_07_after_lidar_oa_bendyruler_setup.param.param
```

`OA_TYPE=1` を入れたところ、Mission Plannerの `RangeFinder1(cm)` が `0.00` のまま変化しなくなった。`OA_TYPE=0` に戻したところ、距離表示が復活した。

```text
OA_TYPE = 1
-> RangeFinder1表示が0.00になる

OA_TYPE = 0
-> RangeFinder1表示が復活
```

現時点の推奨設定:

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2.0
AVOID_BACKUP_SPD = 0
RNGFND1_MAX_CM   = 700
```

RangeFinder基本設定:

```text
RNGFND1_TYPE     = 20
RNGFND1_ORIENT   = 0
RNGFND1_MIN_CM   = 20
RNGFND1_MAX_CM   = 700
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD     = 115
```

判断:

- まずSimple Object Avoidanceで「LiDARをProximityとして認識して止まるか」を確認する。
- BendyRulerの `OA_TYPE=1` はその後。
- Manualでは自動停止の確認には使わない。
- Simple Object Avoidance確認はAcro低速で行う。
- Auto / Guided / RTLでのBendyRuler確認は後回し。

## 7. 次回以降の作業方針

次に行うテスト:

```text
20260612_01_lidar_simple_avoid_acro_stop_check
```

推奨保存名:

```text
projects/02_チューニング/logs/accepted/20260612_01_lidar_simple_avoid_acro_stop_check.bin
projects/02_チューニング/params/tuned/20260612_01_after_lidar_simple_avoid_acro_stop_check.param
```

テスト手順:

```text
1. OA_TYPE=0 のままにする
2. PRX1_TYPE=4
3. AVOID_ENABLE=7
4. AVOID_MARGIN=2.0
5. AVOID_BACKUP_SPD=0
6. RNGFND1_MAX_CM=700
7. FC再起動
8. Mission PlannerでRangeFinder1(cm)が距離変化することを確認
9. 障害物を正面2-3m先に置く
10. Acroに入れる
11. 低速で前進
12. 2m付近で減速または停止するか確認
13. 止まらなければ即HoldまたはManualへ退避
```

期待する挙動:

| 状態 | 判断 |
| --- | --- |
| 2m付近で前進が抑制される | OK |
| 2m付近で停止する | OK |
| 少し回避・旋回する | Simple Avoidanceでも起きる可能性あり |
| そのまま突っ込む | NG、即中止 |
| 障害物なしでも進まない | 周囲や地面を拾っている可能性 |

まだやらないこと:

```text
OA_TYPE=1 に戻す
AutoでBendyRuler確認
Guidedで障害物回避確認
RTL
SmartRTL
高速走行
```

## 8. 2026-06-11時点の総合判断

通過扱い:

| 項目 | 判断 |
| --- | --- |
| Acro割当 | 通過 |
| Manual / Hold退避 | 通過 |
| Acro低速走行 | 通過 |
| Acro S字TurnRate | 通過 |
| Speed controller | 現状変更不要 |
| Turn Rate controller | 現状変更不要 |
| Guided低速移動 | 通過 |
| Auto Mission / Waypoint | 通過 |
| Waypoint到達 | WP1-WP4到達 |
| Mission Complete | 達成 |
| LiDAR静置距離確認 | 通過 |

残課題:

| 課題 | 状態 |
| --- | --- |
| Compass PreArm警告 | `Check mag field (xy diff:117>100)` が終了後に出たため、次回ARM前に確認 |
| LiDAR走行中の安定性 | 静置では良好、走行中は0mが多かったため追加確認 |
| Simple Object Avoidance | 未実施 |
| BendyRuler | `OA_TYPE=1` でRangeFinder表示が0になったため保留 |
| Auto-stop / 障害物停止 | 未実施 |
| RTL / SmartRTL | 未実施 |
| Battery failsafe | 長時間走行前に設定検討 |

現時点で以下は変更しない。

```text
ATC_SPEED_*
ATC_STR_RAT_*
```

理由:

- Acro低速チェックでSpeed追従は良好。
- S字TurnRateチェックで左右差は小さい。
- Guided / Autoでも速度追従、Waypoint到達、Mission Completeまで確認済み。
- 初回チューニングとしては制御系変更の必要が薄い。

次の最優先:

```text
OA_TYPE=0 のSimple Object Avoidanceで、Acro低速障害物停止確認を行う。
```
