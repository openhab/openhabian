# openHABian - Hassle-free openHAB Setup

The Raspberry Pi and other small single-board computers are quite famous platforms for openHAB.
However, setting up a fully working Linux system with all recommended packages and openHAB recommendations is a **boring task** taking quite some time and **Linux newcomers** shouldn't worry about these technical details.

***A home automation enthusiast doesn't have to be a Linux enthusiast!***

openHABian aims to provide a **self-configuring** Linux system setup specific to the needs of every openHAB user.
The project provides two things:

* A set of scripts to set up openHAB on any Debian/Ubuntu based system
* Complete **SD-card images pre-configured with openHAB** and many other openHAB- and Hardware-specific preparations, for the Raspberry Pi and the Pine A64.

## Installation and Setup

Please check the [official documentation article](http://docs.openhab.org/installation/openhabian.html) to learn about openHABian and please visit and subscribe to our very active [community forum thread](https://community.openhab.org/t/13379).

Enjoy openHABian and the wondrous world of openHAB!!

----

## Development

For image building, please see the `build-....sh` scripts to get an idea of the process.

The RPi image is based on the [raspbian-ua-netinst](https://github.com/debian-pi/raspbian-ua-netinst) project,
the Pine64 image is based on [build-pine64-image](https://github.com/longsleep/build-pine64-image).

If you find a bug or want to propose a feature, please check open Issues and Pull Requests and read the [CONTRIBUTING](CONTRIBUTING.md) guideline.

Happy Hacking!
