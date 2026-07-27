# 2026-06-13 Guided障害物停止確認

## 結論

現在のObject Avoidance設定で、Guided mode中に障害物があると停止することを確認した。

## 確認内容

- `AVOID_ENABLE=0` ではGuided目標へ正しい方向に進むことを確認。
- 現在のObject Avoidance有効設定では、Guided mode中に障害物を検知して停止することを確認。
- Sonar Range表示は生きており、RangeFinder入力は有効。

## 判断

- Guided目標、GPS、基本Navigationは大きく破綻していない可能性が高い。
- `AVOID_ENABLE=0` で正しい方向へ進むため、以前の反対方向へ行こうとする挙動はObject Avoidance側の介入、または河原の石・地面反射を障害物として拾った影響の可能性が高い。
- Guided中の障害物「停止」は確認済み。
- 障害物を避けて別方向へ進む「自動回避」は、まだ採用判断しない。

## 運用判断

- 河原のような石が多い場所では、BendyRulerの経路回避評価には向かない。
- 現時点では、障害物ありのGuidedは「停止できる」ことを主な成果とする。
- 自動で回り込ませる確認は、石の少ない平坦地で、逃げ道を明確に作ってから行う。

## 次の候補

停止後に少し下がる挙動を確認する場合:

```text
AVOID_BACKUP_SPD = 0.2
```

Guidedで曲がって避ける確認をする場合:

```text
OA_TYPE         = 1
OA_BR_LOOKAHEAD = 5
OA_MARGIN_MAX   = 2
```

ただし、前方TF-Luna 1個では横方向の空きは直接見えていないため、回り込み成功を前提にしない。

## 保存候補

```text
projects/02_チューニング/logs/test_runs/20260613_07_guided_obstacle_stop_check.md
projects/02_チューニング/params/tuned/20260613_07_after_guided_obstacle_stop_check.param
```
