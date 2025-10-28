---
layout: documentation
title: openHABian Troubleshooting
source: https://github.com/openhab/openhabian/blob/main/docs/openhabian-troubleshooting.md
---

# openHABian Troubleshooting

::: warning
**Please do not ask for help on the forum unless you have read this guide.**
:::

First off sorry that you had to come here, ideally this would never happen but technology and openHABian are both imperfect so here we are.
Hopefully the information in this guide will help and your system will be up and running in no time.

## Quick Checks

First things first, do a sanity check on a couple of simple things.

### Hardware

openHABian may not always perform as expected if running on unsupported or insufficient hardware.
Make sure that your system follows the current guidance given in the main documentation [here](./openhabian.md#hardware).

After checking your hardware, a couple of things to be aware of:

#### Less than 1 GB of RAM

If you are running on a system with less than 1 GB of RAM you will likely experience issues.
You may think you can get away with less than 1 GB of RAM but you won't have enough memory to run much other than openHAB.
If you experience issues then be aware it is unlikely that there will be much we can do to help.
There can be many different problems that having a minimal amount of RAM will cause (slowness, exceptions, unforced reboots, etc.).
There is not one thing you can check so be aware of that.

#### 1 GB of RAM

For systems with 1 GB of RAM then you will probably be fine with most things and even be able to run a couple of extra components.
Your system still has limits and they will be easily reached if you get a bunch of things going to be conservative.

Additionally, running a 64 bit image on only 1 GB of RAM tends to result in the same situation as running on a system with [less than 1 GB of RAM](#less-than-1-gb-of-ram) so probably don't try to do that either.

If you are running an older 32 bit system on 1 GB of RAM is typically fine.
Be aware that when openHAB 5 releases, 32 bit support will be dropped so you won't be able to upgrade to openHAB 5 without switching over to a 64 bit system.

#### 2+ GB of RAM

You probably have enough RAM to run all the packages you want unless you are going crazy so you should probably keep reading to see what else could be going wrong.

### Network Access

openHABian requires direct Internet access for the duration of the installation.
Ensure that your openHABian box has access to the internet and is not being blocked by any settings configured in your router.
Both Ethernet and Wi-Fi are supported at install time.

openHABian will use Ethernet if connected.
If neither Ethernet nor [static Wi-Fi configuration](#Wi-Fi) work and the Internet cannot be reached, the installer will fire up a hotspot with a wireless LAN named `openhabian-<n>`.
Use a mobile device to connect to it, select your home Wi-Fi or enter its name and password and openHABian will connect there permanently, i.e. safe across reboots.
If none of the things listed below work you are going to need to do more research on your own.
Networking is highly complex and there are many different things that could be the issue.

#### Wi-Fi

A non-interactive installation with static use of your home Wi-Fi requires user configuration action prior to the first boot of openHABian.
For more information on how to configure Wi-Fi before first boot see [Wi-Fi Settings](./openhabian.md#wi-fi-settings)

If you would rather not try to do any additional configuration before first boot you can try to make use of the [hotspot](./openhabian.md#wi-fi-hotspot) feature.
Note that if you observe issues after configuring Wi-Fi with hotspot you should attempt to configure it manually as mentioned above just to be safe.

#### DHCP

If you don't know what DHCP is and your network is working fine for everything else you probably have the correct setup and don't need to do any more.
If you do know what it is and have done any configuration of it in the past, go make sure that none of the settings are not blocking anything.
If you think this might be your issue but don't know what it is you should probably do some research about how to change the settings on your router.

::: tip Note
If you want to set a static IP address you need to do it through your router.
Configuring a static IP through openHABian is not supported.
:::

#### IPv6

There have been reports of occasional issues when IPv6 support is enabled in openHABian.
If you observe issues you may try disabling support see IPv6 settings [here](./openhabian.md#ipv6).

## Preparing Debug Logs / Reporting Issues

If you've tried the advice up to this point and it has still failed to install, it is time to dive deeper and enable debug logging.

### Enabling Debug Logs

Before your first boot, you will need to edit `openhabian.conf` and set `debugmode` to `maximum` (or optionally `on` if you think you only need minimal debugging).
To do so, you need to mount the first partition of your SD card. It's a Windows FAT filesystem so you can and should be doing that right after flashing your image to SD.
See [`debugmode`](./openhabian.md#debugmode) for more information.

After setting `debugmode` boot your system for the first time.
Wait for it to complete the setup process, then login and check `/boot/first-boot.log` for the detailed logs.
If you are impatient, you can try and follow along with the installation logs in the web browser at [http://openhabian:81](http://openhabian:81).

If you want to try and salvage a failed install, you will be on your own.
The only option that we can support is a complete reinstall, sorry, there are just too many potential issues to support anything more than that.

### Opening Github Issues

Some helpful general guidance on opening issues for anything openHAB related is given [here](https://community.openhab.org/t/how-to-file-an-issue/68464).
Please take a moment to read through this thread to get a good background on what will come next first.

When you have read the thread above, please be sure to use the openHABian repository located at [openhab/openhabian](https://github.com/openhab/openhabian).
Make sure to search current and closed issues to check if others may have had a similar problem that may offer a solution to you as well.
If you find an issue that matches yours please share your experience and any relevant logs on that issue rather than opening a new issue.
If you are having a hard time seeing closed issues, be sure to remove the `is:open` filter at the start of the search bar.


If you need to open a new issue, please provide as much information as possible.
We have created an issue template that you can fill out when opening a new issue, please follow it and provide all that it asks for.
If possible, please attach a copy of `/boot/first-boot.log` when opening a new issue so that maintainers can look over it.

If you feel like you know the solution to your issue and would like to contribute it, please open a Pull Request.
Explaining `git` and GitHub unfortunately is out of our scope but the internet is your friend.
Double check the guidelines in [CONTRIBUTING.md](https://github.com/openhab/openhabian/blob/main/CONTRIBUTING.md) as well.

## Final Notes

Hopefully something in this guide was helpful and resolved your issue.

Some final things to note:

We cannot support any personal changes you have made to openHABian, so if you encounter an issue because of personal modifications, you will be on your own.

Remember that openHAB and openHABian are both maintained by volunteers, please be patient, we are doing our best and really want to make this a system that you love.

If you discover something that you find useful and want to contribute it back to openHABian, please open an issue and we would be happy to discuss its inclusion (no promises though).
