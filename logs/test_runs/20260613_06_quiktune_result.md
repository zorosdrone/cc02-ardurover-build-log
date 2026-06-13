# 2026-06-13 Rover QuikTune結果

## 結論

Rover QuikTuneは完了し、ゲイン保存まで成功。

Mission Planner Messages:

```text
RTun: Tuning DONE
RTun: tuning gains saved
```

## 実行状況

- `rover-quicktune.lua` は読み込み成功。
- Circle走行中に `Scripting1` の `Mid` で開始。
- Steering tune、Speed tuneとも完了。
- 完了後に自動保存された。

## 変更された主な値

```text
ATC_STR_RAT_FLTD  0.000 -> 2.000
ATC_STR_RAT_FLTT  0.000 -> 2.000
ATC_STR_RAT_FF    0.200 -> 0.364
ATC_STR_RAT_P     0.200 -> 0.182
ATC_STR_RAT_I     0.200 -> 0.182

CRUISE_SPEED      2.000 -> 0.977
CRUISE_THROTTLE   50.000 -> 45.015
ATC_SPEED_I       0.200 -> 0.460
```

## Messages抜粋

```text
14:46:58 RTun: starting ATC_STR_RAT tune
14:47:16 RTun: adjusted ATC_STR_RAT_FF 0.200 -> 0.364
14:47:16 RTun: adjusted ATC_STR_RAT_P 0.200 -> 0.182
14:47:16 RTun: adjusted ATC_STR_RAT_I 0.200 -> 0.182
14:47:16 RTun: ATC_STR_RAT_FF tuning done
14:47:20 RTun: starting ATC_SPEED tune
14:47:30 RTun: adjusted CRUISE_SPEED 2.000 -> 0.977
14:47:30 RTun: adjusted CRUISE_THROTTLE 50.000 -> 45.015
14:47:30 RTun: adjusted ATC_SPEED_I 0.200 -> 0.460
14:47:30 RTun: Tuning DONE
14:47:35 RTun: tuning gains saved
```

## 注意点

完了後に以下が出た。

```text
RTun: must be armed and moving to tune
```

これは、QuikTune完了後またはDisarm後も `Scripting1` が `Mid` のままだった可能性が高い。次回は完了後すぐに `Scripting1` 行を `Low` に戻す。

## 判断

- QuikTuneは成功扱い。
- 変更値は採用候補。
- 次回は新しいゲインでManual / Acro低速、Hold停止、Circle安定性を確認する。
- 走行が穏やかであれば、`params/tuned/20260613_06_after_quiktune.param` として保存する。

## 次の確認

1. Mission Plannerで現在パラメータを保存する。
2. `params/tuned/20260613_06_after_quiktune.param` として保存する。
3. `Scripting1` を `Low` に戻す。
4. Manual低速で直進、旋回、停止を確認する。
5. Acro低速で速度追従とTurn Rateが荒くないか確認する。
6. 問題があればQuikTune前パラメータへ戻す。
