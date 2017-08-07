-- Edit this file suit your needs 
-- Then create the folder /path/to/domoticz/scripts/dzVents/modules and place it there
-- renaming it to ideAlarmConfig.lua

-- See https://github.com/allan-gam/ideAlarm/wiki/configuration
-- After editing, always verify that it's valid LUA at http://codepad.org/ (Mark your paste as "Private"!!!)

local _C = {}

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
		classASensors={'dl1a*'},
		classBSensors={'dl1b*', 'md1b*'},
		armAwayToggleBtn='Toggle Z1 Arm Away',
		armAwayTogglesNeeded=1,
		armHomeToggleBtn='Toggle Z1 Arm Home',
		armHomeTogglesNeeded=1,
		mainZone=true
	},
	-- End configuration of the first alarm zone

	-- Start configuration of the second alarm zone
	{
		name='Pembridge Square Residence',
		armingModeTextDevID=551,
		statusTextDevID=555,
		entryDelay=0,
		exitDelay=0,
		alertDevices={'Notting Hill Alert Horn', 'Big Ben Chimes'},
		classASensors={'dl2*', 'Another Switch'},
		classBSensors={},
		armAwayToggleBtn='Toggle Z2 Arm Away',
		armAwayTogglesNeeded=1,
		armHomeToggleBtn='Toggle Z2 Arm Home',
		armHomeTogglesNeeded=1,
		mainZone=false
	},
	-- End configuration of the first second alarm zone

}

return _C
