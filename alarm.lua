--[[
alarm.lua

Please read: https://github.com/allan-gam/domoticz-dzVents-alarm/wiki

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

local scriptVersion = '0.9.1'

package.path = globalvariables['script_path']..'modules/?.lua;'..package.path
--print(package.path)
local config = require "alarm_config"

-- Create the data declarations and toggleButtons array
local data = {}
local toggleButtons = {}
local triggerDevices = {'dl*', 'wl*', 'md*', 'pb*'}

for i, alarmZone in pairs(config.ALARM_ZONES) do
	data['armAwayToggleBtn'..i] = {history = true, maxItems = 1, maxMinutes = 1} -- Used for counting if switch was pressed multiple times
	data['armHomeToggleBtn'..i] = {history = true, maxItems = 1, maxMinutes = 1} -- Used for counting if switch was pressed multiple times
	if alarmZone.armAwayToggleBtn ~= '' then table.insert(triggerDevices, alarmZone.armAwayToggleBtn) end
	if alarmZone.armHomeToggleBtn ~= '' then table.insert(triggerDevices, alarmZone.armHomeToggleBtn) end
	table.insert(triggerDevices, alarmZone.statusTextDevID)
	table.insert(triggerDevices, alarmZone.armingModeTextDevID)
end

return {
	active = true,
	logging = {
		level = domoticz.LOG_INFO, -- Select one of LOG_DEBUG, LOG_INFO, LOG_ERROR, LOG_FORCE to override system log level
		marker = 'alarm '..scriptVersion
	},
	on = {
		devices = triggerDevices
	},
	data = data,
	execute = function(domoticz, device)

		-- Possible Zone states
		local ZS_NORMAL = 'Normal'
		local ZS_ALERT = 'Alert'
		local ZS_ERROR = 'Error'
		local ZS_TRIPPED = 'Tripped'
		local ZS_TIMED_OUT = 'Timed out'

		domoticz.log('Alarm script triggered by device: '..device.name..', device state is: '..device.state, domoticz.LOG_DEBUG)

		-- Calls a helper function if it has been defined. Otherwise does nothing really.
		local function callIfDefined(f)
			return function(...)
				local error, result = pcall(config.helpers[f], ...)
				if error then -- f exists and is callable
					return result
				end
			end
		end

		local function updateZoneStatus(zone, newStatus)
				newStatus = newStatus or ZS_NORMAL
			if domoticz.devices(config.ALARM_ZONES[zone].statusTextDevID).state ~= newStatus then
				domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].statusTextDevID, newStatus) -- This will trigger this script again
				domoticz.log(config.ALARM_ZONES[zone].name..' new status: '..newStatus, domoticz.LOG_INFO)
			end
		end

		local function disArmZone(zone)
			-- Disarms a zone unless it's already disarmed. Disarming a zone also resets it's status
			if domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state ~= domoticz.SECURITY_DISARMED then
				domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, domoticz.SECURITY_DISARMED)
			end
			updateZoneStatus(zone, ZS_NORMAL)
		end

		local function armZone(zone, armingMode, delay)
			-- Arms a zone unless it's already disarmed. Arming a zone also resets it's status
			delay = delay or 0
			armingMode = armingMode or domoticz.SECURITY_ARMEDAWAY
			if domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state ~= armingMode then
				domoticz.log(config.ALARM_ZONES[zone].name..' new arming mode: '..armingMode, domoticz.LOG_INFO)
				domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, armingMode, delay)
			end
			updateZoneStatus(zone, ZS_NORMAL)
		end

		local function toggleSirens(alertingZones)
			local tempMessage = ''
			local allAlertDevices = {}
			for i=1, #config.ALARM_ZONES do
				local zone = config.ALARM_ZONES[i]
				for j=1, #zone.alertDevices do
					allAlertDevices[zone.alertDevices[j]] = 'Off'
				end
			end

			for i=1, #alertingZones do
				local zone = config.ALARM_ZONES[alertingZones[i]]
				domoticz.log('Turning on noise for zone '..zone.name, domoticz.LOG_FORCE)
				for j=1, #zone.alertDevices do
					if not config.ALARM_TEST_MODE then allAlertDevices[zone.alertDevices[j]] = 'On' end
				end

				-- Get a list of the tripped sensors for the zone
				tempMessage = tempMessage .. 'Alarm in ' .. zone.name .. '. '
				local alarmSensors = domoticz.devices().filter(function(device)
					local u = device.name:sub(1,2) -- Get alarm sensor type from device name
					v = tonumber(device.name:sub(3,3)) -- Get Zone number from device name
					return (
						(u == 'dl' or u == 'wl' or u == 'md' or u == 'pb')
						and device.lastUpdate.minutesAgo < 2
						and (v ~= nil) 
						and v == alertingZones[i]
					)
				end)
				alarmSensors.forEach(function(alarmSensor)
					local c = alarmSensor.name:sub(6)
					tempMessage = tempMessage .. c ..' tripped @ '..alarmSensor.lastUpdate.raw..'. '
				end)
			end

			if tempMessage ~= '' then
				callIfDefined('alarmAlertMessage')(domoticz, tempMessage, config.ALARM_TEST_MODE)
				domoticz.log(tempMessage, domoticz.LOG_FORCE)
			end

			for key,value in pairs(allAlertDevices) do
				if (domoticz.devices(key) ~= nil)
				and domoticz.devices(key).state ~= value then
					domoticz.devices(key).toggleSwitch()
				end
			end
		end

		local alertingZones = {}

		-- Loop through the Zones
		for i=1, #config.ALARM_ZONES do

			-- Retrieve and save current alarm zones arming mode and status in the config.ALARM_ZONES table
			config.ALARM_ZONES[i]['armingMode'] = domoticz.devices(config.ALARM_ZONES[i].armingModeTextDevID).state
			config.ALARM_ZONES[i]['status'] = domoticz.devices(config.ALARM_ZONES[i].statusTextDevID).state

			-- Deal with alarm status changes
			if device.id == config.ALARM_ZONES[i].statusTextDevID then
				domoticz.log('Deal with alarm status changes '.. 'for zone '..config.ALARM_ZONES[i].name, domoticz.LOG_DEBUG)

				-- Call to optional custom helper function handling alarm status changes for the zone 
				callIfDefined('alarmStatusChange')(domoticz, i, config.ALARM_ZONES[i].status)

				if config.ALARM_ZONES[i].status == ZS_NORMAL then
					-- Nothing more to do here
				elseif config.ALARM_ZONES[i].status == ZS_ALERT then
					table.insert(alertingZones, i)
				elseif config.ALARM_ZONES[i].status == ZS_ERROR then
					domoticz.log(config.ALARM_ZONES[i].name..' an error has occurred for alarm zone  '..config.ALARM_ZONES[i].name, domoticz.LOG_ERROR)
				elseif config.ALARM_ZONES[i].status == ZS_TRIPPED then
					callIfDefined('alarmZoneTripped')(domoticz, i)
				elseif config.ALARM_ZONES[i].status == ZS_TIMED_OUT then
					if config.ALARM_ZONES[i].armingMode ~= domoticz.SECURITY_DISARMED then
						-- A sensor was tripped, delay time has passed and the zone is still armed so ...
						domoticz.helpers.setTextDevice(config.ALARM_ZONES[i].statusTextDevID, ZS_ALERT)
						callIfDefined('alarmZoneAlert')(domoticz, i)
					else
						domoticz.log('No need for any noise, the zone is obviously disarmed now.', domoticz.LOG_INFO)
						updateZoneStatus(i, ZS_NORMAL)
					end
				end

			end

			-- Deal with arming mode changes for the main zone
			-- E.g. the text device text for arming mode has changed
			if (device.id == config.ALARM_ZONES[i].armingModeTextDevID) then
				local armingMode = config.ALARM_ZONES[i]['armingMode']
				callIfDefined('alarmArmingModeChanged')(domoticz, i, armingMode, config.ALARM_ZONES[i].mainZone)

				if (config.ALARM_ZONES[i].mainZone == true) then
					-- Syncing Domoticz built in Security Panel with the main zones arming status
					if armingMode ~= domoticz.security then
						domoticz.log('Syncing Domoticz built in Security Panel with the main zones arming status', domoticz.LOG_INFO)
						if armingMode == domoticz.SECURITY_DISARMED then
							domoticz.devices('Security Panel').disarm()
						elseif armingMode == domoticz.SECURITY_ARMEDHOME then
							domoticz.devices('Security Panel').armHome()
						elseif armingMode == domoticz.SECURITY_ARMEDAWAY then
							domoticz.devices('Security Panel').armAway()
						end
					end
				end

			end

		end

		toggleSirens(alertingZones)

		-- Has an alarm situation arised caused by the change of the current sensor?
		-- Get sensor devices by filtering on devices names
		local v
		if device.state == 'Open' or device.state == 'On' then
			local alarmSensors = domoticz.devices().filter(function(device)
				local u = device.name:sub(1,2) -- Get alarm sensor type from device name
				v = tonumber(device.name:sub(3,3)) -- Get Zone number from device name
				local x = device.name:sub(4,4) -- Get alarm class from device name.

				return (
					(u == 'dl' or u == 'wl' or u == 'md' or u == 'pb')
					and (v ~= nil) 
					and v >= 1 and v <= #config.ALARM_ZONES
					and (config.ALARM_ZONES[v].armingMode == domoticz.SECURITY_ARMEDAWAY or
					(config.ALARM_ZONES[v].armingMode == domoticz.SECURITY_ARMEDHOME and x == 'a'))
					)
			end)
			alarmSensors.forEach(function(alarmSensor)
				if device.name == alarmSensor.name then
					v = tonumber(device.name:sub(3,3)) -- Get Zone number from device name. Must do again! Why?
					domoticz.log(alarmSensor.name..' in zone '..config.ALARM_ZONES[v].name..' was tripped', domoticz.LOG_INFO)
					if  domoticz.devices(config.ALARM_ZONES[v].statusTextDevID).state ~= ZS_TRIPPED
					and domoticz.devices(config.ALARM_ZONES[v].statusTextDevID).state ~= ZS_TIMED_OUT
					and domoticz.devices(config.ALARM_ZONES[v].statusTextDevID).state ~= ZS_ALERT then
						if (config.ALARM_ZONES[v].entryDelay > 0) then
							domoticz.helpers.setTextDevice(config.ALARM_ZONES[v].statusTextDevID, ZS_TRIPPED)
						end
						domoticz.helpers.setTextDevice(config.ALARM_ZONES[v].statusTextDevID, ZS_TIMED_OUT, config.ALARM_ZONES[v].entryDelay) -- Timer delayed command
					end
				end
			end)
		end

		--Function to toggle the zones arming mode between 'Disarmed' and armType
		local function toggleArmingMode(zone, armType)
			if config.ALARM_ZONES[zone].mainZone then
				-- This zone is connected to the Domoticz Security Panel Device
			end

			local currentArmingMode = domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state
			local newArmingMode
			newArmingMode = (currentArmingMode ~= domoticz.SECURITY_DISARMED and domoticz.SECURITY_DISARMED or armType)
			local delay = (newArmingMode == domoticz.SECURITY_ARMEDAWAY and config.ALARM_ZONES[zone].exitDelay or 0)
			domoticz.log('Toggling arming mode for zone '..config.ALARM_ZONES[zone].name..
				' from '..currentArmingMode..' to '..newArmingMode..(delay>0 and ' with a delay of '..delay..' seconds' or ' immediately'), domoticz.LOG_INFO)

			if newArmingMode == domoticz.SECURITY_DISARMED then
				disArmZone(zone)
			else
				armZone(zone, newArmingMode, delay)
			end

		end

		-- Checking if the toggle buttons have been pressed specified number of times within one minute
		for i, alarmZone in pairs(config.ALARM_ZONES) do
			if device.state == 'On' and (device.name == alarmZone.armAwayToggleBtn or device.name == alarmZone.armHomeToggleBtn) then
				local armToggleData, qtyNeeded, armType
				if device.name == alarmZone.armAwayToggleBtn then
					armToggleData = domoticz.data['armAwayToggleBtn'..i]
					qtyNeeded = alarmZone.armAwayTogglesNeeded
					armType = domoticz.SECURITY_ARMEDAWAY
				else
					armToggleData = domoticz.data['armHomeToggleBtn'..i]
					qtyNeeded = alarmZone.armHomeTogglesNeeded
					armType = domoticz.SECURITY_ARMEDHOME
				end
				if (armToggleData.size == 0) then armToggleData.add(0) end
				local armToggleCount = armToggleData.getLatest().data + 1
				if armToggleCount >= qtyNeeded then
					domoticz.log(armType.. ' toggle button for Alarm Zone '..alarmZone.name..' was pressed '
						..armToggleCount..' time(s)!', domoticz.LOG_INFO)
					toggleArmingMode(i, armType)
					armToggleCount = 0
				end
				armToggleData.add(armToggleCount)
			end
		end

	end
}
