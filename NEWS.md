Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Install openHAB function changed ## July 23, 2021
Menu option 03 "Install or upgrade to openHAB release 3" was changed to now
actually do what most users have been expecting it to: it now also upgrades
the environment to work with openHAB3 and installs openHAB3 "stable" version.
Previously, you had to additionally use menu option 42 to migrate the
environment.

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

## New `openhabian.conf` option `initialconfig` ## May 9, 2021
This new option allows to automatically import an openHAB 3 backup from a file
or URL.
