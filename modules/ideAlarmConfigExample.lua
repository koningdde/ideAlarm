--[[
Edit this file suit your needs 
-- Create the folder /path/to/domoticz/scripts/dzVents/modules (if it not already exists)
-- and place this file in that folder by the name ideAlarmConfig.lua

-- See https://github.com/allan-gam/ideAlarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)
--]]

local _C = {}

local SENSOR_CLASS_A = 'a' -- Sensor can be triggered in both arming modes. E.g. "Armed Home" and "Armed Away".
local SENSOR_CLASS_B = 'b' -- Sensor can be triggered in arming mode "Armed Away" only.

--[[
-------------------------------------------------------------------------------
DO NOT ALTER ANYTHING ABOVE THIS LINE
-------------------------------------------------------------------------------
--]]

_C.ALARM_TEST_MODE = false -- if ALARM_TEST_MODE is set to true it will prevent audible alarm

-- Number of seconds which after the alert devices will be turned off
-- automatically even if an active alert situation still exists.
-- 0 = Disable automatic turning off alert devices.   
_C.ALARM_ALERT_MAX_SECONDS = 15

_C.ALARM_ZONES = {
	-- Start configuration of the first alarm zone
	{
		name='My Home',
		armingModeTextDevID=550,
		statusTextDevID=554,
		entryDelay=15,
		exitDelay=20,
		alertDevices={'Siren', 'Garden Lights'},
		sensors = {
			['Entrance Door'] = {['class'] = SENSOR_CLASS_A, ['enabled'] = true},
			['Another Door'] = {['class'] = SENSOR_CLASS_A, ['enabled'] = true},
		},
		armAwayToggleBtn='Toggle Z1 Arm Away',
		armHomeToggleBtn='Toggle Z1 Arm Home',
		mainZone = true,
		canArmWithTrippedSensors = true,
		syncWithDomoSec = true, -- Only a single zone is allowed to sync with Domoticz's built in Security Panel
	},
	-- End configuration of the first alarm zone
}

return _C
