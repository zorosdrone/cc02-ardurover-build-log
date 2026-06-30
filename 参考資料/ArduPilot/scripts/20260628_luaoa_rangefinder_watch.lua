-- CC-02 ArduRover Lua 前方Rangefinder監視サンプル。
--
-- 目的:
--   前方Rangefinderを読み取り、距離帯をGCSメッセージへ表示する。
--   Guided TargetをLuaから読めるかも診断ログへ表示する。
--
-- 範囲:
--   このスクリプトは OA_TYPE=1 / BendyRuler を使用しない。
--   このスクリプトは操舵、スロットル、速度、モード変更を指令しない。
--   まずSITLで使い、実機ではタイヤを浮かせた読み取り確認だけに使う。
--
-- 想定設定:
--   Rover最新版SITL、またはCC-02の前方Rangefinder構成
--   SCR_ENABLE=1
--   前方センサーは RNGFND1_ORIENT=0
--   最新版向けに rangefinder:distance_orient(0) を使い、距離はm単位で扱う。
--   Roverで vehicle:get_target_location() がnilになる場合は、WP距離・方位の
--   フォールバックが使えるかだけを確認する。

local MAV_SEVERITY = {
  CRITICAL = 2,
  WARNING = 4,
  NOTICE = 5,
  INFO = 6,
}

local SCRIPT_VERSION = "20260630-target-probe-v2"

local FRONT_ORIENT = 0
local WARN_M = 5.0
local STOP_M = 2.5
local REPORT_INTERVAL_MS = 1000
local TARGET_REPORT_INTERVAL_MS = 2000
local UPDATE_INTERVAL_MS = 100

local last_report_ms = 0
local last_target_report_ms = 0
local last_target_status = nil
local version_reported = false

local function now_ms()
  return millis():toint()
end

local function report(severity, text)
  gcs:send_text(severity, text)
end

local function read_front_m()
  if not rangefinder:has_data_orient(FRONT_ORIENT) then
    return nil
  end

  return rangefinder:distance_orient(FRONT_ORIENT)
end

local function read_target_direct()
  local ok, target = pcall(function()
    return vehicle:get_target_location()
  end)

  if not ok then
    return false, "err"
  end

  if target == nil then
    return false, "nil"
  end

  return true, "ok"
end

local function read_target_wp_vector()
  local ok_current, current = pcall(function()
    return ahrs:get_location()
  end)
  local ok_distance, distance_m = pcall(function()
    return vehicle:get_wp_distance_m()
  end)
  local ok_bearing, bearing_deg = pcall(function()
    return vehicle:get_wp_bearing_deg()
  end)

  if not ok_current or current == nil then
    return false, "no-pos"
  end

  if not ok_distance or distance_m == nil or distance_m < 0.5 then
    return false, "no-dist"
  end

  if not ok_bearing or bearing_deg == nil then
    return false, "no-brg"
  end

  local ok_offset = pcall(function()
    local target = current:copy()
    target:offset_bearing(bearing_deg, distance_m)
  end)

  if not ok_offset then
    return false, "offset-err"
  end

  return true, string.format("%.1fm %.0fd", distance_m, bearing_deg)
end

local function target_status_text()
  local direct_ok, direct_status = read_target_direct()
  if direct_ok then
    return "direct=ok"
  end

  local wp_ok, wp_status = read_target_wp_vector()
  if wp_ok then
    return "direct=" .. direct_status .. " wp=ok " .. wp_status
  end

  return "direct=" .. direct_status .. " wp=" .. wp_status
end

local function report_target_status(t)
  if t - last_target_report_ms < TARGET_REPORT_INTERVAL_MS then
    return
  end

  local status = target_status_text()
  if status ~= last_target_status then
    report(MAV_SEVERITY.NOTICE, "LUAOA: target " .. status)
    last_target_status = status
    last_target_report_ms = t
  end
end

local function update()
  local t = now_ms()

  if not version_reported then
    report(MAV_SEVERITY.NOTICE, "LUAOA: loaded " .. SCRIPT_VERSION)
    version_reported = true
  end

  report_target_status(t)

  local distance_m = read_front_m()
  if distance_m == nil then
    if t - last_report_ms > REPORT_INTERVAL_MS then
      report(MAV_SEVERITY.WARNING, "LUAOA: no front rangefinder data")
      last_report_ms = t
    end
    return
  end

  if t - last_report_ms > REPORT_INTERVAL_MS then
    if distance_m <= STOP_M then
      report(MAV_SEVERITY.WARNING, string.format("LUAOA: stop zone %.1f m", distance_m))
    elseif distance_m <= WARN_M then
      report(MAV_SEVERITY.INFO, string.format("LUAOA: warn zone %.1f m", distance_m))
    else
      report(MAV_SEVERITY.INFO, string.format("LUAOA: clear %.1f m", distance_m))
    end
    last_report_ms = t
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
