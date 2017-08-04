-- Edit this file suit your needs 
-- Then create the folder /path/to/domoticz/scripts/dzVents/modules and place it there
-- renaming it to ideAlarmHelpers.lua

-- See https://github.com/allan-gam/ideAlarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)

local _C = {}

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
