Hit tab to unselect buttons and scroll through the text using UP/DOWN or PGUP/PGDN.
All announcements are stored in `/opt/openhabian/docs/NEWSLOG.md` for you to lookup.

## Bintray shutdown ## May 3, 2021
Bintray, our hoster for the stable openHAB software distribution, has shutdown their
support for Open Source projects like ours effective May, 1st so you need to replace
any bintray repositories. We have moved to Artifactory.
openhabian-config will ask you on start about replacing the openhab stable repo.
Check /etc/apt/sources.list.d/* afterwards just in case.
Also check if you still use dynamically downloaded addons (remote=true in
/etc/openhab/services/addons.cfg or see the corresponding UI setting under
System Services "Add-On Management").


## Future of master branch ## January 20, 2021
We will no longer make regular updates to the master branch as we migrate away from
supporting openHAB2.
As such in the coming months we will make bug fixes directly to the 'stable' branch
for openHA2.
With that said, please migrate off of the 'master' branch as it will be deleted soon.
You can change branches at any time use menu option 01.


## openHAB 3 released ## December 21, 2020
In the darkest of times (midwinter for most of us), openHAB 3 gets released.
See [documentation](docs/openhabian.md#on-openhab3) and [www.openhab.org](http://www.openhab.org) for details.

Merry Christmas and a healthy New Year!


## WiFi Hotspot ## November 14, 2020
Whenever your system has a WiFi interface that fails to initialize on installation or startup,
openHABian will now launch a [WiFi hotspot](docs/openhabian.md#WiFi-Hotspot) you can use to connect your system to an existing WiFi network.


## Tailscale VPN network ## October 6, 2020
Tailscale is a management toolset to establish a WireGuard based VPN between multiple systems
if you want to connect to openHAB(ian) instances outside your LAN over Internet.
It'll take care to detect and open ports when you and your peers are located behind firewalls.
This makes use of the tailscale service. Don't worry, for private use it's free of charge.
