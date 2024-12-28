---
layout: documentation
title: openHABian Troubleshooting
source: https://github.com/openhab/openhabian/blob/main/docs/openhabian-troubleshooting.md
---

# openHABian Troubleshooting

::: important
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
If you experience issues then be aware it is unlikely that there will be much we can do to help, we have been unable to figure out how to magically give more RAM to you by an update.
In our experience it typically requires purchasing new hardware and starting with a fresh install of openHABian.

#### 1 GB of RAM

For systems with 1 GB of RAM then you will probably be fine with most things and even be able to run a couple of extra components.
Your system still has limits and they will be easily reached if you get a bunch of things going to be conservative.

Additionally, running a 64 bit image on only 1 GB of RAM tends to result in the same situation as running on a system with [less than 1 GB of RAM](#less-than-1-gb-of-ram) so probably don't try to do that either.

#### 2+ GB of RAM

You probably have enough RAM to run all the packages you want unless you are going crazy so you should probably keep reading to see what else could be going wrong.

### Network Access

openHABian requires direct Internet access for the duration of the installation.
Ensure that your openHABian box has access to the internet and is not being blocked by any settings configured in your router.
Both Ethernet and Wi-Fi are both supported at install time.

If none of the things listed below work you are going to need to do more research on your own.
Networking is highly complex and there are many different things that could be the issue.

#### Wi-Fi

WiFi requires user configuration prior to the first boot of openHABian.
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

If you've tried the advice up to this point and its still failed to install, its time to dive deeper and enable debug logging.

### Enabling Debug Logs

Before your first boot, you will need to edit `/boot/openhabian.conf` and `debugmode` to `on`.
If you want even more logging you could also use `maximum` to increase the output (it will show the output of every command run by `openhabian-config`).
See [`debugmode`](./openhabian.md#debugmode) for more information.

After setting `debugmode` boot your system for the first time (yeah again).
Wait for it to complete the setup process, then login and check `/boot/first-boot.log` for the detailed logs.
If you are impatient, you can try and follow along with the installation logs in the web browser at [http://openhabian:81](http://openhabian:81).

If you want to try and salvage a failed install, you will be on your own.
The only option that we can support is a complete reinstall, sorry, there are just too many potential issues to support anything more than that

## TODO
### How to open a Github issue
While written for openHAB, the guideline at <https://community.openhab.org/t/how-to-file-an-issue/68464> also applies to openHABian issues.
Please proceed as told there.
openHABian has its own repository at <https://github.com/openhab/openhabian>.
Search the issues listed there first if 'your' problem has already been seen and eventually opened as an issue by someone else (you should remove the `is:open` filter from the search bar to let you see closed issues).
If so, you may leave a "me too" comment there but please do not open another issue to avoid duplicates.
You can reference other issues (eventually also request to reopen closed ones) and Pull Requests by their number (just type #XXX along with your text, GitHub will insert the proper link).
If you open an issue, we kindly ask you to deliver as much information as possible.
It is awkward and annoying if we need to spend time asking and asking what the real problem is about.
Please avoid that situation, be proactive and tell us in the first place.
Once you opened the issue, copy `/boot/first-boot.log` from your openHABian box over to your desktop and upload it to GitHub.
If you succeed logging on and get to see a banner with system information, please also copy that as part of your issue.

If you're able to help in producing a fix to problems, we happily take any Pull Request.
Explaining git and Github unfortunately is out of our scope (the internet is your friend).
See the guidelines outlined in [CONTRIBUTING.md](https://github.com/openhab/openhabian/blob/main/CONTRIBUTING.md) as well.
For simple fixes to a single file only, you can click through the source starting at <https://github.com/openhab/openhabian> and edit the file online, GitHub will then offer to create the PR.
You can also clone the openHABian repository, make your changes locally and use git to check in your changes and upload them to a repo copy of yours, then follow the git-offered link to create the PR.

## Checkpoint
Remember to always let `openhabian-config` update itself on start.

If you want to change anything to work around some not yet fixed bug, you can directly edit the files in and below `/opt/openhabian` on your box.
Just do not let `openhabian-config` update itself on start as that would overwrite your changes.
You can also clone (download) a different openHABian version than the most current one, e.g. if a maintainer or contributor to openHABian offers or asks you to test-drive a development version.
Set the `clonebranch` parameter in `/etc/openhabian.conf` to the branch name to load, then update `openhabian-config` on start.
**Note**: You must not modify `repositoryurl` to point elsewhere than the official repo.
openHABian will only ever update from there so you can only test drive a test branch that a developer has provided you on the official site.

The main program is in `openhabian-setup.sh`.
If the initial unattended install fails again and again at the same step (say Java installation), you may try to comment that step out.
But mind the code in `build-image/first-boot.bash` towards the end starting with `git clone`.
This is where openHABian updates itself.
If you don't comment that out as well, it'll overwrite your changes on the next install run.

## Disclaimer
For obvious reasons, changing openHABian code is not a supported procedure.
We just want to give you a hint what you _could_ try doing if your install fails and you're sitting there, desperately looking for a fix.
Search the internet and learn for yourself how to edit a file, learn to understand shell programming basics, you're on your own here.
If you change openHABian code on your box, remember for the time it takes to get openHABian officially fixed, you must not let `openhabian-config` update itself on start as that would overwrite your changes.
