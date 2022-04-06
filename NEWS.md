Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Electric Vehicle Charge Controller ## April 6, 2022
EVCC controls charging of your EV. It supports many wallboxes and vehicles.
While there's some overlap with OH, EVCC has a two-way API and users can 
selectively combine the best of both worlds.

## Raspberry Pi OS 64bit support ## April 1, 2022
No, not an April Fools joke. It is finally here. The title says it all.

## Major Java provider switch ## December 15, 2021
We have switched to supporting only the OpenJDK package provided by default 
from the APT repo for all new installations of openHABian.
Existing installations will be unaffected, however you will no longer receive 
updates to your current Java install until you install Java from the new 
provider which you can do by running menu option 45.

Experimental support for Java 17 has also been added along with this change. In
the future once Adoptium (formerly AdoptOpenJDK) releases a Debian based package
repository support for Adoptium Java installs will be added as well.

## Node-RED and openHAB 3 ## December 10, 2021
We have updated the package of the Node-RED addon for openHAB 3 to
`node-red-contrib-openhab3` to better support openHAB 3 installations which use
this addon.

You can install it today using `openhabian-config` menu option 25, which will
install / upgrade all necessary components for Node-RED operation.
