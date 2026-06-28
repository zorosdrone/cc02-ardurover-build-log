# SITL Luaサンプルスクリプト

更新日: 2026-06-28

対象: Rover SITL、Lua Scripting、前方Rangefinder、Guided制御

## 結論

この文書は、DeepWiki検索結果をきっかけに作成したLuaサンプルの説明である。

保存しているサンプルは、`OA_TYPE=1` / BendyRulerを使うものではない。前方RangefinderをLuaで読み、必要に応じてGuided向けAPIを試すためのSITL学習用スクリプトとして扱う。

実機投入用の完成スクリプトではない。実機では、通常運用正本のNative Simple Object Avoidanceを安全側の基準として残し、Lua制御はSITLで挙動と失敗時動作を確認してから分離試験する。

## 保存しているサンプル

| ファイル | 用途 | 走行指令 | 位置づけ |
| --- | --- | --- | --- |
| [20260628_luaoa_rangefinder_watch.lua](../../参考資料/ArduPilot/scripts/20260628_luaoa_rangefinder_watch.lua) | 前方Rangefinderの読み取り確認 | なし | 最初に使う監視専用サンプル |
| [20260628_luaoa_min_guided_avoid.lua](../../参考資料/ArduPilot/scripts/20260628_luaoa_min_guided_avoid.lua) | 最低限のGuided回避確認 | あり | SITLで状態機械の骨格を見るサンプル |

どちらも、SITLではArduPilot作業ディレクトリ直下の`scripts`へ置いて使う。

```text
ardupilot/scripts/20260628_luaoa_rangefinder_watch.lua
ardupilot/scripts/20260628_luaoa_min_guided_avoid.lua
```

起動前にScriptingを有効化し、再起動する。

```text
SCR_ENABLE=1
```

## DeepWikiサンプルとの関係

DeepWikiの元サンプルは、「障害物が近い場合にLuaからRoverへ回避指令を出す」という考え方を示す概念例として有用である。

ただし、このリポジトリでは次の理由で、そのまま配置用Luaにはしない。

- 距離取得が`proximity:get_obstacle_distance()`中心の概念例で、CC-02のArduRover 4.6.3向け説明で使っている`rangefinder:distance_cm_orient(0)`と違う
- 近距離で即座に操舵・スロットル指令を出す構成で、目的地保存、停止保持、API失敗時の停止処理が不足している
- 仕様04では、前方センサー1個の制約、Guided目的地復帰、Native OAとの分離を明確にしている
- `OA_TYPE=1` / BendyRulerの経路計画と、Luaによる直接制御を混ぜると試験結果を切り分けにくい

そのため、ここではDeepWikiの考え方を残しつつ、CC-02側の前提に合わせて2段階のサンプルに分けた。

## サンプル1: 前方Rangefinder監視

対象ファイル:

```text
参考資料/ArduPilot/scripts/20260628_luaoa_rangefinder_watch.lua
```

目的は、Luaから前方Rangefinderを読めるか確認することである。

このスクリプトは、前方0度のRangefinderを100 ms周期で読み、距離帯をGCSメッセージへ表示する。操舵、スロットル、速度、モード変更は一切行わない。

主な確認内容:

- `rangefinder:has_data_orient(0)`で前方センサーのデータ有無を確認できる
- `rangefinder:distance_cm_orient(0)`で前方距離をcm単位で読める
- `DISTANCE_SENSOR.current_distance`やMission Planner表示とLuaの表示値が一致する
- 警戒距離、停止距離のしきい値判定が期待どおり出る

このサンプルは、仕様04のうち`SCP-03`の距離監視に相当する入口である。減速、停止、後退、旋回、目的地復帰は行わない。

## サンプル2: 最低限Guided回避

対象ファイル:

```text
参考資料/ArduPilot/scripts/20260628_luaoa_min_guided_avoid.lua
```

目的は、DeepWikiサンプルの「障害物を検出したらLuaで回避指令を出す」考え方を、CC-02向けAPIでSITL確認することである。

このスクリプトは、Guided中に前方障害物を検出した場合に、次の流れを試す。

```text
CLEAR
→ SLOW
→ STOP
→ BACKUP
→ TURN
→ RECHECK
→ RESUME
```

主な動作:

- `vehicle:get_mode()`でGuided中か確認する
- `vehicle:get_target_location()`でGuided目的地を保存する
- `rangefinder:distance_cm_orient(0)`で前方距離を監視する
- `vehicle:set_desired_speed()`で警戒時の減速を試す
- `vehicle:set_desired_turn_rate_and_speed()`で停止、短時間後退、固定方向旋回を試す
- `vehicle:set_target_location()`で保存した目的地への復帰を試す
- API失敗、センサー喪失、最大試行回数到達時は`FAULT`として停止指令を出す

このサンプルは、仕様04の完全実装ではない。状態機械の骨格をSITLで確認するための最小版である。

## 仕様04との関係

[Guided位置指定対応Lua障害物回避仕様書](04_Guided位置指定対応Lua障害物回避仕様書.md) に対する位置づけは次の通り。

| 仕様項目 | 監視サンプル | 最低限回避サンプル |
| --- | --- | --- |
| `SCP-01` Guided対象モード | 対応なし | 簡易対応 |
| `SCP-02` 目的地保持 | 対応なし | 簡易対応 |
| `SCP-03` 距離監視 | 対応 | 対応 |
| `SCP-04` 減速・停止 | 表示のみ | 簡易対応 |
| `SCP-05` 限定回避 | 対応なし | 短時間後退・固定旋回のみ |
| `SCP-06` 目的地復帰 | 対応なし | 簡易対応 |
| `SCP-07` 異常処理 | データなし表示のみ | 簡易`FAULT` |
| `SCP-08` ログ | 距離帯表示のみ | 状態遷移と異常表示 |

最低限回避サンプルでも、仕様04の受入試験を満たしたとは扱わない。SITLで各APIの戻り値、Guided内部状態、目的地復帰、Lua停止時の挙動を確認する必要がある。

## BendyRulerとの分離

`OA_TYPE=1`はArduPilot標準のBendyRuler経路計画を使う設定である。一方、この文書のLuaサンプルはLuaからRoverのGuided向けAPIを呼ぶ別系統である。

このため、次を混同しない。

| 試験 | 内容 |
| --- | --- |
| BendyRuler試験 | `OA_TYPE=1`でArduPilot標準の経路計画を確認する |
| Lua監視試験 | LuaでRangefinderを読むだけ |
| Lua回避試験 | LuaがGuided中に減速・停止・限定回避を試す |

前方センサー1個だけでは左右の空き比較はできない。最低限回避サンプルでも、空いている側を選ぶのではなく、固定方向に少し向きを変えてから前方を再確認する。

## REPLで試す意味

DeepWikiの「学習目的であれば、REPLを使って各APIを対話的に試す」という助言は、長いLuaファイルを投入する前に、小さいAPI呼び出しで戻り値と単位を確認するという意味で扱う。

先に確認したいAPI:

| API | 確認すること |
| --- | --- |
| `vehicle:get_mode()` | Guidedのモード番号が想定どおりか |
| `vehicle:get_target_location()` | Guided目的地を取得できるか |
| `vehicle:set_target_location(location)` | 保存した目的地へ戻せるか |
| `vehicle:set_desired_speed(speed)` | Guided中に速度上限を変更できるか |
| `vehicle:set_desired_turn_rate_and_speed(rate, speed)` | 停止、後退、旋回指令が成功するか |
| `rangefinder:has_data_orient(0)` | 前方Rangefinderデータが有効か |
| `rangefinder:distance_cm_orient(0)` | 前方距離の単位がcmで期待どおりか |

REPLは実機走行判断の代わりではない。実機ではまずタイヤを浮かせ、距離読み取りだけを確認する。

## 実機へ移す前の確認

最低限、次をSITLで確認してから実機へ進む。

1. `DISTANCE_SENSOR.current_distance`とLuaの距離表示が一致する
2. Guided目的地をLuaが取得できる
3. 警戒距離で`SLOW`へ入る
4. 停止距離で`STOP`へ入り、速度0指令を継続する
5. `BACKUP`、`TURN`、`RECHECK`が意図した時間だけ実行される
6. 前方安全時に`RESUME`へ入り、保存した目的地を再設定できる
7. Rangefinder喪失、API失敗、最大試行回数到達で`FAULT`へ入る
8. モード変更またはDisarmでLuaが回避シーケンスを中止する
9. QuikTuneなど他のLuaスクリプトと同時実行しない
10. 試験後に通常運用正本パラメータへ戻せる

実機では、最初から最低限回避サンプルを地上走行させない。まず監視サンプルで距離表示だけ確認し、次にタイヤを浮かせてGuided目的地保存と停止指令を確認する。

## 参照

- DeepWiki検索結果: <https://deepwiki.com/search/roversitllua_9a1a8cdc-c57c-4af6-b18b-1ef83728b137>
- ArduPilot master `Rover.cpp`: <https://github.com/ArduPilot/ardupilot/blob/master/Rover/Rover.cpp>
- ArduPilot Scripting README: <https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Scripting/README.md>
- [Guided位置指定対応Lua障害物回避仕様書](04_Guided位置指定対応Lua障害物回避仕様書.md)
