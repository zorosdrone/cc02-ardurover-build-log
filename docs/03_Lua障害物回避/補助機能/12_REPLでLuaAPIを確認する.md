# REPLでLua APIを確認する

長いLuaファイルを投入する前に、小さいAPI呼び出しで戻り値と単位を確認しておく。

先に確認したいAPI:

| API | 確認すること |
| --- | --- |
| `vehicle:get_mode()` | Guidedのモード番号が想定どおりか |
| `vehicle:get_target_location()` | Roverで実装されていればGuided目的地を取得できるか |
| `vehicle:get_wp_distance_m()` | RoverでGuided WPまでの距離を取得できるか |
| `vehicle:get_wp_bearing_deg()` | RoverでGuided WPへの方位を取得できるか |
| `ahrs:get_location()` | 現在位置を取得できるか |
| `Location:offset_bearing(bearing, distance)` | 現在位置からTarget座標を復元できるか |
| `vehicle:set_target_location(location)` | 保存した目的地へ戻せるか |
| `vehicle:set_desired_speed(speed)` | Guided中に速度上限を変更できるか |
| `vehicle:set_desired_turn_rate_and_speed(rate, speed)` | 停止、後退、旋回指令が成功するか |
| `rangefinder:has_data_orient(0)` | 前方Rangefinderデータが有効か |
| `rangefinder:distance_orient(0)` | 前方距離の単位がmで期待どおりか |

REPLは実機走行判断の代わりではない。実機ではまずタイヤを浮かせ、距離読み取りだけを確認する。
