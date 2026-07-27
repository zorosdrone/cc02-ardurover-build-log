# Guided位置指定対応Lua障害物回避仕様書

更新日: 2026-06-20

状態: 初版仕様 / SITL実装前

対象: CC-02 ArduRover、Pixhawk 6C Mini、ArduRover 4.6.3、前方TF-Luna、Lua Scripting

## 1. 結論

第1版は、`GUIDED`モードで設定された目的地へ走行中に、前方Rangefinderで障害物を検出し、Luaが次の限定回避を行う機能とする。

```text
目的地を保存
→ 減速
→ 停止
→ 短距離後退
→ 固定方向旋回
→ 前方再確認
→ 保存した目的地を再設定
```

通常の`AUTO`ウェイポイント走行、Acro、Manualへの走行介入は第1版の対象外とする。

Luaスクリプトは対象外モードでも距離監視を継続できるが、走行指令は出さない。`AUTO`対応は`NAV_SCRIPT_TIME`またはAuto内Guidedを使用する別フェーズで設計する。

## 2. 目的

- Guided位置指定中の障害物前停止だけでなく、限定的な後退・旋回・再確認を実現する
- 回避後に、障害物検出前のGuided目的地へ復帰する
- 前方センサー1個の制約を超える判断を行わない
- センサー、Lua、API、モードの異常時に走行継続側へ倒さない
- 標準SITLで状態機械を反復検証してから実機へ移す

## 3. 対象範囲

### 3.1 第1版で実装する

| ID | 機能 | 内容 |
| --- | --- | --- |
| `SCP-01` | 対象モード | Rover `GUIDED`、モード番号15 |
| `SCP-02` | 目的地保持 | 回避開始前のGuided目的地を保存する |
| `SCP-03` | 距離監視 | 前方0度のRangefinderを100 ms周期で監視する |
| `SCP-04` | 減速・停止 | 距離閾値と連続判定により減速・停止する |
| `SCP-05` | 限定回避 | 短距離後退、固定方向旋回、前方再確認を行う |
| `SCP-06` | 目的地復帰 | 保存した目的地を再設定してGuided位置追従へ戻す |
| `SCP-07` | 異常処理 | センサー喪失、API失敗、タイムアウト時に停止保持する |
| `SCP-08` | ログ | 状態遷移、距離、目的地保存・復帰、異常原因を記録する |

### 3.2 第1版では実装しない

| ID | 対象外 | 理由 |
| --- | --- | --- |
| `OOS-01` | 通常Autoウェイポイントへの完全介入 | 通常AutoのWPサブモードでは速度・旋回APIを使用できない |
| `OOS-02` | Acro / Manualへの速度上書き | Rover 4.6.3のLua APIでは自然に介入できない |
| `OOS-03` | 左右の空きを同時比較 | 前方センサー1個では左右を観測できない |
| `OOS-04` | 空いている側の自動選択 | 固定方向旋回後に前方を再確認する方式とする |
| `OOS-05` | 任意障害物の経路計画 | BendyRuler相当の経路探索は行わない |
| `OOS-06` | 高速走行 | Lua周期、制動距離、センサー範囲の評価前である |
| `OOS-07` | 無制限の自動後退 | 後方センサーがなく、後退方向の安全を確認できない |

## 4. 現在の実機ベースライン

通常運用正本:

```text
projects/02_チューニング/params/tuned/20260613_pixhawk6c_rover_tuned_01.param
```

| 項目 | 現在値 / 状態 |
| --- | --- |
| Firmware | ArduRover 4.6.3系 |
| 前方センサー | Benewake TF-Luna、`TELEM2` |
| Rangefinder | `RNGFND1_TYPE=20`、`RNGFND1_ORIENT=0` |
| 有効範囲 | `RNGFND1_MIN_CM=20`、`RNGFND1_MAX_CM=700` |
| Native Simple OA | `OA_TYPE=0`、`PRX1_TYPE=4`、`AVOID_ENABLE=7` |
| Guided設定 | `GUID_OPTIONS=0` |
| 通常速度 | `WP_SPEED=2` m/s |
| 最小旋回半径 | `TURN_RADIUS=0.9` m |
| Lua | `SCR_ENABLE=1`、QuikTune用`RTUN_ENABLE=1` |
| 実機確認 | Native OAによるAcro低速停止、Guided停止を確認済み |

通常運用正本は上書きしない。Lua制御試験は専用パラメータファイルで行う。

## 5. モード別動作

| 現在モード | 距離監視 | 走行指令 | 動作 |
| --- | --- | --- | --- |
| Disarmed | 可能 | 出さない | `IDLE` |
| Guided、目的地なし | 可能 | 出さない | 目的地待ち |
| Guided、目的地あり | 可能 | 出す | 第1版の対象 |
| Auto通常WP | 可能 | 出さない | 監視と状態表示のみ |
| Auto内Guided | 可能 | 第1版では出さない | 将来拡張 |
| `NAV_SCRIPT_TIME` | 可能 | 第1版では出さない | 将来拡張 |
| Acro / Manual | 可能 | 出さない | 操縦者へ警告のみ |
| Hold等 | 可能 | 出さない | `IDLE` |

### 5.1 モード変更時

- 回避中にGuided以外へ変更された場合、Luaは回避シーケンスを中止する
- Luaから自動的にGuidedへ戻さない
- 保存済み目的地を破棄し、状態を`IDLE`へ戻す
- モード変更後の車両制御は新しいモードと操縦者へ委ねる
- モード変更をGCSへ警告として出す

## 6. 使用API

ArduRover 4.6.3のAPIだけを使用し、master / 4.7系の名称を混ぜない。

| 用途 | API | 単位 / 戻り値 |
| --- | --- | --- |
| モード取得 | `vehicle:get_mode()` | Roverモード番号 |
| 目的地取得 | `vehicle:get_target_location()` | `Location`または`nil` |
| 目的地再設定 | `vehicle:set_target_location(location)` | 成功時`true` |
| Guided WP減速 | `vehicle:set_desired_speed(speed)` | m/s、成功時`true` |
| 停止・後退・旋回 | `vehicle:set_desired_turn_rate_and_speed(rate, speed)` | deg/s、m/s、成功時`true` |
| データ有無 | `rangefinder:has_data_orient(0)` | boolean |
| 前方距離 | `rangefinder:distance_cm_orient(0)` | cm |

### 6.1 Guided位置指令との関係

`vehicle:set_desired_turn_rate_and_speed()`を呼ぶと、Guided内部は位置追従`WP`から速度・旋回指令へ切り替わる。

したがって回避開始前に目的地を保存し、`RESUME`時に`vehicle:set_target_location()`で再設定する。再設定に失敗した場合は走行を再開しない。

## 7. 処理の全体フロー

```text
起動
  ↓
モード・Arm・目的地・Rangefinder確認
  ↓
IDLE ── Guided目的地あり ──> CLEAR
                                  ↓ 障害物接近
                                SLOW
                                  ↓ 停止距離
                                STOP
                                  ↓ 停止確認
                               BACKUP
                                  ↓ 時間上限
                                 TURN
                                  ↓ 最低旋回量・時間
                               RECHECK
                     ┌────────────┴────────────┐
                  前方安全                   前方閉塞
                     ↓                          ↓
                  RESUME             再試行上限未満 → BACKUP
                     ↓                          ↓
           保存目的地を再設定          再試行上限到達 → FAULT
                     ↓
                   CLEAR

異常検出 ──> FAULT ──> 停止保持
```

## 8. 状態仕様

| 状態 | 入口条件 | 出力 | 終了条件 |
| --- | --- | --- | --- |
| `IDLE` | 無効、Disarmed、対象外モード、目的地なし | 走行指令なし | Guided、Armed、目的地・距離有効 |
| `CLEAR` | Guided位置追従中、前方安全 | Guided位置追従と試験用通常速度を維持 | 警戒距離を連続検出で`SLOW` |
| `SLOW` | 警戒距離内 | Guided WPの速度上限を低下 | 停止距離で`STOP`、安全距離で通常速度へ戻して`CLEAR` |
| `STOP` | 停止距離内 | 旋回0、速度0を継続送信 | 停止確認後に`BACKUP` |
| `BACKUP` | 停止確認済み | 旋回0、低速後退 | 後退時間上限で`TURN` |
| `TURN` | 後退完了 | 固定方向へ低速旋回 | 最低旋回時間経過で`RECHECK` |
| `RECHECK` | 最低旋回完了 | 速度0、センサー安定待ち | 安全なら`RESUME`、閉塞なら再試行または`FAULT` |
| `RESUME` | 前方安全 | 保存目的地を再設定、試験用通常速度を復帰 | API成功で`CLEAR`、失敗で`FAULT` |
| `FAULT` | センサー・API・タイムアウト異常 | Guided中は旋回0、速度0を送信 | Disarmまたは明示的なリセット |

### 8.1 目的地保存

- `CLEAR`中は`vehicle:get_target_location()`を周期的に読み、最新の有効目的地を保持する
- `SLOW`から`STOP`へ遷移する時点で目的地を固定する
- 回避中に新しい目的地を自動採用しない
- 回避を中止したい場合は操縦者がモードを変更する
- `RESUME`成功後に、次の目的地更新を許可する

### 8.2 停止判定

第1段階では次の両方を満たした場合に停止完了とする。

- 速度0指令を所定時間以上継続した
- 機体速度が停止判定値以下である、またはSITLで停止を確認できる十分な待機時間を経過した

速度取得APIの採否は実装時にRover 4.6.3で確認する。取得できない場合は、安全側の停止待機時間を使用する。

### 8.3 後退制限

後方センサーがないため、後退は最も強く制限する。

- SITLでは低速・短時間の固定後退とする
- 実機初期試験では後退を無効化できること
- 実機で有効化する前に後方の物理的安全を確認する
- 後退速度、時間、最大回数に上限を持つ
- 後退中の前方距離増加を、後方安全の根拠に使用しない

### 8.4 固定方向旋回

- 旋回方向は設定値で固定する
- 左右の空きを比較して方向選択しない
- 前方センサーが障害物を外した瞬間に旋回を終了しない
- 最低旋回時間を満たしてから前方再確認へ移る
- `TURN_RADIUS=0.9` mを考慮し、速度に対して過大な旋回レートを要求しない

## 9. 初期設定値

次の値はSITL初期値であり、実機採用値ではない。

| 設定候補 | 初期値 | 意味 |
| --- | ---: | --- |
| `LUAOA_ENABLE` | 0 | 明示的に1へ変更するまで制御しない |
| `LUAOA_WARN` | 5.0 m | 警戒距離 |
| `LUAOA_STOP` | 2.5 m | 停止距離 |
| `LUAOA_RESUME` | 6.0 m | 再開可能距離 |
| `LUAOA_COUNT` | 3回 | 状態遷移の連続確定回数 |
| `LUAOA_PERIOD` | 100 ms | 制御周期 |
| `LUAOA_RUNSPD` | 1.0 m/s | SITL用の通常走行速度上限 |
| `LUAOA_SLOWSPD` | 0.5 m/s | 警戒中の速度上限 |
| `LUAOA_BACKSPD` | 0.2 m/s | 後退速度の絶対値 |
| `LUAOA_BACKMS` | 1000 ms | 1回の後退時間 |
| `LUAOA_TURNSPD` | 0.3 m/s | 固定旋回時の速度 |
| `LUAOA_TURNRT` | 15 deg/s | 固定旋回レート |
| `LUAOA_TURNMS` | 3000 ms | 最低旋回時間 |
| `LUAOA_SETTLE` | 500 ms | 前方再確認前の停止待機 |
| `LUAOA_MAXTRY` | 3回 | 最大回避試行回数 |
| `LUAOA_DATATO` | 500 ms | センサーデータタイムアウト |
| `LUAOA_DIR` | 1 | 固定旋回方向。符号で左右を指定 |

実機では`WP_SPEED=2` m/sをそのまま初期試験速度にしない。タイヤ浮かせ試験後、平坦地で十分に低い速度から決定する。

## 10. 異常処理

| ID | 異常 | 検出 | 動作 |
| --- | --- | --- | --- |
| `FLT-01` | Rangefinderデータなし | `has_data_orient(0)==false` | Guided中は`FAULT`、停止保持 |
| `FLT-02` | 距離更新タイムアウト | 更新時刻が上限超過 | `FAULT`、停止保持 |
| `FLT-03` | 回避開始前の目的地取得失敗 | `get_target_location()==nil` | 回避開始禁止、停止または`IDLE` |
| `FLT-04` | 走行API失敗 | APIが`false` | `FAULT`、再開禁止 |
| `FLT-05` | 目的地再設定失敗 | `set_target_location()==false` | `FAULT`、停止保持 |
| `FLT-06` | 回避タイムアウト | 状態ごとの上限超過 | `FAULT`、停止保持 |
| `FLT-07` | 最大試行回数超過 | `MAXTRY`到達 | `FAULT`、停止保持 |
| `FLT-08` | 回避中のモード変更 | `get_mode()!=15` | シーケンス中止、Lua出力停止、警告 |
| `FLT-09` | Lua実行停止 | スクリプト自身では検出不能 | 下記の実行停止時安全要件に従う |

`FAULT`解除を距離回復だけで自動化しない。Disarmまたは専用リセット操作を必要とする。

### 10.1 Lua実行停止時の重要な制約

Guidedの3秒タイムアウトで停止できるのは、Luaが`set_desired_turn_rate_and_speed()`等を最後に送っている`STOP`、`BACKUP`、`TURN`、`RECHECK`中である。

`CLEAR`または`SLOW`でGuided位置追従`WP`が動いている最中にLuaが異常終了した場合、位置目標そのものは残るため、Lua異常だけを理由に自動停止するとは限らない。

したがって次を実機運用の必須条件とする。

- `AVOID_ENABLE=0`のLua単独構成を無人・常用運転へ使用しない
- Lua単独の実機試験は最低速度、平坦地、即時モード変更またはDisarm可能な監視下で行う
- 常用前にNative OAを停止用バックストップとして併用できるか分離試験する
- またはLuaとは独立したウォッチドッグ停止手段を用意する
- `CLEAR`中のLua停止でも安全停止できることを実機投入ゲートとする

## 11. Native OAとの分離

Lua制御とNative Simple Object Avoidanceを同時に評価しない。

### 11.1 監視のみ

- 通常運用正本を維持できる
- Luaは距離表示と状態判定だけを行う
- 速度・モードへ介入しない

### 11.2 Lua制御単独試験

- 試験前に専用パラメータファイルを保存する
- `AVOID_ENABLE=0`としてNative OAの走行介入を分離する
- `RTUN_ENABLE=0`としてQuikTuneを開始しない
- `PRX1_TYPE`とTF-Luna Rangefinder設定は、距離確認に必要な範囲で維持する
- 試験終了後は通常運用正本へ戻す

Lua単独試験は原因切り分けのための試験構成であり、常用構成ではない。

### 11.3 常用候補構成

- Native OAは停止用バックストップとして残す
- Luaは停止後の限定回避と目的地復帰を担当する
- Native OAとLuaが同時に出力した場合の優先関係をSITLで確認する
- Native OAがLuaの後退・旋回を阻害する場合は、常用構成として採用せず独立ウォッチドッグ方式を検討する
- 停止原因とLua状態をログで区別できることを採用条件とする

試験用保存名:

```text
projects/02_チューニング/params/tuned/YYYYMMDD_01_guided_lua_avoid_test.param
```

## 12. ログ仕様

状態遷移時に、接頭辞`LUAOA`を付けたGCSメッセージを出す。

記録項目:

- 現在状態、遷移前状態、遷移理由
- 前方距離、データ有無、連続判定回数
- 現在モード、Arm状態
- 目的地保存成功、目的地再設定成功
- 走行APIの戻り値
- 回避試行回数
- 各状態の開始時刻と経過時間
- `FAULT`コード

通常周期の全データをGCSメッセージへ出さず、状態遷移と異常を優先する。詳細な周期データはDataFlashまたはLuaログへ分離する。

## 13. SITL受入試験

| ID | 試験 | 合格条件 |
| --- | --- | --- |
| `GUA-01` | Guided目的地保存 | 設定した目的地をLuaが取得・保持する |
| `GUA-02` | 障害物なし | Luaが走行を妨げず目的地へ到達する |
| `GUA-03` | 警戒減速 | 警戒距離内で速度が低下する |
| `GUA-04` | 停止 | 停止距離より手前で停止する |
| `GUA-05` | 限定回避 | 後退、固定旋回、前方再確認の順で遷移する |
| `GUA-06` | 目的地復帰 | 回避前と同じ目的地を再設定して走行を再開する |
| `GUA-07` | 再試行 | 再確認で閉塞なら上限内で再試行する |
| `GUA-08` | 最大試行 | 上限到達後に`FAULT`で停止保持する |
| `GUA-09` | センサー喪失 | `FAULT`へ入り走行継続しない |
| `GUA-10` | API失敗 | 失敗を記録し目的地復帰しない |
| `GUA-11` | モード変更 | 回避を中止し新しいモードへLua出力しない |
| `GUA-12` | 反復 | 同一条件20回でポストへ衝突しない |
| `GUA-13` | Lua停止・回避中 | Guidedの指令タイムアウトで停止する |
| `GUA-14` | Lua停止・CLEAR中 | Guided WPが残る危険を再現し、バックストップ方式を確認する |
| `AUT-01` | 通常Auto WP | 距離監視のみでLua走行APIを呼ばない |
| `AUT-02` | Auto中の障害物 | 第1版がAuto回避を行ったと誤認させないログを出す |

## 14. 実機移行試験

1. TF-Luna値とMission Planner表示を一致確認する
2. タイヤを浮かせ、Guided目的地保存と速度0指令を確認する
3. 実機初期試験では`BACKUP`を無効化する
4. 平坦で石の少ない場所を使用する
5. 最低速度で減速・停止だけを確認する
6. 後方の安全を確保して短距離後退を有効化する
7. 固定旋回と前方再確認を追加する
8. 保存目的地への復帰を確認する
9. `FAULT`、モード変更、Disarmを確認する
10. 通常運用正本へ戻しNative OA停止を再現する

## 15. 完了条件

- Guided目的地を回避前に保存できる
- 障害物を停止距離より手前で検出し停止できる
- 後退・固定旋回・前方再確認を上限付きで実行できる
- 前方安全確認後、同じGuided目的地を再設定できる
- センサー喪失、API失敗、タイムアウトで停止保持できる
- `CLEAR`中のLua異常終了に対する独立した停止手段を確認できる
- 通常Auto WP、Acro、Manualへ意図しない走行指令を出さない
- Lua制御とNative OAの停止原因をログで区別できる
- SITLで20回以上の反復試験を通過する
- 実機試験後に通常運用正本へ復帰できる

## 16. 将来拡張

### 16.1 Auto対応

通常Auto WPへLuaの後退・旋回を直接重ねない。次のいずれかを別仕様として評価する。

- ミッションに`NAV_SCRIPT_TIME`を入れ、Luaへ制御を明示的に渡す
- Auto内Guidedを使用する
- LuaがGuidedへ一時切替し、回避後にAutoミッションを安全に再開する

ミッション再開位置、`MIS_RESTART`、目的地復帰、モード切替失敗をSITLで確認するまで実機へ入れない。

### 16.2 C++独自モード

既存Acroの操作感を維持しながら障害物時だけ自然に介入する要件が確定した場合に検討する。第1版Luaの状態機械と試験結果を移植元とする。

## 17. 公式実装根拠

- [Rover-4.6.3 Rover.cpp](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/Rover.cpp)
- [Rover-4.6.3 mode.h](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode.h)
- [Rover-4.6.3 mode_auto.cpp](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode_auto.cpp)
- [Rover-4.6.3 mode_guided.cpp](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/Rover/mode_guided.cpp)
- [Rover-4.6.3 Lua API定義](https://github.com/ArduPilot/ardupilot/blob/Rover-4.6.3/libraries/AP_Scripting/docs/docs.lua)

## 18. 関連資料

- [Lua障害物回避プロジェクト概要](../README.md)
- [Rover SITL前方Rangefinder / 標準OA / Lua設定手順](../01_RoverSITL前方Rangefinder設定手順.md)
- [LuaとC++独自モードの実装判断](LuaとC++の実装判断.md)
- [Guided障害物停止確認](../../02_チューニング/logs/test_runs/20260613_07_guided_obstacle_stop_check.md)
