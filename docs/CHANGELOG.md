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

## Removal of `master` branch ## May 6, 2021
As now the `master` branch has been removed and will no longer work in any
installations, please use menu option 01 to switch the the `stable` branch if
you have a need for openHAB 2 support. Please note that the `stable` branch will
not receive regular updates anymore only targeted patches that are deemed
necessary by openHABian maintainers, to receive regular patches please migrate
to openHAB 3 using menu option 42.

## Bintray shutdown ## May 3, 2021
Bintray, the hosting service formerly used for the openHAB stable distribution,
has shutdown their service effective May 1st, 2021. As a result any APT
repositories using the Bintray service need to be replaced. For openHAB, we have
moved to using Artifactory as our hosting service, `openhabian-config` will ask
you on startup about automatically replacing the openHAB stable repository for
you. Check `/etc/apt/sources.list.d/*` afterwards for any other APT repositories
using Bintray as they will not be automatically replaced.

## Future of master branch ## January 20, 2021
We will no longer make regular updates to the master branch as we migrate away
from supporting openHAB 2. As such in the coming months we will make bug fixes
directly to the `stable` branch for openHA 2. With that said, please migrate off
of the `master` branch as it will be deleted soon. You can change branches at
any time using menu option 01.


## openHAB 3 released ## December 21, 2020
In the darkest of times (midwinter for most of us), openHAB 3 was released.
See [documentation](openhabian.md#on-openhab-2-and-3) and
[www.openhab.org](https://www.openhab.org) for details.

Merry Christmas and a healthy New Year!


## WiFi hotspot ## November 14, 2020
Whenever your system has a WiFi interface that fails to initialize on
installation or startup, openHABian will now launch a
[WiFi hotspot](openhabian.md#WiFi-Hotspot) you can use to bootstrap WiFi i.e. to
connect your system to an existing WiFi network.


## openHAB 3 readiness ## October 28, 2020
openHABian now provides menu options 4X to upgrade your system to openHAB3 and
to downgrade back to current openHAB 2 See [documentation](openhabian.md) for
details. Please be aware that openHAB3 as well as openHABian are not thoroughly
tested so be prepared to meet bugs and problems in the migration process as
well. Don't migrate your production system unless you're fully aware of the
consequences.


## Tailscale VPN network ## October 6, 2020
Tailscale is a management toolset to establish a WireGuard based VPN between
multiple systems if you want to connect to openHAB(ian) instances outside your
LAN over Internet. It'll take care to detect and open ports when you and your
peers are located behind firewalls. Don't worry, for private use it's free of
charge.


## Offline installation ## October 1, 2020
We now allow for deploying openHABian to destination networks without Internet
connectivity. While the optional components still require access to download,
the openHABian core is fully contained in the download image and can be
installed and run without Internet. This will also provide a failsafe
installation when any of the online sources for the tools we need to download is
unavailable for whatever reason.


## Auto-backup ## August 29, 2020
openHABian can automatically take daily syncs of your internal SD card to
another card in an external port. This allows for fast swapping of cards to
reduce impact of a failed SD card. The remaining space on the external device
can also be used to setup openHABian's Amanda backup system.


## Wireguard VPN ## July 4, 2020
Wireguard can be deployed to enable for VPN access to your openHABian box when
it's located in some remote location.
You need to install the Wireguard client from <http://www.wireguard.com/install>
to your local PC or mobile device that you want to use for access.
Copy the configuration file `/etc/wireguard/wg0-client.conf` from this box or
transmit QR code to load the tunnel.
Any feedback is highly appreciated on the forum.


### New Java providers now out of beta
Java 11 has been proven to work with openHAB 2.5.


## End support for PINE A64(+) and older Linux distributions ## June 17, 2020
`openhabian-config` will now issue a warning if you start on unsupported
hardware or OS releases. See [README](../README.md) for supported HW and OS.

In short, PINE A64 is no longer supported and OS releases other than the current
`stable` and the previous one are deprecated. Running on any of those may still
work or not.

The current and previous Debian / Raspberry Pi OS (previously called Raspbian)
releases are 10 ("buster") and 9 ("stretch"). The most current Ubuntu LTS
releases are 20.04 ("focal") and 18.04 ("bionic").


## New parameters in `openhabian.conf` ## June 10, 2020
See `/etc/openhabian.conf` for a number of new parameters such as the useful
`debugmode`, a fake hardware mode, the option to disable ipv6 and the ability to
update from a custom repository other than the `master` and `stable` branches.

In case you are not aware, there is a Debug Guide in the `docs/` directory.


### New Java options
Preparing for openHAB 3, new options for the JDK that runs openHAB are now
available:

-   Java Zulu 8 32-Bit OpenJDK (default on ARM based platforms)
-   Java Zulu 8 64-Bit OpenJDK (default on x86 based platforms)
-   Java Zulu 11 32-Bit OpenJDK
-   Java Zulu 11 64-Bit OpenJDK
-   AdoptOpenJDK 11 OpenJDK (potential replacement for Zulu)

openHAB 3 will be Java 11 only.  2.5.X is supposed to work on both, Java 8 and
Java 11. Running the current openHAB 2.X on Java 11 however has not been tested
on a wide scale. Please be aware that there is a small number of known issues in
this: v1 bindings may or may not work.

Please participate in beta testing to help create a smooth transition user
experience for all of us.

See [announcement thread](https://community.openhab.org/t/Java-testdrive/99827)
on the community forum.


## Stable branch ## May 31, 2020
Introducing a new versioning scheme to openHABian. Please welcome the `stable`
branch.

Similar to openHAB where there's releases and snapshots, you will from now on be
using the stable branch. It's the equivalent of an openHAB release. We will keep
providing new changes to the master branch first as soon as we make them
available, just like we have been doing in the past. If you want to keep living
on the edge, want to make use of new features fast or volunteer to help a little
in advancing openHABian, you can choose to switch back to the master branch.
Anybody else will benefit from less frequent but well better tested updates to
happen to the stable branch in batches, whenever the poor daring people to use
`master` have reported their trust in these changes to work flawlessly.

You can switch branches at any time using the menu option 01.


### Zram enabled by default
Swap, logs and persistence files are now put into zram per default.
See [zram status thread](https://community.openhab.org/t/zram-status/80996) for
more information.


### Supported hardware and Operating Systems
openHABian now fully supports all Raspberry Pi SBCs with our fast-start image.
As an add-on package, it is supposed to run on all Debian based OSs.

Check the [README](../README.md) to see what "supported" actually means and what
you can do if you want to run on other HW or OS.
