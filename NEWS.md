Hit tab to unselect the buttons and scroll through the text using UP/DOWN or
PGUP/PGDN.
All announcements will be stored in /opt/openhabian/docs/NEWSLOG.md for you to
lookup.

## August 29, 2020
## Auto-backup (BETA)
openHABian can automatically take daily syncs of your internal SD card to
another card in an external port. This allows for fast swapping of cards
to reduce impact of a failed SD card.
The remaining space on the external device will also be used to setup openHABian's Amanda backup system.


## July 4, 2020
### Wireguard VPN (BETA)
Wireguard can be deployed to enable for VPN access to your openHABian box when
it's located in some remote location.
You need to install the Wireguard client from <http://www.wireguard.com/install>
to your local PC or mobile device that you want to use for access.
Copy the configuration file '/etc/wireguard/wg0-client.conf' from this box or
transmit QR code to load the tunnel.
Any feedback is highly appreciated on the forum.

### New Java providers now out of beta
Java 11 has been proven to work with openHAB 2.5.
