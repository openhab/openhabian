# openHABian

Hassle-free [openHAB 2](http://openhab.org) Raspbian image as a minimal unattended netinstaller for the Raspberry Pi.

> This project is based on the powerful [raspbian-ua-netinst](https://github.com/debian-pi/raspbian-ua-netinst) and most technical details can be taken from there.

The provided image of only 64MB contains a minimal boot system. This system will then install Raspbian followed by openHAB and a set of useful tools. All packages will be downloaded in their newest version.

* openHAB 2 latest snapshot (package repository)
* Oracle Java 8 (*build 1.8.0_101*, needed for my.openhab)
* Samba ([preconfigured](includes/smb.conf))
* custom [.bashrc](includes/bash.bashrc) and [.vimrc](includes/vimrc) files
* openHAB syntax highlighting in [vim](https://github.com/cyberkov/openhab-vim) and [nano](https://github.com/airix1/openhabnano)
* uses whole SD card by default (8GB or 16GB SD card sufficient)
* 16MB GPU memory split
* git based versioning of `etc` by the help of [etckeeper](http://etckeeper.branchable.com)
* useful packages like screen, mc, htop ...

The set of scripts may later also be used to configure any other kind of Linux system.

The next milestone is to provide an interactive configuration wizard, installing and configuring packages like HABmin, Homegear or Grafana.

**Setup**

* Raspberry Pi models 1B+, 2B or 3B recommended
* Write [image](https://github.com/openhab/openhabian/releases) to SD card ([instructions](https://www.raspberrypi.org/documentation/installation/installing-images/README.md))
* Connect Ethernet, SD card and power to your Raspberry Pi
* Wait up to **45 minutes** (setup depends on your downlink as almost everything is downloaded live)
* Green LED will indicate when setup is finished
  * Irregular blinking: setup in progress...
  * Steady "heartbeat": setup **successful**
  * Fast blinking: error while setup, check `/var/log/raspbian-ua-netinst.log`, create GitHub Issue
* Connect to the openHAB 2 portal (available after another 15 minutes): [http://openhabianpi:8080](http://openhabianpi:8080)
* Connect via ssh with `pi:raspberry`
* Connect to the Samba network share with `openhab:habopen`
* enjoy!

You may need to change the timezone setting through ssh and `sudo raspi-config` (Default is *GMT+01:00*). Besides that, you should be able to start working with openHAB 2 without further ssh contact.

Please note, that openHABian is a custom Raspbian image with certain preinstalled and preconfigured components. After initial setup use like a normal Linux system - refer to [docs/RaspberryPi](http://docs.openhab.org/installation/rasppi.html) and [docs/LinuxInstallation](http://docs.openhab.org/installation/linux.html) for further details.
