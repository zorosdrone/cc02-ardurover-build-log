# Pi Zero 2 Wカメラ

Rover搭載のRaspberry Pi Zero 2 WへKEYESTUDIO 5MPカメラを接続し、認識、静止画撮影、1080p動画撮影まで確認した記録を管理する。

## 対象構成

- Raspberry Pi Zero 2 W（ホスト名: `pizero2`）
- Debian GNU/Linux 12（Bookworm）/ `aarch64`
- KEYESTUDIO 5MP固定焦点カメラ
- センサー: OmniVision `OV5647`
- 接続: CSI、15ピン－22ピンのPi Zero用カメラケーブル
- Rover側用途: Rpanionを動かすコンパニオンコンピュータ。Pixhawk 6C Miniとは`TELEM1`でMAVLink接続

## 資料

- [Pi Zero 2 W OV5647カメラのセットアップ・撮影テスト](2026-08-03_PiZero2W_OV5647カメラ_セットアップ撮影テスト.md)

## 2026-08-03確認結果

- Pi側ケーブル端の金属接点をPi基板側へ向けることで、`ov5647`を認識した。
- `rpicam-hello --list-cameras`で2592×1944のセンサーとして認識した。
- 2592×1944 JPEG静止画の撮影に成功した。
- 1920×1080、30 fps、約5秒のH.264動画撮影に成功した。
- 既存のカメラ関連パッケージに版不整合があり、カメラ関連パッケージだけを更新した。
- ArduPilotパラメータ、Rpanion設定、MAVLink設定は変更していない。
