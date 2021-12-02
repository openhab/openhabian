As an **openHAB end user** looking for a system to run on, please check out the official documentation:  
-   <https://www.openhab.org/docs/installation/openhabian.html>

# openHABian - Hassle-free openHAB Setup
[![GitHub](https://img.shields.io/github/license/openhab/openhabian)](https://github.com/openhab/openhabian/blob/main/LICENSE.md)
[![ShellCheck](https://github.com/openhab/openhabian/actions/workflows/shellcheck-action.yml/badge.svg)](https://github.com/openhab/openhabian/actions/workflows/shellcheck-action.yml)
[![BATS](https://github.com/openhab/openhabian/actions/workflows/bats-action.yml/badge.svg)](https://github.com/openhab/openhabian/actions/workflows/bats-action.yml)
[![Installation](https://github.com/openhab/openhabian/actions/workflows/installation-action.yml/badge.svg)](https://github.com/openhab/openhabian/actions/workflows/installation-action.yml)
[![Build](https://github.com/openhab/openhabian/actions/workflows/build-action.yml/badge.svg)](https://github.com/openhab/openhabian/actions/workflows/build-action.yml)

<img align="right" width="220" src="./docs/images/logo.svg" />

Setting up a fully working Linux system with all needed packages and useful tooling is a boring, lengthy albeit challenging task.
Fortunately,

***A home automation enthusiast doesn't have to be a Linux enthusiast!***

openHABian is here to provide a **self-configuring** Linux system setup to meet the needs of every openHAB user, in two flavors:

*   A **SD-card image pre-configured with openHAB** for all *Raspberry Pi* models
*   As a set of scripts that sets up openHAB and tools on any Debian based system

### A note on dedication and commitment
We sometimes read about people deciding against use of openHABian because they want to install additional software and believe openHABian does not let them do this.
Everybody wants their home automation to be stable and most people install a *dedicated* RPi, i.e. they don't install any other software there that may interfere with proper openHAB operation.
Reasonably so, this is our clear recommendation.
Saving another 50 bucks is not worth putting the reliable day-to-day operations of your home at risk.

Then again that being said, those who insist to *can* use openHABian as the starting point for their 'generic' server and run whatever software else on top.
There's no genuine reason why this wouldn't work.
The openHABian image is really just Raspberry Pi OS (lite) under the hood and openHABian is "just" some scripts that install a number of packages and configures the system in a specific way, optimized to run openHAB.

What you must not do, though, is to mess with system packages and config *and* expect anyone to help you with that.
Let's clearly state this as well: when you deliberately decide to make manual changes to the OS software packages and configuration (i.e. outside of `openhabian-config`), you will be on your own.
Your setup is untested, and no-one but you knows about your changes.
openHABian maintainers are really committed to providing you with a fine user experience, but this takes enormous efforts you don't get to see as a user.
So if you choose to deviate from standard openHABian installations and run into problems thereafter, don't be unfair: don't waste maintainer's or anyone's time by asking for help or information on your issues on the forum.

### A note on openHAB version 2
openHABian was created to provide a seamless user experience with the current openHAB software, that is currently version 3.X.
openHAB 2 will continue to work on openHABian, but openHAB 2 support is no longer actively maintained and the software will only receive select patches deemed necessary by the maintainers of the project.
If you need openHAB 2 support please use the `stable` branch of openHABian.
You can switch branches using menu option 01 in `openhabian-config` but ATTENTION you cannot up- or downgrade this way and you cannot arbitrarily change versions. There's a high risk you mess up your system (the openHABian server OS setup, that is) if you do.
The image will install openHAB 3 by default, to have it install openHAB 2, set `clonebranch=stable` in `openhabian.conf`.

## Hardware
### Our recommendation
Let's put this first: our current recommendation is to get a RPi 4 with 2 or 4 GB, a 3 A power supply and a 16 GB SD card.
Also get another 32 GB or larger SD card and a USB card reader to make use of the ["auto backup" feature](docs/openhabian.md#Auto-Backup).

### Supported hardware
As of openHABian version 1.6 and later, all Raspberry Pi models are supported as hardware.
Anything x86 based may work or not.
Anything else ARM based such as ODroids, OrangePis and the like may work or not.
NAS servers such as QNAP and Synology boxes will not work.
Support for PINEA64 was dropped in this current release.

We strongly recommend that users choose Raspberry Pi 2, 3 or 4 systems to have 1 GB of RAM or more.
All RPi 0 and 1 only have 512 MB. This can be sufficient to run a smallish openHAB setup, but it will not be enough to run a full-blown system with many bindings and memory consuming openHABian features/components such as zram, InfluxDB or Grafana.
And all but the 0W2 have a single and lame CPU core only, turning their use into an ordeal.
We do not actively prohibit installation on any hardware, including unsupported systems, but we might skip or deny to install specific extensions such as those memory hungry applications named above.

Supporting hardware means testing every single patch and every release.
There are simply too many combinations of SBCs, peripherals and OS flavors that maintainers do not have available, or, even if they did, the time to spend on the testing efforts that is required to make openHABian a reliable system.

Let's make sure you understand the implications of these statements: it means that to run on hardware other than RPi 2/3/4 or (bare metal i.e. not virtualized) x86 may work but this is **not** supported.

It may work to install and run openHABian on unsupported hardware.
If it does not work, you are welcome to find out what's missing and contribute it back to the community with a Pull Request.
It is sometimes simple things like a naming string.
We'll be happy to include that in openHABian so you can use your box with openHABian unless there's a valid reason to change or remove it.
However, that does not make your box a "supported" one as we don't have it available for our further development and testing.
So there remains a risk that future openHABian releases will fail to work on your SBC because we changed a thing that broke support for your HW - unintentionally so however inevitable.

For ARM hardware that we don't support, you can try any of the [fake hardware parameters](docs/openhabian.md/#fake-hardware-mode) to 'simulate' RPi hardware and Raspberry Pi OS. If that still doesn't work for you, give [Ubuntu](https://ubuntu.com/download/iot) or [ARMbian](https://www.armbian.com/) a try.

## OS support
Going beyond what the RPi image provides, as a manually installed set of scripts, we support running openHABian on x86 hardware on generic Debian.
On ARM, we only support Raspberry Pi OS.
These are what we develop and test openHABian against.
We do **not support Ubuntu** so no promises. We provide code "as-is", it may work or not.
Several optional components such as WireGuard or Homegear are known to expose problems.

We expect you to use the current stable distribution, 'bullseye' for Raspberry Pi OS (ARM) and Debian (x86).
To install openHABian on anything older or newer may work or not.
If you encounter issues, you may need to upgrade first or to live with the consequences of running an OS on the edge of software development.

Either way, please note that you're on your own when it comes to configuring and installing the HW with the proper OS yourself.

### 64 bit?
RPi3 and 4 have a 64 bit processor and you may want to run openHAB in 64 bit.
We provide a 64bit version of the image but it is unsupported so use it at your own risk.
Please don't ask for support if it does not work for you.
It's just provided as-is.
Be aware that to run in 64 bit has a major drawback: increased memory usage.
That is not a good idea on a heavily memory constrained platform like a RPi.
Also remember openHABian makes use of Raspberry Pi OS which as per today still is a 32 bit OS.
We are closely observing development and will adapt openHABian once it will reliably work on 64 bit.

On x86 hardware, 64 bit is the standard.

## Installation and Setup
Please check the [official documentation article](https://www.openhab.org/docs/installation/openhabian.html) to learn about openHABian and please visit and subscribe to our [community forum thread](https://community.openhab.org/t/13379).

If you want to install openHABian on non-supported hardware, you can actually fake it to make openHABian treat your box as if it was one of the supported ones.
Needless to say that that may work out or not, but it's worth a try.
See [`openhabian.conf`](docs/openhabian.md#openhabianconf) for how to edit `openhabian.conf` before booting.
Set the `hw`, `hwarch` and `release` parameters to match your system best.

## Development
openHABian is foremost a collection of `bash` scripts versioned and deployed using git.
In the current state the scripts can only be invoked through the terminal menu system [whiptail](https://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail).
There is a longterm need to better separate the UI part from the script code.
A work has started to define conventions and further explain the code base in the document [CONTRIBUTING.md](CONTRIBUTING.md) along with development guidelines in general.

A good place to look at to start to understand the code is the file `openhabian-setup.sh`.

### Building Hardware Images
Take a look at the `build.bash` script to get an idea of the process.
Run the code below with `platform` being `rpi`.
The RPi image is based on the [Raspberry Pi OS Lite](https://www.raspberrypi.org/downloads/raspberry-pi-os/) (previously called Raspbian) standard image.

``` bash
sudo bash ./build.bash platform
```

As the script uses `openhab/openhabian` git repository during installation it must sometimes be changed to test code from other repositories, like a new feature in a fork.
There are two commands for replacing the git repo with a custom one.

The first command uses the current checked-out repository used in the filesystem:

``` bash
sudo bash build.bash platform dev-git
```

The second command uses a fully customizable repository:

``` bash
sudo bash build.bash platform dev-url branch url
```

### Testing
Testing is done continuously with GitHub Actions using the test framework [BATS](https://github.com/bats-core/bats-core) and the linter [ShellCheck](https://www.shellcheck.net/).
As the tests focus on installing software, a [Docker](https://www.docker.com/) solution is used for easy build-up and teardown.

To run the test suite on a `amd64` platform execute the commands below.
Docker and ShellCheck need to be installed first.
For more details regarding the tests see [Test Architecture](https://github.com/openhab/openhabian/blob/main/CONTRIBUTING.md#test-architecture) in CONTRIBUTING.md.

``` bash
docker build --tag openhabian/bats-openhabian -f tests/Dockerfile.amd64-BATS .
docker run --rm --name "openhabian-bats" -d openhabian/bats-openhabian
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "development-." .'
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "unit-." .'
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "installation-." .'
docker exec -i "openhabian-bats" bash -c 'bats --tap --recursive --filter "destructive-." .'
docker stop openhabian-bats

docker build --tag openhabian/install-openhabian -f tests/Dockerfile.amd64-installation .
docker run --privileged --rm --name "openhabian-install" -d openhabian/install-openhabian
docker exec -i "openhabian-install" bash -c "./build.bash local-test && /boot/first-boot.bash"
docker stop openhabian-install
```

The ShellCheck linter can be run by using the following commands:

``` bash
shellcheck -x -s bash openhabian-setup.sh
shellcheck -x -s bash functions/*.bash
shellcheck -x -s bash build-image/*.bash
shellcheck -x -s bash build.bash tests/ci-setup.bash
```


Happy Hacking!
