#!/usr/bin/env bash

get_git_revision() {
  local branch=$(git -C $BASEDIR rev-parse --abbrev-ref HEAD)
  local shorthash=$(git -C $BASEDIR log --pretty=format:'%h' -n 1)
  local revcount=$(git -C $BASEDIR log --oneline | wc -l)
  local latesttag=$(git -C $BASEDIR describe --tags --abbrev=0)
  local revision="[$branch]$latesttag-$revcount($shorthash)"
  echo "$revision"
}

openhabian_update() {
  FAILED=0
  echo -n "$(timestamp) [openHABian] Updating myself... "
  read -t 1 -n 1 key
  if [ "$key" != "" ]; then
    echo -e "\nRemote git branches available:"
    git -C $BASEDIR branch -r
    read -e -p "Please enter the branch to checkout: " branch
    branch="${branch#origin/}"
    if ! git -C $BASEDIR branch -r | grep -q "origin/$branch"; then
      echo "FAILED - The custom branch does not exist."
      return 1
    fi
  else
    branch="master"
  fi
  shorthash_before=$(git -C $BASEDIR log --pretty=format:'%h' -n 1)
  git -C $BASEDIR fetch --quiet origin || FAILED=1
  git -C $BASEDIR reset --quiet --hard "origin/$branch" || FAILED=1
  git -C $BASEDIR clean --quiet --force -x -d || FAILED=1
  git -C $BASEDIR checkout --quiet "$branch" || FAILED=1
  if [ $FAILED -eq 1 ]; then
    echo "FAILED - There was a problem fetching the latest changes for the openHABian configuration tool. Please check your internet connection and try again later..."
    return 1
  fi
  shorthash_after=$(git -C $BASEDIR log --pretty=format:'%h' -n 1)
  if [ "$shorthash_before" == "$shorthash_after" ]; then
    echo "OK - No remote changes detected. You are up to date!"
    return 0
  else
    echo "OK - Commit history (oldest to newest):"
    echo -e "\n"
    git -C $BASEDIR --no-pager log --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)<%an>%Creset %C(dim yellow)%G?' --reverse --abbrev-commit --stat $shorthash_before..$shorthash_after
    echo -e "\n"
    echo "openHABian configuration tool successfully updated."
    echo "Visit the development repository for more details: $REPOSITORYURL"
    echo "You need to restart the tool. Exiting now... "
    exit 0
  fi
  git -C $BASEDIR config user.email 'openhabian@openHABian'
  git -C $BASEDIR config user.name 'openhabian'
}

system_check_default_password() {
  introtext="The default password was detected on your system! That's a serious security concern. Others or malicious programs in your subnet are able to gain root access!
  \nPlease set a strong password by typing the command 'passwd'!"

  echo -n "$(timestamp) [openHABian] Checking for default openHABian username:password combination... "
  if is_pi && id -u pi &>/dev/null; then
    USERNAME="pi"
    PASSWORD="raspberry"
  elif is_pi || is_pine64; then
    USERNAME="openhabian"
    PASSWORD="openhabian"
  else
    echo "SKIPPED (method not implemented)"
    return 0
  fi
  id -u $USERNAME &>/dev/null
  if [ $? -ne 0 ]
  then
    echo "OK (unknown user)"
    return 0
  fi
  export PASSWORD
  ORIGPASS=$(grep -w "$USERNAME" /etc/shadow | cut -d: -f2)
  export ALGO=$(echo $ORIGPASS | cut -d'$' -f2)
  export SALT=$(echo $ORIGPASS | cut -d'$' -f3)
  GENPASS=$(perl -le 'print crypt("$ENV{PASSWORD}","\$$ENV{ALGO}\$$ENV{SALT}\$")')
  if [ "$GENPASS" == "$ORIGPASS" ]; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Default Password Detected!" --msgbox "$introtext" 12 70
    fi
    echo "FAILED"
  else
    echo "OK"
  fi
}

openhabian_hotfix() {
  if ! grep -q "sleep" /etc/cron.d/firemotd; then
    introtext="It was brought to our attention that openHABian systems cause requests spikes on remote package update servers. This unwanted behavior is related to a simple cronjob configuration mistake and the fact that the openHABian user base has grown quite big over the last couple of months. Please continue to apply the appropriate modification to your system. Thank you."
    if ! (whiptail --title "openHABian Hotfix Needed" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 15 80) then return 0; fi
    firemotd
  fi
}

ua-netinst_check() {
  if [ -f "/boot/config-reinstall.txt" ]; then
    introtext="Attention: It was brought to our attention that the old openHABian ua-netinst based image has a problem with a lately updated Linux package.
If you upgrade(d) the package 'raspberrypi-bootloader-nokernel' your Raspberry Pi will run into a Kernel Panic upon reboot!
\nDo not Upgrade, do not Reboot!
\nA preliminary solution is to not upgrade the system (via the Upgrade menu entry or 'apt upgrade') or to modify a configuration file. In the long run we would recommend to switch over to the new openHABian Raspbian based system image! This error message will keep reapearing even after you fixed the issue at hand.
Please find all details regarding the issue and the resolution of it at: https://github.com/openhab/openhabian/issues/147"
    if ! (whiptail --title "openHABian Raspberry Pi ua-netinst image detected" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 20 80) then return 0; fi
  fi
}
