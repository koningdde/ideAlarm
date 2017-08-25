**If upgrading from previous versions**
Below are important instructions if you are upgrading ideAlarm from a previous version. If you make a new installation you can ignore what follows.

**PLEASE MAKE SURE THAT YOU GO THROUGH ALL STEPS BELOW WHERE IT SAYS "BREAKING CHANGE", DON'T SKIP ANY VERSION**

***Version 2.0.2***
- Removed hard coding of local protocol, IP and port.

***Version 2.0.1***
- Fixed an issue where nagging occured to often.

***Version 2.0.0***
- **BREAKING CHANGE** Action is required if upgrading from a previous version. The configuration file has 2 new variables and another old variable has changed name. Therefore you should make a change in your file **ideAlarmConfig.lua** (located in the modules folder) Please add the variables **_C.NAG_SCRIPT_TRIGGER_INTERVAL** and **_C.NAG_INTERVAL_MINUTES** as you can see in the [configuration file example](https://github.com/allan-gam/ideAlarm/blob/master/modules/ideAlarmConfigExample.lua). Then for every sensor that you have defined, there is a variable named **nagTimeoutSecs**. Rename all of those to **nagTimeoutMins** and change the value to 5.
- Two new custom optional helper functions can now be used. You don't have to define them, but if you wish to use them, the examples can be seen at the very end of The example custom [event helper](https://github.com/allan-gam/ideAlarm/wiki/Event-Helpers). The new functions are named **alarmNagOpenSensors** and **alarmOpenSensorsAllZones**. You can read about them in the Wiki.

***Version 1.1.0***
- Added the new zone state alarm.***ZS_ARMING***. A new ideAlarm custom helper function (***alarmZoneArming***) can now be used.

***Version 1.0.3***
- Logic improvements.
- **BREAKING CHANGE** Action is required if upgrading from a previous version. The custom [event helper](https://github.com/allan-gam/ideAlarm/wiki/Event-Helpers) function **alarmZoneArmingWithTrippedSensors**
has an additional argument and the logic in the example file has changed. Therefore you should make a change in your file **ideAlarmHelpers.lua**
(located in the modules folder). Please have a look at the function **alarmZoneArmingWithTrippedSensors** in the [The example helpers file](https://raw.githubusercontent.com/allan-gam/ideAlarm/master/modules/ideAlarmHelpersExample.lua) what it should look like.

***Version 1.0.2***
- Minor fixes.

***Version 1.0.1***
- Minor fixes.

***Version 1.0.0***
- Initial release.
