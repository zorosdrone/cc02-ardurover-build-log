# Rover SITL前方Rangefinder / Lua設定手順

更新日: 2026-06-20

基準バージョン: ArduRover 4.6.3

## 目的

ArduPilot Rover SITLの内蔵機能だけで、前方へ1本の測距レイを出す仮想Rangefinderを構成する。MAVProxyとLuaの両方で距離を確認し、CC-02用Lua障害物回避ロジックを実機投入前に検証できる状態にする。

この手順では360度LiDARの`sim:ld06`を使用しない。

> [!IMPORTANT]
> 公式記事には「単体SITLの内蔵バリアを前方1点Rangefinderで測る」という一連の手順はない。本書は、公式WikiのアナログRangefinder設定、360度LiDAR用の仮想バリア地点、および`SIM_Aircraft.cpp` / `SITL.cpp`の水平Rangefinder実装を組み合わせた検証手順である。測距値を実行確認してからLua制御へ進む。

## 1. 実機設定とSITL設定を分ける

CC-02実機のTF-Luna設定:

```text
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD     = 115
RNGFND1_TYPE     = 20
RNGFND1_MIN_CM   = 20
RNGFND1_MAX_CM   = 700
RNGFND1_ORIENT   = 0
```

本書のSITL設定:

```text
RNGFND1_TYPE     = 1
RNGFND1_PIN      = 0
RNGFND1_SCALING  = 10
RNGFND1_MIN_CM   = 0
RNGFND1_MAX_CM   = 5000
RNGFND1_ORIENT   = 0
```

SITL用設定を実機Pixhawkへ書き込まない。

## 2. ArduPilotの版を確認

ArduPilotリポジトリのルートで実行する。

```bash
git describe --tags --always --dirty
```

この手順は`Rover-4.6.3`用である。

| 項目 | Rover-4.6.3 | master / 4.7系 |
| --- | --- | --- |
| 最小距離 | `RNGFND1_MIN_CM`、cm | `RNGFND1_MIN`、m |
| 最大距離 | `RNGFND1_MAX_CM`、cm | `RNGFND1_MAX`、m |
| Lua距離API | `distance_cm_orient()`、cm | `distance_orient()`、m |

## 3. Rover SITLを仮想バリア地点で起動

ArduPilotリポジトリのルートで実行する。

```bash
Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0
```

付けない指定:

```text
--serial5=sim:ld06
```

この座標は、公式Wikiが360度LiDARの仮想バリア試験に使用している地点である。前方1点Rangefinderとの組み合わせは公式Wikiに明記されていない。

前方1点でも同じポスト群を測るという判断は、Roverの水平Rangefinderが`measure_distance_at_angle_bf()`を呼び、`SITL.cpp`のポスト群との交差距離を取得する実装に基づく。

既存SITLパラメータを消す場合のみ`-w`を付ける。`-w`は毎回使用しない。

## 4. 前方Rangefinderを設定

MAVProxyコンソールで実行する。

```text
param set SIM_SONAR_ROT 0
param set SIM_SONAR_SCALE 10

param set RNGFND1_TYPE 1
param set RNGFND1_PIN 0
param set RNGFND1_SCALING 10
param set RNGFND1_MIN_CM 0
param set RNGFND1_MAX_CM 5000
param set RNGFND1_ORIENT 0

reboot
```

| パラメータ | 値 | 意味 |
| --- | ---: | --- |
| `SIM_SONAR_ROT` | 0 | SITLの測距レイを車体前方へ向ける |
| `SIM_SONAR_SCALE` | 10 | 仮想距離からアナログ電圧へのm/Vスケール |
| `RNGFND1_TYPE` | 1 | Analog Rangefinder |
| `RNGFND1_PIN` | 0 | SITL仮想アナログ入力 |
| `RNGFND1_SCALING` | 10 | アナログ電圧から距離へのm/Vスケール |
| `RNGFND1_MIN_CM` | 0 | 最小距離0 cm |
| `RNGFND1_MAX_CM` | 5000 | 最大距離50 m |
| `RNGFND1_ORIENT` | 0 | ArduPilot側で前向きとして登録 |

`SIM_SONAR_ROT`は測距レイの物理方向、`RNGFND1_ORIENT`はArduPilotが扱うセンサー方向であり、両方を0にする。

再起動後に確認する。

```text
param show SIM_SONAR_ROT
param show SIM_SONAR_SCALE
param show RNGFND1_TYPE
param show RNGFND1_PIN
param show RNGFND1_SCALING
param show RNGFND1_MIN_CM
param show RNGFND1_MAX_CM
param show RNGFND1_ORIENT
```

### master / 4.7系を使う場合

距離パラメータだけをm単位へ差し替える。

```text
param set RNGFND1_MIN 0
param set RNGFND1_MAX 50
```

`_CM`版とm版を混ぜない。

## 5. 仮想ポストを地図へ表示

MAVProxyコンソールで実行する。

```text
script /tmp/post-locations.scr
```

このスクリプトはポストを作るものではなく、SITLソースに定義されたポスト位置を地図へ描く。

ファイルがない場合:

1. Rangefinder設定後に再起動したか確認する
2. SITLコンソールの`Writing /tmp/post-locations.scr`を確認する
3. 数秒待って再実行する
4. WSL内のMAVProxyから実行しているか確認する

## 6. MAVProxyで距離を確認

```text
module load graph
graph RANGEFINDER.distance
```

合格条件:

- ポストへ向けて接近すると距離が減少する
- 旋回してレイがポストを外すと最大距離相当へ戻る
- ポスト間では検出しないことがある
- 距離値が飛ぶ場合は向きとスケールを再確認する

SITLのポストは半径1 m、格子間隔10 mで、交差判定レイは200 mである。連続した壁ではない。

## 7. Luaを有効化

MAVProxyコンソールで実行する。

```text
param set SCR_ENABLE 1
reboot
```

SITLでは、シミュレーターを起動したディレクトリ直下の`scripts`フォルダーからLuaを読む。

```bash
mkdir -p scripts
```

`scripts/front_rangefinder_monitor.lua`を作成する。

```lua
local FRONT = 0
local UPDATE_MS = 500

local function update()
    if rangefinder:has_data_orient(FRONT) then
        local distance_cm = rangefinder:distance_cm_orient(FRONT)
        local distance_m = distance_cm * 0.01
        gcs:send_text(
            6,
            string.format("Front range: %.2f m", distance_m)
        )
    else
        gcs:send_text(4, "Front range: no data")
    end

    return update, UPDATE_MS
end

gcs:send_text(6, "Front range monitor started")
return update, UPDATE_MS
```

この確認用スクリプトは距離表示だけを行い、速度やモードを変更しない。

master / 4.7系では、距離取得を次へ差し替える。

```lua
local distance_m = rangefinder:distance_orient(FRONT)
```

SITLを再起動し、次のメッセージを確認する。

```text
Front range monitor started
Front range: xx.xx m
```

## 8. Lua停止制御へ進む条件

監視が安定してから停止制御を追加する。

初期検討値:

```text
警戒距離: 5.0 m
停止距離: 2.5 m
再開距離: 6.0 m
確定回数: 3回連続
制御周期: 100 ms
```

これはSITL初期値であり、実機TF-Lunaの`AVOID_MARGIN=2`や実測停止距離とは別に評価する。

実機停止距離:

```text
実測制動距離
+ センサーとLuaの遅延中に進む距離
+ 安全余裕
```

実装順:

1. 警告表示
2. 警戒距離で減速
3. 停止距離で停止保持
4. センサー喪失で停止保持
5. 後退
6. 固定方向旋回
7. 前方再確認
8. 走行再開

`vehicle:set_desired_speed()`、`vehicle:set_desired_turn_rate_and_speed()`、`vehicle:set_mode()`はRover-4.6.3のLua APIに存在する。採用APIと対象モードを固定し、停止だけを単独試験してから回避へ進む。

## 9. 実機へ移す前の分離手順

現在の通常運用正本はNative Simple Object Avoidanceを有効化している。

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2
AVOID_BACKUP_SPD = 0
```

Lua制御の実機試験前に、現在パラメータを別名保存する。

```text
params/tuned/YYYYMMDD_01_before_lua_avoid_test.param
```

試験ルール:

- 読取りだけのLuaはNative OAを維持して確認できる
- Luaが速度・モードへ介入する試験では、Native OAとの重複を避ける
- Native OAを無効化する場合は試験用パラメータだけで行う
- `RTUN_ENABLE=0`をLua試験用設定の候補とする
- QuikTuneの`Scripting1`を開始しない
- タイヤ浮かせ、低速、平坦地の順で進む
- 終了後は`20260613_pixhawk6c_rover_tuned_01.param`へ戻す

## 10. 試験表

| ID | 試験 | 合格条件 |
| --- | --- | --- |
| RF-01 | SITL距離受信 | `RANGEFINDER.distance`が更新される |
| RF-02 | ポストへ接近 | 距離が連続的に減る |
| RF-03 | その場旋回 | ポストを外すと最大距離へ戻る |
| RF-04 | ポスト間 | 未検出になり得ることを確認 |
| LUA-01 | Lua起動 | 起動メッセージが1回出る |
| LUA-02 | API単位 | Luaのm表示とMAVProxyが一致する |
| LUA-03 | センサー無効 | `no data`を検出する |
| SAFE-01 | Lua停止 | 停止距離より手前で停止する |
| SAFE-02 | Lua異常 | 走行継続ではなく停止側へ倒れる |
| REAL-01 | 実機読取り | TF-Luna値とMission Planner表示が一致する |
| REAL-02 | 設定復帰 | 通常運用正本でNative OA停止を再現する |

## 11. トラブルシュート

### `RNGFND1_MIN_CM`が見つからない

ファームウェア系統を確認する。

```text
param show RNGFND1_MIN*
param show RNGFND1_MAX*
```

### Luaで`distance_orient`がnilになる

ArduRover 4.6.3では`distance_cm_orient()`を使う。

### 距離が常に50 m付近

- レイがポストを通っているか
- `SIM_SONAR_ROT=0`か
- ポスト間を向いていないか
- 両方のSCALINGが10か

### Luaが起動しない

- `SCR_ENABLE=1`後に再起動したか
- SITL起動ディレクトリ直下に`scripts`があるか
- `.lua`拡張子か
- GCSメッセージに構文エラーがないか

### 実機TF-Lunaが読めなくなった

SITL用設定を実機へ書いていないか確認し、通常運用正本へ戻す。

```text
RNGFND1_TYPE = 20
RNGFND1_PIN  = -1
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD = 115
```

## 関連資料

- [Lua障害物回避プロジェクト概要](README.md)
- [現在状況](../01_現在状況.md)
- [ArduRoverパラメータ](../06_ArduRoverパラメータ.md)
- [チューニングログ](../09_チューニングログ.md)
- [2026-06-13 Guided障害物停止確認](../../logs/test_runs/20260613_07_guided_obstacle_stop_check.md)

## 公式資料

- [Adding Simulated Peripherals to sim_vehicle](https://ardupilot.org/dev/docs/adding_simulated_devices.html)
- [Using SITL with AirSim（アーカイブ）](https://ardupilot.org/dev/docs/sitl-with-airsim.html)
- [Rover-4.6.3 Rangefinderパラメータ定義](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_RangeFinder/AP_RangeFinder_Params.cpp)
- [Rover-4.6.3 Lua API定義](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_Scripting/docs/docs.lua)
- [Rover-4.6.3 水平Rangefinder処理](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/SITL/SIM_Aircraft.cpp)
- [Rover-4.6.3 仮想ポスト実装](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/SITL/SITL.cpp)
- [Lua Scripts](https://ardupilot.org/rover/docs/common-lua-scripts.html)
- [Simple Object Avoidance](https://ardupilot.org/rover/docs/common-simple-object-avoidance.html)
