# HC-SR04左右距離計

CC-02の左右にHC-SR04（2020 NewVersion）を追加し、Pixhawk 6C MiniのGPIOで距離を取得するためのサブプロジェクト。

現時点では**設計・配線計画段階**であり、Echo電圧、実機での距離取得、左右センサー同士の音響干渉は未確認。

## 資料

- [HC-SR04左右距離計の接続と設定](01_HC-SR04左右距離計_接続と設定.md)
- [AUX 6V案／CAN 5V案の比較接続図（PNG）](images/hc-sr04-dual-gpio-wiring.png)
- [AUX 6V案／CAN 5V案の比較接続図（SVG）](images/hc-sr04-dual-gpio-wiring.svg)

## 採用案

- 前方の既設TF-Lunaは `RNGFND1` のまま維持する。
- 左HC-SR04を `RNGFND2`、右HC-SR04を `RNGFND3` とする。
- 信号はPixhawk 6C MiniのAUX1～AUX4をGPIOとして使用する。
- 電源はAUXの `+`（VDD_SERVO、公称6V）と `-`（GND）を使用し、CAN電源ケーブルを不要にする。
- 公称6VはNewVersionの仕様上限5.5Vを超えるが、6V直結の実用例と配線簡素化を優先した実験運用とする。
- Echoは抵抗を入れず、AUX信号端子へ直接接続する。
- HC-SR04は出荷時のGPIOモード（`R4=NC`、`R5=NC`）で使う。
