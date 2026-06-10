# Hardware Assumptions

## 判断ルール

Pixhawk、GPS、Compass、電源モジュール、Serial割当の判断では、一般論をそのまま結論にしない。

必ず次を分けて確認する。

- 一般的なルール
- 製品固有の挙動
- ボード固有のピン配置や実装
- 現在のパラメータ値
- 実際の物理搭載状態
- 最終的な実機検証

表示されている値やデフォルト値だけで、正しいとは判断しない。
また、センサICの軸がモジュールの矢印やケース表示と一致するとも限らない。

最終判断は、方位確認、RC入力確認、センサ値変化、電圧実測、導通・ピン配置確認などの実機テストで行う。

## Holybro IST8310 Compass

Holybro M10 / M9N / M8N系GPSモジュールでIST8310コンパスを使う場合、GPSモジュールの矢印が車体前方を向いていても、ArduPilot側では `COMPASS_ORIENT=6` / `Yaw270` が正しいことがある。

理由は、GPSモジュールの矢印方向と、基板上のIST8310磁気センサの内部軸が一致しない場合があるため。

そのため、次の判断はしない。

```text
GPSモジュールが前向き
-> Orientation=None が必ず正しい
```

代わりに、次の順で確認する。

1. 現在の `COMPASS_ORIENT`、`COMPASS_EXTERNAL`、`COMPASS_USE*`、`COMPASS_PRIO*` を確認する。
2. モジュール名、コンパスIC、メーカー資料、ArduPilot既知事例を確認する。
3. 実際の搭載向き、ケーブル出口、マスト位置を確認する。
4. Compass Calibrationを行う。
5. 車体前方を北 / 東 / 南 / 西へ向け、HUD方位が合うか確認する。

確認目安:

| 車体前方 | HUD方位 |
| --- | --- |
| 北 | 0 deg付近 |
| 東 | 90 deg付近 |
| 南 | 180 deg付近 |
| 西 | 270 deg付近 |

この実方位確認が合っているなら、`Yaw270` のように直感と違う値でも維持する。

## 参考

- Holybro IST8310 Compass Orientation: <https://docs.holybro.com/gps-and-rtk-system/f9p-h-rtk-series/ardupilot-ist8310-compass-orientation>
- ArduPilot wiki issue #3994: <https://github.com/ArduPilot/ardupilot_wiki/issues/3994>
