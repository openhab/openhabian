Hit tab to unselect buttons and scroll through the text using UP/DOWN or PGUP/PGDN.
All announcements are stored in `/opt/openhabian/docs/NEWSLOG.md` for you to lookup.

## Bintray shutdown ## May 3, 2021
Bintray, the hosting service formerly used for the openHAB stable distribution,
has shutdown their service effective May 1st, 2021. As a result any APT
repositories using the Bintray service need to be replaced. For openHAB, we have
moved to using Artifactory as our hosting service, `openhabian-config` will ask
you on startup about automatically replacing the openHAB stable repository for
you. Check `/etc/apt/sources.list.d/*` afterwards for any other APT repositories
using Bintray as they will not be automatically replaced.

## Future of master branch ## January 20, 2021
We will no longer make regular updates to the master branch as we migrate away
from supporting openHAB 2. As such in the coming months we will make bug fixes
directly to the `stable` branch for openHA 2. With that said, please migrate off
of the `master` branch as it will be deleted soon. You can change branches at
any time using menu option 01.


## openHAB 3 released ## December 21, 2020
In the darkest of times (midwinter for most of us), openHAB 3 was released.
See [documentation](docs/openhabian.md#on-openhab-2-and-3) and
[www.openhab.org](https://www.openhab.org) for details.

Merry Christmas and a healthy New Year!
