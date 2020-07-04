Hit tab to unselect the buttons and scroll through the text using UP/DOWN or
PGUP/PGDN.
All announcements will be stored in /opt/openhabian/docs/NEWSLOG.md for you to
lookup.

## July 4, 2020
### Wireguard VPN (BETA)
Added Wireguard VPN (BETA).
Wireguard can be deployed to enable for VPN access to your openHABian box when
it's located in some remote location.
You need to install the Wireguard client from http://www.wireguard.com/install
to your local PC or mobile device that you want to use for access.
Copy the configuration file /etc/wireguard/wg0-client.conf from this box to
load the tunnel.
Note this is an ALPHA test so don't expect it to work out of the box.
Any feedback is highly appreciated on the forum.

### new Java providers now out of beta
Java 11 has proven to work with 2.5


## June 17, 2020
### Ubuntu support and removed support for PINE A64(+) and older Linux distributions
`openhabian-config` will now issue a warning if you start on unsupported
hardware or OS releases. See [README](README.md) for supported HW and OS.

In short, PINE A64 is no longer supported and OS releases other than the current
`stable` and the previous one are deprecated. Running on any of those may still
work or not.

The current and previous Debian / Raspberry Pi OS (previously called Raspbian)
releases are 10 ("buster") and 9 ("stretch"). Most current Ubuntu LTS releases
are 20.04 ("focal") and 18.04 ("bionic").

