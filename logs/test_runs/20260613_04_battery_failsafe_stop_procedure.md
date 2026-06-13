# 2026-06-13 Battery failsafe / 停止手段 確認

## 結論

Battery failsafeの設定と動作確認は成功。

採用設定:

```text
BATT_LOW_VOLT     = 10.8
BATT_CRT_VOLT     = 10.2
BATT_FS_LOW_ACT   = 1    # RTL
BATT_FS_CRT_ACT   = 2    # Hold
```

保存済みパラメータ:

```text
params/tuned/20260613_04_after_battery_failsafe_setup.param
```

判断:

- Low batteryではRTLへ入る設定。
- Critical batteryではHoldへ入る設定。
- SmartRTLは障害物停止保証として扱わないため、Battery failsafe actionには採用しない。
- 実電圧を危険域まで下げる本番同等テストではなく、しきい値を一時的に上げる疑似テストで動作確認した扱い。

## GCS側Auto-stop

GCS側Auto-stopは不要。

判断:

- rover-gcs側から距離しきい値でSTOPを送る機能は採用しない。
- 障害物前停止はArduPilot側Simple Object Avoidanceを主とする。
- 障害物接触時はManual / Hold / Disarmへ即退避する。

## 次の作業

1. 障害物接触時の退避手順を記録する。
2. 必要なら最終採用パラメータを保存する。
3. 長時間走行前に、Mission Planner表示電圧とテスター実測の差を再確認する。

## 確定値

- `BATT_LOW_VOLT=10.8`
- `BATT_CRT_VOLT=10.2`
- `BATT_FS_LOW_ACT=1`
- `BATT_FS_CRT_ACT=2`
- 手動中止目安はLow battery発生時点で走行継続しない。
