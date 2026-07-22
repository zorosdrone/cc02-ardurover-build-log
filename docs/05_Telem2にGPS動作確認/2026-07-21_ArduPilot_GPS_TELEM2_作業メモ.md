# ArduPilot GPS・コンパス切替作業メモ

- 作業日：2026-07-21
- 対象FC：Pixhawk 6C Mini
- 対象機体：ArduPilot Rover
- 目的：TELEM2に接続したGPSを使用し、GPSモジュール内蔵コンパスではなくPixhawk内蔵コンパスを使用する

---

## 1. 本日実施・確認したこと

### 1.1 TELEM2の用途をレンジファインダーからGPSへ変更

TELEM2はArduPilot上では`SERIAL2`として設定する。

現在のパラメータファイルでは、TELEM2側は次の状態になっている。

```text
SERIAL2_PROTOCOL = 5
SERIAL2_BAUD     = 9
SERIAL2_OPTIONS  = 0
```

意味：

| パラメータ | 値 | 内容 |
|---|---:|---|
| `SERIAL2_PROTOCOL` | `5` | GPSとして使用 |
| `SERIAL2_BAUD` | `9` | 9600bps |
| `SERIAL2_OPTIONS` | `0` | UART反転・半二重・TX/RX入替なし |

GPS配線は、同名同士ではなくTXとRXを交差させる。

```text
GPS TXD → TELEM2 RX
GPS RXD ← TELEM2 TX
GPS GND ↔ TELEM2 GND
GPS VCC ← TELEM2 VCC
```

---

### 1.2 旧レンジファインダー設定を無効化

現在のパラメータでは、レンジファインダーと近接センサーは無効になっている。

```text
RNGFND1_TYPE = 0
RNGFND2_TYPE = 0
PRX1_TYPE    = 0
```

このため、以前表示されていた次の警告に対する設定上の後処理は完了している。

```text
PreArm: PRX1: No Data
PreArm: Rangefinder 1: Not Detected
```

---

### 1.3 GPSモジュール内蔵コンパスからPixhawk内蔵コンパスへ切替

Mission Plannerのコンパス画面では、次のコンパスだけが表示された。

```text
DevType     : IST8310
BusType     : I2C
Bus         : 0
External    : オフ
Orientation : None
```

`External`がオフなので、画面上で現在使用対象になっているのはPixhawk内蔵コンパスと判断できる。

現在のパラメータファイルでは、コンパスのスロットが次のようになっている。

```text
COMPASS_DEV_ID  = 0
COMPASS_USE     = 0
COMPASS_EXTERNAL = 1

COMPASS_DEV_ID2 = 658433
COMPASS_USE2    = 1
COMPASS_EXTERN2 = 0
COMPASS_ORIENT2 = 0
```

つまり、現在認識されている内蔵コンパスが「Compass 2」側のスロットに登録されている。  
Mission Plannerの画面では1個だけ表示され、`External`もオフであるため、この状態自体は使用可能。

今後の作業：

1. Pixhawk内蔵コンパスだけが表示されることを確認
2. `Use Compass`を有効にする
3. Orientationは`None`
4. コンパスキャリブレーションを実施
5. 再起動後に方位を確認

GPSの位置情報はUART、GPSモジュール内蔵コンパスは通常I²Cであり、別系統である。  
GPSをTELEM2へ接続しただけでは、GPSモジュール内蔵コンパスを使うことにはならない。

---

### 1.4 セーフティスイッチ設定

現在は次の設定になっている。

```text
BRD_SAFETY_DEFLT = 0
```

これは起動時からセーフティ解除状態にする設定。GPS認識とは無関係であり、自動ARM設定でもない。

---

## 2. 現在のGPS関連パラメータ

アップロードした現在のパラメータ`2026072101_inGPS_01.param`から確認した値：

```text
SERIAL2_PROTOCOL = 5
SERIAL2_BAUD     = 9
SERIAL2_OPTIONS  = 0

SERIAL3_PROTOCOL = 5
SERIAL3_BAUD     = 230
SERIAL3_OPTIONS  = 0

SERIAL4_PROTOCOL = 5
SERIAL4_BAUD     = 230
SERIAL4_OPTIONS  = 0

GPS1_TYPE        = 1
GPS2_TYPE        = 0
GPS_AUTO_CONFIG  = 1
GPS_AUTO_SWITCH  = 1
GPS_PRIMARY      = 0
GPS1_RATE_MS     = 200

BRD_SER2_RTSCTS  = 2

SERIAL_PASS1     = 0
SERIAL_PASS2     = -1
SERIAL_PASSTIMO  = 15
```

### 現状の評価

- `SERIAL2_PROTOCOL=5`：TELEM2をGPSとして使う設定になっている
- `SERIAL2_BAUD=9`：9600bps
- `SERIAL2_OPTIONS=0`：通常UARTとして妥当
- `GPS1_TYPE=1`：GPS形式をAUTO検出
- `GPS2_TYPE=0`：GPSは1台構成
- `SERIAL_PASS2=-1`：Passthroughは現在無効
- `SERIAL3_PROTOCOL=5`と`SERIAL4_PROTOCOL=5`：TELEM2以外のポートもGPS用途として残っている

GPSをTELEM2だけで使用するなら、未使用ポートをGPSから外した方が構成が明確になる。

---

## 3. 旧Pixhawk 2.4.8で動作していたパラメータから得た情報

旧パラメータ`pixhawk.param`では、GPS関連が次の状態だった。

```text
GPS1_TYPE        = 5
GPS2_TYPE        = 0
GPS_AUTO_CONFIG  = 1
GPS1_RATE_MS     = 200

SERIAL3_PROTOCOL = -1
SERIAL3_BAUD     = 9

SERIAL4_PROTOCOL = 5
SERIAL4_BAUD     = 9
```

このファイルから確実に読み取れるGPS受信条件は次の2点。

```text
GPSプロトコル：NMEA
UART速度      ：9600bps
```

ただし、旧FCで実際に接続していた物理コネクタはGPSポートとの実機情報がある一方、保存されたファイルでは`SERIAL4_PROTOCOL=5`となっている。  
物理ポート名、基板実装、ArduPilot上の論理SERIAL番号、保存時点の設定が一致しているとは限らないため、旧ファイルのSERIAL番号を新FCへそのまま移植しない。

移植すべきなのは次の受信条件。

```text
GPS1_TYPE    = 5
SERIALx_BAUD = 9
GPS1_RATE_MS = 200
```

現在の接続先はTELEM2なので、`SERIALx`は`SERIAL2`へ置き換える。

---

## 4. TELEM2だけでGPSを使う場合の推奨整理案

旧Pixhawkで動作したものと同じGPSを使っている前提では、次の構成が最も明確。

```text
SERIAL2_PROTOCOL = 5
SERIAL2_BAUD     = 9
SERIAL2_OPTIONS  = 0

SERIAL3_PROTOCOL = -1
SERIAL4_PROTOCOL = -1

GPS1_TYPE        = 5
GPS2_TYPE        = 0
GPS_AUTO_CONFIG  = 1
GPS_AUTO_SWITCH  = 0
GPS_PRIMARY      = 0
GPS1_RATE_MS     = 200

BRD_SER2_RTSCTS  = 0

SERIAL_PASS2     = -1
```

### 補足

- `GPS1_TYPE=5`：旧構成で動作実績のあるNMEA固定
- `SERIAL2_BAUD=9`：旧構成で動作実績のある9600bps
- `SERIAL3_PROTOCOL=-1`、`SERIAL4_PROTOCOL=-1`：GPSをTELEM2だけに限定
- `GPS_AUTO_SWITCH=0`：GPSが1台なので切替不要
- `BRD_SER2_RTSCTS=0`：RTS/CTSを使わずTX/RXだけで接続する構成を明示

`SERIALx_PROTOCOL`などを変更した後は、Pixhawkを完全に再起動する。

---

## 5. `NoGPS`の意味

Mission Plannerの表示は切り分けに使える。

| 表示 | 意味 |
|---|---|
| `NoGPS` | ArduPilotがGPS受信機を認識できていない |
| `No Fix` | GPS受信機は認識済みだが、衛星測位が成立していない |
| `3D Fix` | GPS受信機を認識し、3次元測位が成立 |

今回の問題は`NoGPS`なので、衛星受信環境より先に次を確認する。

1. GPSへの電源供給
2. GPS TXDとTELEM2 RXの配線
3. UARTボーレート
4. NMEAデータが出ているか
5. `SERIAL2_PROTOCOL`
6. `GPS1_TYPE`

---

## 6. Passthrough確認とは

Passthroughは、Pixhawkを一時的にUSB-UART変換器として使う診断方法。

```text
GPS
  ↓ UART生データ
TELEM2 / SERIAL2
  ↓
Pixhawk
  ↓ USB
PCの通信ソフト
```

通常はPixhawkがGPSデータを解析する。  
Passthroughでは解析せず、GPSから来たUARTの文字列・バイト列をPCへそのまま転送する。

これにより、次の区間にデータが届いているか確認できる。

```text
GPS TXD → 配線 → TELEM2 RX → Pixhawk USB
```

Passthroughは通常運用に必要な機能ではなく、トラブル切り分け専用。

---

## 7. Passthrough確認時の設定

TELEM2をUSBへ転送する場合：

```text
SERIAL_PASS1    = 0
SERIAL_PASS2    = 2
SERIAL_PASSTIMO = 0
```

意味：

| パラメータ | 内容 |
|---|---|
| `SERIAL_PASS1=0` | PixhawkのUSB側 |
| `SERIAL_PASS2=2` | TELEM2／SERIAL2側 |
| `SERIAL_PASSTIMO=0` | 診断中にタイムアウトさせない |

設定を書き込んだ後は、診断が終わるまで再起動しない。

現在のファイルでは次のため、Passthroughは無効。

```text
SERIAL_PASS2 = -1
```

---

## 8. Passthroughデータが表示される場所

Mission PlannerのHUDやメッセージ欄には表示されない。

PixhawkのUSB COMポートを、別のシリアル通信ソフトで開いて確認する。

使用例：

- Tera Term
- RealTerm
- u-center

### Tera Termの場合

1. PixhawkをUSBでPCへ接続
2. Mission PlannerはUDP接続を使用
3. Passthroughパラメータを書き込む
4. Pixhawkを再起動しない
5. Tera Termを起動
6. PixhawkのCOMポートを選択
7. シリアル設定を9600bpsにする
8. Tera Termの黒いメイン画面を見る

NMEAなら次のような文字列が流れる。

```text
$GNGGA,...
$GNRMC,...
$GPGGA,...
```

### 結果の判断

#### 文字列が表示される

次の区間は正常。

```text
GPSのUART出力
GPS TX配線
TELEM2 RX入力
PixhawkからUSBへの転送
```

この場合、`NoGPS`の原因はArduPilot側のGPS形式・ポート設定に絞りやすい。

#### 何も表示されない

主な候補：

- GPSに電源が来ていない
- GPS TXDとTELEM2 RXが接続されていない
- TX/RXを同名同士で接続している
- GPSのUART出力が無効
- GPSの実際のボーレートが9600bpsではない
- 違うCOMポートを開いている
- Passthroughが有効になっていない

---

## 9. GPS基板単体のUART出力確認

GPS基板には次の端子がある。

```text
GND / VCC / TXD / RXD
```

USB-UART変換器を使う場合、受信確認だけなら次の配線でよい。

```text
GPS GND → USB-UART GND
GPS TXD → USB-UART RXD
GPS RXD → 未接続
```

GPSを基板上のUSBから給電する場合、USB-UART変換器側のVCCは接続しない。  
電源出力同士を接続しないよう注意する。

---

## 10. 本日の重要な知見

### 知見1：物理ポート名とArduPilotのSERIAL番号は区別する

例：

```text
物理ポート：TELEM2
論理設定  ：SERIAL2
```

ただし、FCの種類、基板実装、ファームウェアターゲットによって割当が異なる場合がある。  
別FCのパラメータからSERIAL番号だけをコピーしない。

---

### 知見2：GPS位置情報とコンパスは別の通信

```text
GPS位置情報：UART（TX/RX）
コンパス　：I²C（SDA/SCL）が一般的
```

TELEM2にGPSのTX/RXを接続しても、GPSモジュール内蔵コンパスまで接続されるわけではない。

---

### 知見3：`NoGPS`と`No Fix`は別問題

`NoGPS`ではGPS受信機の認識・通信を確認する。  
衛星が見える場所へ移動する前に、UART通信を成立させる必要がある。

---

### 知見4：Passthroughは「生データが届いているか」を見る診断

PassthroughでNMEA文字列が見えれば、GPSからTELEM2までの物理通信は成立している。  
それでも`NoGPS`なら、ArduPilotの設定やGPS形式の問題を疑う。

---

### 知見5：旧動作実績からGPSの通信条件を推定できる

旧Pixhawk 2.4.8のパラメータから、このGPSは次の条件で動作していた可能性が高い。

```text
NMEA
9600bps
5Hz
```

現在のPixhawk 6C Miniでも、まず同じ条件をTELEM2へ適用するのが合理的。

---

## 11. 次回の作業手順

### 手順A：通常設定を整理

```text
SERIAL2_PROTOCOL = 5
SERIAL2_BAUD     = 9
SERIAL2_OPTIONS  = 0
SERIAL3_PROTOCOL = -1
SERIAL4_PROTOCOL = -1
GPS1_TYPE        = 5
GPS2_TYPE        = 0
GPS_AUTO_SWITCH  = 0
BRD_SER2_RTSCTS  = 0
```

書き込み後、Pixhawkを完全に再起動する。

### 手順B：Mission Plannerで状態確認

1. メッセージ欄でGPS検出表示を確認
2. HUDが`NoGPS`から`No Fix`または`3D Fix`へ変化するか確認
3. 変化しなければPassthrough確認へ進む

### 手順C：Passthrough確認

```text
SERIAL_PASS1    = 0
SERIAL_PASS2    = 2
SERIAL_PASSTIMO = 0
```

書き込み後は再起動せず、Tera TermでPixhawkのUSB COMを9600bpsで開く。

### 手順D：結果に応じた切り分け

| 結果 | 次の確認 |
|---|---|
| NMEA文字列あり | ArduPilotのGPS形式・パラメータを再確認 |
| 文字化けした連続データあり | ボーレートまたはバイナリ形式を確認 |
| 完全に無反応 | 電源・配線・GPS TXD・ボーレートを確認 |

### 手順E：診断終了

Passthrough確認後はPixhawkを再起動し、通常のGPS処理へ戻す。  
再起動後、`SERIAL_PASS2=-1`になっていることを確認する。

---

## 12. 現時点の未解決事項

- GPSをTELEM2へ接続した状態で`NoGPS`が解消していない
- GPS基板のTXDから実際にNMEAデータが出ているか未確認
- GPSのUART速度が本当に9600bpsか、現物では未確認
- 現在の`GPS1_TYPE=1`より、旧実績値の`GPS1_TYPE=5`が適切か実機確認が必要
- `SERIAL3_PROTOCOL=5`と`SERIAL4_PROTOCOL=5`が残っているため、TELEM2だけの構成へ整理する余地がある
- Pixhawk内蔵コンパスのキャリブレーション完了状況を最終確認する必要がある

---

## 13. 使用したパラメータファイル

- `2026072101_inGPS_01.param`  
  Pixhawk 6C Miniの現在設定

- `pixhawk.param`  
  旧Pixhawk 2.4.8でGPSが動作していた構成の参考設定
