--[[
Edit this file suit your needs 
-- Create the folder /path/to/domoticz/scripts/dzVents/modules (if it not already exists)
-- and place this file in that folder by the name ideAlarmConfig.lua

-- See https://github.com/allan-gam/ideAlarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)
--]]

local _C = {}

local SENSOR_CLASS_A = 'a' -- Sensor active in both arming modes. E.g. "Armed Home" and "Armed Away".
local SENSOR_CLASS_B = 'b' -- Sensor active in arming mode "Armed Away" only.

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

			-- active can be a boolean or a function as in the example below
			-- The sensor below will only trigger the alarm if
			-- "Master" is not at home and it's dark
			['Garden Shed Door'] = {['class'] = SENSOR_CLASS_A, ['active'] =
				function(domoticz)
					return (domoticz.devices('Master Present').state ~= 'On'
						and domoticz.time.isNightTime)	
				end},

		},
		armAwayToggleBtn='Toggle Z1 Arm Away',
		armAwayTogglesNeeded = 3,
		armHomeToggleBtn='Toggle Z1 Arm Home',
		armHomeTogglesNeeded = 1,
		mainZone = true
	},
	-- End configuration of the first alarm zone

	-- Start configuration of the second alarm zone
	{
		name = 'Pembridge Square Residence',
		armingModeTextDevID = 551,
		statusTextDevID = 555,
		entryDelay = 15,
		exitDelay = 15,
		alertDevices={'Notting Hill Alert Horn', 'Big Ben Chimes'},
		sensors = {
			['Big Gate'] = {['class'] = SENSOR_CLASS_A, ['active'] = true},
			['Patio Door'] = {['class'] = SENSOR_CLASS_B, ['active'] = true},
		},
		armAwayToggleBtn = '',
		armAwayTogglesNeeded = 1,
		armHomeToggleBtn = '',
		armHomeTogglesNeeded = 1,
		mainZone = false
	},
	-- End configuration of the second alarm zone
}

return _C
