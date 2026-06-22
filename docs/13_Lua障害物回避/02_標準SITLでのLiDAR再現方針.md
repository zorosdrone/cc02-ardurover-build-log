# 標準ArduRover SITLで前方LiDARによる障害物前停止を試す

更新日: 2026-06-22

対象: 最新ArduPilotソース（`master`）、Rover SITL、MAVProxy、前方1点Rangefinder、標準Simple Object Avoidance

この手順では、実機CC-02の前方TF-Luna 1台という構成に合わせ、SITLも前方1点Rangefinderだけを使用する。360度LiDARの`sim:ld06`は使用しない。Luaも使用しない。

## 結論

前方1点Rangefinderを`PRX1_TYPE=4`でProximity Sensorへ変換すれば、ArduPilot標準のSimple Object Avoidanceによる障害物前停止をSITLで試せる。

```text
SITL内蔵ポスト
    ↓
前方1点Rangefinder
    ↓
PRX1_TYPE=4
    ↓
Simple Object Avoidance
    ↓
減速・停止
```

一方、前方1点では左右の空き方向を観測できないため、BendyRulerの安全な自律迂回は合格判定できない。本書ではSimple Object Avoidanceの前停止を主試験とし、BendyRulerは設定・起動・反応を確認する実験試験として扱う。

## 1. SITLと実機の対応

| 項目 | 最新ソースSITL | CC-02実機 |
| --- | --- | --- |
| ファームウェア | 最新`master` | ArduRover 4.6.3 |
| センサー | 前方1点SITL Rangefinder | 前方TF-Luna 1台 |
| Rangefinder型 | `RNGFND1_TYPE=100` | `RNGFND1_TYPE=20` |
| 最小・最大距離 | `RNGFND1_MIN/MAX`、m | `RNGFND1_MIN_CM/MAX_CM`、cm |
| 向き | `RNGFND1_ORIENT=0` | `RNGFND1_ORIENT=0` |
| Proximity変換 | `PRX1_TYPE=4` | `PRX1_TYPE=4` |
| 標準停止 | `AVOID_ENABLE=7` | `AVOID_ENABLE=7` |
| 停止余裕 | `AVOID_MARGIN=2` | `AVOID_MARGIN=2` |
| 経路計画 | `OA_TYPE=0` | `OA_TYPE=0` |

SITLと実機でRangefinderドライバと距離パラメータ名は異なるが、センサーの視野、向き、Proximity変換、Simple Object Avoidanceの設定は合わせる。

## 2. 試験前の版確認

ArduPilotリポジトリのルートで実行し、試験ログへコミットIDを残す。

```bash
git describe --tags --always --dirty
git branch --show-current
git rev-parse HEAD
```

`master`は更新される。「最新」とだけ記録せず、再現可能なSHAを残す。

### 確認結果（2026-06-22）

| 項目 | 確認値 |
| --- | --- |
| 実行端末 | `TrigkeyS5` |
| ArduPilotディレクトリ | `~/ardupilot` |
| `git describe --tags --always --dirty` | `ArduPilot-4.6.0-beta1-7220-g7cd2375e07` |
| ブランチ | `master` |
| コミット | [`7cd2375e0798913d4bb1a3b7b2402502ea3635e5`](https://github.com/ArduPilot/ardupilot/commit/7cd2375e0798913d4bb1a3b7b2402502ea3635e5) |

`git describe`の出力に`-dirty`接尾辞は付いていない。このコミットを以後のSITL試験結果の基準版とする。

## 3. 前方1点Rangefinder付きRover SITLを起動

```bash
Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0
```

付けない指定:

```text
--serial5=sim:ld06
```

既存SITLパラメータを消す場合だけ、初回の起動コマンドへ`-w`を付ける。毎回は使用しない。

## 4. センサー受信だけを確認

最初は標準回避制御を無効にし、前方距離とProximity変換だけを確認する。

```text
param set SIM_SONAR_ROT 0
param set RNGFND1_TYPE 100
param set RNGFND1_MIN 0
param set RNGFND1_MAX 50
param set RNGFND1_ORIENT 0

param set PRX1_TYPE 4
param set AVOID_ENABLE 0
param set OA_TYPE 0
reboot
```

再起動後に確認する。

```text
param show SIM_SONAR_ROT
param show RNGFND1_TYPE
param show RNGFND1_MIN
param show RNGFND1_MAX
param show RNGFND1_ORIENT
param show PRX1_TYPE
param show AVOID_ENABLE
param show OA_TYPE

script /tmp/post-locations.scr
module load graph
graph DISTANCE_SENSOR.current_distance
module load proximity
```

`DISTANCE_SENSOR.current_distance`はcm単位である。`module load proximity`では、前方1点だけがProximity情報として表示される。

### センサー確認の合格条件

- MAVProxyマップへ仮想ポストが表示される
- 車体前方にポストを向けると距離が減る
- 車体を旋回してレイがポストを外すと範囲外相当の大きな値へ戻る
- Proximity表示は前方だけで、左右や後方には検出情報がない
- `AVOID_ENABLE=0`なので、この段階では自動停止しない

ここを通過するまで、標準停止試験へ進まない。

## 5. Simple Object Avoidanceを有効化

```text
param set AVOID_ENABLE 7
param set AVOID_MARGIN 2
param set AVOID_BEHAVE 1
param set AVOID_BACKUP_SPD 0
param set OA_TYPE 0
reboot

script /tmp/post-locations.scr
module load graph
graph DISTANCE_SENSOR.current_distance
module load proximity
```

| パラメータ | 値 | 意味 |
| --- | ---: | --- |
| `PRX1_TYPE` | 4 | RangefinderをProximity Sensorとして使用 |
| `AVOID_ENABLE` | 7 | Fence、Proximity、Beacon Fenceを有効化。今回の障害物入力はProximity |
| `AVOID_MARGIN` | 2 | 障害物から維持しようとする距離2 m |
| `AVOID_BEHAVE` | 1 | Stop。Roverの既定もStopだが試験条件を明示する |
| `AVOID_BACKUP_SPD` | 0 | 障害物へ近すぎても自動後退させない |
| `OA_TYPE` | 0 | BendyRuler等の経路計画を無効化 |

速度グラフを開く。

```text
module load graph
graph VFR_HUD.groundspeed
```

## 6. 障害物前停止を試す

マップ上で車体前方にポストが来るよう向きを合わせ、低速で接近する。例として`ACRO`を使用する。

```text
mode acro
arm throttle
rc 3 1550
```

停止後はスロットルを中立へ戻し、Disarmする。

```text
rc 3 1500
disarm
```

### 合格条件

- Luaスクリプトを使っていない
- `MANUAL`以外のモードで試験している
- 前方距離が減るとRoverが減速を開始する
- ポストへ接触する前に対地速度が0付近になる
- 停止後も前進指令を残した状態で、障害物を通り抜けない
- `AVOID_BACKUP_SPD=0`なので自動後退しない
- `OA_TYPE=0`なので左右への自律迂回は行わない

`MANUAL`ではSimple Object Avoidanceが停止させない。必要なら最後に低速で負の対照試験として確認する。

## 7. BendyRuler実験設定

> [!IMPORTANT]
> この手順はBendyRulerを有効化して反応を観察するための実験手順である。前方LiDAR 1台では左右の空き方向を直接観測できないため、「安全に迂回できた」という合格判定や実機採用判断には使用しない。

### 7.1 対象モード

BendyRulerの経路計画は次のモードで使用する。

- `AUTO`
- `GUIDED`
- `RTL`

`ACRO`や`MANUAL`では、`OA_TYPE=1`にしてもBendyRulerによる経路迂回試験にはならない。

### 7.2 前提条件

- Simple Object AvoidanceのAcro停止試験に合格している
- `PRX1_TYPE=4`で前方距離がProximityへ入っている
- MAVLink InspectorでProximity用`DISTANCE_SENSOR id=10`が更新されている
- 最初はSITLの単独ポストを使う
- 左右に十分な逃げ空間がある
- 試験速度を1 m/s以下にする
- 通常設定へ戻せるよう、変更前パラメータを保存する

MAVProxyで変更前のSITLパラメータを保存する例:

```text
param save /tmp/cc02_sitl_before_bendyruler.param
```

### 7.3 BendyRulerを有効化

停止・Disarmしてから実行する。

```text
mode hold
disarm

param set OA_TYPE 1
reboot
```

`OA_TYPE=1`設定後に、Mission Plannerではパラメータを再読込みする。MAVProxyでは次を実行する。

```text
param fetch
```

続けて初回SITL試験値を設定する。

```text
param set OA_BR_LOOKAHEAD 5
param set OA_MARGIN_MAX 2
param set WP_SPEED 1

param set OA_DB_SIZE 100
param set OA_DB_EXPIRE 10
param set OA_DB_OUTPUT 3

reboot
```

| パラメータ | 値 | 意味 |
| --- | ---: | --- |
| `OA_TYPE` | 1 | BendyRulerを有効化 |
| `OA_BR_LOOKAHEAD` | 5 | 進行方向を5 m先まで探索 |
| `OA_MARGIN_MAX` | 2 | 経路計画で使用する障害物距離2 m |
| `WP_SPEED` | 1 | AUTO / GUIDED試験速度を1 m/sへ制限 |
| `OA_DB_SIZE` | 100 | 障害物データベースを有効化。変更後は再起動が必要 |
| `OA_DB_EXPIRE` | 10 | 未更新の障害物を10秒で削除 |
| `OA_DB_OUTPUT` | 3 | 障害物DBをGCSへ全出力して観察しやすくする |

Roverは水平BendyRulerだけを使用する。Copter向けの`OA_BR_TYPE`はRoverの設定対象ではない。

再起動後に確認する。

```text
param show OA_TYPE
param show OA_BR_LOOKAHEAD
param show OA_MARGIN_MAX
param show OA_DB_SIZE
param show OA_DB_EXPIRE
param show OA_DB_OUTPUT
param show WP_SPEED
```

### 7.4 GUIDEDで反応を確認

1. `script /tmp/post-locations.scr`で仮想ポストを表示する
2. Roverと目標点を結ぶ直線上に単独ポストが来る配置を選ぶ
3. `GUIDED`へ切り替える
4. ポストの向こう側へGUIDED目標を送る
5. 進路、対地速度、Proximity表示、GCSメッセージを観察する

```text
mode guided
arm throttle
```

確認項目:

- `OA_TYPE=1`のまま動作している
- Proximity用`DISTANCE_SENSOR id=10`が失われていない
- 障害物接近時に停止、進路変更、または経路なしの反応が出る
- 障害物を外した後、GUIDED目標へ向かう動作へ復帰する

前方1点構成では「右へ避けた」「左へ避けた」という結果だけで成功判定しない。見えていない側へ進路を変える可能性があるため、反応確認に留める。

試験後は停止・Disarmする。

```text
mode hold
disarm
```

### 7.5 Simple Object Avoidanceへ戻す

変更前に保存したパラメータを戻す方法:

```text
param load /tmp/cc02_sitl_before_bendyruler.param
reboot
```

最低限を手動で戻す場合:

```text
param set OA_TYPE 0
param set OA_DB_OUTPUT 1
param set AVOID_MARGIN 2
param set AVOID_BACKUP_SPD 0
reboot
```

`WP_SPEED`なども変更前の値へ戻す。復帰後、AcroでSimple Object Avoidanceの前停止を再確認する。

### 7.6 既存の実機用実験版との違い

既存の`params/tuned/20260613_08_oa_type1_bendyruler_test.param`は、実機4.6.3で小回りを試した過去の実験版である。

```text
OA_BR_LOOKAHEAD  = 2
OA_MARGIN_MAX    = 1
AVOID_MARGIN     = 1
AVOID_BACKUP_SPD = 0.2
```

本書のSITL初回値`LOOKAHEAD=5`、`MARGIN=2`とは目的が異なる。過去実験版を通常運用正本や最新SITLへそのまま読み込まない。

## 8. 前方1点構成での制約

### 左右の安全方向を選べない

前方1点Rangefinderが取得できるのは、現在の車体正面にある障害物までの距離だけである。

```text
左側の空き: 不明
前方の距離: 測定可能
右側の空き: 不明
```

そのため、`OA_TYPE=1`へ変更してBendyRulerを動作させても、安全な左右方向を観測に基づいて比較できない。本構成ではBendyRulerの成功・安全性を判定しない。

### 標準機能で確認する範囲

- 前方障害物の検出
- 距離に応じた減速
- `AVOID_MARGIN`を用いた前停止
- センサーが前方から外れた場合の動作
- `MANUAL`とそれ以外のモード差

### 標準機能だけでは確認しない範囲

- 左右を比較した自律迂回
- 後退後の安全方向選択
- 固定旋回後の前方再確認
- 袋小路からの離脱

後退・固定旋回・前方再確認を実現する場合は、前方1点という実機制約を前提にLua状態機械として別試験する。

## 9. 実機4.6.3へ対応させる設定

実機ではRangefinder部分だけをTF-Luna用へ置き換える。

```text
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD     = 115
RNGFND1_TYPE     = 20
RNGFND1_MIN_CM   = 20
RNGFND1_MAX_CM   = 700
RNGFND1_ORIENT   = 0

PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2
AVOID_BACKUP_SPD = 0
OA_TYPE          = 0
```

SITL用の`RNGFND1_TYPE=100`、`RNGFND1_MIN`、`RNGFND1_MAX`を実機へ書き込まない。

## 10. トラブルシュート

### 前方距離が表示されない

- `RNGFND1_TYPE=100`か
- `RNGFND1_ORIENT=0`か
- `SIM_SONAR_ROT=0`か
- 設定後に再起動したか
- ポストを車体正面へ向けているか

### Rangefinder値は出るが停止しない

- `PRX1_TYPE=4`か
- `AVOID_ENABLE`にProximityのbit 1が含まれるか。`7`には含まれる
- `AVOID_BEHAVE=1`か
- `MANUAL`で試していないか
- `AVOID_ENABLE=0`のセンサー確認段階のままではないか

### 停止距離が2 mにならない

`AVOID_MARGIN=2`は、グラフ上の距離を常に2.00 mへ固定する設定ではない。速度、加速度制限、Roverの制御応答、ポストの半径などが停止位置へ影響する。低速から始め、実測停止距離をログへ残す。

### 停止するが迂回しない

本構成では正常である。`OA_TYPE=0`で停止だけを採用しており、前方1点では左右の空き方向も観測できない。

## 11. 試験記録

| ID | 試験 | 合格条件 |
| --- | --- | --- |
| STD-FRONT-01 | 前方距離受信 | ポスト接近で距離が減る |
| STD-FRONT-02 | Proximity変換 | 前方RangefinderがProximityへ反映される |
| STD-FRONT-03 | Simple OA停止 | ポスト手前で対地速度が0付近になる |
| STD-FRONT-04 | `MANUAL`負の対照 | 自動停止しないことを低速で確認 |
| STD-FRONT-05 | レイ逸脱 | 旋回してポストを外した場合の挙動を確認 |
| STD-FRONT-06 | 反復 | 同じ条件を10回繰り返す |
| STD-BR-01 | BendyRuler有効化 | `OA_TYPE=1`と関連パラメータを確認 |
| STD-BR-02 | GUIDED反応 | 前方障害物に対する停止・進路変更・経路なし反応を記録 |
| STD-BR-03 | Simple OA復帰 | `OA_TYPE=0`へ戻しAcro停止を再確認 |

### 実施結果（2026-06-22）

| ID | モード | 結果 | 証拠・補足 |
| --- | --- | --- | --- |
| `STD-FRONT-03` | `ACRO` | 合格 | ArduPilot標準Simple Object Avoidanceによる障害物前停止を確認済み |

各試験で最低限、次を記録する。

- `git rev-parse HEAD`
- 使用モード
- `RNGFND1_*`、`PRX1_*`、`AVOID_*`、`OA_TYPE`
- 接近開始速度
- 停止時のRangefinder距離
- ポスト中心または外周からの停止距離
- DataFlashログとMAVProxy画面

## 関連資料

- [Lua障害物回避プロジェクト概要](README.md)
- [Rover SITL前方Rangefinder / Lua設定手順](01_RoverSITL前方Rangefinder設定手順.md)
- [仮想ポストKML表示補助](補助機能/10_MP_仮想ポストKML表示補助.md)
- [rover-gcsのWebots連携ガイド](https://github.com/zorosdrone/rover-gcs/blob/main/docs/webots_setup.md)

## 公式資料

- [Adding Simulated Peripherals to sim_vehicle](https://ardupilot.org/dev/docs/adding_simulated_devices.html)
- [Simple Object Avoidance](https://ardupilot.org/rover/docs/common-simple-object-avoidance.html)
- [Object Avoidance with BendyRuler](https://ardupilot.org/rover/docs/common-oa-bendyruler.html)
- [Proximity Sensors](https://ardupilot.org/rover/docs/common-proximity-landingpage.html)
- [最新Rangefinderパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_RangeFinder/AP_RangeFinder_Params.cpp)
- [最新SITL Rangefinderドライバ](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_RangeFinder/AP_RangeFinder_SITL.cpp)
- [最新Simple Avoidanceパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AC_Avoidance/AC_Avoid.cpp)
- [最新BendyRulerパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AC_Avoidance/AP_OABendyRuler.cpp)
- [最新OA Path Plannerパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AC_Avoidance/AP_OAPathPlanner.cpp)
- [最新OA Databaseパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/master/libraries/AC_Avoidance/AP_OADatabase.cpp)
