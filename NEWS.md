Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.


## Node-RED and openHAB 3 ## December 10, 2021
We have updated the package of the Node-RED addon for openHAB 3 to
`node-red-contrib-openhab3` to better support openHAB 3 installations which use
this addon.

You can install it today using `openhabian-config` menu option 25, which will
install / upgrade all necessary components for Node-RED operation.

## openHABian 1.7 ## December 1, 2021
We have upgraded our base operating system to Raspberry Pi OS Bullseye.

As usual upgrades on supported systems will be unaffected, use the
`openhabian-config` menu to apply any updates available to your system. We will
not automatically update your current base system (i.e buster -> bullseye) -
don't fix what ain't broke. Debian buster will be at least supported two more
years. If you are eager to upgrade, read up on `dist-upgrade` or reinstall your
system. Please note that if you choose to upgrade and not reinstall, you are on
your own, don't expect to get support from the developers of openHABian if
something goes wrong.

Noteworthy changes since last image release:
  * New base OS: Raspberry Pi OS Bullseye
  * Added support for Raspberry Pi Zero 2 W
  * Ability to update zram without reinstalling it
  * More robust Java install routine
  * Fixed Amanda install not prompting for email address to send reports to
  * General bug fixes

Known bugs:
  * Homegear is currently broken on Bullseye (complain to their devs)

## Update zram-config ## November 7, 2021
The ability to update zram-config without having to uninstall and reinstall has
been added. Use menu option 38 and select "Update zram" to update your existing
installation without losing any configuration settings.
