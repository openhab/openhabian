openHAB Shortcut Folders

This folder contains links (bind mounts) to all relevant openHAB folders, which
are located elsewhere on the file system. Compare the actual folder structure:
https://www.openhab.org/docs/installation/linux.html#file-locations

You can access this folder via Samba network share and should have write access
to all subdirectories. The only exception is the 'openhab2-sys' folder, which
you should not need to write to and was left out for security reasons.

A few hints:

- You might want to mount this folder locally:
  https://www.openhab.org/docs/installation/linux.html#mounting-locally

- Using the 'openhab-etc' subdirectory with the VS Code Extension requires the
  main folder to be mounted (Windows).
  https://www.openhab.org/docs/configuration/editors.html#network-preparations

- The content of the subdirectories should be backed up on a regular basis,
  if you ever need to restore files from a backup, please be careful which
  files you overwrite and make sure to correct the permissions.
  https://www.openhab.org/docs/installation/linux.html#backup-and-restore

- If you ever have access right problems (e.g. missing write permissions) or
  have restored files and need to make sure they have the right set of owner,
  group and permissions, please execute the "Fix Permissions" menu entry from
  the openHABian Configuation Tool.

Enjoy your openHAB experience with openHABian
https://www.openhab.org/docs/installation/openhabian.html
