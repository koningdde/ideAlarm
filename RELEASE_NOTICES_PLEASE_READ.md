
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
