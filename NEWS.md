Hit tab to unselect the buttons and scroll through the text using UP/DOWN or
PGUP/PGDN.
All announcements will be stored in /opt/openhabian/docs/NEWSLOG.md for you to
lookup.

## August 15, 2020
## Auto-backup (ALPHA)
Have openHABian automatically take daily syncs of your internal SD card to
another card in an external card reader. In case your card breaks down, you
can switch cards to get back online fast.
Will also use this card for Amanda backup storage.


## July 4, 2020
### Wireguard VPN (ALPHA)
Wireguard can be deployed to enable for VPN access to your openHABian box when
it's located in some remote location.
You need to install the Wireguard client from <http://www.wireguard.com/install>
to your local PC or mobile device that you want to use for access.
Copy the configuration file '/etc/wireguard/wg0-client.conf' from this box or
transmit QR code to load the tunnel.
Note this is an ALPHA test so don't expect it to work out of the box.
Any feedback is highly appreciated on the forum.

### New Java providers now out of beta
Java 11 has been proven to work with openHAB 2.5.
