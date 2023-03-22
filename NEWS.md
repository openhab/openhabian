Hit tab to unselect buttons and scroll through the text using UP/DOWN or
PGUP/PGDN. All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md`
for you to lookup.

## IMPORTANT: Java 17 is now the default ## March 22, 2023
As upcoming openHAB 4 will require Java 17 to run, it's time to move so from
now on we install Java 17 by default.
NOTE: openHAB 3.X is said to work with but isn't thoroughly tested on Java 17
so you might run into issues when you install 3.X.
This is also a request to all of you to gather and share experiences.
Please switch to (via menu) the *main* branch of openHABian or install it
right away as using the default branch (openHAB3) will keep installing Java 11
for the time being. Let us know your feedback via forum.
You can also change java versions via menu or on install via openhabian.conf.

## Install log now on port 81 ## February 23, 2023
As there have been conflicts with the hotspot function, the install time web
log was now moved to port 81. The standard port 80 is reserved for the hotspot.

## Raspberry Imager ## August 17, 2022
Now openHABian can be selected directly within Raspberry Imager to write the
image to an SD card.
