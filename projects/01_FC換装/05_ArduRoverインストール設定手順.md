# ArduRoverインストール設定手順

## 目的

Pixhawk 6C MiniへArduRoverをインストールし、CC-02 Roverとしてベンチ確認できる初期設定まで行う。

この手順では、旧Pixhawk 2.4.8Proのパラメータを丸コピーしない。旧パラメータは参照値として使い、Pixhawk 6C Miniのポート割り当てに合わせて必要項目だけ再設定する。

## 前提

- 対象FC: Holybro Pixhawk 6C Mini Model A (Current)
- Firmware target: `Pixhawk6C`
- Vehicle firmware: ArduRover
- 電源モジュール: PM02
- GPS / Compass: 旧M8Nの`GPS2`流用は中止。Rover向けに追加購入したM10 GPSをGPSモジュールとして採用し、`GPS1` 10ピンへ接続する
- Raspberry Pi / MAVLink: `TELEM1`へ接続済み
- LiDAR / RangeFinder: `TELEM2`へ接続済み
- ステアリング: `MAIN 1`
- ESC / スロットル: `MAIN 3`
- Safety Button / Buzzer: 移植しない

現在のチューニング前ベースラインは `projects/02_チューニング/params/tuned/20260610_before_tune.param`。この手順内の「候補値」は初期設定時の目安であり、現在値は [ArduRoverパラメータ](06_ArduRoverパラメータ.md) を正とする。

## 公式資料

- ArduPilot Mission Planner Loading Firmware: <https://ardupilot.org/planner/docs/common-loading-firmware-onto-pixhawk.html>
- ArduPilot Pixhawk 6C / 6C Mini: <https://ardupilot.org/copter/docs/common-holybro-pixhawk6C.html>
- Holybro Pixhawk 6C Mini Supported Firmware: <https://docs.holybro.com/autopilot/pixhawk-6c-mini/supported-firmware>
- Holybro Pixhawk 6C Mini Ports: <https://docs.holybro.com/autopilot/pixhawk-6c-mini/pixhawk-6c-mini-ports>
- ArduPilot Rover Motor and Servo Connections: <https://ardupilot.org/rover/docs/rover-motor-and-servo-connections.html>
- ArduPilot Rover Motor and Servo Configuration: <https://ardupilot.org/rover/docs/rover-motor-and-servo-configuration.html>
- ArduPilot Rover Arming / Disarming: <https://ardupilot.org/rover/docs/arming-your-rover.html>

## 作業前の安全状態

1. 車体を台に載せ、タイヤを浮かせる。
2. 走行用LiPoを外す。
3. ESC / モーター電源は接続しない。
4. ステアリングサーボとESCは、初回ファーム書き込み時には接続しなくてよい。
5. Pixhawk 6C MiniはUSB-CだけでPCに接続する。
6. Mission Plannerでは、ファーム書き込み前に`CONNECT`しない。

## 1. ArduRoverファームウェアを書き込む

1. Mission Plannerを起動する。
2. Pixhawk 6C MiniをPCのUSBポートへ直接接続する。
   - USBハブは避ける。
3. 右上のCOMポートを選択する。
   - 通常は`AUTO`または認識されたCOMポート。
   - Baudは`115200`でよい。
4. `SETUP` -> `Install Firmware`を開く。
5. `Rover`を選択する。
6. ボード選択が出た場合は`Pixhawk6C`を選ぶ。
   - Pixhawk 6C MiniはPixhawk 6Cと同じFirmware Targetを使う。
7. 画面指示に従い、抜き差し要求が出たらUSBを抜いて差し直す。
8. `erase`、`program`、`verify`、`Upload Done`が完了するまで待つ。
9. 書き込み後、数秒待ってから`CONNECT`する。
10. 接続後、Flight DataまたはMessagesでArduRoverとして起動していることを確認する。

現在確認した安定版の直接URL:

```text
https://firmware.ardupilot.org/Rover/stable/Pixhawk6C/ardurover.apj
```

2026-06-08時点で、上記stableの表示バージョンは`4.6.3-FIRMWARE_VERSION_TYPE_OFFICIAL`。

## 2. 初回パラメータ保存

ArduRover書き込み直後、何も大きく変更する前に保存する。

保存先:

```text
projects/01_FC換装/params/after_fc_replace/YYYYMMDD_pixhawk6c_ardurover_initial.param
```

Mission Planner:

```text
CONFIG / TUNING -> Full Parameter Tree -> Save to File
```

## 3. 最初に設定するポート割り当て

### Serial / UART

| 用途 | 6C Mini物理ポート | ArduPilot Serial | 初期設定候補 | メモ |
| --- | --- | --- | --- | --- |
| Raspberry Pi / MAVLink | `TELEM1` | `SERIAL1` | `SERIAL1_PROTOCOL=2`, `SERIAL1_BAUD=921` | 移行済み。動作確認OK。 |
| LiDAR / RangeFinder | `TELEM2` | `SERIAL2` | `SERIAL2_PROTOCOL=9`, `SERIAL2_BAUD=115` | 移行済み。Mission PlannerでSonar Range表示OK。 |
| M10 GPS | `GPS1` | GPS1系 | `GPS1_TYPE=1` | Rover向けに追加購入済み。2026-06-09、10ピン接続で屋内`Not Fix`、屋外`3D Fix`確認済み。2026-06-12、GPSモジュールとして採用。 |
| 旧M8N GPS | `GPS2` | `SERIAL4` | `SERIAL4_PROTOCOL=5`, `SERIAL4_BAUD=230`候補 | LED点灯後も`No GPS`のため流用中止。履歴としてのみ残す。 |

注意:

- 6C Miniでは`SERIAL4`が物理`GPS2`。
- 現行LiDARの`SERIAL4_PROTOCOL=9`をそのままコピーすると、GPS2と衝突する。
- M10 GPSを`GPS1`へ接続する場合でも、`SERIAL4`はLiDAR用に戻さない。LiDARは`TELEM2`のままにする。
- 1つのUARTにRaspberry PiとLiDARを同時接続しない。

### GPS2 6ピン

この節は旧M8N流用検討時の履歴である。
2026-06-12時点ではRover向けに追加購入したM10 GPSを`GPS1`で採用したため、旧M8Nの`GPS2`流用作業は中止する。

結論:

- 現行M8NのGPS側6ピンコネクタが、標準Pixhawk GPS配列 `VCC / TX / RX / SCL / SDA / GND` と同じなら、Pixhawk 6C Miniの`GPS2`へそのまま挿してGPS UARTの確認ができる。
- ただし、現行M8NのCompass側は別の`I2C`コネクタとして出ているため、GPS側コネクタだけを挿してもCompassまで確認できるとは限らない。
- 最初の確認は「現行GPS側6ピンを`GPS2`へ挿してGPS認識を確認」でよい。
- その後、Compassを使う場合は、現行Compass側I2Cコネクタを6C Miniの独立`I2C`ポートへ挿すか、GPS2 6ピンのI2Cピンへまとめる変換を作る。

| GPS2側 | M8N側 | 注意 |
| --- | --- | --- |
| `VCC` | 5V | GPS側とCompass側の5Vは重複給電にならないよう整理する。 |
| `UART TX` | M8N `RX` | 自作変換ケーブルを作る場合の対応。既製6ピンをそのまま挿す場合は個別に交差配線しない。 |
| `UART RX` | M8N `TX` | 自作変換ケーブルを作る場合の対応。既製6ピンをそのまま挿す場合は個別に交差配線しない。 |
| `I2C SCL` | Compass `SCL` | SCL同士。 |
| `I2C SDA` | Compass `SDA` | SDA同士。 |
| `GND` | GND | GNDは共通化。 |

現行コネクタごとの扱い:

| 現行コネクタ | 現行Pixhawk 2.4.8Pro側 | 6C Miniでの扱い | そのまま刺せるか |
| --- | --- | --- | --- |
| M8N GPS側6ピンコネクタ | `GPS` | まず`GPS2`へ挿してGPS UARTを確認 | 標準Pixhawk GPS配列なら刺せる |
| M8N Compass側I2Cコネクタ | `I2C` | 独立`I2C`へ挿す、または`GPS2` 6ピンのI2Cへまとめる | コネクタ形状とピン順が合えば独立`I2C`へ刺せる可能性あり |

今回の確認順:

1. 現行M8NのGPS側6ピンコネクタを、6C Miniの`GPS2`へ挿す。
2. Mission PlannerでGPSが認識されるか確認する。
3. GPSが認識されれば、GPS UART側の配線はそのまま使える可能性が高い。
4. 次にCompass側I2Cコネクタを6C Miniの独立`I2C`ポートへ挿せるか確認する。
5. Compass側がそのまま刺さらない、またはピン順が合わない場合だけ、I2C変換ケーブルを作る。

整理案:

- 短期: GPS側6ピンは`GPS2`へ、Compass側I2Cは独立`I2C`へ接続する。
- 長期: 配線をすっきりさせたい場合だけ、GPS UART + Compass I2Cを`GPS2` 6ピンへまとめる。

### GPS接続確認

GPS確認は、モーターが動かない状態で行う。
ESC / モーター電源は接続せず、Pixhawk 6C MiniはUSB、またはPM02からFC側だけ給電する。

通電前に確認すること:

1. `GPS2` 6ピンのピン順を公式資料と実物で確認する。
2. `GPS2 VCC`とM8Nの5V、`GPS2 GND`とM8NのGNDが対応している。
3. `GPS2 UART TX`はM8N GPS側`RX`へ接続する。
4. `GPS2 UART RX`はM8N GPS側`TX`へ接続する。
5. `GPS2 I2C SCL`はCompass側`SCL`へ接続する。
6. `GPS2 I2C SDA`はCompass側`SDA`へ接続する。
7. GPS側5VとCompass側5Vを二重に引き回していない。

ここでいう「ピン順を確認」は、Pixhawk 6C Mini本体の仕様を疑うという意味ではない。
6C Mini側`GPS2`のピン順はHolybro公式資料の値を正とする。
確認する対象は、実際に作る変換ケーブル、コネクタの向き、M8N側の線色、GPS側2股ケーブルのどの線がどの信号かである。

手元で確認する方法:

1. Holybro公式資料のJST-GHピン番号図を見て、`GPS2`コネクタのPin 1位置を確認する。
2. 変換ケーブルを挿す向きで、テスターの導通モードを使い、`GPS2`側Pin 1からケーブル先端のどの線へ出ているかを確認する。
3. 同じようにPin 2からPin 6まで、ケーブル先端の対応をメモする。
4. M8N側は、現行Pixhawk 2.4.8ProでGPSポートに刺さっていた線をGPS UART系、I2Cポートに刺さっていた線をCompass I2C系として分ける。
5. M8N側の基板やコネクタに`VCC`、`GND`、`TX`、`RX`、`SCL`、`SDA`の印字があれば、それを優先して確認する。
6. 印字が見えない場合は、元のPixhawk 2.4.8Pro側資料と写真から、どのコネクタがGPS UART系か、どのコネクタがCompass I2C系かを確認する。

現行Pixhawk 2.4.8Pro側の注意:

- `projects/01_FC換装/photos/wiring/20260608_換装前GPSコネクタ_爪下向き確認.JPG` では、現行GPSコネクタの爪/キーは下側に見える。
- そのため、一般的なJST-GHの「爪を上にした図」を現行2.4.8Pro側へそのまま当てはめない。
- 現行で動いていたGPSコネクタの赤線を+5V側、黒線をGND側として扱い、6C Mini側JST-GHのPin 1/Pin 6へ対応させる。
- 旧コネクタを6C Miniへ直接挿すのではなく、6C Mini側はJST-GH 6ピンケーブルを使って変換する。

旧Pixhawk標準GPSポートのピン順:

```text
Pin1 = VCC +5V
Pin2 = TX OUT
Pin3 = RX IN
Pin4 = CAN2 TX / 未使用扱い
Pin5 = CAN2 RX / 未使用扱い
Pin6 = GND
```

現行M8N GPS側の信号としては、FCのTXを受けるPin2がGPS RX、FCのRXへ送るPin3がGPS TXになる。

現行GPS 6ピンケーブルの対応:

```text
赤 = Pin1 +5V
黄 = Pin2 GPS RX
緑 = Pin3 GPS TX
黒 = Pin6 GND
```

6C Mini `GPS2`へGPS単体確認用に接続する場合:

```text
6C Mini GPS2 Pin1 VCC      -> 現行GPS 赤 +5V
6C Mini GPS2 Pin2 UART_TX  -> 現行GPS 黄 GPS RX
6C Mini GPS2 Pin3 UART_RX  -> 現行GPS 緑 GPS TX
6C Mini GPS2 Pin6 GND      -> 現行GPS 黒 GND
```

テスターで電圧を測る場合は、通電後にまず`VCC-GND`間が約5Vであることだけ確認する。
TX/RX/SCL/SDAへテスター棒を当ててショートさせないよう注意する。

Mission Plannerで確認すること:

1. `SERIAL4_PROTOCOL=5`、`SERIAL4_BAUD=230`を設定する。
2. GPS種別はAuto / u-blox系のままにする。
   - GPSが1台だけなら設定対象は`GPS1_TYPE`。
   - 物理ポート`GPS2`へ接続していても、ArduPilot上では1台目GPSなので`GPS1_TYPE=1`でよい。
   - `GPS2_TYPE`または`GPS_TYPE2`は2台目GPS用であり、今回のM8N 1台構成では設定しない。
3. 再起動する。
4. `DATA`画面でGPS状態、衛星数、HDOPを確認する。
5. 屋内で3D Fixしなくても、GPSが認識されて衛星数が増えるかを見る。
6. Compass画面で外部Compassが認識されているか確認する。
7. GPS Fix後、PreArm messageにGPS / Compass関連のエラーが残らないか確認する。

切り分け:

| 症状 | 見る場所 | 主な原因候補 |
| --- | --- | --- |
| GPSが認識されない | `DATA`のGPS表示、MAVLink InspectorのGPS系メッセージ | `SERIAL4_PROTOCOL`、`SERIAL4_BAUD`、`GPS1_TYPE`、GPS2給電、コネクタ向き、TX/RX不一致 |
| GPSは認識されるがFixしない | 衛星数、HDOP、GPS LED | 屋内、アンテナ位置、空が見えない、初回測位待ち |
| GPSは認識されるがCompassが出ない | Compass画面 | SCL/SDA逆、I2C線未接続、外部Compass設定 |
| Compassエラーが出る | PreArm message、Compass画面 | 搭載位置、電源線/ESC/モーターの磁気影響、キャリブレーション未実施 |

2026-06-09:

- M10 GPSを`GPS1` 10ピンへ接続し、Mission Plannerで屋内`Not Fix`、屋外`3D Fix`を確認。
- `Not Fix`はGPS未認識ではなく、GPS認識済みでFix待ちの状態として扱う。
- Compass画面でIST8310系コンパスが見えていることを確認。
- 当時は`Compass not calibrated`表示あり。2026-06-10現在はCompassオフセット値が入っているため、屋外前に`COMPASS_ENABLE=1`へ戻し、搭載位置固定後にPreArmと磁場差を再確認する。

旧M8NのGPS2流用は中止したため、現在の屋外チューニング前確認は、採用M10 GPS / Compassの`GPS1`接続を前提に進める。GPS2 6ピン変換の記述は履歴として残す。

### OLED Module I2C実験

現行Pixhawk Proセット付属のOLED Moduleを6C Miniで試す場合は、GPS/Compassとは分けて、まずOLED単体で独立`I2C`ポートへ接続する。

OLED基板印字:

```text
GND / VCC / SCL / SDA
```

写真上の線色:

```text
GND = 黒
VCC = 赤
SCL = 緑
SDA = 黄
```

6C Mini独立`I2C`:

```text
Pin1 VCC
Pin2 I2C2_SCL
Pin3 I2C2_SDA
Pin4 GND
```

接続:

```text
OLED GND / 黒 -> 6C Mini I2C Pin4 GND
OLED VCC / 赤 -> 6C Mini I2C Pin1 VCC
OLED SCL / 緑 -> 6C Mini I2C Pin2 SCL
OLED SDA / 黄 -> 6C Mini I2C Pin3 SDA
```

Mission Planner:

```text
NTF_DISPLAY_TYPE = 1  # SSD1306
```

表示されない場合:

```text
NTF_DISPLAY_TYPE = 2  # SH1106
```

設定後はFCを再起動する。
`NTF_DISPLAY_TYPE`が存在しない場合、そのファームウェア構成ではオンボードOLED表示が有効でない可能性がある。

## 4. 電源モジュール PM02

Pixhawk 6C Mini公式情報では、Power Monitor 1の候補値は以下。

| パラメータ | 候補値 |
| --- | --- |
| `BATT_MONITOR` | `4` |
| `BATT_VOLT_PIN` | `8` |
| `BATT_CURR_PIN` | `4` |
| `BATT_VOLT_MULT` | `18.182` |
| `BATT_AMP_PERVLT` | `36.364` |
| `BATT_CAPACITY` | `2200` |

設定後に必ず確認する。

1. テスターでLiPo電圧を測る。
2. Mission PlannerのBattery表示と比較する。
3. 0.2V以上ずれる場合はBattery Monitor画面で電圧キャリブレーションする。

2026-06-09の確認:

```text
実測電圧: 12.40V
Mission Planner表示: 12.11V
差分: -0.29V
表示誤差: 約-2.3%
補正係数: 12.40 / 12.11 = 約1.024
```

注意:

- 上記の測定はスモークストッパー使用時の可能性がある。
- スモークストッパー経由の電圧は、保護素子や配線抵抗による電圧降下を含む可能性があるため、PM02の電圧校正根拠にしない。
- `BATT_VOLT_MULT=18.182`は暫定値として扱い、通常給電で再測定してから最終判断する。

スモークストッパーが入っていない通常給電で同じ差が出た場合、`BATT_VOLT_MULT=18.182`からの単純計算の補正候補は以下。

```text
18.182 * 12.40 / 12.11 = 約18.62
```

2026-06-09:

- `BATT_VOLT_MULT=18.182`を実機へ暫定設定済み。
- スモークストッパー使用時の可能性があるため、この値は校正根拠にしない。
- 次に、スモークストッパーを外した通常給電でテスター実測とMission Planner表示を再比較する。
- 再測定後も低めに出る場合だけ、補正を検討する。

スモークストッパーなしの再測定:

```text
実測電圧: 12.40V
Mission Planner表示: 12.44V
差分: +0.04V
表示誤差: 約+0.3%
```

この差は実用上小さいため、当時は`BATT_VOLT_MULT=18.182`のまま追加補正しない判断とした。

2026-06-10現在の `projects/02_チューニング/params/tuned/20260610_before_tune.param` では `BATT_VOLT_MULT=18.62`。走行前に通常給電・テスター実測・Mission Planner表示を再比較し、`18.182`と`18.62`のどちらを採用するか [ArduRoverパラメータ](06_ArduRoverパラメータ.md) と [チューニングログ](../02_チューニング/09_チューニングログ.md) に記録する。
4. 電流表示は低電流では誤差が大きいので、最初は「異常に大きい/ゼロ固定でないか」の確認に留める。

## 5. サーボ / ESC出力

ArduRoverの通常RCカー構成では、ステアリングはOutput 1、スロットルはOutput 3。

| 用途 | 6C Mini出力 | パラメータ | 候補値 |
| --- | --- | --- | --- |
| ステアリング | `MAIN 1` | `SERVO1_FUNCTION` | `26` |
| ESC / スロットル | `MAIN 3` | `SERVO3_FUNCTION` | `70` |

現行値を初期参考にする項目:

| パラメータ | 現行値 | メモ |
| --- | --- | --- |
| `SERVO1_MIN` / `SERVO1_MAX` | `1100` / `1900` | ステアリング範囲。ベンチで再確認。 |
| `SERVO3_MIN` / `SERVO3_MAX` | `1350` / `1750` | ESC範囲。ニュートラルと前後進を再確認。 |
| `RC1_TRIM` | `1490` | ステアリング中立参考。 |
| `RC3_TRIM` | `1510` | 旧スロットルCh3時代の参考値。2026-06-09以降の前進/後進入力はCh2。 |

## 6. RC入力とモード

| 項目 | パラメータ | 候補値 / 方針 |
| --- | --- | --- |
| ステアリング入力 | `RCMAP_ROLL` | `1` |
| スロットル入力 | `RCMAP_THROTTLE` | `2` |
| モードチャンネル | `MODE_CH` | 現在値は`5`。旧記録/初期候補の`8`と混同しない。 |
| 補助スイッチ | `RC7_OPTION` | 現在値`153`。意味が確定するまで変更しない。 |

Mission Planner:

```text
INITIAL SETUP -> Mandatory Hardware -> Radio Calibration
```

### 6.1 プロポ / 受信機を認識させる手順

この段階では、まだRCキャリブレーションを完了させる必要はない。
まずMission Planner上でRC入力バーが動くことだけを確認する。

前提:

- 送信機: RadioLink T8FB BT
- 受信機: RadioLink R8EF V1.6
- 接続方式: SBUS
- R8EF側: `S.BUS / CH1`
- Pixhawk 6C Mini側: `RC IN`

安全前提:

- ESC / モーター電源は入れない。
- ESCを接続済みの場合は、タイヤを浮かせる。
- 送信機のスロットルは中立。
- スロットルカットが使える場合はON。

手順:

1. 送信機 T8FB BT の電源を入れる。
2. スロットルを中立にする。
3. R8EF受信機の `S.BUS / CH1` から Pixhawk 6C Mini の `RC IN` へ接続する。
4. Pixhawk 6C Miniへ給電する。
5. R8EFのLED状態を確認する。
   - SBUS系モードになっていることを確認する。
   - PWM専用モードの場合は、R8EFのモードをSBUS系へ切り替える。
6. Mission PlannerでPixhawkへ接続する。
7. 以下を開く。

```text
INITIAL SETUP -> Mandatory Hardware -> Radio Calibration
```

8. ステアリングを動かし、`Radio 1` または `RC1` のバーが動くことを確認する。
9. スロットルを動かし、`Radio 2` または `RC2` のバーが動くことを確認する。
10. モードスイッチを動かし、現在の `MODE_CH=5` に対応する `Radio 5` / `RC5` のバーが動くことを確認する。旧記録にある `Radio 8` / `RC8` は現在値ではない。

ここまで確認できれば、プロポ / 受信機はPixhawk側に認識されている。

2026-06-09:

- RadioLink R8EF / T8FB BT は Pixhawk 6C Mini `RC IN`で認識OK。
- 次は、`RC1`ステアリング、`RC2`スロットル、`MODE_CH=5`のモードスイッチ割り当て確認とRadio Calibrationを行う。
- RCフェイルセーフ確認は未実施。タイヤを浮かせた状態で別途確認する。

期待する割り当て:

| 操作 | Mission Planner上の入力 | パラメータ |
| --- | --- | --- |
| ステアリング | `RC1` | `RCMAP_ROLL=1` |
| スロットル | `RC2` | `RCMAP_THROTTLE=2` |
| モードスイッチ | `RC5` | `MODE_CH=5` |

認識しない場合:

| 症状 | 確認すること |
| --- | --- |
| RCバーが何も動かない | R8EFがバインド済みか、`S.BUS / CH1`から`RC IN`へ接続しているか、`S / + / -`の向きが正しいか |
| 一部のチャンネルだけ動く | T8FB側のチャンネル割り当て、ミキシング、エンドポイント |
| スロットルが`RC2`以外で動く | `RCMAP_THROTTLE`またはプロポ側チャンネル割り当て |
| ステアリングが`RC1`以外で動く | `RCMAP_ROLL`またはプロポ側チャンネル割り当て |
| プロポOFFでRadio failsafeにならない | T8FB/R8EF側のFail Safe設定、`FS_THR_ENABLE`、`FS_THR_VALUE` |

確認:

- ステアリング操作でRC1が動く。
- スロットル操作でRC2が動く。
- スロットル中立が1500us付近になる。
- 送信機OFFでRCフェイルセーフが発生する。

## 7. 安全設定

Safety Buttonは移植しないため、以下の方針にする。

| 項目 | パラメータ | 候補値 / 方針 |
| --- | --- | --- |
| ARM必須 | `ARMING_REQUIRE` | `1` |
| PreArmチェック | `ARMING_CHECK` | `1`を基本にする |
| Safety Button | `BRD_SAFETY_DEFLT` | `0`候補。Safety Buttonなし運用のため。 |
| RCフェイルセーフ | `FS_THR_ENABLE` | `1`候補 |
| RCフェイルセーフしきい値 | `FS_THR_VALUE` | 現行`910`を参考に再確認 |
| GCSフェイルセーフ | `FS_GCS_ENABLE` | GCS依存運用にするか決めてから設定 |
| DISARM時出力 | `MOT_SAFE_DISARM` | 安全側は`1`候補。ESCの挙動を見て判断。 |

GPS関連のPreArm判断は、`ARMING_CHECK`を有効にしたうえでMission PlannerのPreArm message、GPS fix、EKF状態を確認する。現行パラメータに存在するGPS関連の参照値は、`GPS1_TYPE=1`、`AHRS_GPS_USE=1`、`AHRS_GPS_MINSATS=6`。

室内Manual走行テストでは、磁気環境が悪いため一時的に以下を使う場合がある。

```text
COMPASS_ENABLE = 0
```

これは室内の低速Manual走行確認専用の一時設定とする。
屋外走行、Auto、Guided、RTL、SmartRTL、GPS/EKF評価へ進む前には、`COMPASS_ENABLE=1`へ戻し、M10 GPS/Compassを搭載位置に固定してCompass Calibrationを行う。

物理安全策:

- ESC / モーター電源を後入れにする。
- RC送信機側にスロットルカットを設定する。
- 初回ARM確認は必ずタイヤを浮かせる。

## 8. LiDAR / RangeFinder

推奨:

```text
LiDAR -> TELEM2
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD = 115
RNGFND1_TYPE = 20
RNGFND1_MIN_CM = 20
RNGFND1_MAX_CM = 200
RNGFND1_SCALING = 3
```

2026-06-10現在の `projects/02_チューニング/params/tuned/20260610_before_tune.param` では `RNGFND1_MAX_CM=700`。`200`はAuto-stop最大閾値`100cm`を十分カバーする候補値、`700`は現在値として扱う。どちらを採用するかは、実測距離、GCS表示、屋外反射条件、Auto-stop閾値で判断する。

### TF-Luna 6ピンコネクタ

6C Mini側は`TELEM2`用JST-GH 6ピンを作る。
TF-LunaはUART接続のため、`TELEM2`のCTS/RTSは使わない。

TF-Luna公式ユーザーマニュアル上のUARTピン:

```text
No.1 = +5V
No.2 = RXD / SDA
No.3 = TXD / SCL
No.4 = GND
```

`TF-Luna User Manual.pdf` の `6.1 Description about Line Sequence and Connection` / `Table 6` は、ピン番号と機能を定義しており、線色は定義していない。
BenewakeのQuick Implementation系資料には `1=Red/+5V`, `2=White/RXD-SDA`, `3=Green/TXD-SCL`, `4=Black/GND` の色表記があるが、実作業では線色ではなくピン番号と導通確認を優先する。

今回の現物ケーブル色:

TF-Luna本体を正面、レンズを上、コネクタを手前、線を下に見た状態で、左から以下の並びとする。
最新の接写写真では、TF-Lunaコネクタを左から `赤 / 青 / 黄 / 緑 / 白 / 黒` と目視判別できる。
ただし、最終結線では色だけでなく、TF-Lunaコネクタのピン番号と導通確認を優先する。

```text
No.1 = 赤 = +5V
No.2 = 青 = RXD / SDA
No.3 = 黄 = TXD / SCL
No.4 = 緑 = GND
No.5 = 白 = Configuration Input
No.6 = 黒 = Multiplexing Output
```

接続:

```text
6C Mini TELEM2 Pin1 VCC  -> TF-Luna No.1 赤 +5V
6C Mini TELEM2 Pin2 TX   -> TF-Luna No.2 青 RXD
6C Mini TELEM2 Pin3 RX   -> TF-Luna No.3 黄 TXD
6C Mini TELEM2 Pin4 CTS  -> 未接続
6C Mini TELEM2 Pin5 RTS  -> 未接続
6C Mini TELEM2 Pin6 GND  -> TF-Luna No.4 緑 GND
```

6C Mini側JST-GH 6ピンの推奨線色:

```text
Pin1 VCC  = 赤
Pin2 TX   = 青
Pin3 RX   = 黄
Pin4 CTS  = 未使用
Pin5 RTS  = 未使用
Pin6 GND  = 緑、または黒
```

TF-Luna現物では緑が`GND`なので、緑をTX/RXに使うと混乱しやすい。
TX/RXは、接続先のTF-Luna側の色に合わせて、`TX=青`, `RX=黄` とする。

注意:

- TF-LunaのConfiguration Input線、現物色では白線はGNDへ接続しない。
- Configuration InputをGNDへ落とすとI2Cモードになるため、UART確認では未接続にする。
- TF-LunaのMultiplexing Output線、現物色では黒線は今回未使用。
- 通電前に`VCC-GND`ショートがないことを確認する。
- 通電後、TF-Luna側に5Vが来ていることを確認してからMission Plannerで距離値を見る。

`RNGFND1_MAX_CM=200`は換装前の現行値であり、rover-gcsのAuto-stop閾値範囲 `40 / 60 / 80 / 100cm` を十分にカバーする。ただし2026-06-10現在値は`700`のため、通常設定として`200`へ戻すか、屋外実測のため`700`を維持するかを記録してから変更する。

`700`はデフォルト相当の広い確認値としては使えるが、この機体のAuto-stop運用では遠距離値を拾う必要が薄いため、必要な場合だけ一時的な動作確認値として使う。

確認:

- Mission PlannerでRangeFinder距離値が変化する。
- `20cm`から`200cm`程度の範囲で値が破綻しない。
- rover-gcsのAuto-stop表示と停止動作は、換装後に別途確認する。

Mission Plannerでの動作確認:

1. `CONFIG` / `Full Parameter Tree`で以下を設定する。

```text
SERIAL2_PROTOCOL = 9
SERIAL2_BAUD = 115
RNGFND1_TYPE = 20
RNGFND1_MIN_CM = 20
RNGFND1_MAX_CM = 200
RNGFND1_SCALING = 3
```

2. 設定を書き込み、Pixhawkを再起動する。
3. `DATA`画面を開く。
4. `Status`タブを開く。
5. `sonarrange`、`rangefinder1`、`rngfnd1`、`dist1`のようなRangeFinder系項目を探す。
6. TF-Lunaの前に手や板を置き、距離値が変化するか確認する。
7. `Messages`にRangeFinder、Serial、PreArm関連のエラーが出ていないか確認する。

値が出ない場合:

1. TF-Luna本体に5Vが来ているか確認する。
2. `SERIAL2_PROTOCOL=9`、`SERIAL2_BAUD=115`になっているか確認する。
3. `TELEM2 TX -> TF-Luna RXD`、`TELEM2 RX <- TF-Luna TXD`が逆になっていないか確認する。
4. 白線Configuration InputがGNDへ落ちていないか確認する。
5. `Status`タブに表示項目が見つからない場合は、`MAVLink Inspector`で`DISTANCE_SENSOR`メッセージを探す。

## 9. パラメータ設定後のセンサーキャリブレーション

センサーキャリブレーションは、Serial、PM02、RC、Safety、LiDAR / RangeFinderの初期パラメータを設定した後に実施する。

前提として、Pixhawk 6C Miniはローバーへ組み込むか、少なくとも実際の搭載位置・搭載向きで仮固定した状態で行う。
特にAccelとCompassは、FCの向き、GPS/Compassの位置、電源線・ESC線・モーター周辺の磁気環境に影響されるため、机上で裸のFCだけをキャリブレーションしてから搭載する運用は避ける。

この段階では、GPS/Compass、受信機、PM02、LiDAR、Raspberry Pi接続は実運用に近い配線状態にしてよい。
ただし、ESC / モーター電源はまだ入れず、サーボ・ESC出力確認の段階まで物理的に切っておく。

搭載位置、FCの向き、GPS/Compassの位置、主要な電源線の取り回しを変更した場合は、Accel CalibrationとCompass Calibrationをやり直す。GPS/Compassマストの長さを変えた場合も、磁気環境と機体上の相対位置が変わるためCompass Calibrationをやり直す。

Mission PlannerのMandatory Hardwareで実施する。

### マスト長変更後のCompass Calibration

2026-06-10時点のベースライン `projects/02_チューニング/params/tuned/20260610_before_tune.param` では、室内Manualテスト用に `COMPASS_ENABLE=0` が入っている。このままではMission PlannerのCompass画面で `Start` を押しても校正が進まないことがある。Compass Calibrationを行う前に、いったんCompassとGPSを屋外用の状態へ戻す。

#### 作業前に保存する

Mission Plannerで現在値を保存する。

```text
projects/02_チューニング/params/tuned/20260610_before_compass_mast_cal.param
```

記録するもの:

- 変更前マスト長:
- 変更後マスト長:
- M10 GPS / Compassの向き:
- M10 GPS / Compassの固定方法:
- 周囲の磁気影響になりそうなもの:
- 使用した開始パラメータ:

#### Full Parameter Listで確認する

Mission Plannerの表示名により `GPS_TYPE` と出る場合があるが、この機体の `.param` では `GPS1_TYPE` を確認する。

```text
COMPASS_ENABLE
COMPASS_USE
COMPASS_USE2
COMPASS_USE3
COMPASS_PRIO1_ID
COMPASS_EXTERNAL
COMPASS_ORIENT
GPS1_TYPE
GPS2_TYPE
```

Compass Calibration前の復帰値:

```text
COMPASS_ENABLE = 1
COMPASS_USE = 1
GPS1_TYPE = 1
```

この機体はRover向けに追加購入したM10 GPS / Compass 1台を使う前提なので、複数Compassを使わない場合は以下のままでよい。

```text
COMPASS_USE2 = 0
COMPASS_USE3 = 0
GPS2_TYPE = 0
```

`IST8310` がCompass画面に見えていることを確認する。`External` が未チェックに見える場合は、まず `COMPASS_ENABLE=1` に戻して再起動し、Compass Priority、External判定、Orientation表示を確認する。`COMPASS_EXTERNAL` や `COMPASS_ORIENT` は画面表示と実機の搭載向きが合っているかを確認し、むやみに変更しない。

#### 校正手順

1. `COMPASS_ENABLE=1`、`COMPASS_USE=1`、`GPS1_TYPE=1` を設定する。
2. `Write Params` を押す。
3. 送信機・受信機を有効化し、Mission PlannerのMessagesで `Radio failsafe on` が消えていることを確認する。
4. Pixhawkを再起動する。
   - Mission Plannerの `Preflight_Reboot_Shutdown` が効かない、または反応しにくい場合は、まずRadio failsafe状態を確認する。
   - 送信機・受信機を有効化してRadio failsafeを解除すると、Mission Plannerから再起動できることを確認済み。
5. Mission Plannerへ再接続する。
6. `INITIAL SETUP -> Mandatory Hardware -> Compass` を開く。
7. `IST8310` が表示されていることを確認する。
8. `Use Compass 1` がチェックされていることを確認する。
9. GPS/Compassを変更後のマスト長、実搭載位置、実搭載向きで固定する。
10. 金属机、PC、工具、バッテリー、大電流線、ESC、モーターからできるだけ離す。
11. `Start` を押す。
12. 機体を前後左右上下に向けながらゆっくり回す。
13. 成功したら、Radio failsafeが解除されていることを確認してから再起動する。
14. 再接続後、PreArm、EKF、GPS、Compass関連メッセージを確認する。

#### 校正後に保存する

成功後、以下の名前で保存する。

```text
projects/02_チューニング/params/tuned/20260610_after_compass_mast_cal.param
```

記録する差分:

- `COMPASS_ENABLE`
- `COMPASS_USE*`
- `COMPASS_PRIO*`
- `COMPASS_EXTERNAL`
- `COMPASS_ORIENT`
- `COMPASS_OFS_*`
- `COMPASS_DIA_*`
- `COMPASS_ODI_*`
- `COMPASS_SCALE`
- `GPS1_TYPE`
- PreArm結果
- Mission Planner Compass画面の表示名、External、Orientation

屋外用・自律走行用へ進む場合は、以下を維持する。

```text
COMPASS_ENABLE = 1
GPS1_TYPE = 1
ARMING_CHECK = 1
```

室内Manual走行テストだけへ戻す場合に限り、別ファイルへ保存したうえで `COMPASS_ENABLE=0` に戻してよい。ただし、その状態のまま屋外、Auto、Guided、RTL、SmartRTL、Compass Calibrationへ進まない。

1. Accel Calibration
   - FCを実際の搭載向きで固定してから行う。
2. Compass Calibration
   - M10 GPS内蔵Compassを使う。
   - Mission PlannerのCompass PriorityでIST8310系Compassが見えていることを確認済み。
   - 内蔵Compassが干渉する場合は、使用コンパスを外部M10側優先にする。
   - GPS/Compassも実際の搭載位置、またはそれに近い仮固定状態で行う。
   - 室内Manual走行テストで`COMPASS_ENABLE=0`にした場合は、屋外/自律系確認前に`COMPASS_ENABLE=1`へ戻してから行う。
3. Radio Calibration
   - 受信機と送信機の接続確認後に行う。これはFCの搭載向きには依存しない。
4. Servo Output確認
5. Battery Monitor確認
6. RangeFinder確認

## 10. ベンチテスト順序

1. USBのみでMission Planner接続。
2. ファームウェア、ボード、ArduRover起動を確認。
3. PM02のみ接続し、電圧表示を確認。
4. RC受信機を接続し、Radio Calibration。
5. 採用M10 GPSを`GPS1`へ接続し、GPS fixとCompass認識を確認。
6. TELEM1へRaspberry Piを接続し、MAVLink通信を確認。
7. TELEM2へLiDARを接続し、RangeFinder値を確認。
8. ステアリングサーボを`MAIN 1`へ接続し、出力方向を確認。
9. ESC信号線を`MAIN 3`へ接続する。
10. まだ走行用LiPoは接続しない。
11. タイヤを浮かせる。
12. ESC電源を入れる。
13. DISARM状態で車輪が動かないことを確認。
14. ARMする。
15. 低スロットルで前進/後退/中立を確認。
16. DISARMする。
17. ESC電源を切る。

## 11. 初回設定後の保存

初回ベンチ確認が通ったら、パラメータを保存する。

```text
projects/01_FC換装/params/after_fc_replace/YYYYMMDD_pixhawk6c_bench_ok.param
```

同時に、以下を記録する。

- ArduRoverバージョン
- Mission Plannerバージョン
- 使用したFirmware target
- 接続したポート
- 変更したパラメータ
- ベンチ確認結果

## 12. まだ走行しない条件

以下のどれかが残る場合は走行しない。

- 使用するGPSの3D Fixが確認できていない
- 屋外試験前に`COMPASS_ENABLE=1`へ戻していない
- Compass calibrationまたはPreArm確認が未完了
- RC failsafe未確認
- DISARM時のESC挙動が不明
- ステアリング方向が逆
- スロットル中立が不安定
- Battery voltage表示が実測と大きく違う
- LiDAR値が不安定
- rover-gcs / Mission PlannerでARM状態が確認できない
