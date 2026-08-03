# CC-02 ArduRover 実機ビルドログ

タミヤ CC-02をベースにしたArduRover実機の構成、FC換装、配線、パラメータ、チューニング、走行試験、障害物回避、遠隔操作、トラブルシュートを記録するリポジトリです。

WebGCSアプリ本体のソースコードは別リポジトリの [rover-gcs](https://github.com/zorosdrone/rover-gcs) で管理し、このリポジトリには実機側の根拠資料と検証結果を保存します。

## 現在の状態

最終スナップショットは **2026-07-28** です。詳細と次回作業は [現在状況](docs/01_現在状況.md) を参照してください。

### 通常運用の基準

| 項目 | 現状 |
| --- | --- |
| ベース車両 | タミヤ CC-02 |
| フライトコントローラ | Holybro Pixhawk 6C Mini Model A |
| ファームウェア | ArduRover 4.6.3系 |
| GPS / Compass | M10 GPS + IST8310、`GPS1`接続 |
| 距離センサー | Benewake TF-Luna、`TELEM2`接続 |
| Raspberry Pi / MAVLink | `TELEM1`接続 |
| 通常運用パラメータ | [`20260613_pixhawk6c_rover_tuned_01.param`](projects/02_チューニング/params/tuned/20260613_pixhawk6c_rover_tuned_01.param) |
| 通常運用の障害物対応 | `OA_TYPE=0` のSimple Object Avoidance |

2026-06-13までに、屋外低速チューニング、Rover QuikTune、Battery failsafe、RTL / SmartRTL、Acro低速とGuidedでの障害物前停止を確認しました。`OA_TYPE=1` のBendyRulerは河原で地面や石の反射の影響が大きく、実験用のままです。

### Lua障害物回避

SITLで状態機械とGuided Target復帰を確認した後、ArduRover 4.6.3実機へ移行しました。実機v9.1で、次の一連の限定回避を確認済みです。

```text
直進後退
  -> 前進旋回
  -> 前方再確認
  -> Guided Target復帰
```

現行の実機用スクリプトは [`luaoa_guided_avoid_rover463.lua`](projects/03_Lua障害物回避/scripts/luaoa_guided_avoid_rover463.lua) です。コード内容はv9.4相当で、停止距離`1.0 m`、走行速度`0.50 m/s`、後退`2.25秒`、前進旋回`6.0秒`を基準にしています。

ただし、次の点は未完了です。

- コード内の起動識別子が`20260727-rover463-staged-v9.3`のままで、v9.4相当の内容と一致していない
- 後退距離、旋回角、最小離隔の定量測定
- TF-Lunaの対象なし値`0.00～0.02 m / st=2`と極近距離障害物の識別
- 前方センサー1台では確認できない横方向・後方の安全検知

このため、Lua版は通常運用設定ではなく、段階ゲート付きの**限定試験版**として扱います。試験後は通常運用パラメータへ戻してください。

主な根拠:

- [Lua障害物回避プロジェクト概要](projects/03_Lua障害物回避/README.md)
- [実機テスト手順](projects/03_Lua障害物回避/07_実機テスト手順.md)
- [SITLから実機移行で起きた問題と再発防止](projects/03_Lua障害物回避/08_SITLから実機移行で起きた問題と再発防止.md)
- [Lua後退失敗のBINログ解析](projects/03_Lua障害物回避/logs/test_runs/20260726_01_lua_backup_failure_bin_analysis.md)
- [2026-07-27試験後パラメータ](projects/03_Lua障害物回避/params/20260727_01_after_luaoa_v93_avoid_test.param)
- [実機試験動画](projects/03_Lua障害物回避/videos/Rover_Lua_Obstacle_Avoidance.mp4)

### 並行して管理している検証

- **WebGCS遠隔操作**: WebGCSのRC Override経路と、携帯回線テザリング、Rpanion、Tailscale、DigitalOceanを使う遠隔操作手順を記録
- **TELEM2 GPS検証**: Pixhawk 2.4.8のTELEM2へNEO-M8Nを接続し、GPS認識とUBXパススルーを確認

TELEM2 GPS検証はPixhawk 2.4.8を対象とした別検証です。現在のCC-02通常運用構成であるPixhawk 6C Mini + M10 GPSと混同しないでください。

## サブプロジェクト

| 番号 | プロジェクト | 状態 / 主な内容 |
| --- | --- | --- |
| 01 | [FC換装](projects/01_FC換装/README.md) | Pixhawk 6C Miniへの換装、配線、ArduRover導入、換装前後パラメータ |
| 02 | [チューニング](projects/02_チューニング/README.md) | 低速走行、旋回、フェイルセーフ、標準OA、QuikTune、代表ログ |
| 03 | [Lua障害物回避](projects/03_Lua障害物回避/README.md) | SITLから実機限定試験へ移行。一連の回避を確認、定量評価は継続 |
| 04 | [WebGCS遠隔操作](projects/04_WebGCS遠隔操作/README.md) | RC Overrideと携帯回線経由の遠隔操作手順 |
| 05 | [TELEM2 GPS検証](projects/05_TELEM2_GPS検証/README.md) | Pixhawk 2.4.8 + NEO-M8NのGPS認識、UBXパススルー |
| 06 | [HC-SR04左右距離計](projects/06_HC-SR04左右距離計/README.md) | 左右HC-SR04のGPIO接続、電源方式、ArduPilot設定の検討 |
| 07 | [Pi Zero 2 Wカメラ](projects/07_PiZero2Wカメラ/README.md) | KEYESTUDIO OV5647のCSI接続、カメラ環境修復、静止画・1080p動画撮影確認 |

配置方針は [サブプロジェクト一覧](projects/README.md) にまとめています。

## リポジトリ構成

```text
.
├─ projects/   テーマ別の本文、パラメータ、ログ、写真、動画
├─ docs/       全体概要、現在状況、管理手順、共通資料
├─ cad/        OpenSCAD設計元と3Dプリント用STL
├─ diagrams/   配線図、構成図、信号系統図の管理
├─ notes/      未整理メモ、一時メモ、判断メモ
├─ output/     文書から生成したPDFなどの出力
└─ 参考資料/   メーカー資料とrover-gcs関連資料の索引・保存物
```

プロジェクト固有の成果物は、それぞれの`projects/<番号_名称>/`配下へ置きます。複数プロジェクトから参照する状態整理や管理表は`docs/`へ置きます。

## 主要ドキュメント

### 最初に読む

- [概要](docs/00_概要.md)
- [現在状況](docs/01_現在状況.md)
- [サブプロジェクト一覧](projects/README.md)
- [ハードウェア判断ルール](docs/hardware-assumptions.md)

### FC換装と実機設定

- [FC換装計画](projects/01_FC換装/02_FC換装計画.md)
- [Pixhawk 6C Mini換装メモ](projects/01_FC換装/03_Pixhawk6Cmini換装メモ.md)
- [配線](projects/01_FC換装/04_配線.md)
- [ArduRoverインストール設定手順](projects/01_FC換装/05_ArduRoverインストール設定手順.md)
- [ArduRoverパラメータ](projects/01_FC換装/06_ArduRoverパラメータ.md)
- [走行試験](projects/01_FC換装/07_走行試験.md)

### チューニング

- [ArduRoverチューニング手順](projects/02_チューニング/08_ArduRoverチューニング手順.md)
- [チューニングログ](projects/02_チューニング/09_チューニングログ.md)

### Lua障害物回避

- [SITL BendyRuler実行手順](projects/03_Lua障害物回避/00_SITL_BendyRuler実行手順.md)
- [SITL前方Rangefinder / 標準OA / Lua設定手順](projects/03_Lua障害物回避/01_RoverSITL前方Rangefinder設定手順.md)
- [SITL Luaサンプルスクリプト](projects/03_Lua障害物回避/05_SITL_Luaサンプルスクリプト.md)
- [SITL用Guided障害物回避Luaの仕組みと動作解説](projects/03_Lua障害物回避/06_SITL用Guided障害物回避Lua_仕組みと動作解説.md)
- [Mission Planner前方距離表示確認](projects/03_Lua障害物回避/補助機能/11_MissionPlanner_前方距離表示確認.md)
- [REPLでLua APIを確認する](projects/03_Lua障害物回避/補助機能/12_REPLでLuaAPIを確認する.md)
- [キーボード操縦手順](projects/03_Lua障害物回避/補助機能/20_キーボード操縦手順.md)

### WebGCS遠隔操作

- [WebGCS TXによるプロポ入力上書き](projects/04_WebGCS遠隔操作/20260720_WebGCS_TXによるプロポ入力上書き.md)
- [携帯回線テザリング経由WebGCS操作手順](projects/04_WebGCS遠隔操作/20260720_携帯回線テザリング経由WebGCS操作手順.md)

### TELEM2 GPS検証

- [ArduPilot GPS TELEM2作業メモ](projects/05_TELEM2_GPS検証/2026-07-21_ArduPilot_GPS_TELEM2_作業メモ.md)
- [Pixhawk 2.4.8 TELEM2 GPSパススルー確認手順](projects/05_TELEM2_GPS検証/2026-07-22_Pixhawk248_TELEM2_GPSパススルー確認手順.md)
- [確認手順PDF](output/pdf/2026-07-22_Pixhawk248_TELEM2_GPSパススルー確認手順.pdf)

### Pi Zero 2 Wカメラ

- [Pi Zero 2 Wカメラプロジェクト概要](projects/07_PiZero2Wカメラ/README.md)
- [OV5647カメラのセットアップ・撮影テスト](projects/07_PiZero2Wカメラ/2026-08-03_PiZero2W_OV5647カメラ_セットアップ撮影テスト.md)

### 共通資料と管理表

- [トラブルシュート](docs/10_トラブルシュート.md)
- [部品リスト](docs/11_部品リスト.md)
- [ISDT 608PD LiPo放電・保管手順](docs/12_ISDT608PD_LiPo放電_保管手順.md)
- [DigitalOcean運用メモ](docs/13_DigitalOcean運用メモ.md)
- [パラメータ管理](docs/パラメータ管理.md)
- [ログ管理](docs/ログ管理.md)
- [写真管理](docs/写真管理.md)
- [動画管理](docs/動画管理.md)
- [CADフォルダ説明](cad/README.md)
- [図面管理](diagrams/図面管理.md)
- [メモ管理](notes/メモ管理.md)
- [参考資料一覧](参考資料/資料一覧.md)

## 記録と安全の方針

- パラメータの表示値やデフォルト値だけで正しいと判断せず、対象機体、ファームウェア、配線、実機ログを対応付ける。
- 室内Manual試験用の一時設定、通常運用の正本、LuaやBendyRulerの実験設定を分けて保存する。
- PWMや状態遷移の確認だけを実車の移動証明にせず、必要に応じて`RCOU`、速度、位置、目視動画を組み合わせる。
- Compass Orientationは外装の矢印だけで決めず、北・東・南・西へ向けたMission PlannerのHUD方位で確認する。
- GPS位置、Home位置、走行軌跡を含むログは、公開前に公開可否を確認する。

## Git LFS

再解析価値の高い代表ログと公開用動画はGit LFSで管理します。

```bash
git lfs install
git clone https://github.com/zorosdrone/cc02-ardurover-build-log.git
```

主なGit LFS対象:

- `projects/**/logs/accepted/`内の`.bin`、`.BIN`、`.ulg`、`.tlog`
- `projects/**/videos/`内の`.mp4`、`.MP4`、`.mov`、`.MOV`

すべての生ログは保存せず、代表ログだけを`logs/accepted/`へ置きます。各試験の条件、結果、判断は`logs/test_runs/`のMarkdownへ残します。

## このリポジトリに入れないもの

次のWebアプリ実装は [rover-gcs](https://github.com/zorosdrone/rover-gcs) 側で管理します。

- React / Viteのフロントエンドコード
- FastAPIバックエンドコード
- WebGCSのUI実装
- Webアプリのデプロイ構成

このリポジトリには、WebGCSをCC-02実機で使うためのパラメータ、接続手順、試験結果だけを保存します。
