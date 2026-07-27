# 2026-06-29 SITL Lua Guided回避 再開メモ

更新日: 2026-06-29

> 本書の「現在」「最新」は2026-06-29時点のSITL学習版を指す。実機版を含む現在状況は[プロジェクト概要](../../README.md)を参照する。

対象: Rover SITL、Lua Scripting、前方Rangefinder、Guided回避サンプル

## 2026-06-30 追記

Target復帰できなかった主原因は、Lua状態遷移ではなく、標準Rover側で`vehicle:get_target_location()`がTargetを返せないことと判断した。

対策として、`luaoa_min_guided_avoid.lua`を更新し、Guided WP走行中に次の情報からTarget座標を復元するようにした。

```lua
vehicle:get_wp_distance_m()
vehicle:get_wp_bearing_deg()
ahrs:get_location()
Location:offset_bearing()
```

新しい識別文字列:

```lua
local SCRIPT_VERSION = "20260630-wp-vector-target-v6"
```

期待ログ:

```text
LUAOA: loaded 20260630-wp-vector-target-v6
LUAOA: guided target ready via wp-vector
LUAOA: RECHECK -> RESUME
LUAOA: RESUME -> CLEAR: target restored
```

また、`restore_run_speed()`から`set_desired_turn_rate_and_speed(0, RUN_SPEED_MS)`へのフォールバックを削除した。`set_target_location()`成功直後にTurnRateAndSpeedへ戻してWP制御を解除しないためである。

## 今日の到達点

1番目の監視サンプル `luaoa_rangefinder_watch.lua` は、前方Rangefinderを読み取り、`warn zone` / `stop zone` をGCSへ表示できた。
実行結果画像は次に保存済み。

```text
projects/03_Lua障害物回避/images/sitl-lua-rangefinder-watch-stop-zone.png
```

2番目の回避サンプル `luaoa_min_guided_avoid.lua` は、`SLOW`、`STOP`、`BACKUP`、`TURN`、`RECHECK`、`RESUME` まで状態遷移するところまで確認した。
2026-06-29時点ではTargetへ戻らない問題が残っていたが、2026-06-30にWP距離・方位からTargetを復元する修正を入れた。

## 現在のLua保存元

```text
projects/03_Lua障害物回避/scripts/luaoa_min_guided_avoid.lua
```

現在の識別文字列:

```lua
local SCRIPT_VERSION = "20260630-wp-vector-target-v6"
```

起動時に次のログが出れば、最新Luaが読み込まれている。

```text
LUAOA: loaded 20260630-wp-vector-target-v6
```

## 現在の主な回避パラメータ

```lua
local WARN_M = 8.0
local STOP_M = 4.0
local RESUME_M = 10.0
local REQUIRED_COUNT = 3

local RUN_SPEED_MS = 1.0
local SLOW_SPEED_MS = 0.3
local BACK_SPEED_MS = 0.45
local TURN_SPEED_MS = 0.45
local TURN_RATE_DEG_S = 35

local STOP_HOLD_MS = 1500
local BACK_MS = 4500
local TURN_MS = 4500
local MAX_TRY = 5
```

意図:

- 8 mで減速
- 4 mで停止
- 約2.0 m後退
- 強めに4.5秒旋回
- 前方10 m以上で復帰判定
- 最大5回まで再試行

## 今日分かったこと

`reboot` だけでは、Lua差し替えが確実に反映されないことがあった。
古いLuaが動いているかは、ログと時間差で判別できる。

古い版の兆候:

```text
LUAOA: RESUME -> FAULT: resume speed failed
LUAOA: FAULT resume speed failed
```

または、`BACKUP -> TURN` が約1秒で出る場合。
現在の強化版では `BACK_MS = 4500` なので、`BACKUP -> TURN` は約4.5秒後になるはず。

確実に反映するには、MAVProxyの `reboot` ではなく、`sim_vehicle.py` ごと停止して起動し直す。

## Target復帰に関する現状

2026-06-29時点の問題は、LuaがGuided目標を保存できていないことだった。

原因は、標準Roverでは`vehicle:get_target_location()`がTargetを返せないこと。2026-06-30版では、まず正式APIを試し、失敗した場合はWP距離・方位からTargetを復元する。

```text
LUAOA: guided target ready via wp-vector
```

このログがFly To送信後に出れば、Lua側で復帰Targetを保存できている。

復帰成功時の期待ログ:

```text
LUAOA: RECHECK -> RESUME
LUAOA: RESUME -> CLEAR: target restored
```

Fly To送信後もTarget保存ログが出ない場合は、Target復帰試験へ進まない。

```text
LUAOA: waiting for guided target
```

## 次回の再開手順

WSLで、SITL側へ最新Luaをコピーする。

```bash
cd ~/ardupilot
cp /mnt/c/path/to/cc02-ardurover-build-log/projects/03_Lua障害物回避/scripts/luaoa_min_guided_avoid.lua scripts/
```

読み込まれる予定のファイルを確認する。

```bash
grep -n "SCRIPT_VERSION\|WARN_M\|STOP_M\|RESUME_M\|BACK_MS\|TURN_MS\|set_desired_turn_rate_and_speed(0, RUN_SPEED_MS)" scripts/luaoa_min_guided_avoid.lua
```

期待値:

```text
SCRIPT_VERSION = "20260630-wp-vector-target-v6"
WARN_M = 8.0
STOP_M = 4.0
RESUME_M = 10.0
BACK_MS = 4500
TURN_MS = 4500
```

`set_desired_turn_rate_and_speed(0, RUN_SPEED_MS)` は出ないこと。速度復帰でTurnRateAndSpeedへ戻すフォールバックは削除済み。

試験中は `scripts/` 直下にこのLuaだけ置く。

```bash
ls ~/ardupilot/scripts
```

`ahrs-print-angle-and-rates.lua` など他の `.lua` がある場合は、試験中だけ退避する。

```bash
mkdir -p ~/ardupilot/scripts_disabled
mv ~/ardupilot/scripts/ahrs-print-angle-and-rates.lua ~/ardupilot/scripts_disabled/
```

その後、`sim_vehicle.py` を起動し直す。

```bash
cd ~/ardupilot
Tools/autotest/sim_vehicle.py -v Rover --console --map \
  -l 51.8752066,14.6487840,54.15,0
```

MAVProxyで、仮想ポストと距離表示を出す。

```text
script /tmp/post-locations.scr
module load graph
graph DISTANCE_SENSOR.current_distance
```

起動直後に次を確認する。

```text
LUAOA: loaded 20260630-wp-vector-target-v6
```

Guided目標を送った後、次を確認する。

```text
LUAOA: guided target ready via wp-vector
```

これが出ない場合は、Target復帰確認ではなく、Guided目標、Arm状態、WP距離・方位APIの確認へ戻る。

## 次回の確認観点

- 最新Luaが本当に読み込まれているか
- `BACKUP -> TURN` が約4.5秒後になっているか
- 4 m手前で `STOP` に入るか
- Fly To送信後に `guided target ready via wp-vector` が出るか
- 回避後、`RESUME -> CLEAR: target restored` になるか
- 速度復帰失敗時にTurnRateAndSpeedへ切り替え直さないか
- Mission Planner側に `FAILSAFE InternalError 0x100000` が出る条件を切り分ける

## 関連ファイル

```text
projects/03_Lua障害物回避/05_SITL_Luaサンプルスクリプト.md
projects/03_Lua障害物回避/scripts/luaoa_rangefinder_watch.lua
projects/03_Lua障害物回避/scripts/luaoa_min_guided_avoid.lua
projects/03_Lua障害物回避/images/sitl-lua-rangefinder-watch-stop-zone.png
```
