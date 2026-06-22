# WSLからSITLとBendyRulerを実行する最短手順

更新日: 2026-06-23

## 目的

WSLでRover SITLを起動し、前方RangefinderとBendyRulerを設定して、GUIDED走行で反応を確認する。

BendyRulerはArduPilotの標準機能なので、この確認にLuaスクリプトは使用しない。

> [!IMPORTANT]
> この手順はSITLでBendyRulerの反応を確認する実験用である。前方Rangefinder 1本では左右の空きを観測できないため、安全な迂回ができることの証明にはならない。

## 1. WSLでRover SITLを起動

WindowsのPowerShellでWSLを開く。

```powershell
wsl
```

WSLでArduPilotへ移動し、仮想ポストがある地点でRover SITLを起動する。

```bash
cd ~/ardupilot
git rev-parse --short HEAD

Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0
```

`--serial5=sim:ld06`は付けない。通常は`-w`も付けない。

## 2. 前方RangefinderとBendyRulerを設定

MAVProxyコンソールで、変更前の設定を保存してから実行する。

```text
param save /tmp/cc02_sitl_before_bendyruler.param

param set SIM_SONAR_ROT 0
param set RNGFND1_TYPE 100
param set RNGFND1_MIN 0
param set RNGFND1_MAX 50
param set RNGFND1_ORIENT 0

param set PRX1_TYPE 4
param set AVOID_ENABLE 7
param set AVOID_MARGIN 2
param set AVOID_BEHAVE 1
param set AVOID_BACKUP_SPD 0

param set OA_TYPE 1
reboot
```

再接続後、BendyRulerの試験値を設定する。

```text
param fetch

param set OA_BR_LOOKAHEAD 5
param set OA_MARGIN_MAX 2
param set WP_SPEED 1

param set OA_DB_SIZE 100
param set OA_DB_EXPIRE 10
param set OA_DB_OUTPUT 3
reboot
```

## 3. 距離と設定を確認

再接続後、MAVProxyコンソールで実行する。

```text
script /tmp/post-locations.scr
module load graph
graph DISTANCE_SENSOR.current_distance
module load proximity

param show OA_TYPE
param show OA_BR_LOOKAHEAD
param show OA_MARGIN_MAX
param show WP_SPEED
```

次を確認する。

- MAVProxyの地図に仮想ポストが表示される
- 車体前方にポストがあると距離が小さくなる
- `OA_TYPE`が`1`になっている
- `WP_SPEED`が`1 m/s`になっている

## 4. GUIDEDでBendyRulerを実行

MAVProxyコンソールで実行する。

```text
mode guided
arm throttle
```

Mission Plannerの地図で、Roverから見て仮想ポストの向こう側をGUIDED目標に指定する。画面表示に応じて、地図の右クリックメニューから`Fly To Here`または`ここに移動`を選ぶ。

次の反応を観察する。

- ポストへ近づくと減速または停止する
- BendyRulerが進路変更を試す
- 経路が見つからない場合は、その旨のメッセージや停止が発生する
- `DISTANCE_SENSOR.current_distance`が更新され続ける

前方Rangefinder 1本では、進路変更先が安全かどうかは判断しない。BendyRulerが動作したことの確認に留める。

## 5. 停止して元の設定へ戻す

試験終了時は、まず停止してDisarmする。

```text
mode hold
disarm
```

保存した設定へ戻す。

```text
param load /tmp/cc02_sitl_before_bendyruler.param
reboot
```

## 手順の流れ

```text
WSLを開く
  → Rover SITLを起動
  → 前方Rangefinderを設定
  → OA_TYPE=1でBendyRulerを有効化
  → GUIDED目標を送る
  → 反応を確認
  → HOLD・Disarm
  → 保存した設定へ戻す
```

## 詳細資料

- [Rover SITL前方Rangefinder / Lua設定手順](01_RoverSITL前方Rangefinder設定手順.md)
- [標準ArduRover SITLで前方LiDARによる障害物前停止を試す](02_標準SITLでのLiDAR再現方針.md)
