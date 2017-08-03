-- Edit this file suit your needs 
-- Then create the folder /path/to/domoticz/scripts/dzVents/modules and place it there
-- renaming it to alarm_config.lua

-- See https://github.com/allan-gam/domoticz-dzVents-alarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)

local _C = {}

_C.ALARM_TEST_MODE = false -- if ALARM_TEST_MODE is set to true it will prevent audible alarm

_C.ALARM_ZONES = {
	{
		name='Pembridge Square',
		armingModeTextDevID=550,
		statusTextDevID=554,
		entryDelay=15,
		exitDelay=20,
		alertDevices={'Notting Hill Alert Horn', 'Big Ben Chimes'},
		armAwayToggleBtn='Toggle Z1 Arm Away',
		armAwayTogglesNeeded=1,
		armHomeToggleBtn='Toggle Z1 Arm Home',
		armHomeTogglesNeeded=1,
		mainZone=true
	},
	{
		name='Garden Shed',
		armingModeTextDevID=551,
		statusTextDevID=555,
		entryDelay=0,
		exitDelay=0,
		alertDevices={'Garden Shed Siren', 'Garden Lights'},
		armAwayToggleBtn='Toggle Z2 Arm Away',
		armAwayTogglesNeeded=1,
		armHomeToggleBtn='Toggle Z2 Arm Home',
		armHomeTogglesNeeded=1,
		mainZone=false
	},
}

-- Alarm helper functions
_C.helpers = {

	alarmStatusChange = function(domoticz, zone, zoneStatus)
		if zone == 1 then
			-- do something 
		end
	end,

	alarmZoneTripped = function(domoticz, zone)
		if zone == 1 then
			-- do something 
		end
	end,

	alarmZoneAlert = function(domoticz, zone)
		-- do something 
	end,

	alarmArmingModeChanged = function(domoticz, zone, armingMode, isMainZone)
		if isMainZone then
			-- do something 
		end
	end,

	alarmAlertMessage= function(domoticz, message, testMode)
		if not testMode then
			-- do something
		end
	end,

}

return _C
