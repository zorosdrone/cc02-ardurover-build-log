# SITLから実機移行で起きた問題と再発防止

更新日: 2026-07-26

対象:

- CC-02 Rover
- Pixhawk 6C Mini
- ArduRover 4.6.3
- 前方TF-Luna
- Lua Guided障害物回避

関連ファイル:

- [実機用Lua](Scripts/luaoa_guided_avoid_rover463.lua)
- [実機テスト手順](07_実機テスト手順.md)
- [SITL用Lua](Scripts/luaoa_min_guided_avoid.lua)
- [使用中の実機パラメータ](../../params/04_webapp_ts/20260720_01_webapp_rc1_steering_rc3_throttle.param)

## 結論

SITLで確認できたのは、主にLuaの状態遷移とGuided Targetの保存・復帰ロジックである。
実機で必要になる次の要素までは、SITL成功だけでは保証できなかった。

- 実センサーが「対象なし」「近すぎる」「データなし」をどの値で返すか
- Lua APIへ指令を渡した後、実際にどのPWMが出るか
- ESCがそのPWMを前進、停止、後退のどれとして受け取るか
- 保存済みparamファイルとPixhawk上の実値が一致しているか
- 同時に置かれた別LuaやNative OAが制御へ介入しないか

今回の最大の知見は、次の一文にまとめられる。

> 同じLua状態機械が動くことと、同じ入力が得られ、同じ物理動作が起きることは別である。

次回は、統合回避試験の前に「センサー入力契約」と「アクチュエータ出力契約」を実機で短時間確認する。
統合走行そのものは1回のシンプルな試験でよいが、その前提条件をログで確定してから実施する。

## 今回、想定どおり動いた部分

実機ログでは、次の状態遷移そのものは動作した。

```text
IDLE
  -> CLEAR
  -> SLOW
  -> STOP
  -> BACKUP
  -> TURN
  -> RECHECK
  -> RESUME
  -> CLEAR
```

また、次も確認できた。

- ArduRover 4.6.3でLuaが起動した
- 前方TF-Lunaの正の距離値を取得できた
- `wp-vector`方式でGuided Targetを取得できた
- 3 m付近で減速、2 m付近で停止判定へ入った
- 停止後にBACKUP、TURN、RECHECKへ遷移した
- 前方クリア判定後に元のGuided Targetへ戻った
- 最大試行回数でFAULT停止できた

したがって、SITLで作った状態機械全体が無効だったわけではない。
問題は、状態機械へ入る実機固有の値と、状態機械から出した指令の物理的な結果にあった。

## 実機版の変更履歴から得た知見

| 版 | 主な変更 | 結果／知見 |
| --- | --- | --- |
| v2 | 実機4.6.3用API、段階制御、`RTUN_ENABLE=0`必須 | QuikTune Lua削除後も実機値`1`でFAULT。不要な依存だった |
| v3 | RTUN条件削除、FAULT連打修正、SITL同様の再試行 | 状態機械は進んだが、距離0を障害物として繰り返した |
| v4 | Rangefinder statusをログへ追加 | 対象なしが`0.00 m / st=2`だと実測できた |
| v5 | `0 / st=2`を内部で4 mへ変換 | 制御は通るが、生値0が4 m表示になり観測値と意味が混ざった |
| v6 | 生値0を表示したまま、制御だけ対象なし扱い | 方向性は正しいが、0.01～0.02 mで誤停止した |
| v7 | 後退を負速度から直接スロットル`-0.35`へ変更 | APIとBACKUPログは正常だが物理的に後退しなかった |
| v8 | 後退`-0.70`、Throttle PWMログ追加 | PWMとESC動作を切り分ける診断版。結果確認待ち |

特にv5からv6への変更で、次の原則が明確になった。

> 生の観測値は書き換えず、観測値から判断した意味を別の変数で持つ。

望ましいログ例:

```text
raw_d=0.00 st=2 class=NO_TARGET
```

距離表示を4 mへ置き換えると、後からログを見たときに「センサーが4 mを測った」のか
「Luaが対象なしを4 mへ置換した」のか区別できない。

## SITLでは簡単に動き、実機では動かなかった理由

### 1. SITLは理想化されたセンサー値を返す

SITLのRangefinderでは、仮想障害物までの距離が一貫した単位と状態で返る。
一方、今回のTF-Luna実機では、前方に対象がないときに次の値が観測された。

```text
distance = 0.00 m
status   = 2 (OutOfRangeLow)
```

さらに、対象なしの状態でも次の小さい正値が混ざった。

```text
0.01 m / st=2
0.02 m / st=2
```

ArduPilotのステータス名だけを読むと、`OutOfRangeLow`は「近すぎる」と解釈したくなる。
しかし今回の実機では、「前方に対象がない」場合にも同じステータスとゼロ付近の値が出た。

このため、次のどちらも不十分だった。

- `has_data_orient()`がtrueなら距離をそのまま使う
- 距離が厳密に`0`のときだけ対象なしとする

実機固有の入力契約は、仕様書の値だけではなく、実測した組合せで決める必要がある。

今回の暫定仕様は「0 mを障害物なし」としたが、0.01～0.02 mも観測されている。
次の版では、例えば`st=2`かつゼロ近傍を「対象なし候補」とするデッドバンドを検討する必要がある。
ただし、本当に20 cm未満の障害物を見落とす可能性があるため、値は実機試験で決める。

### 2. ファームウェア世代でLua APIと単位が違う

SITL用の新しいコードでは、距離APIがm単位だった。
ArduRover 4.6.3実機ではcm単位APIを使用する。

| 対象 | API | 単位 |
| --- | --- | --- |
| 新しいSITL | `distance_orient()` | m |
| ArduRover 4.6.3実機 | `distance_cm_orient()` | cm |

状態機械を共通化しても、ハードウェア／ファームウェア依存の読取り層は分離する必要がある。

今回の対策:

- SITL用と4.6.3実機用のLuaを別ファイルにした
- 実機用ではcmからmへの変換箇所を1か所に限定した
- 起動ログへ実機用スクリプトの版を表示した

### 3. APIがtrueを返しても、物理的に動いたとは限らない

当初の後退処理は次だった。

```lua
vehicle:set_desired_turn_rate_and_speed(0, -0.20)
```

ログ上はAPI失敗にならず、BACKUP状態も設定時間継続した。
しかし実車は後退しなかった。

ここでAPIのtrueが意味するのは、指令がGuided制御へ受理されたことである。
次は保証しない。

- 速度コントローラが十分な負スロットルを出した
- 出力PWMがESCのニュートラル帯を越えた
- ESCで後退が有効になっている
- 車輪が実際に逆回転した
- 車体が所定距離を後退した

SITLでは負速度がそのまま理想的な後退運動になる。
実機では、速度制御ゲイン、Feed Forward、PWM範囲、ESCデッドバンド、ESC設定が間に入る。

今回の現行paramには次の特徴がある。

```text
ATC_SPEED_FF   = 0
ATC_SPEED_P    = 0.4604364
ATC_SPEED_I    = 0.4604364
SERVO3_MIN     = 1350
SERVO3_TRIM    = 1500
SERVO3_MAX     = 1750
```

低い負速度を短時間だけ指令した場合、速度制御の出力がESCの後退領域へ届かない可能性がある。

次に直接スロットル`-0.35`へ変更したが、ログ上で指令を繰り返しても後退しなかった。
そのため現行v8では次を行っている。

- 直接スロットルを`-0.70`へ変更
- `SRV_Channels:get_output_pwm(70)`でThrottle機能の実出力PWMを記録

2026-07-26時点では、v8のPWM実測と物理後退結果は未確認である。
解決済みとは扱わない。

判定方法:

| v8ログ | 判断 |
| --- | --- |
| PWMが1500付近 | Pixhawk側で後退PWMになっていない |
| PWMが1500より十分小さく、車輪が動かない | ESCの後退設定、ニュートラル、配線側を確認 |
| PWMが負方向へ変化し、車輪も逆回転 | LuaからESCまでの出力契約は成立 |
| 車輪は逆回転するが車体が動かない | 駆動系、路面、出力不足を確認 |

### 4. 状態名は動作完了を意味しない

次のログは、後退が完了したことを意味するように見える。

```text
LUAOA463: BACKUP -> TURN: backup complete
```

実際に意味していたのは、`BACK_MS`が経過したことだけだった。
移動距離や車輪回転を確認していない。

今後はログを次のように区別する。

- `backup command complete`: 指令時間が終了
- `backup motion confirmed`: 速度、位置または車輪回転で後退を確認

物理フィードバックがない状態で`complete`と記録すると、原因調査を誤りやすい。

### 5. 保存paramとPixhawkの実値が一致していなかった

使用すると指定したparamファイルでは、次の値だった。

```text
RTUN_ENABLE = 0
```

一方、実機ログでは`RTUN_ENABLE=1`としてLuaがFAULTへ入った。

原因は、保存ファイルを確認しただけで、試験直前のPixhawk実値との差分を確定していなかったことである。
さらにQuikTune Luaを削除済みなのに、障害物回避Luaが`RTUN_ENABLE=0`を必須条件にしていた。

対策:

- QuikTune Luaが存在しない場合、障害物回避Luaは`RTUN_ENABLE`へ依存しない
- 試験前にPixhawkからフルパラメータを保存する
- 基準paramとの差分を取る
- 「ファイル上の予定値」と「実機から読んだ現在値」を別欄で記録する

### 6. 別機能との競合をコード条件へ入れすぎた

実機用Luaは当初、QuikTuneやNative OAとの競合を避けるため、多くの起動条件を持った。
その結果、実際には競合しない`RTUN_ENABLE`まで起動拒否条件になった。

競合対策は必要だが、次の2種類を分ける。

| 種類 | 扱い |
| --- | --- |
| 同時に走行出力を出すため必ず競合する | Lua側の起動条件で拒否する |
| 関連ファイルが存在するときだけ競合する | 配置確認と手順で管理する |

今回、`AVOID_ENABLE=0`はNative OAとLuaが同時に走行制御しないための条件として維持した。
一方、QuikTune Lua削除後の`RTUN_ENABLE`は、障害物回避Luaの起動条件から外した。

### 7. SITLと実機で試験スケールが違った

SITLでは広い距離範囲と長い動作時間を使っていた。

```text
BACK_SPEED_MS = 0.45
BACK_MS       = 4500
TURN_RATE     = 35 deg/s
TURN_MS       = 4500
```

実機初期版は大幅に小さくした。

```text
BACK_SPEED_MS = 0.20
BACK_MS       = 1200
TURN_RATE     = 20 deg/s
TURN_MS       = 1200
```

低速化自体は正しいが、後退ではESCデッドバンド、旋回では最低旋回角を下回る可能性がある。
「安全のため小さくする」だけでなく、実機が反応する最小有効値を先に測る必要がある。

### 8. GCSメッセージの長さにも実機差が出た

長い状態遷移メッセージの末尾が、Mission Plannerで単独の`d`として表示された。

```text
LUAOA463: RECHECK -> FAULT: max avoid tries reache
d
```

制御異常ではなく、STATUSTEXTの表示単位による分割だった。
しかし実機試験中の診断を難しくする。

対策:

- 状態名と理由を短くする
- 1行に多くの情報を入れない
- `d=`, `st=`, `pwm=`など短いキーを使う
- 起動版、状態遷移、診断値を別メッセージに分ける

## SITLで確認できること／できないこと

| 項目 | SITLで確認 | 実機確認 |
| --- | --- | --- |
| Lua構文、例外処理 | できる | 起動ログで再確認 |
| 状態遷移 | できる | 同じ遷移になるか確認 |
| 距離閾値のロジック | できる | 実センサー値で再調整 |
| Guided Target保存・復帰 | できる | GPS/EKF条件込みで確認 |
| センサーの対象なし出力 | 通常は再現しない | 必須 |
| 0付近のノイズ | 注入しない限り再現しない | 必須 |
| PWM出力 | 再現しない | 必須 |
| ESCデッドバンド | 再現しない | 必須 |
| ESC後退設定 | 再現しない | 必須 |
| タイヤ、路面、駆動負荷 | 再現しない | 必須 |
| 別Lua／実機param競合 | 条件を作れば確認可能 | 最終確認必須 |

SITLは不要ではない。
状態機械と異常系を高速に反復できる点で有効である。
ただし、実機のセンサーとアクチュエータを理想化したままでは、最後の入出力差を検出できない。

## 次回開発で先に準備するもの

### 1. センサー入力契約表

制御Luaを書く前に、監視だけのLuaで次を記録する。

| 実機条件 | 距離 | status | signal quality | 採用する意味 |
| --- | ---: | ---: | ---: | --- |
| 前方に対象なし | 実測 | 実測 | 実測 | NO_TARGET |
| 板を3 m | 実測 | 実測 | 実測 | VALID |
| 板を1 m | 実測 | 実測 | 実測 | VALID |
| 最小距離未満 | 実測 | 実測 | 実測 | TOO_CLOSEまたはNO_TARGET |
| センサーを切断 | 実測 | 実測 | 実測 | NO_DATA |
| 屋外の黒色／斜面対象 | 実測 | 実測 | 実測 | VALIDまたはUNRELIABLE |

Lua内部では距離だけを返さず、次の意味へ正規化する。

```text
VALID
NO_TARGET
TOO_CLOSE
NO_DATA
UNRELIABLE
```

状態機械は、この正規化後の値だけを見る。

### 2. アクチュエータ出力契約表

統合回避Luaより先に、短い診断LuaまたはManual確認で次を記録する。

| 指令 | API戻り値 | Throttle PWM | 車輪 | 車体 |
| --- | --- | ---: | --- | --- |
| 停止 | 実測 | 実測 | 停止 | 停止 |
| 前進小 | 実測 | 実測 | 前進 | 前進 |
| 後退小 | 実測 | 実測 | 後退／無反応 | 後退／無反応 |
| 後退中 | 実測 | 実測 | 後退 | 後退 |
| 旋回 | 実測 | 実測 | 実測 | 実測 |

最低限、次の対応を確定する。

```text
Lua指令値
  -> Guided内部目標
  -> Throttle PWM
  -> ESC状態
  -> 車輪回転
  -> 車体移動
```

### 3. 実機param差分

試験直前に次を保存する。

```text
YYYYMMDD_HHMM_before_lua_test.param
```

基準paramとの差分で、少なくとも次を確認する。

```text
SCR_ENABLE
SCR_USER1
RTUN_ENABLE
AVOID_ENABLE
AVOID_BACKUP_SPD
RNGFND1_TYPE
RNGFND1_MIN_CM
RNGFND1_MAX_CM
RNGFND1_ORIENT
ATC_SPEED_*
SERVO3_MIN
SERVO3_TRIM
SERVO3_MAX
SERVO3_REVERSED
SERVO3_FUNCTION
WP_SPEED
```

### 4. 配置Lua一覧

試験記録に`APM/scripts`の一覧を残す。

```text
ファイル名
サイズ
更新日時
SHA-256
起動識別文字列
```

パラメータだけでなく、実際に読み込まれたLuaを起動ログで識別する。

### 5. 実機異常値をSITLへ注入する仕組み

今回観測した値をSITLまたはLua単体試験へ入力できるようにする。

最低限のテストケース:

```text
0.00 m / st=2
0.01 m / st=2
0.02 m / st=2
1.5 m / st=4
4 m以上
NoData
APIはtrueだが移動量0
```

標準SITLがESCを再現できない場合でも、Lua状態機械へ疑似入力と疑似出力結果を渡すテストは作れる。

## 次回の最小試験順序

複数の走行フェーズへ細分化する必要はない。
ただし、統合走行前に次の3つだけは独立して確認する。

### 準備A: 距離監視

Disarmのまま30～60秒確認する。

合格条件:

- 対象なしの値とstatusが記録できる
- 1～3 mの板を正しい正値で読める
- 0付近の揺れ幅を記録できる

### 準備B: 後退出力

Manual後退とLua後退のPWMを比較する。

合格条件:

- Manualで物理的に後退できる
- Lua後退中のPWMがManual後退時と同じ側へ動く
- 車輪が逆回転する

Manualで後退できない場合、統合Lua試験へ進まない。
LuaではESC設定や配線を修正できない。

### 統合試験: 障害物回避を1回

次を1回の走行で確認する。

```text
接近
  -> 減速
  -> 停止
  -> 後退
  -> 旋回
  -> 前方再確認
  -> Target復帰
```

状態ログだけでなく、距離、status、Throttle PWM、物理移動を同時に記録する。

## 完了条件を4層に分ける

今後は「動いた」を1つの判定にしない。

| 層 | 完了条件 |
| --- | --- |
| ロジック | 期待した状態遷移になった |
| 指令 | APIが成功し、期待した指令値を保持した |
| 出力 | PWMなど実出力が期待範囲になった |
| 物理 | 車体が期待方向へ移動した |

今回の後退は、ロジックと指令までは通過したが、出力と物理が未確認だった。
この区別を最初からログへ持たせれば、「BACKUPへ入ったのにバックしない」を早い段階で切り分けられる。

## 実装上の推奨構造

次回は状態機械から実機APIを直接呼ばず、次の2層を挟む。

```text
Rangefinder adapter
  raw distance/status/quality
    -> VALID / NO_TARGET / TOO_CLOSE / NO_DATA

Actuator adapter
  desired motion
    -> API result / PWM / observed motion
```

状態機械:

```text
normalized sensor
  -> CLEAR / SLOW / STOP / BACKUP / TURN / RECHECK
  -> desired motion
```

これにより、SITL版と実機版で共通化するのは状態機械だけになる。
センサー値とアクチュエータ出力の差はadapterへ閉じ込められる。

## 現在の未解決事項

2026-07-26終了時点で、次は未解決または未確認である。

1. v8の`back thr=-0.70`時に実際のThrottle PWMがいくつになるか
2. PWMが後退側でもESC／車輪が後退するか
3. Manualモードで現在も後退できるか
4. 対象なし時の0.01～0.02 mをどこまでNO_TARGETとして扱うか
5. 極近距離障害物と対象なしをTF-Luna 1台で区別できるか
6. 後退を時間だけで終了せず、移動確認へ変更するか

これらを確認するまでは、実機Lua障害物回避の後退機能を完成扱いにしない。

## 次回開始時のチェックリスト

- [ ] Pixhawkから試験直前paramを保存した
- [ ] 基準paramとの差分を確認した
- [ ] `APM/scripts`の一覧、サイズ、ハッシュを記録した
- [ ] 起動ログでLua版を確認した
- [ ] 対象なし、1 m、3 m、近距離のRangefinder値を記録した
- [ ] Manual前進、停止、後退を確認した
- [ ] Lua後退中のThrottle PWMを確認した
- [ ] Native OAとLua制御を同時に有効化していない
- [ ] 状態ログと物理動作を別々に判定する
- [ ] 試験後に通常運用paramへ戻した

## 公式参照

- [ArduRover 4.6.3 Lua API](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_Scripting/docs/docs.lua)
- [Rover GuidedのTurnRateAndSpeed／SteeringAndThrottle実装](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode_guided.cpp)
- [ArduPilot Rangefinder backend](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_RangeFinder/AP_RangeFinder_Backend.cpp)
- [Rover RFNDログのstatus定義](https://ardupilot.org/rover/docs/logmessages.html)
