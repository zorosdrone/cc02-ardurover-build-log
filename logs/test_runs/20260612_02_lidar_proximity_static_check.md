# 2026-06-12 LiDAR Proximity静置確認

## 状況

`20260612_01_lidar_simple_avoid_acro_stop_check` で、AcroModeでも2m付近で停止しなかった。

その後、パラメータを確認したところ、実走時点では以下だった。

```text
PRX1_TYPE = 0
```

このため、前方LiDARはRangeFinder単体としては動いていたが、Simple Object Avoidance用のProximity入力としては有効化されていなかった可能性が高い。

## 追加確認結果

`PRX1_TYPE=4` に変更したところ、距離表示をしなくなった。

```text
PRX1_TYPE = 0
→ RangeFinder距離表示あり

PRX1_TYPE = 4
→ 距離表示なし
```

## 判断

- Acroで2m停止しなかった直接原因は、少なくとも実走時点で `PRX1_TYPE=0` だったことが大きい。
- ただし、`PRX1_TYPE=4` にすると距離表示が消えるため、そのまま実走再試験には進まない。
- `PRX1_TYPE=4` でRangeFinder表示が消えた場合でも、Proximity ViewerまたはDataFlashの `PRX` に前方障害物が出ていれば、Proximity側へ変換されている可能性がある。
- Proximity Viewer / `PRX` にも出ない場合は、`PRX1_TYPE=4` がこの構成のTF-Luna RangeFinder入力と噛み合っていない可能性が高い。

## 次に確認すること

安全のため、走行テストはまだ行わない。

1. `PRX1_TYPE=0` に戻し、`RangeFinder1(cm)` または `sonarrange` が0.5m / 1m / 2mで変化することを確認する。
2. `PRX1_TYPE=4` に変更し、FCを再起動する。
3. `RangeFinder1(cm)` 表示が消えても、Mission PlannerのProximity Viewerで前方障害物が出るか確認する。
4. Armまたは `LOG_DISARMED=1` でログを残し、DataFlashに `PRX` メッセージが出るか確認する。
5. Proximity Viewer / `PRX` のどちらにも出ない場合は、`PRX1_TYPE=0` に戻してRangeFinder単体運用へ戻る。

## 保留すること

```text
Acroで障害物停止再試験
OA_TYPE=1
BendyRuler
Auto / Guidedでの障害物回避
高速走行
```
