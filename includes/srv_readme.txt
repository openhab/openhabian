openHAB Shortcut Folders

This folder contains links (bind mounts) to all relevant openHAB folders, which
are located elsewhere on the file system. Compare the folder structure:
http://docs.openhab.org/installation/linux.html#file-locations

You can access this folder via Samba network share and should have write access
to all subdirectories. The only exception is the 'openhab2-sys' folder, which
you should not need to write to and was left out for security reasons.

A few hints:

- You might want to mount this folder locally:
  http://docs.openhab.org/installation/linux.html#mounting-locally

- Using the 'openhab-etc' subdirectory with the SmartHome Designer requires the
  folder to be mounted (Windows).
  http://docs.openhab.org/installation/designer.html#network-preparations

- The content of the subdirectories should be backed up on a regular basis,
  if you ever need to restore files from a backup, please be careful which
  files to overwrite and make sure to correct the permissions.
  http://docs.openhab.org/installation/linux.html#backup-and-restore

Enjoy your openHAB experience with openHABian
http://docs.openhab.org/installation/openhabian.html
