Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Welcome trixie! ## January 14, 2025

The new openHABian image for Raspberry Pi systems is now based on the most
recent Debian 13 known as "trixie".
It incorporates the Raspi OS image from December 2025.

## Back to the roots: openJDK 21 ## January 14, 2025
Recent Debian bookworm based versions of openHABian provided and actually
pre-configured your system with Temurin Java version 21.
For the most part, the reason for was that there was and still is no good
openJDK for the bookworm distributions on ARM hardware.
Starting with openHABian version 1.12, there now is and we returned and now
by default provide all new openHABian installations with openJDK 21.

## openHAB 5.1 released ## December 21, 2025
openHAB 5.1 was released!


## 64 bit OS support only ## Aug 1, 2025

With openHAB 5, we are sorry but we have to drop support for 32 bit systems.
There is no officially supported and stable version of Java 21 available that
runs on ARM hardware with a 32 bit Linux.
Check your OS for 32/64 bit using getconf LONG_BIT and read the release notes
https://github.com/openhab/openhab-distro/releases/tag/5.0.0#openhabian
to find out how to proceed with your openHAB upgrade to version 5.
Starting with openHABian v1.11, the upgrade menu function (03) will no longer
work if you are still on an 32 bit system.
You can still manually select to install Temurin 21 Java and openHAB 
but be aware that you will be running an unsupported version of openHAB so
if you run into any trouble, please do not ask for help but upgrade to 64.


