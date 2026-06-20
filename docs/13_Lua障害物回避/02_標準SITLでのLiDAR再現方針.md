# 標準ArduRover SITLで前方LiDARを再現する方針

更新日: 2026-06-20

対象: ArduRover 4.6.3、MAVProxy、前方1点Rangefinder、Lua

参照: [rover-gcsのWebots連携ガイド](https://github.com/zorosdrone/rover-gcs/blob/main/docs/webots_setup.md)

## 検討した疑問

Webotsでは目的のシミュレーションを実現できているが、設定方法が複雑である。標準のArduRover SITLとMAVProxyの2Dマップだけで、前方LiDAR相当の距離取得とLua障害物回避の検証を再現できるか。

## 結論

**今回のプロジェクトは、標準のArduRover SITL＋MAVProxyの2Dマップだけで実現可能です。**

Webots環境を完全に再現するわけではありませんが、目的である次の検証には十分です。

* 前方1点LiDAR相当の距離取得
* Luaからの距離監視
* 警戒・減速・停止判定
* センサー喪失時の停止
* 後退・固定方向旋回・再確認からなる状態機械
* 同一条件での反復テスト

ただし、**実車に近い物理挙動や自由な障害物配置まで求める場合はWebotsが必要**です。

---

## Webots環境と標準SITLの置き換え関係

Webotsの技術文書では、距離情報が次の経路を通っています。

```text
WebotsのDistanceSensor
        ↓
DISTANCE_SENSORをUDP 14551へ送信
        ↓
MAVProxy独自モジュール webotsrf
        ↓
SITLのmasterへ再注入
        ↓
RNGFND1_TYPE=10（MAVLink）
        ↓
ArduPilotのRangefinder
```

Webotsで取得した距離は、そのままではSITLに入らないため、独自MAVProxyモジュールで`DISTANCE_SENSOR`を再送しています。これが現在の構成を複雑にしている主要部分です。([GitHub][1])

標準SITLでは、この部分を次のように置き換えられます。

```text
SITL内蔵の仮想ポスト
        ↓
SITL内部の前方測距レイ
        ↓
仮想アナログRangefinder
        ↓
RNGFND1_TYPE=1
        ↓
ArduPilotのRangefinder
        ↓
Lua
```

つまり、Webots、UDP距離送信、`webotsrf.py`、WindowsとWSL間のIP設定、ファイアウォール設定が不要になります。

---

## 実現可能と判断できる根拠

### 1. 標準SITLはアナログRangefinderを公式にサポートしている

ArduPilot公式資料には、SITL内蔵の仮想Rangefinderを次の設定で有効化する手順があります。

```text
SIM_SONAR_SCALE = 10
RNGFND1_TYPE    = 1
RNGFND1_SCALING = 10
RNGFND1_PIN     = 0
```

公式資料では再起動後のRangefinder値をMAVProxyで確認できる。現在のローカル環境では、`graph DISTANCE_SENSOR.current_distance`でcm単位の距離グラフが表示されることを確認済みである。([ArduPilot.org][2])

ArduRover 4.6.3では距離範囲のパラメータ名だけが異なります。

```text
RNGFND1_MIN_CM = 0
RNGFND1_MAX_CM = 5000
```

現在作成されている設定手順は、このバージョン差を正しく分離しています。

---

### 2. Roverでは水平Rangefinderが障害物センサーとして処理される

ArduRover 4.6.3の`SIM_Aircraft.cpp`では、RoverまたはCopterでRangefinderが水平向きの場合、地面までの高度ではなく、障害物までの距離を取得する分岐があります。

```cpp
return sitl->measure_distance_at_angle_bf(
    location,
    sitl->sonar_rot.get() * 45
);
```

コメントでも、水平Rangefinderを「distance to obstacles」として扱う実装だと明示されています。`SIM_SONAR_ROT=0`なら車体前方0度のレイになります。([GitHub][3])

したがって、次の設定の組み合わせは論理的に成立します。

```text
SIM_SONAR_ROT    = 0
RNGFND1_ORIENT   = 0
```

* `SIM_SONAR_ROT=0`：シミュレーター内の測距レイを前方にする
* `RNGFND1_ORIENT=0`：取得したセンサーをArduPilot側でも前方として登録する

---

### 3. 360度LiDAR用の仮想ポストを前方1点レイでも測定できる

公式資料は、360度LiDARを仮想バリア地点で起動し、`post-locations.scr`でポストを表示する方法を説明しています。([ArduPilot.org][2])

ソースコード側では、前方Rangefinderも360度LiDARも、同じ`measure_distance_at_angle_bf()`系の仮想障害物計算を利用します。関数は車両位置から指定角度へレイを伸ばし、ポストとの交差距離を返します。また、`/tmp/post-locations.scr`も同じ処理から生成されます。([GitHub][4])

このため、

```text
360度LiDARを使う地点
＋
標準アナログRangefinder
＋
SIM_SONAR_ROT=0
```

という組み合わせで、前方1点LiDAR相当の試験が成立します。

これは公式Wikiに一連の手順として掲載された構成ではありませんが、**ArduRover 4.6.3の実装上は接続されています**。現在のプロジェクト資料でも、この点は「公式手順」と「ソースから導いた検証手順」を分けて記述できています。

---

### 4. Luaから同じRangefinder値を取得できる

ArduRover 4.6.3のLua APIには、次のメソッドがあります。

```lua
rangefinder:has_data_orient(orientation)
rangefinder:distance_cm_orient(orientation)
```

したがって、前方を表す`0`を指定できます。

```lua
local FRONT = 0

if rangefinder:has_data_orient(FRONT) then
    local distance_cm =
        rangefinder:distance_cm_orient(FRONT)
end
```

APIの存在は4.6.3のLua定義で確認できます。([GitHub][5])

つまり、標準SITLと実機TF-Lunaでは、センサー設定は違ってもLua側の読取り部分を共通化できます。

```text
標準SITL
RNGFND1_TYPE=1
        ↓
distance_cm_orient(0)

実機TF-Luna
RNGFND1_TYPE=20
        ↓
distance_cm_orient(0)
```

これが今回の構成の大きな利点です。

---

## プロジェクトの各フェーズの実現性

| フェーズ         | 実現性 | 判断                            |
| ------------ | --: | ----------------------------- |
| 前方距離の表示      |  高い | 標準SITLとLua APIで直接可能           |
| 距離に応じた状態判定   |  高い | Luaだけで実装可能                    |
| 警戒距離で減速      |  高い | Guided系の走行指令で可能               |
| 停止距離で停止      |  高い | Guided系の速度指令で可能               |
| センサー喪失時の停止   |  高い | `has_data_orient()`とタイムアウトで可能 |
| 一定時間後退       |  高い | 負の速度指令で可能                     |
| 固定方向旋回       |  高い | 旋回レート＋速度指令で可能                 |
| 前方再確認        |  高い | 同じRangefinder値で可能             |
| 左右の安全方向を直接比較 | 不可能 | 前方1点だけでは左右を同時に観測できない          |
| 後退・固定旋回後の前方再確認 |  高い | 新しい進行方向を同じRangefinderで確認できる      |
| 実車の正確な制動距離再現 |  低い | 標準SITLの簡易車両モデルでは不足            |
| 任意形状の障害物配置   |  低い | 内蔵ポストは固定的                     |
| 接触・衝突物理      |  低い | ポストは主に測距計算用                   |

LuaにはRover向けの次のAPIも定義されています。

```lua
vehicle:set_desired_turn_rate_and_speed(turn_rate, speed)
vehicle:set_desired_speed(speed)
vehicle:set_steering_and_throttle(steering, throttle)
```

特に旋回レートと速度の組み合わせは、公式サンプルでもRoverを円運動させる用途に使用されています。([GitHub][5])

---

## 重要な制約

### 1. ポストは「物理的な障害物」とは限らない

標準SITLの内蔵ポストは、測距レイとの交差距離を計算するための仮想物体です。ソースを見る限り、WebotsのSolidノードのように車体との衝突反力を発生させる構造ではありません。

したがって、Luaが停止しなければRoverはポスト位置を通過する可能性があります。

これは今回の目的にはむしろ有用です。

```text
距離が停止閾値以下になった
    ↓
Luaが停止指令を出したか
    ↓
停止位置がポスト位置を越えなかったか
```

という判定をログから行えば、回避ロジックの成否を評価できます。

---

### 2. ポストは連続した壁ではない

内蔵障害物は格子状のポスト群であり、Webotsの壁や箱のような連続面ではありません。前方1点レイは、ポストとポストの間を向くと何も検出しません。現在の手順書もこの制約を試験項目として適切に扱っています。

したがって初期試験では、次の順序がよいです。

1. ポストを真正面に置く
2. 直進して距離が減ることを確認
3. 停止処理を確認
4. 車体角度を少しずつ変えて未検出条件を確認
5. 旋回中に障害物がレイから外れる動作を確認

---

### 3. Acroモードへの直接介入は別問題

距離取得はAcroでも可能ですが、Luaの走行APIがAcroモード内部のスロットルを直接制限できるとは限りません。

`set_desired_turn_rate_and_speed()`はRoverのGuided制御で使われる指令です。ArduPilot本体でも、MAVLinkの旋回レート＋速度指令は`mode_guided`へ渡されています。([GitHub][6])

そのため、最初の制御試験は次の構成に固定するのが安全です。

```text
GUIDEDモード
    ↓
Luaが前方距離を取得
    ↓
Luaが速度・旋回レートを継続送信
    ↓
停止・後退・旋回を実行
```

**Acro操縦をLuaで上書きする試験から始めない方がよい**です。

---

## Webotsを残す範囲

標準SITLへ移行しても、Webots環境を削除する必要はありません。

### 標準SITLで行うもの

* Lua構文・起動確認
* 距離API確認
* 状態遷移確認
* 閾値とヒステリシス確認
* センサー喪失処理
* 停止・後退・旋回コマンド確認
* 20回以上の反復試験
* リグレッションテスト

### Webotsまたは実機で行うもの

* CC-02に近い操舵特性
* タイヤのグリップとスリップ
* 慣性を含む実際の制動距離
* 壁、箱、車両など任意形状の障害物
* 斜め面や複雑な地形
* 接触・衝突
* TF-Luna固有のノイズや欠測
* センサー取付位置・取付角度の影響

Webotsは最初の開発環境ではなく、**標準SITLを通過したコードの上位試験環境**として残すのが合理的です。

---

## 推奨する最終構成

```text
┌──────────────────────────────────┐
│ 第1段階：標準ArduRover SITL       │
│                                  │
│ 内蔵ポスト                       │
│   ↓                              │
│ 前方1点Rangefinder               │
│   ↓                              │
│ Lua状態機械                      │
│   ↓                              │
│ 減速・停止・後退・固定旋回       │
│                                  │
│ 目的：高速な反復・回帰テスト     │
└──────────────────────────────────┘
                  ↓
┌──────────────────────────────────┐
│ 第2段階：Webots                   │
│                                  │
│ 任意障害物・車体物理・衝突       │
│                                  │
│ 目的：複雑なシナリオ確認         │
└──────────────────────────────────┘
                  ↓
┌──────────────────────────────────┐
│ 第3段階：CC-02実機                │
│                                  │
│ Pixhawk 6C Mini＋TF-Luna         │
│                                  │
│ 目的：停止距離と安全性の最終確認 │
└──────────────────────────────────┘
```

## 最終判定

**今回のプロジェクト概要は技術的に成立しています。** 

特に、

```text
SITL内蔵ポスト
→ 前方1点Rangefinder
→ distance_cm_orient(0)
→ Lua状態機械
→ Guidedの速度・旋回指令
```

という主要経路は、ArduRover 4.6.3の実装とAPIから確認できます。

未確認なのは「実現できるか」ではなく、**手順どおりに実行した際に、現在のローカル環境で期待する距離値が出るかという実行確認**です。最初の合否判定は次の3点で十分です。

```text
1. DISTANCE_SENSOR.current_distanceがcm単位で更新される
2. ポストへ接近すると値が減少する
3. Luaのdistance_cm_orient(0)と同じcm値になる
```

この3点を通過すれば、Webotsを使わずにLua障害物回避の主要開発を進められます。

## プロジェクト内の関連資料

- [Lua障害物回避プロジェクト概要](README.md)
- [Rover SITL前方Rangefinder / Lua設定手順](01_RoverSITL前方Rangefinder設定手順.md)

[1]: https://github.com/zorosdrone/rover-gcs/blob/main/docs/webots_setup.md "rover-gcs/docs/webots_setup.md at main · zorosdrone/rover-gcs · GitHub"
[2]: https://ardupilot.org/dev/docs/adding_simulated_devices.html?utm_source=chatgpt.com "Adding Simulated Peripherals to sim_vehicle"
[3]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/SITL/SIM_Aircraft.cpp "ardupilot/libraries/SITL/SIM_Aircraft.cpp at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[4]: https://raw.githubusercontent.com/ArduPilot/ardupilot/Rover-4.6.3/libraries/SITL/SITL.cpp "raw.githubusercontent.com"
[5]: https://raw.githubusercontent.com/ArduPilot/ardupilot/Rover-4.6.3/libraries/AP_Scripting/docs/docs.lua "raw.githubusercontent.com"
[6]: https://github.com/ardupilot/ardupilot/blob/master/Rover/mode.h?utm_source=chatgpt.com "ardupilot/Rover/mode.h at master"
