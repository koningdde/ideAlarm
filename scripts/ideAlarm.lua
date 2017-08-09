--[[
ideAlarm.lua

Please read: https://github.com/allan-gam/ideAlarm/wiki

Note that any changes to this file will be lost when upgrading.
--]]

package.path = globalvariables['script_path']..'modules/?.lua;'..package.path
--print(package.path)
local alarm = require "ideAlarmModule"

local persistentVariables = alarm.persistentVariables()
local triggerDevices = alarm.triggerDevices()

return {
	active = true,
	logging = {
		level = domoticz.LOG_INFO, -- Select one of LOG_DEBUG, LOG_INFO, LOG_ERROR, LOG_FORCE to override system log level
		marker = alarm.version()
	},
	on = {
		devices = triggerDevices,
		security = {domoticz.SECURITY_ARMEDAWAY, domoticz.SECURITY_ARMEDHOME, domoticz.SECURITY_DISARMED}
	},
	data = persistentVariables,
	execute = function(domoticz, device, triggerInfo)

		domoticz.log('Triggered by '..((device) and 'device: '..device.name..', device state is: '..device.state or 'Domoticz Security'), domoticz.LOG_DEBUG)
		alarm.execute(domoticz, device, triggerInfo)

	end
}
