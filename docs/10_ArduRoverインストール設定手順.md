# ArduRoverインストール設定手順

## 目的

Pixhawk 6C MiniへArduRoverをインストールし、CC-02 Roverとしてベンチ確認できる初期設定まで行う。

この手順では、旧Pixhawk 2.4.8Proのパラメータを丸コピーしない。旧パラメータは参照値として使い、Pixhawk 6C Miniのポート割り当てに合わせて必要項目だけ再設定する。

## 前提

- 対象FC: Holybro Pixhawk 6C Mini Model A (Current)
- Firmware target: `Pixhawk6C`
- Vehicle firmware: ArduRover
- 電源モジュール: PM02
- GPS / Compass: 現行M8Nを流用し、`GPS2` 6ピンへまとめる
- Raspberry Pi / MAVLink: `TELEM1`へ接続する候補
- LiDAR / RangeFinder: `TELEM2`へ接続する候補
- ステアリング: `MAIN 1`
- ESC / スロットル: `MAIN 3`
- Safety Button / Buzzer: 移植しない

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
params/after_fc_replace/YYYYMMDD_pixhawk6c_ardurover_initial.param
```

Mission Planner:

```text
CONFIG / TUNING -> Full Parameter Tree -> Save to File
```

## 3. 最初に設定するポート割り当て

### Serial / UART

| 用途 | 6C Mini物理ポート | ArduPilot Serial | 初期設定候補 | メモ |
| --- | --- | --- | --- | --- |
| Raspberry Pi / MAVLink | `TELEM1` | `SERIAL1` | `SERIAL1_PROTOCOL=2`, `SERIAL1_BAUD=921` | 現行の高速MAVLink接続を移す候補。 |
| LiDAR / RangeFinder | `TELEM2` | `SERIAL2` | `SERIAL2_PROTOCOL=9`, `SERIAL2_BAUD=115` | 現行`SERIAL4_PROTOCOL=9`をここへ移す。 |
| M8N GPS | `GPS2` | `SERIAL4` | `SERIAL4_PROTOCOL=5`, `SERIAL4_BAUD=230` | 現行GPS baud `230`を参照。 |
| 未使用GPS1 | `GPS1` | `SERIAL3` | 必要になるまで変更しない | `GPS1`はSafety/Buzzer系も含むため今回は優先しない。 |

注意:

- 6C Miniでは`SERIAL4`が物理`GPS2`。
- 現行LiDARの`SERIAL4_PROTOCOL=9`をそのままコピーすると、GPS2と衝突する。
- 1つのUARTにRaspberry PiとLiDARを同時接続しない。

### GPS2 6ピン

| GPS2側 | M8N側 | 注意 |
| --- | --- | --- |
| `VCC` | 5V | GPS側とCompass側の5Vは重複給電にならないよう整理する。 |
| `UART TX` | M8N `RX` | TX/RXは交差。 |
| `UART RX` | M8N `TX` | TX/RXは交差。 |
| `I2C SCL` | Compass `SCL` | SCL同士。 |
| `I2C SDA` | Compass `SDA` | SDA同士。 |
| `GND` | GND | GNDは共通化。 |

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
| `RC3_TRIM` | `1510` | スロットル中立参考。 |

## 6. RC入力とモード

| 項目 | パラメータ | 候補値 / 方針 |
| --- | --- | --- |
| ステアリング入力 | `RCMAP_ROLL` | `1` |
| スロットル入力 | `RCMAP_THROTTLE` | `3` |
| モードチャンネル | `MODE_CH` | `8` |
| 補助スイッチ | `RC7_OPTION` | 現行`153`を維持候補。実機スイッチで再確認。 |

Mission Planner:

```text
INITIAL SETUP -> Mandatory Hardware -> Radio Calibration
```

確認:

- ステアリング操作でRC1が動く。
- スロットル操作でRC3が動く。
- スロットル中立が1500us付近になる。
- 送信機OFFでRCフェイルセーフが発生する。

## 7. 安全設定

Safety Buttonは移植しないため、以下の方針にする。

| 項目 | パラメータ | 候補値 / 方針 |
| --- | --- | --- |
| ARM必須 | `ARMING_REQUIRE` | `1` |
| PreArmチェック | `ARMING_CHECK` | `1`を基本にする |
| Safety Button | `BRD_SAFETY_DEFLT` | `0`候補。Safety Buttonなし運用のため。 |
| GPS要求 | `ARMING_NEED_LOC` | Guided / Autoを使うなら`1`候補 |
| RCフェイルセーフ | `FS_THR_ENABLE` | `1`候補 |
| RCフェイルセーフしきい値 | `FS_THR_VALUE` | 現行`910`を参考に再確認 |
| GCSフェイルセーフ | `FS_GCS_ENABLE` | GCS依存運用にするか決めてから設定 |
| DISARM時出力 | `MOT_SAFE_DISARM` | 安全側は`1`候補。ESCの挙動を見て判断。 |

物理安全策:

- ESC / モーター電源を後入れにする。
- RC送信機側にスロットルカットを設定する。
- 初回ARM確認は必ずタイヤを浮かせる。

## 8. センサーキャリブレーション

Mission PlannerのMandatory Hardwareで実施する。

1. Accel Calibration
2. Compass Calibration
   - 外部M8N Compassを使う。
   - 内蔵Compassが干渉する場合は、使用コンパスを外部優先にする。
3. Radio Calibration
4. Servo Output確認
5. Battery Monitor確認
6. RangeFinder確認

## 9. LiDAR / RangeFinder

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

確認:

- Mission PlannerでRangeFinder距離値が変化する。
- 近距離、遠距離で値が破綻しない。
- rover-gcsのAuto-stop表示と停止動作は、換装後に別途確認する。

## 10. ベンチテスト順序

1. USBのみでMission Planner接続。
2. ファームウェア、ボード、ArduRover起動を確認。
3. PM02のみ接続し、電圧表示を確認。
4. RC受信機を接続し、Radio Calibration。
5. GPS2へM8Nを接続し、GPS fixとCompass認識を確認。
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
params/after_fc_replace/YYYYMMDD_pixhawk6c_bench_ok.param
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

- GPS2のTX/RXまたはI2Cが未確認
- Compass calibration未完了
- RC failsafe未確認
- DISARM時のESC挙動が不明
- ステアリング方向が逆
- スロットル中立が不安定
- Battery voltage表示が実測と大きく違う
- LiDAR値が不安定
- rover-gcs / Mission PlannerでARM状態が確認できない
