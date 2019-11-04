---
layout: documentation
title: openHABian
source: https://github.com/openhab/openhabian/blob/master/docs/install-debug.md
---

{% include base.html %}

<!-- Attention authors: Do not edit directly. Please add your changes to the appropriate source repository -->

::: tip Purpose
This document is a to give a guiding hand to users when their openHABian install fails in the first place.
Read on to find out how to improve debug verbosity and how to proceed with that information.
:::

## Prerequisites
First, please make sure you use proper host hardware that is supported as per README.

For one, openHABian requires a minimum of 1GB of RAM to run well. That's including commonly used tools such as frontail and mosquitto and an average-sized openHAB installation on top. So any SBC to have less memory such as a RPi Zero is not supported.

For two, on "supported" hardware in general:
It may work to install and run openHABian on these boxes or not. If it does not work on your box and it isn't any of the supported ones, you are welcome to find out what's missing and come up with a Pull Request. We'll be happy to include that in openHABian so you can use future versions to include that patch on your box. We'll keep that code in unless there's a valid reason to change or remove it. Remind you, though, that that still doesn't make your box a "supported" one as we don't have it available for our further development and testing works. So yes, there then still remains a risk that future openHABian releases will fail to work on your SBC because we changed a thing that broke support for your HW - unintentionally so but also inevitably so.

Second, openHABian requires you to provide direct Internet access. Using private IP addresses is fine as long as your router properly provides NAT (Network Address Translation) services.
Note we assume an Ethernet connection to be present at time of installation. We do not support installing via WiFi.
To illustrate again what "supported" means: this does not mean it wouldn't work, most of the time it does in fact - but we do not take care of this and cannot test against this setup so the functionality may be or become broken at any time, and you are expected to install from Ethernet before asking for help on the forum.

Next, you need your router (or a different device) to provide properly configured DHCP services so your openHABian box gets an IP address assigned when you boot it for the first time.
The DHCP server also has to announce which DNS resolver to use so your box knows how to translate DNS names into IP addresses.
It also needs to announce which IP address to use as the default gateway to the internet - a typical access router to also be the DHCP server will announce it's own address here.
Finally, the DHCP server should also announce the NTP server(s) to use for proper time services. Lack thereof will not break the installation procedure but can lead to all sorts of long term issues so we clearly recommend to setup DHCP to announce a reachable and working NTP server, too.
Note that this is just a summary to cover the most commonly encountered default case. The full boot procedure and how to obtain IP address, DNS resolver, default route and NTP server addresses is highly complex and widely customizable and a comprehensive description how to properly configure your Internet access and router are out of scope of openHABian. Please g**gle for how to accomplish that.


## Installation

Etch-Burn-d(isk)d(ump)-Flash-whatever the image to an SD card, insert it and boot from there.
If you have one available, attach a console (monitor and keyboard) to follow the install process. If you don't have any, try to access the web console at `http://<yourhostip>:8080/first-boot.txt`.
It will display the contents of `/boot/first-log.boot` at intervals of 2 seconds.
Mind you that if installation fails, network access might be possible or not so you might need to access the box via console anyway in order to find out what went wrong.

Login to your box using either the console or the network using `ssh openhabian@<hostname>`. The default hostname (if you didn't change it at installation time) is `openhab`. The default passwort is `openhabian`. 
If that step already fails, it is likely that installation failed because you have not provided proper DNS service as mentioned in the _prerequisites_ section.

Once logged in, enter `sudo bash` to become the root user.
If your install fails at some stage (or hangs forever), there will exist files either `/opt/openHABian-install-failed` or `/opt/openHABian-install-inprogress` to reflect these states (to check, `ls -l /opt/openHABian-install*`).
As a first attempt, you should reboot your box to see if the same problems also occurs on its second attempt.

If that one fails, too, force another install run from scratch by removing the file using `rm -f /opt/openHABian-install*` and rebooting (`reboot`).

### Create a debug log
If the second install run also fails, put openHABian into one of the two more verbose debug levels, edit the config file `nano /etc/openhabian.conf` and set the 'mode' parameter to either `unattended_debug` or `debug_maximum` (it should read `unattended` which is the default), then reboot again
Use `debug_maximum` to have openHABian show every single command it executes so you or the maintainers you send this to can get an idea which part of the code to look at.

Your next boot run will exhibit more verbose logging.
If installation still failsto finish, please retrieve `/boot/first-log.boot` from your box, open a GitHub issue (see next paragraph) and upload the log.

### How to open a Github issue
Check https://github.com/openhab/openhabian/issues/ first if 'your' problem has already been opened as an issue by someone else. If so, you may leave a "me too" comment there but please do not open another issue then.
You can reference other issues (eventually also request to reopen closed ones) and Pull Requests by their number (just type #nnn along your text, GitHub will insert the proper link).
If you open an issue, we kindly ask you to deliver as much information as possible. It is awkwardly annoying if we need to spend time asking and asking what the real problem is about. Please help avoid that situation and tell us in the very first place.
Once you opened the issue, copy `/boot/first-boot.log` over to your desktop and upload it to GitHub.
If you succeed logging on and get to see a banner with system information, please also copy that as part of your issue.

While written for openHAB, here's a guideline you should follow that also applies to openHABian issues:
https://community.openhab.org/t/how-to-file-an-issue/68464

If you're able to help in producing a fix to problems, we happily take any Pull Request.
Explaining git and Github unfortunately is out of scope. For simple fixes to a single file only, you can click through the source starting at https://github.com/openhab/openhabian and edit the file online,
GitHub will then offer to create the PR.
You can also clone the openhabian repository, make your changes locally and use git to check in your changes and upload them to a repo copy of yours, then follow the git-offered link to create the PR. 
Either way, don't forget to sign your work.

## Tips 'n tricks 
::: tip
Remember to always let `openhabian-config` update itself on start.
:::

::: tip
If you want to change anything to work around some not yet fixed bug, you can directly edit the files in and below `/opt/openhabian` on your box.
:::

The main program is in `openhabian-setup.sh`. If the initial unattended install fails again and again at the same step (say Java installation), you may comment that step out. But mind the code in build-image/first-boot.bash quite towards the end starting with`git clone`. This is where openHABian updates itself. If you don't comment that out as well, it'll overwrite your changes on next install run.

::: warning Disclaimer
For obvious reasons, this is not a supported procedure. We just want to give you a hint what you _could_ try doing if your install fails
and you're sitting there, desperately looking for a fix.
G*oo*gle and learn yourself what you need to edit a file, learn to understand shell programming basics, you're on your own here.
If you change openHABian code on your box, temember for the time it takes to get openHABian officially fixed, you must not let openhabian-config update itself on start as that would overwrite your changes.
:::
