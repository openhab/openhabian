Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Install openHAB function changed ## July 23, 2021
Menu option 03 "Install or upgrade to openHAB 3" has been changed to now
actually do what it claims it will do: only install or upgrade to openHAB 3, it
will not update an existing installation, please use menu option 2 for updates.
Menu option 03 will also properly migrate an openHAB 2 environment to the
current openHAB 3 "stable" version.

## Telldus Core service removed ## May 20, 2021
The Telldus Core service has now been removed from openHABian, and will no
longer receive active support from the openHABian developers. Existing
installations will be unaffected. The service was removed as it had become too
difficult to maintain as a result of it requiring packages that are no longer
provided by the Debian distribution used in openHABian. If you would like to
install it on your own please see [this](https://community.openhab.org/t/89856)
forum thread for some guidance.

## deCONZ / Phoscon companion app added ## May 10, 2021
There's a new menu option to install the deCONZ software / Phoscon companion app
to support the popular Dresden Elektronik Conbee and Raspbee ZigBee controllers.
Note you will need to use the [deconz binding](https://www.openhab.org/addons/bindings/deconz/)
and pair your devices using the Phoscon web interface running on port 8081.
