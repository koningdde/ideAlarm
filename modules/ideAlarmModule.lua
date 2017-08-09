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

local scriptVersion = '0.9.22'
local ideAlarm = {}

-- Possible Zone states
local ZS_NORMAL = 'Normal'
local ZS_ALERT = 'Alert'
local ZS_ERROR = 'Error'
local ZS_TRIPPED = 'Tripped'
local ZS_TIMED_OUT = 'Timed out'
local SENSOR_CLASS_A = 'a' -- Sensor active in both arming modes. E.g. "Armed Home" and "Armed Away".
local SENSOR_CLASS_B = 'b' -- Sensor active in arming mode "Armed Away" only.

-- BELOW ARE 3 TEMPORARY FUNCTIONS THAT WILL BE OBSOLETE WHEN DZVENTS 2.3.0 IS RELEASED 
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
local function setTextDevice(idx, sValue, delay)
	delay = delay or 0
	jsonAPI('type=command&param=udevice&idx='..idx.."&nvalue=0&svalue="..urlEncode(sValue), delay)
end
-- END TEMPORARY FUNCTIONS

local function updateZoneStatus(domoticz, zone, newStatus)
		newStatus = newStatus or ZS_NORMAL
	if domoticz.devices(config.ALARM_ZONES[zone].statusTextDevID).state ~= newStatus then
		setTextDevice(config.ALARM_ZONES[zone].statusTextDevID, newStatus) -- This will trigger this script again
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
		setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, domoticz.SECURITY_DISARMED)
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
		setTextDevice(config.ALARM_ZONES[zone].armingModeTextDevID, armingMode, delay)
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
	for _, alarmZone in ipairs(config.ALARM_ZONES) do
		for _, alertDevice in ipairs(alarmZone.alertDevices) do
			allAlertDevices[alertDevice] = 'Off'
		end
	end

	for _, zoneNumber in ipairs(alertingZones) do
		local alarmZone = config.ALARM_ZONES[zoneNumber]
		domoticz.log('Turning on noise for zone '..alarmZone.name, domoticz.LOG_FORCE)
		for _, alertDevice in ipairs(alarmZone.alertDevices) do
			if not config.ALARM_TEST_MODE then allAlertDevices[alertDevice] = 'On' end
		end

			-- Get a list of all tripped and active sensors for this alerting zone
		tempMessage = tempMessage .. 'Alarm in ' .. alarmZone.name .. '. '
		for sensorName, sensorConfig in pairs(alarmZone.sensors) do
			local sensor = domoticz.devices(sensorName) 
			if (sensor.state == 'On' or sensor.state == 'Open') and (sensor.lastUpdate.minutesAgo < 2) then
				local isActive = (type(sensorConfig.active) == 'function') and sensorConfig.active(domoticz) or sensorConfig.active 
				if isActive then
					tempMessage = tempMessage..sensor.name..' tripped @ '..sensor.lastUpdate.raw..'. '
				end
			end
		end
	end

	if tempMessage ~= '' then
		callIfDefined('alarmAlertMessage')(domoticz, tempMessage, config.ALARM_TEST_MODE)
		domoticz.log(tempMessage, domoticz.LOG_FORCE)
	end

	for alertDevice, newState in pairs(allAlertDevices) do
		if (domoticz.devices(alertDevice) ~= nil)
		and domoticz.devices(alertDevice).state ~= newState then
			domoticz.devices(alertDevice).toggleSwitch()
		end
	end
end

local function onToggleButton(domoticz, device)
	-- Checking if the toggle buttons have been pressed specified number of times within one minute
	for i, alarmZone in ipairs(config.ALARM_ZONES) do
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

	for i, alarmZone in ipairs(config.ALARM_ZONES) do

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
					setTextDevice(alarmZone.statusTextDevID, ZS_ALERT)
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
	
	for i, alarmZone in ipairs(config.ALARM_ZONES) do
		-- Deal with arming mode changes for the main zone
		-- E.g. the text device text for arming mode has changed
		if (device.id == alarmZone.armingModeTextDevID) then
			local armingMode = alarmZone.armingMode
			callIfDefined('alarmArmingModeChanged')(domoticz, i, armingMode, alarmZone.mainZone)

			if alarmZone.syncThisZoneToDomoSec then
				if armingMode ~= domoticz.security then
					domoticz.log('Syncing Domoticz built in Security Panel with the zone '..alarmZone.name..'\'s arming status', domoticz.LOG_INFO)
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
	-- A sensor was tripped.
	for i, alarmZone in ipairs(config.ALARM_ZONES) do
		for sensorName, sensorConfig in pairs(alarmZone.sensors) do
			if sensorName == device.name then
				local isActive = (type(sensorConfig.active) == 'function') and sensorConfig.active(domoticz) or sensorConfig.active 
				if isActive
				and (alarmZone.armingMode == domoticz.SECURITY_ARMEDAWAY or
						(alarmZone.armingMode == domoticz.SECURITY_ARMEDHOME and sensorConfig.class == SENSOR_CLASS_A)) then
					domoticz.log(sensorName..' in zone '..alarmZone.name..' was tripped', domoticz.LOG_INFO)
					local alarmStatus = domoticz.devices(alarmZone.statusTextDevID).state
					if  alarmStatus ~= ZS_TRIPPED and alarmStatus ~= ZS_TIMED_OUT and alarmStatus ~= ZS_ALERT then
						if (alarmZone.entryDelay > 0) then
							setTextDevice(alarmZone.statusTextDevID, ZS_TRIPPED)
						end
						setTextDevice(alarmZone.statusTextDevID, ZS_TIMED_OUT, alarmZone.entryDelay) -- Timer delayed command
					end
	  		end
	  		break -- Let this sensor trigger only once in this zone
  		end
		end
	end
end

local function onSecurityChange(domoticz, triggerInfo)
	-- Domoticz built in Security state has changed, shall we sync the new arming mode to any zone?

	for i, alarmZone in ipairs(config.ALARM_ZONES) do
	
		if alarmZone.syncDomoSecToThisZone then
		
			if alarmZone.syncThisZoneToDomoSec then
				domoticz.log('Configuration error in zone '..alarmZone.name
					..'. Both syncDomoSecToThisZone and syncThisZoneToDomoSec should not used at the same time!', domoticz.LOG_ERROR)
				return
			end

			local newArmingMode = triggerInfo.trigger
			if alarmZone.armingMode ~= newArmingMode then
				domoticz.log('The Domoticz built in Security\'s arming mode changed to '..newArmingMode, domoticz.LOG_INFO)
				domoticz.log('Syncing the new arming mode to zone '..alarmZone.name, domoticz.LOG_INFO)
				if newArmingMode == domoticz.SECURITY_DISARMED then
					ideAlarm.disArmZone(domoticz, zone)
				else
					ideAlarm.armZone(domoticz, zone, newArmingMode)
				end
			end

		end

	end
end

function ideAlarm.execute(domoticz, device, triggerInfo)

	local triggerType

	-- What caused this script to trigger?
	if triggerInfo.type == domoticz.EVENT_TYPE_DEVICE then
		for _, alarmZone in ipairs(config.ALARM_ZONES) do
			if device.deviceSubType == 'Text' then
				if device.id == alarmZone.statusTextDevID then
					triggerType = 'status' -- Alarm Zone Status change
					break
				elseif device.id == alarmZone.armingModeTextDevID then
					triggerType = 'armingMode' -- Alarm Zone Arming Mode change
					break
				end
			elseif device.state == 'Open' or device.state == 'On' then
				if device.name == alarmZone.armAwayToggleBtn or device.name == alarmZone.armHomeToggleBtn then
					triggerType = 'toggleSwitch'
					break
				end
			else
				do return end  -- We are not interested in 'Closed' or 'Off' states
			end
		end
		triggerType = triggerType or 'sensor'
	elseif triggerInfo.type == domoticz.EVENT_TYPE_SECURITY then
		triggerType = triggerType or 'security'
	end
		
	domoticz.log('triggerType '.. triggerType, domoticz.LOG_INFO)

	-- Retrieve and save current alarm zones arming mode and status in the config.ALARM_ZONES table
	for _, alarmZone in ipairs(config.ALARM_ZONES) do
		alarmZone.armingMode = domoticz.devices(alarmZone.armingModeTextDevID).state
		alarmZone.status = domoticz.devices(alarmZone.statusTextDevID).state
	end

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
	elseif triggerType == 'security' then
		onSecurityChange(domoticz, triggerInfo)
	end

end

function ideAlarm.version()
	return('ideAlarm V'..scriptVersion)
end

function ideAlarm.statusAll(domoticz)
	local statusTxt = '\n\n'..ideAlarm.version()..'\nListing alarm zones and sensors:\n\n'
	for i, alarmZone in ipairs(config.ALARM_ZONES) do
		statusTxt = statusTxt..'Zone #'..tostring(i)..': '..alarmZone.name
			..((alarmZone.mainZone) and ' (Main Zone) ' or '')
			..((alarmZone.syncThisZoneToDomoSec) and ' (Sync to Domo Sec) ' or '')
			..((alarmZone.syncDomoSecToThisZone) and ' (Sync Domo Sec to zone) ' or '')
			..', '..domoticz.devices(alarmZone.armingModeTextDevID).state
			..', '..domoticz.devices(alarmZone.statusTextDevID).state..'\n===========================================\n'
		-- List all sensors for this zone
		for sensorName, sensorConfig in pairs(alarmZone.sensors) do
			local sensor = domoticz.devices(sensorName) 
			local isActive = (type(sensorConfig.active) == 'function') and sensorConfig.active(domoticz) or sensorConfig.active 
			statusTxt = statusTxt..sensor.name
				..(isActive and ': Active,' or ': Not active,')
				..((sensor.state == 'On' or sensor.state == 'Open') and ' Tripped' or ' Not tripped')..'\n'
		end
		statusTxt = statusTxt..'\n'
	end
	return statusTxt
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

	for _, alarmZone in ipairs(config.ALARM_ZONES) do
		for _, alertDevice in ipairs(alarmZone.alertDevices) do
			allAlertDevices[alertDevice] = 'On'
		end
	end

	local tempMessage = ideAlarm.statusAll(domoticz)
	callIfDefined('alarmAlertMessage')(domoticz, tempMessage, config.ALARM_TEST_MODE)
	domoticz.log(tempMessage, domoticz.LOG_FORCE)

	for alertDevice, _ in pairs(allAlertDevices) do
		domoticz.log(alertDevice, domoticz.LOG_FORCE)
		domoticz.devices(alertDevice).switchOn()
		domoticz.devices(alertDevice).switchOff().afterSec(5)
	end

	return true
end

function ideAlarm.qtyAlarmZones()
	return(#config.ALARM_ZONES)
end

function ideAlarm.mainZone()
	for index, zone in ipairs(config.ALARM_ZONES) do
		if zone.mainZone then return index end
	end
	return(nil)
end

function ideAlarm.armingModeDevIdx(zone)
	zone = zone or ideAlarm.mainZone()
	if zone then return(config.ALARM_ZONES[zone].armingModeTextDevID) end
	return(nil)
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
	for _, alarmZone in ipairs(config.ALARM_ZONES) do
		if alarmZone.armAwayToggleBtn ~= '' then table.insert(tDevs, alarmZone.armAwayToggleBtn) end
		if alarmZone.armHomeToggleBtn ~= '' then table.insert(tDevs, alarmZone.armHomeToggleBtn) end
		table.insert(tDevs, alarmZone.statusTextDevID)
		table.insert(tDevs, alarmZone.armingModeTextDevID)
		-- We don't have a domoticz object at this stage. Otherwise we could check the arming mode and insert
		-- only the trigger devices relevant to the alarm zones current arming mode
		for sensorName, _ in pairs(alarmZone.sensors) do
  		table.insert(tDevs, sensorName)
		end
	end
	return(tDevs)
end

return ideAlarm
