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
local config = require "ideAlarmConfig"
local custom = require "ideAlarmHelpers"

local scriptVersion = '0.9.5'
local ideAlarm = {}

-- Possible Zone states
local ZS_NORMAL = 'Normal'
local ZS_ALERT = 'Alert'
local ZS_ERROR = 'Error'
local ZS_TRIPPED = 'Tripped'
local ZS_TIMED_OUT = 'Timed out'

local function updateZoneStatus(domoticz, zone, newStatus)
		newStatus = newStatus or ZS_NORMAL
	if domoticz.devices(config.ALARM_ZONES[zone].statusTextDevID).state ~= newStatus then
		domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].statusTextDevID, newStatus) -- This will trigger this script again
		domoticz.log(config.ALARM_ZONES[zone].name..' new status: '..newStatus, domoticz.LOG_INFO)
	end
end

local function callIfDefined(f)
	return function(...)
		local error, result = pcall(custom.helpers[f], ...)
		if error then -- f exists and is callable
			return result
		end
	end
end

function ideAlarm.disArmZone(domoticz, zone)
	-- Disarms a zone unless it's already disarmed. Disarming a zone also resets it's status
	zone = zone or ideAlarm.mainZone()
	if domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state ~= domoticz.SECURITY_DISARMED then
		domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, domoticz.SECURITY_DISARMED)
	end
	updateZoneStatus(domoticz, zone, ZS_NORMAL)
end

function ideAlarm.armZone(domoticz, zone, armingMode, delay)
	-- Arms a zone unless it's already disarmed. Arming a zone also resets it's status
	zone = zone or ideAlarm.mainZone()
	delay = delay or (armingMode == domoticz.SECURITY_ARMEDAWAY and config.ALARM_ZONES[zone].exitDelay or 0)
	armingMode = armingMode or domoticz.SECURITY_ARMEDAWAY

	if domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state ~= armingMode then
		domoticz.log('Arming zone '..config.ALARM_ZONES[zone].name..
			' to '..armingMode..(delay>0 and ' with a delay of '..delay..' seconds' or ' immediately'), domoticz.LOG_INFO)
		domoticz.helpers.setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, armingMode, delay)
	end
	updateZoneStatus(domoticz, zone, ZS_NORMAL)
end

--Function to toggle the zones arming mode between 'Disarmed' and armType
function ideAlarm.toggleArmingMode(domoticz, zone, armingMode)
	zone = zone or ideAlarm.mainZone()
	if config.ALARM_ZONES[zone].mainZone then
		-- This zone is connected to the Domoticz Security Panel Device
	end

	local currentArmingMode = domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state
	local newArmingMode
	newArmingMode = (currentArmingMode ~= domoticz.SECURITY_DISARMED and domoticz.SECURITY_DISARMED or armingMode)

	if newArmingMode == domoticz.SECURITY_DISARMED then
		ideAlarm.disArmZone(domoticz, zone)
	else
		ideAlarm.armZone(domoticz, zone, newArmingMode)
	end

end

local function toggleSirens(domoticz, device, alertingZones)
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

local function onToggleButton(domoticz, device)
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
				ideAlarm.toggleArmingMode(domoticz, i, armType) -- need to prefix function call with module
				armToggleCount = 0
			end
			armToggleData.add(armToggleCount)
		end
	end
end

local function onStatusChange(domoticz, device)
	local alertingZones = {}

	-- Loop through the Zones
	-- Check if any alarm zones status has changed

	for i, alarmZone in pairs(config.ALARM_ZONES) do

		-- Deal with alarm status changes
		if device.id == alarmZone.statusTextDevID then
			domoticz.log('Deal with alarm status changes '.. 'for zone '..alarmZone.name, domoticz.LOG_DEBUG)

			-- Call to optional custom helper function handling alarm status changes for the zone 
			callIfDefined('alarmStatusChange')(domoticz, i, alarmZone.status)

			if alarmZone.status == ZS_NORMAL then
				-- Nothing more to do here
			elseif alarmZone.status == ZS_ALERT then
				table.insert(alertingZones, i)
			elseif alarmZone.status == ZS_ERROR then
				domoticz.log('An error has occurred for alarm zone  '..alarmZone.name, domoticz.LOG_ERROR)
			elseif alarmZone.status == ZS_TRIPPED then
				callIfDefined('alarmZoneTripped')(domoticz, i)
			elseif alarmZone.status == ZS_TIMED_OUT then
				if alarmZone.armingMode ~= domoticz.SECURITY_DISARMED then
					-- A sensor was tripped, delay time has passed and the zone is still armed so ...
					domoticz.helpers.setTextDevice(alarmZone.statusTextDevID, ZS_ALERT)
					callIfDefined('alarmZoneAlert')(domoticz, i)
				else
					domoticz.log('No need for any noise, the zone is obviously disarmed now.', domoticz.LOG_INFO)
					updateZoneStatus(domoticz, i, ZS_NORMAL)
				end
			end

		end
	end

	toggleSirens(domoticz, device, alertingZones)
end

local function onArmingModeChange(domoticz, device)
	-- Loop through the Zones
	-- Check if any alarm zones arming mode changed
	
	for i, alarmZone in pairs(config.ALARM_ZONES) do
		-- Deal with arming mode changes for the main zone
		-- E.g. the text device text for arming mode has changed
		if (device.id == alarmZone.armingModeTextDevID) then
			local armingMode = alarmZone.armingMode
			callIfDefined('alarmArmingModeChanged')(domoticz, i, armingMode, alarmZone.mainZone)

			if alarmZone.mainZone then
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

end

local function onSensorChange(domoticz, device)
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
end

function ideAlarm.execute(domoticz, device)

	local triggerType = ''
	for i, alarmZone in pairs(config.ALARM_ZONES) do

		-- Retrieve and save current alarm zones arming mode and status in the config.ALARM_ZONES table
		alarmZone['armingMode'] = domoticz.devices(alarmZone.armingModeTextDevID).state
		alarmZone['status'] = domoticz.devices(alarmZone.statusTextDevID).state

	-- What caused this script to trigger?
		if triggerType == '' then
			if device.deviceSubType == 'Text' then
				if device.id == alarmZone.statusTextDevID then
					triggerType = 'status' -- Alarm Zone Status change
				elseif device.id == alarmZone.armingModeTextDevID then
					triggerType = 'armingMode' -- Alarm Zone Arming Mode change
				end
			elseif device.state == 'Open' or device.state == 'On' then
				if device.name == alarmZone.armAwayToggleBtn or device.name == alarmZone.armHomeToggleBtn then
					triggerType = 'toggleSwitch'
				end
			else
				triggerType = 'irrelevant' -- We are not interested in 'Closed' or 'Off' states 
			end
		end
	
	end

	if triggerType == '' then triggerType = 'sensor' end
	if triggerType == 'irrelevant' then do return end end
	
	domoticz.log('triggerType '.. triggerType, domoticz.LOG_INFO)
	
	if triggerType == 'toggleSwitch' then
		onToggleButton(domoticz, device)
		do return end
	elseif triggerType == 'status' then
		onStatusChange(domoticz, device)
		do return end
	elseif triggerType == 'armingMode' then
		onArmingModeChange(domoticz, device)
		do return end
	elseif triggerType == 'sensor' then
		onSensorChange(domoticz, device)
		do return end
	end

end

function ideAlarm.version()
	return('ideAlarm V'..scriptVersion)
end

function ideAlarm.statusAll(domoticz)
	local statusTxt = '\n\nStatus for all '..tostring(#config.ALARM_ZONES)..' alarm zones:\n'
	for i=1, #config.ALARM_ZONES do
		statusTxt = statusTxt..config.ALARM_ZONES[i]['name']..': '..domoticz.devices(config.ALARM_ZONES[i].armingModeTextDevID).state..', '..domoticz.devices(config.ALARM_ZONES[i].statusTextDevID).state..'\n'
	end
	return statusTxt..'\n'
end

function ideAlarm.armingMode(domoticz, zone)
	-- Retrieves an alarm zones current arming mode 
	zone = zone or ideAlarm.mainZone()
	return domoticz.devices(config.ALARM_ZONES[zone].armingModeTextDevID).state
end

function ideAlarm.isArmed(domoticz, zone)
	-- Retrieves an alarm zones current arming mode 
	zone = zone or ideAlarm.mainZone()
	return(ideAlarm.armingMode(domoticz, zone) ~= domoticz.SECURITY_DISARMED)  
end

function ideAlarm.isArmedHome(domoticz, zone)
	-- Retrieves an alarm zones current arming mode 
	zone = zone or ideAlarm.mainZone()
	return(ideAlarm.armingMode(domoticz, zone) == domoticz.SECURITY_ARMEDHOME)  
end

function ideAlarm.isArmedAway(domoticz, zone)
	-- Retrieves an alarm zones current arming mode 
	zone = zone or ideAlarm.mainZone()
	return(ideAlarm.armingMode(domoticz, zone) == domoticz.SECURITY_ARMEDHOME)  
end

function ideAlarm.testAlert(domoticz)

	if config.ALARM_TEST_MODE then
		domoticz.log('Can not test alerts! Please disable ALARM_TEST_MODE in configuration file first.' , domoticz.LOG_ERROR)
		return false
	end

	local allAlertDevices = {}
	for i=1, #config.ALARM_ZONES do
		local zone = config.ALARM_ZONES[i]
		for j=1, #zone.alertDevices do
			allAlertDevices[zone.alertDevices[j]] = 'On'
		end
	end

	local tempMessage = ideAlarm.statusAll(domoticz)
	callIfDefined('alarmAlertMessage')(domoticz, tempMessage, config.ALARM_TEST_MODE)
	domoticz.log(tempMessage, domoticz.LOG_FORCE)

	for key,value in pairs(allAlertDevices) do
		domoticz.log(key, domoticz.LOG_FORCE)
		domoticz.devices(key).switchOn()
		domoticz.devices(key).switchOff().afterSec(5)
	end

	return true
end

function ideAlarm.qtyAlarmZones()
	return(#config.ALARM_ZONES)
end

function ideAlarm.mainZone()
	for index, value in ipairs(config.ALARM_ZONES) do
		if value['mainZone'] == true then
			return index
		end
	end
	return(nil)
end

function ideAlarm.armingModeDevIdx(zone)
	zone = zone or ideAlarm.mainZone()
	if zone ~= nil then 
		return(config.ALARM_ZONES[zone].armingModeTextDevID)
	else
		return nil
	end
end

function ideAlarm.persistentVariables()
	local pData = {}
	for i, alarmZone in pairs(config.ALARM_ZONES) do
		pData['armAwayToggleBtn'..i] = {history = true, maxItems = 1, maxMinutes = 1} -- Used for counting if switch was pressed multiple times
		pData['armHomeToggleBtn'..i] = {history = true, maxItems = 1, maxMinutes = 1} -- Used for counting if switch was pressed multiple times
	end
	return(pData)
end

function ideAlarm.triggerDevices()
	local tDevs = {}
	for i, alarmZone in pairs(config.ALARM_ZONES) do
		if alarmZone.armAwayToggleBtn ~= '' then table.insert(tDevs, alarmZone.armAwayToggleBtn) end
		if alarmZone.armHomeToggleBtn ~= '' then table.insert(tDevs, alarmZone.armHomeToggleBtn) end
		table.insert(tDevs, alarmZone.statusTextDevID)
		table.insert(tDevs, alarmZone.armingModeTextDevID)
		-- We don't have a domoticz object at this stage. Otherwise we could check the arming mode and insert
		-- only the trigger devices relevant to the alarm zones current arming mode
		for j, sensor in ipairs(alarmZone.classASensors) do
  		table.insert(tDevs, sensor)
		end
		for j, sensor in ipairs(alarmZone.classBSensors) do
  		table.insert(tDevs, sensor)
		end
	end
	return(tDevs)
end

return ideAlarm
