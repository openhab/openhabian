As an **openHABian end user**, please check out the official openHAB documentation:  
🡺 https://www.openhab.org/docs/installation/openhabian.html

# openHABian - Hassle-free openHAB Setup

Setting up a fully working Linux system with all needed packages and openHAB recommendations is a **boring task** taking quite some time and **Linux newcomers** shouldn't worry about these technical details.

***A home automation enthusiast doesn't have to be a Linux enthusiast!***

openHABian aims to provide a **self-configuring** Linux system setup specific to the needs of every openHAB user.
The project provides two things:

* A set of scripts to set up openHAB on any Debian/Ubuntu based system
* Complete **SD-card images pre-configured with openHAB** and many other openHAB- and Hardware-specific preparations, for the Raspberry Pi and the Pine A64.

## Installation and Setup

Please check the [official documentation article](https://www.openhab.org/docs/installation/openhabian.html) to learn about openHABian and please visit and subscribe to our very active [community forum thread](https://community.openhab.org/t/13379).

Enjoy openHABian and the wondrous world of openHAB!!

![](https://www.openhab.org/assets/img/openHABian-config.0c2550f6.png)

----

## Development

[![Shellcheck Status](https://travis-ci.com/openhab/openhabian.svg?branch=master)](https://travis-ci.com/openhab/openhabian) (Shellcheck)

For image building, please see the `build.sh` scripts to get an idea of the process.
```
Simply put:

$ sudo bash build.sh platform
$ sudo bash build.sh platform dev-git # Injecting current local branch as remote endpoint (eg. fork)
$ sudo bash build.sh platform dev-url branch url # Injecting custom branch an repository

where platform can be: rpi, pine64
```

The RPi image is based on the [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian) standard image,
the Pine64 image is based on [build-pine64-image](https://github.com/longsleep/build-pine64-image).

To improve the openHABian configuration tool, please have a look at `openhabian-setup.sh`.

If you find a bug or want to propose a feature, please check open Issues and Pull Requests and read the [CONTRIBUTING](CONTRIBUTING.md) guideline.

Happy Hacking!
