# LuaとC++独自モードの実装判断

更新日: 2026-06-20

対象: CC-02 ArduRover、ArduRover 4.6.3、前方TF-Luna、Lua Scripting

位置づけ: 障害物回避機能をLuaで実装する範囲と、C++独自ドライブモードへ移行する条件を整理する判断資料。

> [!IMPORTANT]
> 現段階ではLua＋GUIDEDで検証を進める。実装時は対象APIをRover 4.6.3のSITLで実行確認し、Acroへ直接介入できる前提では設計しない。

## 結論

**今回の障害物回避ロジック自体はLuaで実現できます。現段階でC++の独自ドライブモード追加は不要です。**

ただし、難しいのはLuaの処理能力ではなく、**ArduRover 4.6.3ではLuaからAcroモードの操縦指令へ自然に割り込めないこと**です。

整理すると次の判断になります。

* **GUIDEDをLuaが操作する方式**：Luaで実現可能
* **Acroの手動操縦を維持し、障害物時だけ速度を上書きする方式**：Luaだけでは不自然
* **「Acro＋独自障害物回避」を正式なモードとして作る**：C++独自モードが適切

---

## Luaで実現できる構成

今回計画している状態機械はLuaで十分書けます。

```text
CLEAR
  ↓ 障害物接近
SLOW
  ↓ 停止距離
STOP
  ↓
BACKUP
  ↓
TURN
  ↓
RECHECK
  ↓ 安全
RESUME

異常時 → FAULT → 停止保持
```

前方Rangefinderから距離を読み、

* 警戒距離で減速
* 停止距離で停止
* 一定時間後退
* 固定方向へ旋回
* 前方を再確認
* 障害物がなければ再開

という処理はLuaで問題ありません。現在のプロジェクト資料の範囲は、LuaのAPIで実装可能です。

問題になるのは、最終的な走行指令をどのモードへ渡すかです。

---

## ArduRover 4.6.3のLua走行APIの制限

主要な走行APIは次の2つです。

```lua
vehicle:set_desired_turn_rate_and_speed(turn_rate, speed)
vehicle:set_steering_and_throttle(steering, throttle)
```

しかし、Rover 4.6.3の実装では、どちらも現在のモードがGUIDEDまたはAUTO内のGUIDEDでなければ`false`を返します。つまり、AcroやManualで直接呼んでも走行指令として受け付けられません。([GitHub][1])

ArduPilot公式のRover用Luaサンプルも、

```lua
vehicle:set_mode(15) -- GUIDED
vehicle:set_desired_turn_rate_and_speed(...)
```

という順序で、まずGUIDEDへ切り替えてから旋回速度と走行速度を送っています。([GitHub][2])

したがってLua版は、実質的に次の構成になります。

```text
RCスティック
    ↓ Luaが読み取る
Lua障害物回避
    ↓
旋回レート・速度へ変換
    ↓
GUIDEDモード
    ↓
Roverの速度・旋回制御
```

見た目は手動操縦でも、内部ではGUIDEDをLuaで操作する「疑似手動モード」です。

---

## Luaで疑似Acroモードを作れるか

作れます。

LuaからRC入力を読みます。

```lua
local steering_pwm = rc:get_pwm(1)
local throttle_pwm = rc:get_pwm(3)
```

それを正規化して、

```text
ステアリング入力 → 目標旋回レート
スロットル入力   → 目標速度
```

へ変換します。

障害物がなければそのままGUIDEDへ送り、障害物があれば速度を制限します。

```text
requested_speed = RCスロットルから計算
limited_speed   = 障害物距離から計算

command_speed = min(requested_speed, limited_speed)
```

その後、

```lua
vehicle:set_desired_turn_rate_and_speed(
    requested_turn_rate,
    command_speed
)
```

を100ms程度の周期で送り続けます。

GUIDED側では、速度・旋回指令が3秒以上更新されなくなると停止する処理が入っています。Luaが停止した場合に永遠に最後の指令で走り続ける構造ではありません。([GitHub][3])

---

## Lua方式の問題点

### 1. Acroそのものではない

AcroモードはC++側の`ModeAcro::update()`で毎周期、

1. パイロットの操舵・スロットルを取得
2. 目標速度と目標旋回レートを計算
3. スロットルコントローラを実行
4. モーターへ出力

という処理を行っています。LuaがAcro内部の`desired_speed`を途中で差し替えるAPIはありません。([GitHub][4])

`vehicle:set_desired_speed()`というAPIもありますが、Roverの基底モードではデフォルトで`false`を返し、Acroはこの関数をオーバーライドしていません。そのため、Acroの目標速度をLuaから変更する用途には使えません。([GitHub][5])

### 2. 実行周期は厳密ではない

Luaスクリプトは低優先度で動作し、指定した100ms周期が厳密に保証されるわけではありません。各スクリプトには実行時間枠がありますが、ハードリアルタイム制御には向きません。([ArduPilot.org][6])

低速Roverで100ms程度の障害物判定なら実用範囲ですが、例えば時速20kmで数十ミリ秒単位の制動判断を行う用途には向きません。

### 3. スクリプトが異常終了する可能性がある

個別スクリプトで実行時エラーが起きると、そのスクリプトは終了します。メモリ不足やLua VMのパニックでは、動作中の全スクリプトが終了する場合があります。([ArduPilot.org][6])

そのため、

* GUIDED指令タイムアウトによる停止
* `SCR_RUN_CHECKSUM`
* センサー更新時刻の監視
* Luaが動作していることの監視
* Native OAへの復帰手段

を用意する必要があります。

---

## C++独自モードが必要になる条件

次の目標ならC++モードを追加する価値があります。

### Acroをそのまま拡張したい

求める挙動が、

```text
通常時：既存Acroと完全に同じ操作感
障害物接近時：前進速度だけ制限
停止後：必要に応じて回避動作
後退操作：操縦者がいつでも実行可能
```

なら、C++で`ModeAcro`を基にした独自モードを作るのが最も自然です。

例えば、

```text
ModeObstacleAcro
```

を作り、Acroの処理へ次を追加します。

```cpp
get_pilot_desired_steering_and_speed(
    desired_steering,
    desired_speed
);

desired_speed =
    obstacle_avoidance.limit_speed(
        desired_speed,
        front_distance
    );

calc_throttle(desired_speed, true);
```

これならRC操作、速度コントローラ、フェイルセーフ、モード切替の構造を維持したまま、障害物距離による速度制限を入れられます。

ArduPilotにはRoverへ新しいドライブモードを追加する公式の開発手順があり、`mode.h`へのモード番号追加、モードクラスの定義、`mode_<name>.cpp`の実装が基本になります。([ArduPilot.org][7])

### 厳密な周期が必要

例えば、

* 50Hz以上で確実に判定
* 制御ループと同じ周期で速度制限
* センサー値を受けた直後に反映
* タイミングのばらつきを最小化

が必要ならC++です。

### ArduPilot内部の情報を直接使いたい

Lua APIで公開されていない、

* Acroの内部目標速度
* スロットルコントローラへの入力
* Native OAが計算した速度上限
* モーター出力直前の制限値
* フェイルセーフの詳細状態
* モード内部状態

へアクセスしたい場合もC++が必要です。

---

## 今回のプロジェクトに適した進め方

### 第1段階：Luaでアルゴリズムを完成させる

標準SITLで次を作ります。

```text
前方Rangefinder
    ↓
距離フィルタ
    ↓
状態機械
    ├ CLEAR
    ├ SLOW
    ├ STOP
    ├ BACKUP
    ├ TURN
    ├ RECHECK
    └ FAULT
    ↓
GUIDED速度・旋回指令
```

これにより、C++のビルドを毎回行わずに、

* 距離閾値
* ヒステリシス
* 確定回数
* 後退時間
* 旋回角度
* タイムアウト
* 再試行回数

を高速に調整できます。現在作成しているSITL前方Rangefinder手順は、この段階に適しています。

### 第2段階：Lua版を実機で低速確認

実機ではGUIDEDに切り替え、RC入力をLua経由で走行指令へ変換します。

この段階で確認するのは、

* Luaの周期で停止が間に合うか
* 操作感が許容できるか
* GUIDED依存が問題になるか
* Lua異常時に安全停止するか

です。

### 第3段階：必要ならC++へ移植

次のどちらかなら、Luaのまま完成でも構いません。

* Luaを有効にした特別な自律回避モードとして使用する
* 低速試験車で、GUIDED内部動作でも問題ない

次を求めるならC++へ移します。

* 通常のAcro操作感を完全に維持
* モードスイッチで選べる正式な独自モード
* LuaやSDカードへ依存しない
* より確実な実行周期
* 製品・常用機能として運用

---

## 判断表

| 目的                |       Lua | C++独自モード |
| ----------------- | --------: | -------: |
| 距離表示              |        最適 |       過剰 |
| 減速・停止ロジック検証       |        最適 |       不要 |
| 後退・固定旋回・再確認       |        可能 |       可能 |
| SITLでの高速な試行錯誤     |        最適 |   ビルドが必要 |
| GUIDEDベースの独自制御    |     適している |       不要 |
| Acroへ直接速度制限を追加    |       不向き |    適している |
| 正式なモードとして選択       | 4.6.3では困難 |    適している |
| 厳密なリアルタイム性        |       不向き |    適している |
| SDカードなしで運用        |     通常は不可 |       可能 |
| ArduPilot内部制御との統合 |      制限あり |   自由度が高い |

## 推奨判断

**最初からC++独自モードを作る必要はありません。**

まずLua＋GUIDEDで、

```text
距離検出
→ 減速
→ 停止
→ 後退
→ 旋回
→ 再確認
```

を完成させるのがよいです。

その結果、最終要件が単なる自律回避ならLuaを継続できます。一方で、最終要件が**「普段はAcroとして手動操縦し、障害物時だけ自然に介入する運転支援モード」**なら、最終的にはC++で`ModeAcro`を派生・複製した独自ドライブモードへ移すのが正解です。

## プロジェクト内の関連資料

- [Lua障害物回避プロジェクト概要](../README.md)
- [Rover SITL前方Rangefinder / 標準OA / Lua設定手順](../01_RoverSITL前方Rangefinder設定手順.md)

[1]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/Rover.cpp "ardupilot/Rover/Rover.cpp at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[2]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_Scripting/examples/rover-set-turn-rate.lua "ardupilot/libraries/AP_Scripting/examples/rover-set-turn-rate.lua at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[3]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode_guided.cpp "ardupilot/Rover/mode_guided.cpp at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[4]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode_acro.cpp "ardupilot/Rover/mode_acro.cpp at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[5]: https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode.h "ardupilot/Rover/mode.h at Rover-4.6.3 · ArduPilot/ardupilot · GitHub"
[6]: https://ardupilot.org/rover/docs/common-lua-scripts.html "Lua Scripts — Rover  documentation"
[7]: https://ardupilot.org/dev/docs/rover-adding-a-new-drive-mode.html "Rover: Adding a New Drive Mode — Dev documentation"
