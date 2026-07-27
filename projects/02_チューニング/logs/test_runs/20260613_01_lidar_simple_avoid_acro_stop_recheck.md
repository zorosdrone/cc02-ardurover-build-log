# 2026-06-13 LiDAR Simple Object Avoidance Acro停止再現確認

## 目的

2026-06-12時点で未確定だった、Acro低速時のLiDAR障害物停止が再現するかを確認する。

## 対象設定

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2.0
AVOID_BACKUP_SPD = 0
RNGFND1_MAX_CM   = 700
```

## 結果

Acro低速で障害物停止の再現を確認した。

## 判断

- Simple Object AvoidanceのAcro低速停止確認は通過。
- `OA_TYPE=0` のSimple Object Avoidanceを採用扱いとする。
- BendyRulerは引き続き保留する。

## 次の作業

1. Compass PreArm警告が再発しないか確認する。
2. Battery実測電圧とMission Planner表示を比較する。
3. Battery failsafeは2026-06-13に設定・動作確認済み。
4. 短距離RTL / SmartRTLを確認する。
5. GCS側Auto-stopは使わない方針で進める。

## 追記待ち

- 実施場所
- 障害物までの停止距離
- 使用パラメータファイル
- BIN / tlog保存先
- Proximity Viewerまたは `PRX` ログ確認結果
