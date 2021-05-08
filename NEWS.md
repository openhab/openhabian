Hit tab to unselect buttons and scroll through the text using UP/DOWN or PGUP/PGDN.
All announcements are stored in `/opt/openhabian/docs/CHANGELOG.md` for you to lookup.

## New `openhabian.conf` option `initialconfig` ## May 9, 2021
This new option allows to automatically import an openHAB3 backup from a file or URL.

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
