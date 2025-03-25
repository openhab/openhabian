Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## Recommended Java providers ## March 9, 2025
As we approach the release of openHAB 5 in the summer, we have added
support for Java 21, which will be a prerequisite for openHAB 5. With that
we recommend installing your distribution's stable version of Java 21 from
the openJDK package, when possible.

At the time of writing, there is no stable version of Java 21 available for
RaspiOS, as such our recommended alternative is to use the Temurin 21 build
of Java which is know to be well supported and stable.

These are the supported ways of installing Java for openHAB on openHABian
and both can be executed from Menu option 45.

## Frontail removed ## December 18, 2024
We suggest removal of the frontail log-viewer package on all systems with
openHAB 4.3+. There is still an option to keep it or install it however it
is no longer supported and is provided as is. The reasoning for removal is
that frontail has serious security vulnerabilities present and is no longer
maintained.

openHAB 4.3 adds a new builtin logviewer. You can look forward to it
becoming even more capable over the coming months as it is refined as well.
