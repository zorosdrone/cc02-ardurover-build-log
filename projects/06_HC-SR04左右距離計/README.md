# HC-SR04左右距離計

CC-02の左右にHC-SR04（2020 NewVersion）を追加し、Pixhawk 6C MiniのGPIOで距離を取得するためのサブプロジェクト。

現時点では**設計・配線計画段階**であり、Echo電圧、実機での距離取得、左右センサー同士の音響干渉は未確認。

## 資料

- [HC-SR04左右距離計の接続と設定](01_HC-SR04左右距離計_接続と設定.md)
- [接続図（PNG）](images/hc-sr04-dual-gpio-wiring.png)
- [接続図（SVG）](images/hc-sr04-dual-gpio-wiring.svg)

## 採用案

- 前方の既設TF-Lunaは `RNGFND1` のまま維持する。
- 左HC-SR04を `RNGFND2`、右HC-SR04を `RNGFND3` とする。
- 信号はPixhawk 6C MiniのAUX1～AUX4をGPIOとして使用する。
- 電源は未使用のCAN1から5V/GNDだけを分岐する。CAN2を使う場合もピン配置は同じ。
- AUX/MAINの＋はQuicRun WP-1060のBEC由来で公称6Vとなるため、HC-SR04の電源には使わない。
- HC-SR04は出荷時のGPIOモード（`R4=NC`、`R5=NC`）で使う。
