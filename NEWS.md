Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Update zram-config ## November 7, 2021
The ability to update zram-config without having to uninstall and reinstall has
been added. Use menu option 38 and select "Update zram" to update your existing
installation without losing any configuration settings.

## Forward web proxy ## September 28, 2021
Installing nginx (menu option 44) will now provide a *forward* proxy on port
8888 in addition to the reverse proxy setup it has been providing.
Configure this as a manual proxy in your browser to access devices in remote
(VPN) locations by their IP.

## Install openHAB function changed ## July 23, 2021
Menu option 03 "Install or upgrade to openHAB 3" has been changed to now
actually do what it claims it will do: only install or upgrade to openHAB 3, it
will not update an existing installation, please use menu option 2 for updates.
Menu option 03 will also properly migrate an openHAB 2 environment to the
current openHAB 3 "stable" version.
