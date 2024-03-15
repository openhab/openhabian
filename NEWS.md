Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## openHABian 1.9 released based on Debian 12 bookworm ## March 13, 2024
We stepped up to latest Debian Linux release. The openHABian image for RPis
uses Raspberry Pi OS (lite) and we finally managed to switch over to latest
RaspiOS which is "bookworm" based.
Note that not all 3rd party tools are fully tested with bookworm homegear.
If you run a bullseye (Debian 11) or even older distribution, please read the
docs how to reinstall. It's safer to reinstall (and import your old config,
of course) than to attempt doing a dist-upgrade.
See also the OH4 migration FAQ on the forum.

## Raspberry Pi 5 support ## March 13, 2024
Support for the new Raspberry Pi 5 is also included as part of the bookworm update.
Please note that while a RPi5 has new HW features such as PCI-E SSD, nothing has
changed about peripheral support in openHABian, unsupported parts may work or not.

