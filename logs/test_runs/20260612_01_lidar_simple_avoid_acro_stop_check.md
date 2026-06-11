# 2026-06-12 LiDAR Simple Object Avoidance Acro停止確認

## 概要

`OA_TYPE=0` のSimple Object Avoidance設定で、Acro低速前進中に前方障害物の約2m手前で停止または前進抑制されるか確認した。

## 結果

```text
AcroModeでも2mで止まらない
```

## 判断

Simple Object AvoidanceのAcro実走確認は未通過。

RangeFinder単体の距離表示が正常でも、Acro中の前進出力に停止・抑制が入っていない。現時点では、次のどこかで切り分けが必要。

- `RangeFinder1(cm)` は距離変化しているが、Proximity側へ入っていない。
- `PRX1_TYPE=4` が有効になっていない、または再起動後に反映されていない。
- `AVOID_ENABLE=7` が有効になっていない、または別設定で無効化されている。
- 前方障害物がProximity Viewer / PRXログ上で前方障害物として見えていない。
- `RNGFND1_ORIENT=0` またはLiDAR搭載向きが実機の前方と一致していない。
- `AVOID_MARGIN=2.0` と実際の距離表示単位・表示値にずれがある。
- 送信機または補助スイッチでProximity AvoidanceがOFF側になっている可能性。

## 次に確認すること

走行は一旦止め、まず静置またはタイヤ浮かせ状態で以下を確認する。

1. `RangeFinder1(cm)` が0.5m / 1m / 2mで正しく変化する。
2. Mission PlannerのProximity Viewerで、前方に障害物が表示される。
3. DataFlashログに `PRX` 系メッセージが出ている。
4. `PRX1_TYPE=4`、`AVOID_ENABLE=7`、`AVOID_MARGIN=2.0`、`AVOID_BACKUP_SPD=0` が再起動後も残っている。
5. `RNGFND1_ORIENT=0` とLiDARの実搭載向きが一致している。
6. `RCx_OPTION=40` がどこかに割り当てられている場合、そのスイッチがProximity Avoidance ON側になっている。

## 次の方針

Proximity ViewerまたはPRXログで前方障害物が見えるまでは、Acroで障害物へ向けた実走確認を繰り返さない。

まずは以下の静置確認へ戻る。

```text
20260612_02_lidar_proximity_static_check
```

推奨保存名:

```text
logs/test_runs/20260612_02_lidar_proximity_static_check.md
params/tuned/20260612_02_after_lidar_proximity_static_check.param
```
