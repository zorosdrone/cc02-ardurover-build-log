# REPLでLua APIを確認する

更新日: 2026-07-01

対象: ArduPilot Rover SITL、Lua Scripting、MAVProxy、Mission Planner

## 目的

長いLuaファイルを投入する前に、REPLで小さいAPI呼び出しを実行し、戻り値、単位、Guided Targetの見え方を確認する。

ArduPilot SITLのLua REPLは、MAVProxyコンソールへLuaを直接入力する機能ではない。公式の`repl.lua`をSITLのスクリプトとして実行し、SITLの仮想シリアルポートへ別ターミナルからTCP接続して使用する。

```text
SITL
 ├─ Rover
 ├─ Lua Scripting
 ├─ repl.lua
 └─ SERIAL5 -> TCP:9995
                  ^
            別ターミナル
            ncで接続
```

REPLは実機走行判断の代わりではない。実機では最初にタイヤを浮かせ、読み取りAPIだけを確認する。

## 事前に確認するAPI

SITLでLua制御を試す前に、次のAPIをREPLで単独確認する。

| API | 確認すること |
| --- | --- |
| `vehicle:get_mode()` | Guidedのモード番号が想定どおりか |
| `vehicle:get_target_location()` | RoverでGuided目的地を直接取得できるか |
| `vehicle:get_wp_distance_m()` | Guided WP / Targetまでの距離をmで取得できるか |
| `vehicle:get_wp_bearing_deg()` | Guided WP / Targetへの方位をdegで取得できるか |
| `ahrs:get_location()` | 現在位置を取得できるか |
| `Location:offset_bearing(bearing, distance)` | 現在位置、方位、距離からTarget座標を復元できるか |
| `vehicle:set_target_location(location)` | 保存または復元した目的地へ戻せるか |
| `vehicle:set_desired_speed(speed)` | Guided中に速度上限を変更できるか |
| `vehicle:set_desired_turn_rate_and_speed(rate, speed)` | 停止、後退、旋回指令が成功するか |
| `rangefinder:has_data_orient(0)` | 前方Rangefinderデータが有効か |
| `rangefinder:distance_orient(0)` | 最新SITLで前方距離をm単位で取得できるか |
| `rangefinder:distance_cm_orient(0)` | Rover 4.6.3系で前方距離をcm単位で取得できるか |

この文書のSITL手順は、最新ArduPilotソースでのREPL確認を主対象にする。CC-02実機ベースラインのArduRover 4.6.3系では、距離APIとパラメータ単位が異なるため、実機へ移す前に`01_RoverSITL前方Rangefinder設定手順.md`のバージョン差も確認する。

## `repl.lua`を配置する

WSLのArduPilotディレクトリで実行する。

```bash
cd ~/ardupilot
mkdir -p scripts
cp libraries/AP_Scripting/applets/repl.lua scripts/
```

REPL試験中は、回避Luaなど他のスクリプトを同時実行しない。

```bash
mkdir -p scripts_disabled

mv scripts/20260628_luaoa_min_guided_avoid.lua \
   scripts_disabled/ 2>/dev/null
```

配置確認:

```bash
ls -l scripts/
```

試験中は、基本的に次だけがある状態にする。

```text
repl.lua
```

## SITLのパラメータを設定する

いったん通常どおりRover SITLを起動する。

```bash
cd ~/ardupilot

Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0
```

MAVProxyコンソールで、Lua ScriptingとScripting用シリアルポートを設定する。

```text
param set SCR_ENABLE 1
param set SERIAL5_PROTOCOL 28
```

設定確認:

```text
param show SCR_ENABLE
param show SERIAL5_PROTOCOL
```

期待値:

```text
SCR_ENABLE 1
SERIAL5_PROTOCOL 28
```

設定後、`Ctrl+C`で`sim_vehicle.py`全体を終了する。

## REPL用TCPポート付きでSITLを起動する

SITL起動時に、`SERIAL5`をTCPポート`9995`へ割り当てる。

```bash
cd ~/ardupilot

Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0 \
  -A --serial5=tcp:9995:wait
```

`:wait`を付けると、別ターミナルから接続するまで起動が止まって見える場合がある。これは正常動作である。

## 別ターミナルからREPLへ接続する

別のWSLターミナルを開いて実行する。

```bash
stty -icanon -echo -icrnl
nc 127.0.0.1 9995
```

`nc`がない場合:

```bash
sudo apt update
sudo apt install netcat-openbsd
```

接続に成功すると、次のような表示が出る。

```text
Lua REPL v1.1 started.
>
```

## 基本確認

計算:

```lua
1 + 2
```

期待値:

```text
3
>
```

Roverのモード番号:

```lua
vehicle:get_mode()
```

前方Rangefinderのデータ有無:

```lua
rangefinder:has_data_orient(0)
```

前方距離。最新SITLではm単位で取得する。

```lua
rangefinder:distance_orient(0)
```

例:

```text
7.436
>
```

Rover 4.6.3系の確認では、cm単位APIを使う。

```lua
rangefinder:distance_cm_orient(0)
```

現在位置:

```lua
ahrs:get_location()
```

変数へ保存する場合:

```lua
p = ahrs:get_location()
p:lat()
p:lng()
```

緯度・経度は`1度 * 10^7`の整数で返る。

## Guided Target取得を確認する

Fly To送信前:

```lua
vehicle:get_target_location()
```

通常は次になる。

```text
nil
```

Mission PlannerからTargetを送信する。

1. RoverをGuidedへ変更する
2. Armする
3. Mission Plannerの地図で`Fly To Here`を実行する

その直後にREPLで確認する。

```lua
vehicle:get_target_location()
```

Roverでは、内部にGuided Targetが存在していても、引き続き`nil`になる場合がある。その場合は、Targetまでの距離と方位を確認する。

```lua
vehicle:get_wp_distance_m()
vehicle:get_wp_bearing_deg()
```

例:

```text
> vehicle:get_target_location()
nil

> vehicle:get_wp_distance_m()
24.318

> vehicle:get_wp_bearing_deg()
91.46
```

この場合は、Guided Target自体はRover内部に存在するが、`get_target_location()`だけがLuaへTargetを返していない、と判断する。

## Target座標をREPL上で復元する

現在位置、Targetまでの距離、方位からTarget座標を復元する。

```lua
target = ahrs:get_location():copy()
```

```lua
target:offset_bearing(
  vehicle:get_wp_bearing_deg(),
  vehicle:get_wp_distance_m()
)
```

復元結果を確認する。

```lua
target:lat()
target:lng()
```

1行で実行する場合:

```lua
target=ahrs:get_location():copy(); target:offset_bearing(vehicle:get_wp_bearing_deg(),vehicle:get_wp_distance_m()); target
```

## REPL入力の注意点

REPLで次のように`local`を付けると、次の入力時には利用できなくなる。

```lua
local x = 3
```

複数の入力で使う変数はグローバル変数として定義する。

```lua
x = 3
x + 1
```

期待値:

```text
4
```

未完のLua文を入力すると、プロンプトが`>>`へ変わる。

```lua
if vehicle:get_target_location() == nil then
```

```text
>>
```

続けて入力する。

```lua
print("target is nil")
end
```

期待値:

```text
target is nil
>
```

入力途中を破棄する場合は`Esc`を2回押す。

## 終了方法

REPL接続側で`Ctrl+C`を押す。その後、端末設定を戻す。

```bash
reset
```

または:

```bash
stty sane
```

TCP接続を切断後、再接続してもREPLが復帰しない場合がある。その場合は、`sim_vehicle.py`全体を終了して再起動するのが確実である。

## トラブルシューティング

### `REPL scripting port not configured`

確認する。

```text
param show SCR_ENABLE
param show SERIAL5_PROTOCOL
```

期待値:

```text
SCR_ENABLE 1
SERIAL5_PROTOCOL 28
```

SITL起動オプションも確認する。

```text
-A --serial5=tcp:9995:wait
```

### 別のScriptingポートへ接続される

`repl.lua`の標準設定は次のとおり。

```lua
local PORT_IDX = 0
```

これは`SERIAL0`を意味するのではなく、`SERIALn_PROTOCOL=28`に設定されたポートのうち、最初のScriptingポートを意味する。

```text
param show SERIAL*_PROTOCOL
```

複数のポートが`28`になっている場合、REPL試験中は不要なものを無効化する。

### `exceeded time limit`

複雑な処理や大量出力で次が出る場合がある。

```text
exceeded time limit
```

最初は処理を複数行に分けて実行する。必要に応じて`SCR_VM_I_COUNT`を調整するが、値を増やす前に処理内容を小さく分割する方がよい。

### `nc`接続後に何も表示されない

確認事項:

```text
SCR_ENABLE=1
SERIAL5_PROTOCOL=28
scripts/repl.luaが存在する
--serial5=tcp:9995:waitを指定している
他のプロセスが9995番ポートを使用していない
```

ポート確認:

```bash
ss -ltnp | grep 9995
```

## 安全上の注意

REPLからは速度指令やTarget設定も実行できる。最初はDisarm状態で、読み取りAPIだけを確認する。

推奨する初期確認:

```lua
vehicle:get_mode()
rangefinder:has_data_orient(0)
rangefinder:distance_orient(0)
vehicle:get_target_location()
vehicle:get_wp_distance_m()
vehicle:get_wp_bearing_deg()
```

実機でREPLを使用する場合は、最初にタイヤを浮かせるなど、機体が移動しない状態で試験する。

## Target復帰調査の判定表

Mission PlannerからFly Toを送信した後、REPLで次を順番に確認する。

```lua
vehicle:get_mode()
vehicle:get_target_location()
vehicle:get_wp_distance_m()
vehicle:get_wp_bearing_deg()
ahrs:get_location()
```

| 確認結果 | 判断 |
| --- | --- |
| `get_target_location()`がLocationを返す | Luaから正式にTarget取得可能 |
| `get_target_location()`が`nil` | Rover側API未実装またはTarget取得不能 |
| 距離と方位が有効 | Guided Target自体はRover内部に存在 |
| 距離と方位も無効 | Fly To未送信、Guided WPでない、またはTarget未設定 |
| Target座標復元可能 | Lua側フォールバック方式を利用可能 |

## 参考

- ArduPilot Lua REPL
  - `libraries/AP_Scripting/applets/repl.lua`
  - `libraries/AP_Scripting/applets/repl.md`
- ArduPilot Lua Scripting API
  - `libraries/AP_Scripting/generator/description/bindings.desc`
- このフォルダの関連資料
  - `../01_RoverSITL前方Rangefinder設定手順.md`
  - `../05_SITL_Luaサンプルスクリプト.md`
  - `../06_SITL用Guided障害物回避Lua_仕組みと動作解説.md`
