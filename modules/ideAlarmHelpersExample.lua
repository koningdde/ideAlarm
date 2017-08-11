-- Edit this file suit your needs 
-- Then create the folder /path/to/domoticz/scripts/dzVents/modules and place it there
-- renaming it to ideAlarmHelpers.lua

-- See https://github.com/allan-gam/ideAlarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)

local _C = {}

-- ideAlarm Custom helper functions. These functions will be called if they exist.
_C.helpers = {

	alarmZoneNormal = function(domoticz, alarmZone)
		-- Normal is good isn't it? We don't have to do anything here.. We could but..
	end,

	alarmZoneTripped = function(domoticz, alarmZone, activeSensors)
		-- A sensor has been tripped but there is still no alert
		-- We should inform whoever tripped the sensor so he/she can disarm the alarm
		-- before a timeout occors and we get an alert
		-- In this example we turn on the kitcken lights if the zones name
		-- is 'My Home' but we could also let Domoticz speak a message or someting.
		if alarmZone.name == 'My Home' then
			-- Let's do something here
			domoticz.devices('Kitchen Lights').switchOn()
		end
	end,

	alarmZoneError = function(domoticz, alarmZone, activeSensors)
		-- An error occurred for an alarm zone. Maybe a door was open when we tried to
		-- arm the zone. Anyway we should do something about it.
		domoticz.notify('Alarm Zone Error!',
			'There was an error for the alarm zone ' .. alarmZone.name,
			domoticz.PRIORITY_HIGH)
	end,

	alarmZoneAlert = function(domoticz, alarmZone, activeSensors, testMode)
		-- It's ALERT TIME!
		local msg = 'Intrusion in zone '..alarmZone.name..'. '
		for _, sensor in ipairs(activeSensors) do
			msg = msg..sensor.name..' tripped @ '..sensor.lastUpdate.raw..'. '
		end
		-- We don't have to turn on/off the alert devices. That's handled by the main script.
		if not testMode then
			domoticz.notify('Alarm Zone Alert!',
				msg, domoticz.PRIORITY_HIGH)
		else
			domoticz.log('(TESTMODE IS ACTIVE) '..msg, domoticz.LOG_INFO)
		end
	end,

	alarmArmingModeChanged = function(domoticz, alarmZone)
		-- The arming mode for a zone has changed. We might want to be informed about that.
		local zoneName = alarmZone.name
		domoticz.notify('Arming mode change',
			'There new arming mode for ' .. alarmZone.name .. ' is ' .. alarmZone.armingMode,
			domoticz.PRIORITY_LOW)
	end,

}

return _C
