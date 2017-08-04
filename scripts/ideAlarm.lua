--[[
ideAlarm.lua

Please read: https://github.com/allan-gam/ideAlarm/wiki

Copyright (C) 2017  BakSeeDaa

		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU General Public License as published by
		the Free Software Foundation, either version 3 of the License, or
		(at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program.  If not, see <http://www.gnu.org/licenses

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
		devices = triggerDevices
	},
	data = persistentVariables,
	execute = function(domoticz, device)

		domoticz.log('Triggered by device: '..device.name..', device state is: '..device.state, domoticz.LOG_DEBUG)
		alarm.execute(domoticz, device)

	end
}
