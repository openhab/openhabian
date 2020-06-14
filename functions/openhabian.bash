#!/usr/bin/env bash

get_git_revision() {
  local branch shorthash revcount latesttag
  branch=$(git -C "$BASEDIR" rev-parse --abbrev-ref HEAD)
  shorthash=$(git -C "$BASEDIR" log --pretty=format:'%h' -n 1)
  revcount=$(git -C "$BASEDIR" log --oneline | wc -l)
  latesttag=$(git -C "$BASEDIR" describe --tags --abbrev=0)
  echo "[$branch]$latesttag-$revcount($shorthash)"
}

apt_update() {
  apt-get -q update >/dev/null 2>&1 &
  PID_APT=$!
}

wait_for_apt_to_finish_update() {
  echo "$(timestamp) [openHABian] Updating Linux package information ... "
  if [ ! -v PID_APT ]; then
    apt_update
  fi
  if wait -f ${PID_APT} 2>/dev/null ; then
    echo FAILED
  else
    echo OK
  fi
}

install_cleanup() {
  echo "$(timestamp) [openHABian] Cleaning up ... "
  cond_redirect apt --yes autoremove -q
}

openhabian_announcements() {
  local newsfile="${BASEDIR}/NEWS.md"
  local readnews="${BASEDIR}/docs/LASTNEWS.md"

  if ! diff -q "$newsfile" "$readnews" >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    if (whiptail --title "openHABian breaking NEWS" --yes-button "I have read this" --no-button "keep displaying" --defaultno --yesno --scrolltext "$(cat $newsfile)" 24 90); then
      cp "$newsfile" "$readnews";
    fi
  fi
}

openhabian_console_check() {
  if [ "$(tput cols)" -lt  120 ]; then
    warningtext="We detected that you use a console which is less than 120 columns wide. This tool is designed for a minimum of 120 columns and therefore some menus may not be presented correctly. Please increase the width of your console and rerun this tool.
    \\nEither resize the window or consult the preferences of your console application."
    whiptail --title "Compatibility Warning" --msgbox "$warningtext" 15 76
  fi
}

openhabian_update_check() {
  local branch
  local introtext="Additions, improvements or fixes were added to the openHABian configuration tool. Would you like to update now and benefit from them? The update will not automatically apply changes to your system.\\n\\nUpdating is recommended."
  FAILED=0
  echo "$(timestamp) [openHABian] openHABian configuration tool version: $(get_git_revision)"
  branch=${clonebranch:-HEAD}
  echo -n "$(timestamp) [openHABian] Checking for changes in origin branch $branch ... "
  git -C "$BASEDIR" config user.email 'openhabian@openHABian'
  git -C "$BASEDIR" config user.name 'openhabian'
  git -C "$BASEDIR" fetch --quiet origin || FAILED=1
  # shellcheck disable=SC2046
  if [ $(git -C "$BASEDIR" rev-parse "$branch") == $(git -C "$BASEDIR" rev-parse @\{u\}) ]; then
    echo "OK"
  else
    echo -n "Updates available... "
    if ! (whiptail --title "openHABian Update Available" --yes-button "Continue" --no-button "Skip" --yesno "$introtext" 15 80); then echo "SKIP"; return 0; fi
    echo ""
    openhabian_update "$branch"
  fi
  openhabian_announcements
  echo -n "$(timestamp) [openHABian] Switching to branch $clonebranch ... "
  # shellcheck disable=SC2015
  git -C "$BASEDIR" checkout --quiet "$clonebranch" && echo "OK" || (FAILED=1; echo "FAILED"; return 0)
}

openhabian_update() {
  local branch shorthash_before
  current=$(git -C "$BASEDIR" rev-parse --abbrev-ref HEAD)
  if [ "$current" == "master" ]; then
    local introtext="You are currently using the very latest (\"master\") version of openHABian.\\nThis is providing you with the latest features but less people have tested it so it is a little more likely that you run into errors.\\nWould you like to step back a little now and switch to use the stable version ?\\nYou can switch at any time by selecting this menu option again or by setting the clonebranch= parameter in /etc/openhabian.conf.\\n"
  else
    if [ "$current" == "stable" ]; then
      local introtext="You are currently using the stable version of openHABian.\\nAccess to the latest features would require you to switch to the latest version.\\nWould you like to step back a little now and switch to use the stable version ?\\nYou can switch versions at any time by selecting this menu option again or by setting the clonebranch= parameter in /etc/openhabian.conf.\\n"
    else
      local introtext="You are currently using neither the stable version nor the latest (\"master\") version of openHABian.\\nAccess to the latest features would require you to switch to master while the default is to use the stable version.\\nWould you like to step back a little now and switch to use the stable version ?\\nYou can switch versions at any time by selecting this menu option again or by setting the clonebranch= parameter in /etc/openhabian.conf.\\n"
    fi
  fi

  FAILED=0
  if [[ -n "$INTERACTIVE" ]]; then
    if [[ "$current" == "stable" || "$current" == "master" ]]; then
      if ! sel=$(whiptail --title "openHABian version" --radiolist "$introtext" 14 75 2 stable "recommended standard version of openHABian" on master "very latest version of openHABian" off 3>&1 1>&2 2>&3); then return 0; fi
    else
      if ! sel=$(whiptail --title "openHABian version" --radiolist "$introtext" 14 75 3 stable "recommended standard version of openHABian" off master "very latest version of openHABian" off "$current" "some other version you fetched yourself" on 3>&1 1>&2 2>&3); then return 0; fi
    fi
    sed -i "s@^clonebranch=.*@clonebranch=$sel@g" "/etc/openhabian.conf"
  fi
  echo -n "$(timestamp) [openHABian] Updating myself... "
  read -r -t 1 -n 1 key
  if [ "$key" != "" ]; then
    echo -e "\\nRemote git branches available:"
    git -C "$BASEDIR" branch -r
    read -r -e -p "Please enter the branch to checkout: " branch
    branch="${branch#origin/}"
    if ! git -C "$BASEDIR" branch -r | grep -q "origin/$branch"; then
      echo "FAILED - The custom branch does not exist."
      return 1
    fi
  else
    branch="${sel:-stable}"
  fi

  shorthash_before=$(git -C "$BASEDIR" log --pretty=format:'%h' -n 1)
  git -C "$BASEDIR" fetch --quiet origin || FAILED=1
  git -C "$BASEDIR" reset --quiet --hard "origin/$branch" || FAILED=1
  git -C "$BASEDIR" clean --quiet --force -x -d || FAILED=1
  git -C "$BASEDIR" checkout --quiet "$branch" || FAILED=1
  if [ $FAILED -eq 1 ]; then
    echo "FAILED - There was a problem fetching the latest changes for the openHABian configuration tool. Please check your internet connection and try again later..."
    return 1
  fi
  shorthash_after=$(git -C "$BASEDIR" log --pretty=format:'%h' -n 1)
  if [ "$shorthash_before" == "$shorthash_after" ]; then
    echo "OK - No remote changes detected. You are up to date!"
    return 0
  else
    echo "OK - Commit history (oldest to newest):"
    echo -e "\\n"
    git -C "$BASEDIR" --no-pager log --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)<%an>%Creset %C(dim yellow)%G?' --reverse --abbrev-commit --stat "$shorthash_before..$shorthash_after"
    echo -e "\\n"
    echo "openHABian configuration tool successfully updated."
    if [[ -n "$INTERACTIVE" ]]; then
      # shellcheck disable=SC2154
      echo "Visit the development repository for more details: $repositoryurl"
      echo "The tool will now restart to load the updates... "
      echo -e "\\n"
      exec "$BASEDIR/$SCRIPTNAME"
      exit 0
    fi
  fi
}

system_check_default_password() {
  introtext="The default password was detected on your system! That's a serious security concern. Others or malicious programs in your subnet are able to gain root access!
  \\nPlease set a strong password by typing the command 'passwd'!"

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
  if ! id -u $USERNAME &>/dev/null; then echo "OK (unknown user)"; return 0; fi
  ORIGPASS=$(grep -w "$USERNAME" /etc/shadow | cut -d: -f2)
  ALGO=$(echo "$ORIGPASS" | cut -d'$' -f2)
  SALT=$(echo "$ORIGPASS" | cut -d'$' -f3)
  export PASSWORD ALGO SALT
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

ua-netinst_check() {
  if [ -f "/boot/config-reinstall.txt" ]; then
    introtext="Attention: It was brought to our attention that the old openHABian ua-netinst based image has a problem with a lately updated Linux package.\\nIf you upgrade(d) the package 'raspberrypi-bootloader-nokernel' your Raspberry Pi will run into a Kernel Panic upon reboot!\\nDo not upgrade, do not reboot!\\nA preliminary solution is to not upgrade the system (via the Upgrade menu entry or 'apt-get upgrade') or to modify a configuration file. In the long run we would recommend to switch over to the new openHABian Raspbian based system image! This error message will keep reapearing even after you fixed the issue at hand.\\nPlease find all details regarding the issue and the resolution of it at: https://github.com/openhab/openhabian/issues/147"
    if ! (whiptail --title "openHABian Raspberry Pi ua-netinst image detected" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 20 80); then return 0; fi
  fi
}

choose_ipv6() {
  local IPV6_DISABLE="net.ipv6.conf.all.disable_ipv6"

  # shellcheck disable=SC2154
  if [[ "$ipv6" == "disable" ]]; then
    if ! grep -qE "^${IPV6_DISABLE}" "${SYSCTL_INIT}"; then
      disable_ipv6 yes
    fi
  else
    if [[ "$ipv6" == "enable" ]]; then
      disable_ipv6 no
    fi
  fi

  sysctl -p
}

# arguments: "yes", "no"
disable_ipv6() {
  local APT_IPV6_DISABLE='Acquire::ForceIPv4 "true";'
  local APT_INIT=/etc/apt/apt.conf/S90force-ipv4
  local IPV6_DISABLE="net.ipv6.conf.all.disable_ipv6"
  local SYSCTL_INIT="/etc/sysctl.d/99-sysctl.conf"

  if [[ "$1" == "yes" ]]; then
    echo "${APT_IPV6_DISABLE}" | sudo tee "${APT_INIT}"

    if ! grep -qE "^${IPV6_DISABLE}" "${SYSCTL_INIT}"; then
      ( echo ""
        echo "###################################################################"
        echo "# disable all IPv6 functionality" >> "${SYSCTL_INIT}"
        echo "${IPV6_DISABLE}=1"
      )	>> "${SYSCTL_INIT}"
    else
      sed -i "s/^# ${IPV6_ENABLE}.*/${IPV6_ENABLE}/g" "${SYSCTL_INIT}"
    fi
  else
    rm -f "${APT_INIT}"
    sed -i "s/^${IPV6_ENABLE}.*/# ${IPV6_ENABLE}/g" "${SYSCTL_INIT}"
  fi
}

choose_ipv6() {
  local IPV6_DISABLE="net.ipv6.conf.all.disable_ipv6"

  # shellcheck disable=SC2154
  if [[ "$ipv6" == "disable" ]]; then
    if ! grep -qE "^${IPV6_DISABLE}" "${SYSCTL_INIT}"; then
      disable_ipv6 yes
    fi
  else
    if [[ "$ipv6" == "enable" ]]; then
      disable_ipv6 no
    fi
  fi

  sysctl -p
}

# arguments: "yes", "no"
disable_ipv6() {
  local APT_IPV6_DISABLE='Acquire::ForceIPv4 "true";'
  local APT_INIT=/etc/apt/apt.conf/S90force-ipv4
  local IPV6_DISABLE="net.ipv6.conf.all.disable_ipv6"
  local SYSCTL_INIT="/etc/sysctl.d/99-sysctl.conf"

  if [[ "$1" == "yes" ]]; then
    echo "${APT_IPV6_DISABLE}" | sudo tee "${APT_INIT}"

    if ! grep -qE "^${IPV6_DISABLE}" "${SYSCTL_INIT}"; then
      ( echo ""
        echo "###################################################################"
        echo "# disable all IPv6 functionality" >> "${SYSCTL_INIT}"
        echo "${IPV6_DISABLE}=1"
      )	>> "${SYSCTL_INIT}"
    else
      sed -i "s/^# ${IPV6_ENABLE}.*/${IPV6_ENABLE}/g" "${SYSCTL_INIT}"
    fi
  else
    rm -f "${APT_INIT}"
    sed -i "s/^${IPV6_ENABLE}.*/# ${IPV6_ENABLE}/g" "${SYSCTL_INIT}"
  fi
}

