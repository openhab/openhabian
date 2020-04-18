---
layout: documentation
title: openHABian
source: https://github.com/openhab/openhabian/blob/master/docs/openhabiab-DEBUG.md
---

<!-- Attention authors: Do not edit directly. Please add your changes to the appropriate source repository -->

This document is to give a guiding hand to users when their openHABian install fails in the first place.
Read on to find out how to improve debug verbosity and how to proceed with that information.

## Prerequisites
First, please make sure you use proper host hardware that is supported as per README.

OpenHABian requires a minimum of 1GB of RAM to run well. While you can get away with a 512MB box like a RPi0W, you must not run anything other than openHAB itself, in particular do NOT run memory hogs such as InfluxDB or Grafana.

On "supported" hardware in general:
It may work to install and run openHABian on unsupported hardware. If it does not work, you are welcome to find out what's missing and contribute back to the community with a Pull Request. It's sometimes simple things like a naming string. We'll be happy to include that in openHABian so you can use your box with openHABian. We'll keep that code in unless there's a valid reason to change or remove it.
Remind you, though, that that doesn't make your box a "supported" one as we don't have it available for our further development and testing works. So there remains a risk that future openHABian releases will fail to work on your SBC because we changed a thing that broke support for your HW - unintentionally so but also inevitably so.

openHABian requires you to provide direct Internet access. Using private IP addresses is fine as long as your router properly provides NAT (Network Address Translation) services.
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
Check if your install fails at some stage (also if it seems to hang forever): there will exist a file either `/opt/openHABian-install-failed` or `/opt/openHABian-install-inprogress` to reflect these states (to check, `ls -l /opt/openHABian-install*`).
As a first attempt, you should reboot your box to see if the same problems also occurs on second attempt.

## Debug
If the problem persists, check `/boot/first-boot.log` to get an indication what went wrong in the install process and where.
You can avoid openHABian to start reinstalling on future reboots by removing the file, i.e. `rm -f /opt/openHABian-install*`, BUT be aware that your installation is incomplete and that you should NOT run openHAB on a box in that state.
You can use this state to debug, you can also use the 6X menu options in openhabian-config` to manually install everything that failed or missing. See `/opt/openhabian/openhabian-setup.sh` and the code in `/opt/openhabian/functions/*.bash` what usually gets installed on an unattended installation. Note that if you keep or recreate (just "touch") `/opt/openhabian-install-failed`, you can reboot at any time to continue unattended installation. So if say Java install fails (Java being a prerequisite to installation of openHAB), you can do that manually (if you know how to) or use `openhabian-config` to do that, then continue installation by rebooting.
Should you succeed at some point in time - great! Let us know what you did to make it work please by opening a Github issue (see below).
As you and we cannot be sure everything on your box is 100% the same what an unattended install gets you, please also remember to do a complete reinstall before you start running openHAB. If possible start with the flash step. If no, at least delete all packages that openhabian-setup installed before you reboot.

### Create a debug log
If the second install attempt after boot also fails, put openHABian into one of the two more verbose debug levels.
To do so, edit the config file `nano /etc/openhabian.conf` and change the 'mode' parameter to either `unattended_debug` or `debug_maximum` (it should read `unattended` which is the default), then reboot again.
Use `debug_maximum` to have openHABian show every single command it executes so you or the maintainers you send this to can get an idea which part of the code to look at.
Your next boot run will exhibit more verbose logging. Remember the output will be written to `/boot/first-boot.log`.
If installation still fails to finish, please retrieve `/boot/first-log.boot` from your box, open a GitHub issue (see next paragraph), thoroughly describe the environment conditions and your findings so far and upload the log.

### How to open a Github issue
While written for openHAB, the guideline at https://community.openhab.org/t/how-to-file-an-issue/68464 also applies to openHABian issues.
Please proceed as told there. openHABian has its own repository at https://github.com/openhab/openhabian/
Search the issues listed there first if 'your' problem has already been seen and eventually opened as an issue by someone else. If so, you may leave a "me too" comment there but please do not open another issue to avoid duplicates.
You can reference other issues (eventually also request to reopen closed ones) and Pull Requests by their number (just type #nnn along with your text, GitHub will insert the proper link).
If you open an issue, we kindly ask you to deliver as much information as possible. It is awkwardly annoying if we need to spend time asking and asking what the real problem is about. Please avoid that situation, be proactive and tell us in the very first place.
Once you opened the issue, copy `/boot/first-boot.log` from your openHABian box over to your desktop and upload it to GitHub.
If you succeed logging on and get to see a banner with system information, please also copy that as part of your issue.

If you're able to help in producing a fix to problems, we happily take any Pull Request.
Explaining git and Github unfortunately is out of scope.
For simple fixes to a single file only, you can click through the source starting at https://github.com/openhab/openhabian and edit the file online, GitHub will then offer to create the PR.
You can also clone the openhabian repository, make your changes locally and use git to check in your changes and upload them to a repo copy of yours, then follow the git-offered link to create the PR. 
Either way, don't forget to sign your work.

## Checkpoint
Remember to always let `openhabian-config` update itself on start.

If you want to change anything to work around some not yet fixed bug, you can directly edit the files in and below `/opt/openhabian` on your box. Just do not let openhabian-config update itself on start as that would overwrite your changes.

The main program is in `openhabian-setup.sh`. If the initial unattended install fails again and again at the same step (say Java installation), you may comment that step out. But mind the code in build-image/first-boot.bash quite towards the end starting with`git clone`. This is where openHABian updates itself. If you don't comment that out as well, it'll overwrite your changes on next install run.

::: warning Disclaimer
For obvious reasons, this is not a supported procedure. We just want to give you a hint what you _could_ try doing if your install fails
and you're sitting there, desperately looking for a fix.
G*oo*gle and learn yourself what you need to edit a file, learn to understand shell programming basics, you're on your own here.
If you change openHABian code on your box, remember for the time it takes to get openHABian officially fixed, you must not let openhabian-config update itself on start as that would overwrite your changes.
:::
