Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

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


## openHAB 5 released ## July 21, 2025
openHAB 5 was released!

Note that unless you explicitly changed it, openHABian by default will be
installing or upgrading to latest openHAB release so you will be getting
openHAB 5 now. Note that that requires to upgrade your JVM to Java 21.


## Frontail removed ## December 18, 2024
We suggest removal of the frontail log-viewer package on all systems with
openHAB 4.3+. There is still an option to keep it or install it however it
is no longer supported and is provided as is. The reasoning for removal is
that frontail has serious security vulnerabilities present and is no longer
maintained.

openHAB 4.3 adds a new builtin logviewer. You can look forward to it
becoming even more capable over the coming months as it is refined as well.
