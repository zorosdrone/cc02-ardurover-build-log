-- CC-02 ArduRover Lua 最低限回避サンプル。
--
-- 目的:
--   DeepWikiサンプルの「近い障害物を検出したらLuaで回避指令を出す」
--   考え方を、ArduPilot最新版SITL向けAPIに寄せて試す。
--
-- 範囲:
--   SITLでの学習・動作確認用。
--   OA_TYPE=1 / BendyRuler は使用しない。
--   前方Rangefinder 1個だけを使うため、左右の空きを比較しない。
--   最新版向けに rangefinder:distance_orient(0) を使い、距離はm単位で扱う。
--   実機で地面に置いたまま実行しない。実機ではまずタイヤを浮かせて確認する。
--
-- 動作:
--   Guided中に前方障害物を検出したら、停止、約2.0 m後退、強めの固定方向旋回、
--   前方再確認、保存したGuided目的地への復帰を試みる。

-- GCSへ表示するメッセージの重要度。ArduPilotのMAV_SEVERITY値に合わせる。
local MAV_SEVERITY = {
  CRITICAL = 2, -- 走行を止めるべき重大異常
  WARNING = 4,  -- 動作継続は可能だが注意が必要
  NOTICE = 5,   -- 状態遷移や起動通知
  INFO = 6,     -- 通常の周期ログ
}

-- 起動時にGCSへ出す識別子。SITLログで、どの版を動かしたか追跡する。
local SCRIPT_VERSION = "20260630-wp-vector-target-v6"

-- RoverのGuidedモード番号と、前方Rangefinderの向き番号。
local MODE_GUIDED = 15
local FRONT_ORIENT = 0

-- 距離しきい値。m単位で統一し、最新版SITLのdistance_orient()に合わせる。
local WARN_M = 8.0       -- 警戒開始距離。この内側で減速候補にする。
local STOP_M = 4.0       -- 停止開始距離。この内側でSTOPへ入る。
local RESUME_M = 10.0    -- 安全確認距離。この外側まで離れたら復帰候補にする。
local REQUIRED_COUNT = 3 -- 誤検出を避けるため、同じ判定が連続した回数だけ採用する。

-- Roverへ出す速度・旋回指令。m/sとdeg/sで指定する。
local RUN_SPEED_MS = 1.0    -- 通常走行へ戻すときの速度上限
local SLOW_SPEED_MS = 0.3   -- 警戒中の低速走行
local BACK_SPEED_MS = 0.45  -- 後退速度。set_desired_turn_rate_and_speedには負値で渡す。
local TURN_SPEED_MS = 0.45  -- 旋回中も少し前進させる速度
local TURN_RATE_DEG_S = 35  -- 固定方向旋回の角速度
local TURN_DIR = 1          -- 旋回方向。1で正方向、-1で逆方向。

-- 状態ごとの保持時間と安全上限。すべてms単位。
local STOP_HOLD_MS = 1500       -- STOPで停止指令を保持する時間
local BACK_MS = 4500            -- BACKUPで後退する時間
local TURN_MS = 4500            -- TURNで固定方向へ旋回する時間
local RECHECK_SETTLE_MS = 500   -- RECHECK開始直後に車体が落ち着くのを待つ時間
local MAX_TRY = 5               -- BACKUP/TURN/RECHECKを繰り返す最大回数
local REPORT_INTERVAL_MS = 1000 -- 通常ログの最短間隔。GCSをログで埋めないため。
local UPDATE_INTERVAL_MS = 100  -- Lua update周期。距離監視の基本周期。

-- 状態機械の作業変数。
local state = "IDLE"           -- 現在状態。IDLE/CLEAR/SLOW/STOP/BACKUP/TURN/RECHECK/RESUME/FAULT
local state_start_ms = 0       -- 現在状態に入った時刻
local last_report_ms = 0       -- 最後に周期ログを出した時刻
local detect_count = 0         -- 障害物側判定が連続した回数
local clear_count = 0          -- 安全側判定が連続した回数
local try_count = 0            -- 回避試行回数
local saved_target = nil       -- 障害物検出前に保存したGuided目的地
local version_reported = false -- 起動メッセージを1回だけ出すためのフラグ

-- 現在時刻をms整数で返す。状態経過時間の計算に使う。
local function now_ms()
  return millis():toint()
end

-- GCSへ1行メッセージを送る薄いラッパー。
local function report(severity, text)
  gcs:send_text(severity, text)
end

-- 通常ログを間引いて送る。100ms周期のupdateで毎回表示しないため。
local function report_limited(severity, text)
  local t = now_ms()
  if t - last_report_ms > REPORT_INTERVAL_MS then
    report(severity, text)
    last_report_ms = t
  end
end

-- 状態を切り替え、遷移理由をGCSへ残す。
local function enter(new_state, reason)
  if state ~= new_state then
    report(MAV_SEVERITY.NOTICE, string.format("LUAOA: %s -> %s: %s", state, new_state, reason))
  end
  state = new_state
  state_start_ms = now_ms()
end

-- 現在状態に入ってからの経過時間を返す。
local function elapsed_ms()
  return now_ms() - state_start_ms
end

-- Luaが走行へ介入してよい前提条件を確認する。
local function is_guided_and_armed()
  return vehicle:get_mode() == MODE_GUIDED and arming:is_armed()
end

-- 前方Rangefinderをm単位で読む。データなしならnilを返して安全側へ倒す。
local function read_front_m()
  if not rangefinder:has_data_orient(FRONT_ORIENT) then
    return nil
  end

  return rangefinder:distance_orient(FRONT_ORIENT)
end

-- Guided目的地を取得する。直接APIがnilならWP距離・方位から復元する。
local function read_guided_target()
  -- Rover masterではLua APIが見えていても、標準Rover側の実装都合で
  -- get_target_location()がnilを返すことがある。
  local ok_target, target = pcall(function()
    return vehicle:get_target_location()
  end)
  if ok_target and target ~= nil then
    return target:copy(), "target-api"
  end

  -- Rover向けフォールバック。GuidedがWP移動として動いている間に、
  -- 現在位置、WP距離、WP方位から現在のGuided目標座標を復元する。
  local ok_current, current = pcall(function()
    return ahrs:get_location()
  end)
  local ok_distance, distance_m = pcall(function()
    return vehicle:get_wp_distance_m()
  end)
  local ok_bearing, bearing_deg = pcall(function()
    return vehicle:get_wp_bearing_deg()
  end)

  if not ok_current or not ok_distance or not ok_bearing or
     current == nil or distance_m == nil or bearing_deg == nil or distance_m < 0.5 then
    return nil, "unavailable"
  end

  target = current:copy()
  local ok_offset = pcall(function()
    target:offset_bearing(bearing_deg, distance_m)
  end)

  if not ok_offset then
    return nil, "unavailable"
  end

  return target, "wp-vector"
end

-- 現在のGuided目的地を保存する。復帰時はこの座標へset_target_locationする。
local function capture_guided_target()
  local current_target, target_source = read_guided_target()
  if current_target == nil then
    return false, target_source
  end

  local first_capture = saved_target == nil
  saved_target = current_target

  if first_capture then
    report(MAV_SEVERITY.NOTICE, "LUAOA: guided target ready via " .. target_source)
  end

  return true, target_source
end

-- Roverへ停止指令を出す。STOP/RECHECK/FAULTで繰り返し呼ぶ。
local function stop_vehicle()
  return vehicle:set_desired_turn_rate_and_speed(0, 0)
end

-- RESUME後に通常速度上限へ戻す。
local function restore_run_speed()
  return vehicle:set_desired_speed(RUN_SPEED_MS)
end

-- 異常時の入口。理由を出してFAULT状態へ入り、以後は停止側へ倒す。
local function fault(reason)
  report(MAV_SEVERITY.CRITICAL, "LUAOA: FAULT " .. reason)
  enter("FAULT", reason)
end

-- Guided解除やDisarm時に、試行回数や保存Targetを捨てて待機状態へ戻す。
local function reset_to_idle(reason)
  detect_count = 0
  clear_count = 0
  try_count = 0
  saved_target = nil
  enter("IDLE", reason)
end

-- 100ms周期で呼ばれる本体。状態機械を1ステップ進める。
local function update()
  if not version_reported then
    report(MAV_SEVERITY.NOTICE, "LUAOA: loaded " .. SCRIPT_VERSION)
    version_reported = true
  end
  if not is_guided_and_armed() then
    if state ~= "IDLE" then
      reset_to_idle("not guided or disarmed")
    end
    return
  end

  local distance_m = read_front_m()

  if state == "IDLE" then
    if capture_guided_target() then
      enter("CLEAR", "guided target ready")
    else
      report_limited(MAV_SEVERITY.INFO, "LUAOA: waiting for guided target")
    end
    return
  end

  if distance_m == nil then
    fault("no front rangefinder data")
    return
  end

  if state == "CLEAR" then
    capture_guided_target()

    if distance_m <= STOP_M then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        capture_guided_target()
        if saved_target == nil then
          fault("no saved target before stop")
          return
        end
        enter("STOP", string.format("distance %.1f m", distance_m))
      end
    elseif distance_m <= WARN_M then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        enter("SLOW", string.format("distance %.1f m", distance_m))
      end
    else
      detect_count = 0
      report_limited(MAV_SEVERITY.INFO, string.format("LUAOA: clear %.1f m", distance_m))
    end
    return
  end

  if state == "SLOW" then
    capture_guided_target()

    if not vehicle:set_desired_speed(SLOW_SPEED_MS) then
      fault("set_desired_speed failed")
      return
    end

    if distance_m <= STOP_M then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        capture_guided_target()
        if saved_target == nil then
          fault("no saved target before stop")
          return
        end
        enter("STOP", string.format("distance %.1f m", distance_m))
      end
    elseif distance_m >= RESUME_M then
      clear_count = clear_count + 1
      if clear_count >= REQUIRED_COUNT then
        detect_count = 0
        clear_count = 0
        if not restore_run_speed() then
          fault("restore speed failed")
          return
        end
        enter("CLEAR", string.format("distance %.1f m", distance_m))
      end
    else
      clear_count = 0
    end
    return
  end

  if state == "STOP" then
    if not stop_vehicle() then
      fault("stop command failed")
      return
    end
    if elapsed_ms() >= STOP_HOLD_MS then
      enter("BACKUP", "stop hold complete")
    end
    return
  end

  if state == "BACKUP" then
    if not vehicle:set_desired_turn_rate_and_speed(0, -BACK_SPEED_MS) then
      fault("backup command failed")
      return
    end
    if elapsed_ms() >= BACK_MS then
      enter("TURN", "backup complete")
    end
    return
  end

  if state == "TURN" then
    if not vehicle:set_desired_turn_rate_and_speed(TURN_RATE_DEG_S * TURN_DIR, TURN_SPEED_MS) then
      fault("turn command failed")
      return
    end
    if elapsed_ms() >= TURN_MS then
      enter("RECHECK", "turn complete")
    end
    return
  end

  if state == "RECHECK" then
    if not stop_vehicle() then
      fault("recheck stop failed")
      return
    end
    if elapsed_ms() < RECHECK_SETTLE_MS then
      return
    end

    if distance_m >= RESUME_M then
      enter("RESUME", string.format("distance %.1f m", distance_m))
    else
      try_count = try_count + 1
      if try_count >= MAX_TRY then
        fault("max avoid tries reached")
      else
        enter("BACKUP", string.format("blocked %.1f m", distance_m))
      end
    end
    return
  end

  if state == "RESUME" then
    if saved_target == nil then
      fault("no saved target for resume")
      return
    end

    if not vehicle:set_target_location(saved_target) then
      fault("set_target_location failed")
      return
    end

    if not restore_run_speed() then
      report(MAV_SEVERITY.WARNING, "LUAOA: target restored but speed restore failed")
    end

    detect_count = 0
    clear_count = 0
    try_count = 0
    enter("CLEAR", "target restored")
    return
  end

  if state == "FAULT" then
    stop_vehicle()
    return
  end
end

-- Lua例外でスクリプト全体を落とさないための保護ラッパー。
local function protected_update()
  local ok, err = pcall(update)
  if not ok then
    report(MAV_SEVERITY.CRITICAL, "LUAOA: internal error " .. err)
    return protected_update, 1000
  end
  return protected_update, UPDATE_INTERVAL_MS
end

return protected_update, 1000
