# openhabian

Hassle-free [openHAB 2](http://openhab.org) Raspbian image as a minimal unattended netinstaller for Raspberry Pi Models 1B, 1B+, 2B and 3B.

> This project is based on the powerful [raspbian-ua-netinst](https://github.com/debian-pi/raspbian-ua-netinst) and most technical details can be taken from there.

The provided image of only 64MB contains a minimal boot system. This system will then install Raspbian followed by openHAB and a set of useful tools. All packages will be downloaded in their newest version.

* openHAB 2 latest snapshot (package repository)
* Samba (preconfigured)
* custom .bashrc and .vimrc
* uses whole SD card by default
* 16MB GPU memory split
* useful packages like screen, mc, htop ...

The set of scripts may later also be used to configure any other kind of Linux system.

The next milestone is to provide an interactive configuration wizard, installing and configuring packages like HABmin, Homegear or Grafana.

**Setup**

* Write [image](https://github.com/ThomDietrich/openhabian/releases) to SD card ([instructions](https://www.raspberrypi.org/documentation/installation/installing-images/README.md))
* Connect ethernet, SD card and power to your Raspberry Pi
* Wait up to **45 minutes** (setup will take some time as everything is downloaded live)
* Green LED will indicate when setup is finished
  * Irregular blinking: setup in progress...
  * Steady "heartbeat": setup **successful**
  * Fast blinking: error while setup, check `/boot/raspbian...log`, create GitHub Issue
* Connect to the openHAB 2 portal (available after another 15 minutes): [http://openhabianpi.local:8080](http://openhabianpi.local:8080)
* Connect via ssh with `pi:raspberry`
* Connect to the Samba network share with `openhab:habopen`
* enjoy!

You may need to change the timezone setting through ssh and `sudo raspi-config`. Besides that, you should be able to start working with openHAB 2 without further ssh contact.
