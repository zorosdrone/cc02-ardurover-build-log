# 2026-06-13 Rover QuikTune 事前確認

## 結論

QuikTune準備へ進んでよい。ただし、実走開始前にLua script導入、Circle mode確認、開始/中止操作確認を行う。

## 現在値

対象パラメータ:

```text
params/tuned/20260613_04_after_battery_failsafe_setup.param
```

確認値:

```text
SCR_ENABLE  = 0
CIRC_SPEED  = 0
CIRC_RADIUS = 20
MODE_CH     = 5
MODE1       = 4   # Hold
MODE2       = 4   # Hold
MODE3       = 0   # Manual
MODE4       = 1   # Acro
MODE5       = 4   # Hold
MODE6       = 0   # Manual
RC7_OPTION  = 153
```

## 方針

- `RC7_OPTION=153` は意味が確定するまで変更しない。
- QuikTune開始/中止は、まずMission PlannerのAux Function画面で1行を `Scripting1` に設定して行う。
- RCスイッチでQuikTuneを開始/中止する設定は、後で未使用チャンネルを確認してから行う。
- Circle modeは、最初はMission Plannerから切り替える。送信機側にはManual / Hold退避先を残す。

## 推奨準備設定

```text
SCR_ENABLE = 1
RTUN_ENABLE = 1
CIRC_SPEED = 1.0
CIRC_RADIUS = 5
```

補足:

- `SCR_ENABLE=1` 設定後はFC再起動が必要。
- `rover-quicktune.lua` をSDカードの `APM/scripts` に配置する。
- `CIRC_SPEED=1.0` は低速初回用。速い場合は `0.7` から始める。
- `CIRC_RADIUS=5` でも場所が狭い場合は、QuikTune実走は行わない。

## 実走前チェック

1. `SCR_ENABLE=1` にして再起動する。
2. `rover-quicktune.lua` を `APM/scripts` に配置する。
3. 再起動後、Mission Planner Messagesにscriptエラーがないことを確認する。
4. `RTUN_ENABLE=1` を設定する。
5. Mission PlannerのAux Function画面で、任意の1行を `Scripting1` に設定する。
6. その `Scripting1` 行の `Low` ボタンで停止/待機、`Mid` ボタンで開始できることをタイヤ浮かせまたは非走行状態で確認する。
7. Manual / Hold / Disarmへ即退避できることを確認する。
8. 広い場所でCircle modeに入り、低速で安定して旋回できることを確認してから開始する。

## 中止基準

- Circle半径が狭すぎる、または外へ膨らむ。
- ステアリングやスロットルが大きく振動する。
- Messagesにscriptエラーが出る。
- GPS / EKF / Compass / Battery警告が出る。
- Manual / Hold退避が一瞬でも不安定。

## 保存候補

QuikTune準備後:

```text
params/tuned/20260613_05_before_quiktune.param
```

QuikTune完了後:

```text
params/tuned/20260613_06_after_quiktune.param
logs/test_runs/20260613_06_quiktune_result.md
```
