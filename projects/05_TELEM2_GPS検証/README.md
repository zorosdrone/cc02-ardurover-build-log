# 05 TELEM2 GPS検証

CC-02 RoverのGPS検証資料を管理する。現搭載のPixhawk 6C MiniとM10 GPSの手順、および旧構成での検証記録を収録する。

## 主な資料

- [Pixhawk 6C Miniと現搭載M10 GPSのパススルー確認手順](2026-10-01_Pixhawk6Cmini_M10_GPSパススルー確認手順.md)
- [ArduPilot GPS TELEM2 作業メモ](2026-07-21_ArduPilot_GPS_TELEM2_作業メモ.md)
- [Pixhawk 2.4.8 TELEM2 GPSパススルー確認手順](2026-07-22_Pixhawk248_TELEM2_GPSパススルー確認手順.md)
- [6C Mini GPS2・旧M8Nパススルー手順（調査済み・実機未確認）](2026-10-01_6Cmini_GPS2_旧M8Nパススルー手順.md)

## 成果物

- `params/` - 検証前パラメータ
- `images/` - Mission Planner、Tera Term、u-centerの確認画像

## 再訪実験の準備状況

持参予定: Rover、Pixhawk 6C Mini、Raspberry Pi Zero 2。Piは電子工作用OSからローバー用環境への復旧を進めている。

- 2026-09-21 ユーザー報告: Pixhawk → Pi → PCのテレメトリ転送を確認。
- 2026-10-01 ユーザー報告: `ssh pi@pizero2` と `ssh pi@100.67.15.67` の両方で、パスワード入力なしのログインを確認。認証方式は未確認。
- 2026-10-01 画面・ユーザー報告: RpanionのConnectedとパケット受信、Mission PlannerのUDP接続、WebGCSの機体状態・距離・Luaメッセージ表示を確認。
- 2026-10-01 ユーザー報告: スロットル・操舵が反応しない症状は、SAFEボタンの長押しが必要だったと判明し、動作を確認。
- 2026-10-01 ブザー確認: 起動音は鳴る（ユーザー報告）。画面の設定は`NTF_BUZZ_TYPES=5`、`NTF_BUZZ_VOLUME=100`。使用中のArduRover 4.6.3（`3fc7011a`）の[標準ToneAlarm実装](https://github.com/ArduPilot/ardupilot/blob/3fc7011a/libraries/AP_Notify/ToneAlarm.cpp)では、起動・ARM/DISARM・PreArm判定変化の通知音はあるが、SAFE切替単独の通知音処理はない。SAFE操作時の無音だけでブザー故障と判断せず、解除確認はボタンLED・HUD表示で行う。
- 2026-10-01 最終整理: 長押し解除後のスイッチLEDの赤色連続点灯は解除状態として問題なしと確認。GPS自体のブザー搭載有無と起動音の音源は未確認であり、起動音だけでGPS内蔵ブザーの存在を断定しない。ブザー設定の変更は行っていない。
- 次の確認: 電源再投入後のテレメトリ自動復帰、Pi設定・FCパラメータの保存、6C MiniでのGPS受信と生ログ保存。

## 現搭載GPSのパススルー確認

現搭載GPSは、GPS1へ10ピン接続したM10。PCからの確認経路は、USB（SERIAL0）とGPS1（SERIAL3）のパススルーを使う。PiはTELEM1、TF-LunaはTELEM2に接続している。

操作・ログ保存・通常状態への復帰は、[Pixhawk 6C MiniとM10 GPSの専用手順書](2026-10-01_Pixhawk6Cmini_M10_GPSパススルー確認手順.md)にまとめた。2026-10-02、ユーザー報告と[保存画像](images/20261002_pixhawk6cmini_m10_ucenter2_com15_3dfix.png)で、u-center 2 v26.05.4・COM15・230400bpsでのGPS情報受信と3D Fix表示を確認した。受信機FWはROM SPG 5.10 (7b202e)。

変更前パラメータのSERIAL3_BAUDは230（230400bps）、GPS1_RATE_MSは200（5Hzの設定目標）。生ログ保存、更新周期の実測、手動照会への応答、通常復帰は今回の画像だけでは未確認。GPSの商品型番とV1/V2も引き続き記録対象とする。
