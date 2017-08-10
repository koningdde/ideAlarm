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
			['Entrance Door'] = {['class'] = SENSOR_CLASS_A, ['active'] = true},
			['Another Door'] = {['class'] = SENSOR_CLASS_A, ['active'] = true},
		},
		armAwayToggleBtn='Toggle Z1 Arm Away',
		armAwayTogglesNeeded = 1,
		armHomeToggleBtn='Toggle Z1 Arm Home',
		armHomeTogglesNeeded = 1,
		mainZone = true,
		syncDomoSecToThisZone = false,
		syncThisZoneToDomoSec = true,
	},
	-- End configuration of the first alarm zone
}

return _C
