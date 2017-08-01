-- Note that the first 2 functions below are not helpers (just local functions), helper functions are defined later ...

-- Interact with all switches and sensors using JSON with an optional delay argument
local function jsonAPI(apiCall, delay)
	local domoticzHost = '127.0.0.1'
	local domoticzPort = '8080'
	delay = delay or 0
	local url = 'http://'..domoticzHost..':'..domoticzPort..'/json.htm?'
	os.execute('(sleep '..delay..';curl -s "'..url..apiCall..'" > /dev/null)&')
end

local function urlEncode(str)
	if (str) then
		str = string.gsub (str, '\n', '\r\n')
		str = string.gsub (str, '([^%w ])',
		function (c) return string.format ('%%%02X', string.byte(c)) end)
		str = string.gsub (str, ' ', '+')
	end
	return str
end

return {
	data = {
	},
	helpers = {
	
		-- Setting text devices the "Normal" way currently doesn't cause changes to be triggered upon
		setTextDevice = function(idx, sValue, delay)
			delay = delay or 0
			jsonAPI('type=command&param=udevice&idx='..idx.."&nvalue=0&svalue="..urlEncode(sValue), delay)
		end,
	
		-- Alarm helper functions
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
}
