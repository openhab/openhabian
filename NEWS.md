Hit tab to unselect the buttons and scroll through the text using UP/DOWN or
PGUP/PGDN.
All announcements will be stored in /opt/openhabian/docs/NEWSLOG.md for you to
lookup.

## November 14, 2020
## WiFi Hotspot
Whenever your system has a WiFi interface that fails to initialize on installation or startup,
openHABian will now launch a [WiFi hotspot](docs/openhabian.md#WiFi-Hotspot) you can use to bootstrap WiFi i.e. to connect your
system to an existing WiFi network.


## October 28, 2020
## openHAB3 readiness (BETA)
openHABian now provides menu options 4X to upgrade your system to openHAB3 and to downgrade
back to current openHAB2 as well. See [documentation](docs/openhabian.md) for details.
Please be aware that openHAB3 as well as openHABian are not thoroughly tested so be prepared
to meet bugs and problems. Don't use this on your production system.


## October 6, 2020
## Tailscale VPN network (BETA)
Tailscale is a management toolset to establish a WireGuard based VPN between multiple systems
if you want to connect to openHAB(ian) instances outside your LAN over Internet.
It'll take care to detect and open ports when you and your peers are located behind firewalls.
This makes use of the tailscale service. Don't worry, for private use it's free of charge.


## October 1, 2020
## Offline installation (BETA)
We now allow for deploying openHABian to destination networks without Internet connectivity.
While the optional components still require access to download, the openHABian core is
fully contained in the download image and can be installed and run without Internet.
This will also provide a failsafe installation when any of the online sources for the tools
we need to download is unavailable for whatever reason.


## August 29, 2020
## Auto-backup
openHABian can automatically take daily syncs of your internal SD card to
another card in an external port. This allows for fast swapping of cards
to reduce impact of a failed SD card.
The remaining space on the external device can also be used to setup openHABian's Amanda backup system.
