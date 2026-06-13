# 2026-06-13 チューニング終了まとめ

## 結論

2026-06-13の屋外チューニングは終了扱い。

本日の通常運用向け終了版:

```text
params/tuned/20260613_pixhawk6c_rover_tuned_01.param
```

QuikTune直後版:

```text
params/tuned/20260613_06_after_quiktune.param
```

OA_TYPE=1 / BendyRuler実験版:

```text
params/tuned/20260613_08_oa_type1_bendyruler_test.param
```

## 通過扱い

- Manual / Hold / Disarm退避
- RC failsafe
- Acro低速
- Guided低速
- Auto Mission / Waypoint
- RTL短距離
- SmartRTL障害物なし
- LiDAR Simple Object Avoidance
- Guided中の障害物停止
- Battery failsafe
- Rover QuikTune

## 採用方針

- 通常運用は `OA_TYPE=0`。
- 障害物前停止はArduPilot Simple Object Avoidanceを主とする。
- GCS側Auto-stopは不要。
- SmartRTLは障害物なし経路限定。
- RTL / SmartRTL中のLiDAR認識は補助扱いで、停止保証としては扱わない。
- BendyRuler / `OA_TYPE=1` は実験扱い。河原では石や地面反射を拾いやすいため採用しない。

## QuikTune結果

```text
RTun: Tuning DONE
RTun: tuning gains saved
```

主な変更:

```text
ATC_STR_RAT_FF    0.200 -> 0.3646377
ATC_STR_RAT_P     0.200 -> 0.1823188
ATC_STR_RAT_I     0.200 -> 0.1823188
ATC_STR_RAT_FLTD  0.000 -> 2.000
ATC_STR_RAT_FLTT  0.000 -> 2.000
CRUISE_SPEED      2.000 -> 0.9776623
CRUISE_THROTTLE   50.000 -> 45
ATC_SPEED_P       0.200 -> 0.4604364
ATC_SPEED_I       0.200 -> 0.4604364
```

## Battery failsafe

```text
BATT_LOW_VOLT     = 10.8
BATT_CRT_VOLT     = 10.2
BATT_FS_LOW_ACT   = 1    # RTL
BATT_FS_CRT_ACT   = 2    # Hold
```

動作確認成功。

## Object Avoidance

通常運用:

```text
OA_TYPE          = 0
PRX1_TYPE        = 4
AVOID_ENABLE     = 7
AVOID_MARGIN     = 2
AVOID_BACKUP_SPD = 0
RNGFND1_MAX_CM   = 700
```

確認結果:

- Acro低速で障害物停止を確認。
- Guided中に障害物があると停止することを確認。
- `AVOID_ENABLE=0` ではGuided目標へ正しい方向に進むことを確認。

実験版:

```text
OA_TYPE          = 1
OA_BR_LOOKAHEAD  = 2
OA_MARGIN_MAX    = 1
AVOID_MARGIN     = 1
AVOID_BACKUP_SPD = 0.2
RNGFND1_MAX_CM   = 400
```

判断:

- `OA_TYPE=1` は回り込み回避の実験用。
- 河原では石や地面反射の影響が大きく、採用判断しない。
- 前方TF-Luna 1個では横方向の空きは直接見えていない。

## 残注意

- Compass PreArm `Check mag field` が再発する場合がある。
- `ARMING_MAGTHRESH=150` は一時緩和候補だが、方位確認なしで自律系に進まない。
- 長時間走行前にMission Planner電圧表示とテスター実測の差を再確認する。
- QuikTuneを再実行しないときは `Scripting1=Low` を確認する。必要なら `RTUN_ENABLE=0` の通常運用版を別保存する。

## 次回候補

1. 本日の終了版でManual / Hold / Acro低速を短く再確認する。
2. 必要なら `RTUN_ENABLE=0` の通常運用版を保存する。
3. `AVOID_BACKUP_SPD=0.2` の停止後バック確認を平坦地で行う。
4. BendyRulerは石の少ない平坦地でのみ再評価する。
