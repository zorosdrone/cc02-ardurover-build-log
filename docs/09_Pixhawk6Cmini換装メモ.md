# rover-gcs / Pixhawk 6C mini換装メモ

## 現行プロジェクト

- リポジトリ: https://github.com/zorosdrone/rover-gcs
- 現行ローバーは ArduPilot Rover + Pixhawk Pro / Pixhawk 2.4.8系FC を使用中。
- FCを Pixhawk 6C mini へ換装したい。
- GCS開発そのものと、FC換装・車体チューニング記録は分離する。
- `rover-gcs` 側は現行維持とし、FC換装やチューニング記録はこの別リポジトリで管理する。

## 現行FC構成

現行で使用しているのは、画像の以下セット品相当。

- Pixhawk Pro / Pixhawk 2.4.8系クローン
- M8N GPS + Compass
- Power Module
- Safety Button
- Buzzer
- RGB LED / OLED / I2C系ケーブル
- PPMケーブル
- 4P GH1.25 / 6P GH1.25 / 2.54mmピン系ケーブル類
- GPSホルダー等

Pixhawk系は ArduPilot / PX4 で使われるオープンなFCハードウェア標準として展開されており、ArduPilotでは Rover を含む複数車種で使える。

## 換装先

- Pixhawk 6C mini
- GPSは現行M8Nを流用する方針
- 6C mini対応のGPS一体型 Safety / Buzzer / LED モジュールには変更しない方針

## 重要な前提

- アナログ入力は使っていない。
- そのため、Pixhawk 2.4.8系にあったADC入力の移植問題は今回の換装では無視してよい。
- ArduPilotの旧Pixhawk系にはアナログ入力・ADC系の説明があるが、今回は未使用のため対象外。

## 機能的に不可能になるもの

現時点の構成では、Pixhawk 6C miniへの換装でローバー運用上「不可能」になる主要機能は基本なし。

問題になるのは機能差ではなく、主に以下。

- コネクタ形状の違い
- ピン配列の違い
- Buzzer / Safety Button の扱い
- GPSの2股配線の扱い
- PM02への電源・電圧電流監視設定

## GPSの2股について

現行M8N GPSの2股は、ほぼ以下の意味。

1. GPS UART系
   - 5V
   - GND
   - TX
   - RX

2. Compass I2C系
   - 5V
   - GND
   - SDA
   - SCL

つまり、GPS測位はUART、外部コンパスはI2Cで別配線になっている。

Pixhawk 6C miniへ流用する場合は、以下のように考える。

```text
現行M8N GPS
  ├─ GPS UART線
  └─ Compass I2C線
        ↓
  Pixhawk 6C mini の GPS2 6ピンへ変換接続
```

Pixhawk 6C miniの`GPS2`は6ピン対応のため、現行M8NのGPS UARTとCompass I2Cを1本の6ピン変換ケーブルにまとめる方針にする。

```text
GPS2 6ピンで使う信号
  - VCC
  - UART TX
  - UART RX
  - I2C SCL
  - I2C SDA
  - GND
```

注意点:

- コネクタが刺さるかではなく、ピン配列が一致するかを確認する。
- 5V / GND / TX / RX / SDA / SCL の並びを必ず確認する。
- 配列違いのまま接続すると、GPS、コンパス、FCを壊す可能性がある。

## Buzzerポートについて

Pixhawk 6C miniには、旧Pixhawk Pro / 2.4.8系のような独立Buzzerポートがない。

6C mini世代では、Buzzer / Safety Button / LED がGPSモジュール側に統合される構成が一般的。しかし今回はGPSを現行M8Nから変えない方針のため、BuzzerとSafety Buttonは標準構成では使わない前提にする。

## Buzzerが無い場合の代替

Buzzerの役割:

- ARM / DISARM通知
- PreArm error通知
- GPS異常通知
- Battery warning通知
- Failsafe通知
- Mode change通知

代替方針:

1. `rover-gcs` 側で画面表示する
2. PC側で音を鳴らす
3. Raspberry Pi側のGPIOで外付けブザー / LEDを鳴らす案もあるが、初期段階では不要

`rover-gcs` 側で追加・強調したい表示:

- ARMED / DISARMED
- Mode
- GPS fix状態
- Battery voltage
- Failsafe状態
- 最後のSTATUSTEXT
- Auto-stop状態
- 通信断警告

PC側音声通知の候補:

- ARMされたら警告音
- DISARMされたら通知音
- Battery lowで警告音
- GPS no fixで警告
- Failsafeで連続警告
- MAVLink通信断で警告

## Safety Buttonが無い場合の代替

Safety Buttonの役割:

- 起動直後にサーボ / モーター出力を抑止する
- 操作者が押してから出力許可する
- 誤作動防止の物理インターロック

代替方針:

- Safety Buttonを無理に移植しない
- 代わりに ESC / モーター側の物理電源カットを用意する
- RC送信機側にもスロットルカットを設定する
- ArduPilot側の `ARMING_CHECK` を有効にして、安易にARMできないようにする

推奨構成:

```text
バッテリー
  ├─ Pixhawk / 受信機 / Raspberry Pi 系
  └─ ESC / モーター 系
        └─ 物理スイッチ、またはXT60抜き差しで後からON
```

これにより、PixhawkやGCSを先に起動して状態確認し、問題なければESC電源を入れる運用にできる。

ローバー用途では、Safety Buttonよりも「ESC / モーターに物理的に電源が入っていない状態」を作れる方が分かりやすく安全。

## 推奨する起動手順

1. ローバーを台に載せる、または車輪を浮かせる
2. 送信機ON
3. スロットル最低
4. スロットルカットON
5. Pixhawk / Raspberry Pi / GCS側だけ起動
6. GPS、Mode、Battery、RC入力、MAVLink通信を確認
7. DISARMEDであることを確認
8. ESC電源ON
9. 車輪が動かないことを確認
10. ARM
11. 低速でステアリング / スロットル確認
12. 走行開始

## 推奨する終了手順

1. DISARM
2. ESC電源OFF
3. Pixhawk / Raspberry Pi電源OFF
4. 送信機OFF

## ArduPilot側で確認するパラメータ

換装後は旧パラメータの丸コピーではなく、再設定ベースにする。

確認対象:

- `SERVOx_FUNCTION`
  - ステアリング、スロットルの割当確認
- `RCMAP_*`
  - RCチャンネル割当確認
- `SERIALx_PROTOCOL`
  - TELEM / Raspberry Pi / MAVLink接続確認
- `SERIALx_BAUD`
  - 通信速度確認
- `ARMING_CHECK`
  - 原則有効
- `BRD_SAFETYENABLE`
  - Safety Buttonなし運用に合わせて確認
- `BRD_SAFETY_DEFLT`
  - 起動時Safety状態の扱い確認
- `FS_THR_ENABLE`
  - RCフェイルセーフ確認
- `FS_GCS_ENABLE`
  - GCS依存運用なら確認
- `BATT_*`
  - PM02接続後に再確認
- `SERIAL1_PROTOCOL` / `SERIAL1_BAUD`
  - Raspberry Pi / MAVLinkを`TELEM1`へ移す候補
- `SERIAL2_PROTOCOL` / `SERIAL2_BAUD`
  - LiDAR / RangeFinderを`TELEM2`へ移す候補
- `SERIAL4_PROTOCOL` / `SERIAL4_BAUD`
  - Pixhawk 6C Miniでは物理`GPS2`。現行LiDAR設定を丸コピーしない
- Compass calibration
- Accelerometer calibration
- RC calibration

## rover-gcs側で追加したい実装候補

Buzzer / Safety Buttonなし運用を補うため、`rover-gcs` に以下を追加するとよい。

### 優先度高

- ARM状態の大きな表示
- DISARM状態の大きな表示
- MAVLink通信断警告
- Failsafe表示
- Battery low表示
- 最新STATUSTEXT表示
- ARM時のPC側警告音
- Failsafe時のPC側警告音
- 通信断時のPC側警告音

### 優先度中

- 起動前チェックリスト画面
- ESC電源ON確認チェック
- 車輪浮かせ確認チェック
- スロットルカット確認チェック
- DISARM確認チェック

### 優先度低

- Raspberry Pi GPIO経由の外部Buzzer / LED制御
- 車体側ステータスLED
- ログ記録UI

## 配線方針

GPSは現行M8Nを流用。

```text
現行M8N GPS
  ├─ GPS UART
  └─ Compass I2C
        ↓
  Pixhawk 6C mini GPS2 6ピンへ変換
```

Buzzer:

```text
旧Buzzerは使わない。
rover-gcs / PC側警告音で代替。
```

Safety Button:

```text
旧Safety Buttonは使わない。
ESC電源物理カット + RCスロットルカット + ARMING_CHECKで代替。
```

Power Module:

```text
PM02を使用する。
PM02はPixhawk 6C miniとセットで購入したパワーモジュール。
既存Pixhawk 2.4.8Pro側のPower Moduleは流用しない。
換装後にMission Plannerで電圧/電流表示を確認し、BATT_* パラメータを再確認する。
```

LiDAR / RangeFinder:

```text
現行はSERIAL4系。
Pixhawk 6C MiniではSERIAL4が物理GPS2に対応するため、LiDARには使わない。

推奨:
  Raspberry Pi / MAVLink -> TELEM1
  LiDAR / RangeFinder    -> TELEM2
  M8N GPS + Compass      -> GPS2
```

## 結論

- GPSは現行M8Nを流用する。
- M8Nの2股はGPS UARTとCompass I2Cなので、6C mini側では`GPS2` 6ピンへまとめて変換接続する方針。
- LiDAR / RangeFinderは`TELEM2`へ移し、`SERIAL2_PROTOCOL=9`, `SERIAL2_BAUD=115`を候補にする。
- Raspberry Pi / MAVLinkは`TELEM1`へ移し、`SERIAL1_PROTOCOL=2`, `SERIAL1_BAUD=921`を候補にする。
- Buzzerは使わない。
- Buzzerの代替は `rover-gcs` / PC側の警告音と画面警告。
- Safety Buttonも使わない。
- Safety Buttonの代替はESC / モーター電源の物理カット、RCスロットルカット、ArduPilotの `ARMING_CHECK`。
- ローバー用途ではこの代替で実用上問題ない。
- `rover-gcs` 側では、ARM状態、Failsafe、Battery、GPS、STATUSTEXT、通信断の警告表示と音通知を追加するとよい。
