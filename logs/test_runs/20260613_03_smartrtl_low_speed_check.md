# 2026-06-13 SmartRTL短距離確認

## 目的

短距離でSmartRTLに入り、障害物がない経路で戻れることを確認する。

## 結果

- 障害物がないところではRTL / SmartRTLとも成功した。
- SmartRTL中に障害物へ接触し、タイヤが空回りした状態になった。

## 判断

- SmartRTLの障害物なし経路復帰は通過。
- SmartRTLは障害物がある経路では使わない。
- 障害物接触時の停止・回避手段としてSmartRTLを採用しない。
- 障害物がある状況では、Hold / Manual / Disarmへ即退避する。

## 次の作業

1. Battery failsafeは2026-06-13に設定・動作確認済み。
2. GCS側Auto-stopは使わない方針で進める。
3. 障害物接触時の退避手順を記録する。
4. BendyRulerは必要性が出るまで保留する。

## 追記待ち

- 実施場所
- SmartRTL開始距離
- 障害物接触時のモード
- Hold / Manual / Disarmへの退避結果
- 使用パラメータファイル
- BIN / tlog保存先
