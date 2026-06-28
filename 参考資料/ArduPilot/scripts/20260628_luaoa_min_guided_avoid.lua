-- CC-02 ArduRover Lua 最低限回避サンプル。
--
-- 目的:
--   DeepWikiサンプルの「近い障害物を検出したらLuaで回避指令を出す」
--   考え方を、CC-02 / ArduRover 4.6.3向けAPIに寄せて試す。
--
-- 範囲:
--   SITLでの学習・動作確認用。
--   OA_TYPE=1 / BendyRuler は使用しない。
--   前方Rangefinder 1個だけを使うため、左右の空きを比較しない。
--   実機で地面に置いたまま実行しない。実機ではまずタイヤを浮かせて確認する。
--
-- 動作:
--   Guided中に前方障害物を検出したら、停止、約2.0 m後退、強めの固定方向旋回、
--   前方再確認、保存したGuided目的地への復帰を試みる。

local MAV_SEVERITY = {
  CRITICAL = 2,
  WARNING = 4,
  NOTICE = 5,
  INFO = 6,
}

local SCRIPT_VERSION = "20260629-target-resume-required-v4"

local MODE_GUIDED = 15
local FRONT_ORIENT = 0

local WARN_CM = 800
local STOP_CM = 400
local RESUME_CM = 1000
local REQUIRED_COUNT = 3

local RUN_SPEED_MS = 1.0
local SLOW_SPEED_MS = 0.3
local BACK_SPEED_MS = 0.45
local TURN_SPEED_MS = 0.45
local TURN_RATE_DEG_S = 35
local TURN_DIR = 1

local STOP_HOLD_MS = 1500
local BACK_MS = 4500
local TURN_MS = 4500
local RECHECK_SETTLE_MS = 500
local MAX_TRY = 5
local REPORT_INTERVAL_MS = 1000
local UPDATE_INTERVAL_MS = 100

local state = "IDLE"
local state_start_ms = 0
local last_report_ms = 0
local detect_count = 0
local clear_count = 0
local try_count = 0
local saved_target = nil
local version_reported = false

local function now_ms()
  return millis():toint()
end

local function report(severity, text)
  gcs:send_text(severity, text)
end

local function report_limited(severity, text)
  local t = now_ms()
  if t - last_report_ms > REPORT_INTERVAL_MS then
    report(severity, text)
    last_report_ms = t
  end
end

local function enter(new_state, reason)
  if state ~= new_state then
    report(MAV_SEVERITY.NOTICE, string.format("LUAOA: %s -> %s: %s", state, new_state, reason))
  end
  state = new_state
  state_start_ms = now_ms()
end

local function elapsed_ms()
  return now_ms() - state_start_ms
end

local function is_guided_and_armed()
  return vehicle:get_mode() == MODE_GUIDED and arming:is_armed()
end

local function read_front_cm()
  if not rangefinder:has_data_orient(FRONT_ORIENT) then
    return nil
  end

  local ok_m, distance_m = pcall(function()
    return rangefinder:distance_orient(FRONT_ORIENT)
  end)
  if ok_m and distance_m ~= nil then
    return math.floor(distance_m * 100 + 0.5)
  end

  local ok_cm, distance_cm = pcall(function()
    return rangefinder:distance_cm_orient(FRONT_ORIENT)
  end)
  if ok_cm then
    return distance_cm
  end

  return nil
end

local function stop_vehicle()
  return vehicle:set_desired_turn_rate_and_speed(0, 0)
end

local function restore_run_speed()
  if vehicle:set_desired_speed(RUN_SPEED_MS) then
    return true
  end
  return vehicle:set_desired_turn_rate_and_speed(0, RUN_SPEED_MS)
end

local function fault(reason)
  report(MAV_SEVERITY.CRITICAL, "LUAOA: FAULT " .. reason)
  enter("FAULT", reason)
end

local function reset_to_idle(reason)
  detect_count = 0
  clear_count = 0
  try_count = 0
  saved_target = nil
  enter("IDLE", reason)
end

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

  local distance_cm = read_front_cm()

  if state == "IDLE" then
    saved_target = vehicle:get_target_location()
    if saved_target == nil then
      report(MAV_SEVERITY.NOTICE, "LUAOA: guided target not visible to Lua; safety-only avoid, no resume target")
      enter("CLEAR", "guided ready safety-only")
    else
      enter("CLEAR", "guided target ready")
    end
    return
  end

  if distance_cm == nil then
    fault("no front rangefinder data")
    return
  end

  if state == "CLEAR" then
    local current_target = vehicle:get_target_location()
    if current_target ~= nil then
      saved_target = current_target
    end

    if distance_cm <= STOP_CM then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        local current_target = vehicle:get_target_location()
        if current_target ~= nil then
          saved_target = current_target
        end
        if saved_target == nil then
          report(MAV_SEVERITY.WARNING, "LUAOA: stop without visible guided target")
        end
        enter("STOP", string.format("distance %d cm", distance_cm))
      end
    elseif distance_cm <= WARN_CM then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        enter("SLOW", string.format("distance %d cm", distance_cm))
      end
    else
      detect_count = 0
      report_limited(MAV_SEVERITY.INFO, string.format("LUAOA: clear %d cm", distance_cm))
    end
    return
  end

  if state == "SLOW" then
    local current_target = vehicle:get_target_location()
    if current_target ~= nil then
      saved_target = current_target
    end

    if not vehicle:set_desired_speed(SLOW_SPEED_MS) then
      fault("set_desired_speed failed")
      return
    end

    if distance_cm <= STOP_CM then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        local current_target = vehicle:get_target_location()
        if current_target ~= nil then
          saved_target = current_target
        end
        if saved_target == nil then
          report(MAV_SEVERITY.WARNING, "LUAOA: stop without visible guided target")
        end
        enter("STOP", string.format("distance %d cm", distance_cm))
      end
    elseif distance_cm >= RESUME_CM then
      clear_count = clear_count + 1
      if clear_count >= REQUIRED_COUNT then
        detect_count = 0
        clear_count = 0
        if not restore_run_speed() then
          fault("restore speed failed")
          return
        end
        enter("CLEAR", string.format("distance %d cm", distance_cm))
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

    if distance_cm >= RESUME_CM then
      enter("RESUME", string.format("distance %d cm", distance_cm))
    else
      try_count = try_count + 1
      if try_count >= MAX_TRY then
        fault("max avoid tries reached")
      else
        enter("BACKUP", string.format("blocked %d cm", distance_cm))
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
      report(MAV_SEVERITY.WARNING, "LUAOA: resume speed restore failed after target restore")
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

local function protected_update()
  local ok, err = pcall(update)
  if not ok then
    report(MAV_SEVERITY.CRITICAL, "LUAOA: internal error " .. err)
    return protected_update, 1000
  end
  return protected_update, UPDATE_INTERVAL_MS
end

return protected_update, 1000
