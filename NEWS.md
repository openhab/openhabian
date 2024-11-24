Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Legacy openHAB 2 support removed ## November 23, 2024
We have removed legacy support for the openHAB 2 systems. Please upgrade to
the latest version of openHAB to receive further support.

## openHABian 1.9 released based on Debian 12 bookworm ## March 13, 2024
We stepped up to latest Debian Linux release. The openHABian image for RPis
uses Raspberry Pi OS (lite) and we finally managed to switch over to latest
RaspiOS which is "bookworm" based.
Note that not all 3rd party tools are fully tested with bookworm homegear.
If you run a bullseye (Debian 11) or even older distribution, please read the
docs how to reinstall. It's safer to reinstall (and import your old config,
of course) than to attempt doing a dist-upgrade.
See also the OH4 migration FAQ on the forum.
