-- CC-02 ArduRover Lua 前方Rangefinder監視サンプル。
--
-- 目的:
--   前方Rangefinderを読み取り、距離帯をGCSメッセージへ表示する。
--
-- 範囲:
--   このスクリプトは OA_TYPE=1 / BendyRuler を使用しない。
--   このスクリプトは操舵、スロットル、速度、モード変更を指令しない。
--   まずSITLで使い、実機ではタイヤを浮かせた読み取り確認だけに使う。
--
-- 想定設定:
--   Rover SITL、またはCC-02 ArduRover 4.6.3系の前方Rangefinder構成
--   SCR_ENABLE=1
--   前方センサーは RNGFND1_ORIENT=0

local MAV_SEVERITY = {
  INFO = 6,
  WARNING = 4,
}

local FRONT_ORIENT = 0
local WARN_CM = 500
local STOP_CM = 250
local REPORT_INTERVAL_MS = 1000
local UPDATE_INTERVAL_MS = 100

local last_report_ms = 0

function update()
  local now_ms = millis():toint()

  if not rangefinder:has_data_orient(FRONT_ORIENT) then
    if now_ms - last_report_ms > REPORT_INTERVAL_MS then
      gcs:send_text(MAV_SEVERITY.WARNING, "LUAOA: no front rangefinder data")
      last_report_ms = now_ms
    end
    return update, UPDATE_INTERVAL_MS
  end

  local distance_cm = rangefinder:distance_cm_orient(FRONT_ORIENT)
  if distance_cm == nil then
    return update, UPDATE_INTERVAL_MS
  end

  if now_ms - last_report_ms > REPORT_INTERVAL_MS then
    if distance_cm <= STOP_CM then
      gcs:send_text(MAV_SEVERITY.WARNING, string.format("LUAOA: stop zone %d cm", distance_cm))
    elseif distance_cm <= WARN_CM then
      gcs:send_text(MAV_SEVERITY.INFO, string.format("LUAOA: warn zone %d cm", distance_cm))
    else
      gcs:send_text(MAV_SEVERITY.INFO, string.format("LUAOA: clear %d cm", distance_cm))
    end
    last_report_ms = now_ms
  end

  return update, UPDATE_INTERVAL_MS
end

return update, 1000
