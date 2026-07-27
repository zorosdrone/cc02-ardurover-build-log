-- CC-02 ArduRover 4.6.3 実機向け段階試験用 Guided 障害物回避
--
-- 重要:
--   実機初回は車輪を浮かせ、SCR_USER1=0（監視のみ）から確認する。
--   接地試験は projects/03_Lua障害物回避/07_実機テスト手順.md に従う。
--   AVOID_ENABLE=0でNative OAとLua制御を分離する。
--   前方TF-Luna 1台では後方・側方の安全を確認できない。
--
-- SCR_USER1:
--   0 = 監視のみ。走行指令を出さない。
--   1 = 減速、停止、停止保持。後退しない。
--   2 = 減速、停止、短距離直進後退、停止保持。旋回しない。
--   3 = 減速、停止、直進後退、前進旋回、再確認、Target復帰。
-- SCR_USER2 = 直進後退時間 [s]。0で既定値2.25。
-- SCR_USER3 = 前進旋回時間 [s]。0で既定値6.0。
-- SCR_USER4 = 前進旋回速度 [m/s]。0で既定値0.20。
-- SCR_USER5 = 符号付き旋回率 [deg/s]。0で既定値+40。
-- SCR_USER6 = 後退スロットル。0で既定値-0.70。
--
-- 制御レベルとSCR_USER2～6はGuided + Armed + Target取得時に固定する。
-- 走行中のレベル引上げは無視する。レベル引下げは即時停止保持する。

local MAV_SEVERITY = {
  CRITICAL = 2,
  WARNING = 4,
  NOTICE = 5,
  INFO = 6,
}

local SCRIPT_VERSION = "20260727-rover463-staged-v9.3"

local MODE_GUIDED = 15
local FRONT_ORIENT = 0
local SERVO_STEERING_FUNCTION = 26
local SERVO_THROTTLE_FUNCTION = 70

-- 現行パラメータのTF-Luna設定（20 cm～4 m）の内側で判定する。
local WARN_M = 3.0
local STOP_M = 1.0
local RESUME_M = 3.5
local REQUIRED_COUNT = 3

-- 初回実機試験用の低速値。
local RUN_SPEED_MS = 0.50
local SLOW_SPEED_MS = 0.25
local DEFAULT_BACK_THROTTLE = -0.70
local DEFAULT_TURN_SPEED_MS = 0.20
local DEFAULT_TURN_RATE_DEG_S = 40

local STOP_HOLD_MS = 1500
local DEFAULT_BACK_MS = 2250
-- MOT_SLEWRATE=100でニュートラルから-70%へ到達する時間を見込み、
-- 1秒後の実PWMがログで確認した後退境界へ入ったか検査する。
local BACK_PWM_CHECK_DELAY_MS = 1000
local BACK_PWM_MAX_US = 1405
local DEFAULT_TURN_MS = 6000
local RECHECK_SETTLE_MS = 700
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
local active_level = 0
local version_reported = false
local increase_warned = false
local backup_pwm_confirmed = false
local cfg_back_throttle = DEFAULT_BACK_THROTTLE
local cfg_turn_speed_ms = DEFAULT_TURN_SPEED_MS
local cfg_turn_rate_deg_s = DEFAULT_TURN_RATE_DEG_S
local cfg_back_ms = DEFAULT_BACK_MS
local cfg_turn_ms = DEFAULT_TURN_MS

local function now_ms()
  return millis():toint()
end

local function report(severity, text)
  gcs:send_text(severity, text)
end

local function report_limited(severity, text)
  local t = now_ms()
  if t - last_report_ms >= REPORT_INTERVAL_MS then
    report(severity, text)
    last_report_ms = t
  end
end

local function enter(new_state, reason)
  if state ~= new_state then
    report(
      MAV_SEVERITY.NOTICE,
      string.format("LUAOA463: %s -> %s: %s", state, new_state, reason)
    )
  end
  state = new_state
  state_start_ms = now_ms()
  if new_state == "BACKUP" then
    backup_pwm_confirmed = false
  end
end

local function elapsed_ms()
  return now_ms() - state_start_ms
end

local function is_guided_and_armed()
  return vehicle:get_mode() == MODE_GUIDED and arming:is_armed()
end

local function requested_level()
  local value = param:get("SCR_USER1")
  if value == nil then
    return 0
  end

  local level = math.floor(value + 0.5)
  if level < 0 then
    return 0
  end
  if level > 3 then
    return 3
  end
  return level
end

local function user_value_or_default(name, default_value)
  local value = param:get(name)
  if value == nil then
    return nil
  end
  if value == 0 then
    return default_value
  end
  return value
end

local function load_tunable_config()
  local back_s = user_value_or_default("SCR_USER2", DEFAULT_BACK_MS * 0.001)
  local turn_s = user_value_or_default("SCR_USER3", DEFAULT_TURN_MS * 0.001)
  local turn_speed =
    user_value_or_default("SCR_USER4", DEFAULT_TURN_SPEED_MS)
  local turn_rate =
    user_value_or_default("SCR_USER5", DEFAULT_TURN_RATE_DEG_S)
  local back_throttle =
    user_value_or_default("SCR_USER6", DEFAULT_BACK_THROTTLE)

  if back_s == nil or turn_s == nil or turn_speed == nil or
     turn_rate == nil or back_throttle == nil then
    return false, "SCR_USER2-6 unavailable"
  end
  if back_s < 0.5 or back_s > 10 then
    return false, "SCR_USER2 range 0.5-10 s"
  end
  if turn_s < 0.5 or turn_s > 20 then
    return false, "SCR_USER3 range 0.5-20 s"
  end
  if turn_speed < 0.05 or turn_speed > 1.0 then
    return false, "SCR_USER4 range 0.05-1.0 m/s"
  end
  if math.abs(turn_rate) < 5 or math.abs(turn_rate) > 120 then
    return false, "SCR_USER5 abs range 5-120 deg/s"
  end
  if back_throttle < -1.0 or back_throttle > -0.1 then
    return false, "SCR_USER6 range -1.0 to -0.1"
  end

  cfg_back_ms = math.floor(back_s * 1000 + 0.5)
  cfg_turn_ms = math.floor(turn_s * 1000 + 0.5)
  cfg_turn_speed_ms = turn_speed
  cfg_turn_rate_deg_s = turn_rate
  cfg_back_throttle = back_throttle
  return true, "ok"
end

local function report_tunable_config()
  report(
    MAV_SEVERITY.NOTICE,
    string.format(
      "LUAOA463: cfg b=%.2f t=%.2f v=%.2f",
      cfg_back_ms * 0.001,
      cfg_turn_ms * 0.001,
      cfg_turn_speed_ms
    )
  )
  report(
    MAV_SEVERITY.NOTICE,
    string.format(
      "LUAOA463: cfg r=%.1f q=%.2f",
      cfg_turn_rate_deg_s,
      cfg_back_throttle
    )
  )
end

local function read_front_m()
  local status = rangefinder:status_orient(FRONT_ORIENT)
  if not rangefinder:has_data_orient(FRONT_ORIENT) then
    return nil, status
  end

  local distance_cm = rangefinder:distance_cm_orient(FRONT_ORIENT)
  return distance_cm * 0.01, status
end

local function read_guided_target()
  local ok_target, target = pcall(function()
    return vehicle:get_target_location()
  end)
  if ok_target and target ~= nil then
    return target:copy(), "target-api"
  end

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
     current == nil or distance_m == nil or bearing_deg == nil or
     distance_m < 0.5 then
    return nil, "unavailable"
  end

  target = current:copy()
  local ok_offset = pcall(function()
    target:offset_bearing(bearing_deg, distance_m)
  end)
  if not ok_offset then
    return nil, "offset-failed"
  end

  return target, "wp-vector"
end

local function capture_guided_target()
  local target, source = read_guided_target()
  if target == nil then
    return false, source
  end

  local first_capture = saved_target == nil
  saved_target = target
  if first_capture then
    report(
      MAV_SEVERITY.NOTICE,
      "LUAOA463: guided target ready via " .. source
    )
  end
  return true, source
end

local function stop_vehicle()
  return vehicle:set_desired_turn_rate_and_speed(0, 0)
end

local function set_run_speed()
  return vehicle:set_desired_speed(RUN_SPEED_MS)
end

local function validate_control_config()
  local min_cm = param:get("RNGFND1_MIN_CM")
  local max_cm = param:get("RNGFND1_MAX_CM")
  local orient = param:get("RNGFND1_ORIENT")
  local avoid_enable = param:get("AVOID_ENABLE")
  local servo1_function = param:get("SERVO1_FUNCTION")
  local servo3_function = param:get("SERVO3_FUNCTION")
  local servo3_min = param:get("SERVO3_MIN")
  local servo3_trim = param:get("SERVO3_TRIM")
  local servo3_reversed = param:get("SERVO3_REVERSED")

  if min_cm == nil or max_cm == nil or orient == nil then
    return false, "rangefinder params unavailable"
  end
  if orient ~= FRONT_ORIENT then
    return false, "RNGFND1_ORIENT must be 0"
  end
  if not (min_cm * 0.01 < STOP_M and
          STOP_M < WARN_M and
          WARN_M < RESUME_M and
          RESUME_M < max_cm * 0.01) then
    return false, "distance thresholds outside RNGFND1 range"
  end
  if avoid_enable == nil or avoid_enable ~= 0 then
    return false, "AVOID_ENABLE must be 0"
  end
  if servo1_function == nil then
    return false, "steering servo params unavailable"
  end
  if servo1_function ~= SERVO_STEERING_FUNCTION then
    return false, "SERVO1_FUNCTION must be 26"
  end
  if servo3_function == nil or servo3_min == nil or
     servo3_trim == nil or servo3_reversed == nil then
    return false, "throttle servo params unavailable"
  end
  if servo3_function ~= SERVO_THROTTLE_FUNCTION then
    return false, "SERVO3_FUNCTION must be 70"
  end
  if servo3_reversed ~= 0 then
    return false, "SERVO3_REVERSED must be 0"
  end
  if servo3_trim ~= 1500 then
    return false, "SERVO3_TRIM must be 1500"
  end
  if servo3_min > BACK_PWM_MAX_US then
    return false, "SERVO3_MIN above reverse pwm limit"
  end

  local expected_back_pwm =
    servo3_trim -
    (servo3_trim - servo3_min) * math.abs(cfg_back_throttle)
  if expected_back_pwm > BACK_PWM_MAX_US then
    return false, "SCR_USER6 cannot reach reverse pwm limit"
  end

  return true, "ok"
end

local function fault(reason)
  pcall(stop_vehicle)
  report(MAV_SEVERITY.CRITICAL, "LUAOA463: FAULT " .. reason)
  enter("FAULT", reason)
end

local function reset_to_idle(reason)
  detect_count = 0
  clear_count = 0
  try_count = 0
  saved_target = nil
  active_level = 0
  increase_warned = false
  enter("IDLE", reason)
end

local function monitor_only(distance_m, level, range_status)
  if distance_m == nil then
    report_limited(
      MAV_SEVERITY.WARNING,
      string.format(
        "LUAOA463: monitor no range st=%s",
        tostring(range_status)
      )
    )
    return
  end

  report_limited(
    MAV_SEVERITY.INFO,
    string.format(
      "LUAOA463: monitor %.2f m st=%s lv=%d",
      distance_m,
      tostring(range_status),
      level
    )
  )
end

local function update()
  if not version_reported then
    report(MAV_SEVERITY.NOTICE, "LUAOA463: loaded " .. SCRIPT_VERSION)
    report(MAV_SEVERITY.NOTICE, "LUAOA463: SCR_USER1 0=monitor 1=stop 2=back 3=full")
    report(MAV_SEVERITY.NOTICE, "LUAOA463: SCR_USER2-6 runtime tune; 0=default")
    version_reported = true
  end

  local level = requested_level()
  local distance_m, range_status = read_front_m()
  local zero_means_clear = distance_m == 0

  if not is_guided_and_armed() then
    if state ~= "IDLE" then
      reset_to_idle("not guided or disarmed")
    end
    monitor_only(distance_m, level, range_status)
    return
  end

  if state == "IDLE" then
    if level == 0 then
      monitor_only(distance_m, level, range_status)
      return
    end

    local tunable_ok, tunable_reason = load_tunable_config()
    if not tunable_ok then
      fault(tunable_reason)
      return
    end

    local config_ok, config_reason = validate_control_config()
    if not config_ok then
      fault(config_reason)
      return
    end
    if distance_m == nil then
      fault(
        "no range at start st=" ..
        tostring(range_status)
      )
      return
    end

    local target_ok = capture_guided_target()
    if not target_ok then
      report_limited(MAV_SEVERITY.INFO, "LUAOA463: waiting for guided target")
      return
    end

    active_level = level
    report(
      MAV_SEVERITY.NOTICE,
      string.format("LUAOA463: control level %d latched", active_level)
    )
    report_tunable_config()
    enter("CLEAR", "guided target ready")
    return
  end

  if level < active_level then
    active_level = level
    fault("control level reduced; stop hold")
    return
  end
  if active_level > 0 and level > active_level and not increase_warned then
    report(
      MAV_SEVERITY.WARNING,
      "LUAOA463: level increase ignored until Hold/Disarm"
    )
    increase_warned = true
  end

  if state == "HOLD" or state == "FAULT" then
    stop_vehicle()
    return
  end

  if distance_m == nil then
    fault("no range st=" .. tostring(range_status))
    return
  end

  if state == "CLEAR" then
    capture_guided_target()

    if not set_run_speed() then
      fault("set run speed failed")
      return
    end

    if zero_means_clear then
      detect_count = 0
      report_limited(
        MAV_SEVERITY.INFO,
        string.format("LUAOA463: clear 0.00 m st=%s", tostring(range_status))
      )
    elseif distance_m <= STOP_M then
      clear_count = 0
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        if saved_target == nil then
          fault("no saved target before stop")
          return
        end
        enter(
          "STOP",
          string.format("d=%.2f st=%s", distance_m, tostring(range_status))
        )
      end
    elseif distance_m <= WARN_M then
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        detect_count = 0
        enter(
          "SLOW",
          string.format("d=%.2f st=%s", distance_m, tostring(range_status))
        )
      end
    else
      detect_count = 0
      report_limited(
        MAV_SEVERITY.INFO,
        string.format("LUAOA463: clear %.2f m level=%d", distance_m, active_level)
      )
    end
    return
  end

  if state == "SLOW" then
    capture_guided_target()

    if not vehicle:set_desired_speed(SLOW_SPEED_MS) then
      fault("set slow speed failed")
      return
    end

    if zero_means_clear then
      detect_count = 0
      clear_count = clear_count + 1
      if clear_count >= REQUIRED_COUNT then
        clear_count = 0
        enter("CLEAR", "zero distance means no target")
      end
    elseif distance_m <= STOP_M then
      clear_count = 0
      detect_count = detect_count + 1
      if detect_count >= REQUIRED_COUNT then
        if saved_target == nil then
          fault("no saved target before stop")
          return
        end
        enter(
          "STOP",
          string.format("d=%.2f st=%s", distance_m, tostring(range_status))
        )
      end
    elseif distance_m >= RESUME_M then
      detect_count = 0
      clear_count = clear_count + 1
      if clear_count >= REQUIRED_COUNT then
        detect_count = 0
        clear_count = 0
        enter("CLEAR", string.format("distance %.2f m", distance_m))
      end
    else
      detect_count = 0
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
      if active_level == 1 then
        enter("HOLD", "level 1 stop only")
      else
        enter("BACKUP", "stop hold complete")
      end
    end
    return
  end

  if state == "BACKUP" then
    -- The current vehicle's reverse output range is narrower than forward.
    -- Direct throttle targets the reverse PWM region measured during Manual.
    -- v9.2 keeps steering neutral during straight reverse and uses the
    -- latched SCR_USER6 throttle. Default time is 2.25 s.
    local steering_cmd = 0
    if not vehicle:set_steering_and_throttle(
      steering_cmd,
      cfg_back_throttle
    ) then
      fault("backup command failed")
      return
    end
    local steering_pwm = SRV_Channels:get_output_pwm(SERVO_STEERING_FUNCTION)
    local throttle_pwm = SRV_Channels:get_output_pwm(SERVO_THROTTLE_FUNCTION)
    report_limited(
      MAV_SEVERITY.INFO,
      string.format(
        "LUAOA463: back s=%.2f/%s t=%.2f/%s",
        steering_cmd,
        tostring(steering_pwm),
        cfg_back_throttle,
        tostring(throttle_pwm)
      )
    )

    if elapsed_ms() >= BACK_PWM_CHECK_DELAY_MS and
       not backup_pwm_confirmed then
      if type(throttle_pwm) ~= "number" then
        fault("backup pwm unavailable")
        return
      end
      if throttle_pwm > BACK_PWM_MAX_US then
        fault(
          string.format(
            "backup pwm %d > %d",
            throttle_pwm,
            BACK_PWM_MAX_US
          )
        )
        return
      end

      backup_pwm_confirmed = true
      report(
        MAV_SEVERITY.NOTICE,
        string.format(
          "LUAOA463: back pwm ok %d; motion unverified",
          throttle_pwm
        )
      )
    end

    if elapsed_ms() >= cfg_back_ms then
      if active_level == 2 then
        enter("HOLD", "level 2 backup command time complete")
      else
        enter("TURN", "backup command time complete")
      end
    end
    return
  end

  if state == "TURN" then
    if not vehicle:set_desired_turn_rate_and_speed(
      cfg_turn_rate_deg_s,
      cfg_turn_speed_ms
    ) then
      fault("turn command failed")
      return
    end

    local steering_pwm = SRV_Channels:get_output_pwm(SERVO_STEERING_FUNCTION)
    local throttle_pwm = SRV_Channels:get_output_pwm(SERVO_THROTTLE_FUNCTION)
    report_limited(
      MAV_SEVERITY.INFO,
      string.format(
        "LUAOA463: turn r=%.1f s=%.2f p=%s/%s",
        cfg_turn_rate_deg_s,
        cfg_turn_speed_ms,
        tostring(steering_pwm),
        tostring(throttle_pwm)
      )
    )

    if elapsed_ms() >= cfg_turn_ms then
      enter("RECHECK", "turn command time complete")
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

    if zero_means_clear then
      enter("RESUME", "zero distance means no target")
    elseif distance_m >= RESUME_M then
      enter("RESUME", string.format("distance %.2f m", distance_m))
    else
      try_count = try_count + 1
      if try_count >= MAX_TRY then
        fault("max tries")
      else
        enter(
          "BACKUP",
          string.format(
            "d=%.2f st=%s try=%d",
            distance_m,
            tostring(range_status),
            try_count
          )
        )
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
      fault("set target location failed")
      return
    end
    if not set_run_speed() then
      fault("target restored but run speed failed")
      return
    end

    detect_count = 0
    clear_count = 0
    try_count = 0
    enter("CLEAR", "target restored")
    return
  end

  fault("unknown state " .. state)
end

local function protected_update()
  local ok, err = pcall(update)
  if not ok then
    if is_guided_and_armed() then
      pcall(stop_vehicle)
    end
    state = "FAULT"
    report(MAV_SEVERITY.CRITICAL, "LUAOA463: internal error " .. tostring(err))
    return protected_update, 1000
  end

  return protected_update, UPDATE_INTERVAL_MS
end

return protected_update, 1000
