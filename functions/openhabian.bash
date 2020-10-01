#!/usr/bin/env bash

## Display a nicely formatted git revision.
##
##    get_git_revision()
##
get_git_revision() {
  local branch
  local latestTag
  local revCount
  local shorthash

  branch="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"
  latestTag="$(git -C "${BASEDIR:-/opt/openhabian}" describe --tags --abbrev=0)"
  revCount="$(git -C "${BASEDIR:-/opt/openhabian}" log --oneline | wc -l)"
  shorthash="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%h' -n 1)"

  echo "[${branch}]${latestTag}-${revCount}(${shorthash})"
}

## Cleanup apt after installation.
##
##    install_cleanup()
##
install_cleanup() {
  echo -n "$(timestamp) [openHABian] Cleaning up... "
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect apt-get clean; then echo "FAILED (apt-get clean)"; return 1; fi
  if cond_redirect apt-get autoremove --yes; then echo "OK"; else echo "FAILED"; return 1; fi
}

## If needed, displays announcements that have been created by the openHABian developers.
##
##    openhabian_announcements()
##
openhabian_announcements() {
  if [[ -z $INTERACTIVE ]]; then return 1; fi

  local newsFile
  local readNews

  newsFile="${BASEDIR:-/opt/openhabian}/NEWS.md"
  readNews="${BASEDIR:-/opt/openhabian}/docs/LASTNEWS.md"

  if ! cmp --silent "$newsFile" "$readNews" &> /dev/null; then
    # shellcheck disable=SC2086
    if (whiptail --title "openHABian announcements" --yes-button "Stop Displaying" --no-button "Keep Displaying" --defaultno --scrolltext --yesno "$(cat $newsFile)" 27 85); then
      cp "$newsFile" "$readNews"
    fi
  fi
}

## Displays a warning if the current console may exibit issues displaing the
## openHABian menus.
##
##    openhabian_console_check()
##
openhabian_console_check() {
  if [[ -z $INTERACTIVE ]]; then return 1; fi
  if [[ $(tput cols) -ge 120 ]]; then return 0; fi

  local warningText

  warningText="We detected that you use a console which is less than 120 columns wide. This tool is designed for a minimum of 120 columns and therefore some menus may not be presented correctly. Please increase the width of your console and rerun this tool.\\n\\nEither resize the window or consult the preferences of your console application."

  whiptail --title "Compatibility Warning" --msgbox "$warningText" 13 80
}

## Check for updates to the openhabian git repository, if so then issue an update.
## This also ensures that announcements will be displayed and that we stay on the correct branch.
##
##    openhabian_update_check()
##
openhabian_update_check() {
  if [[ -z $INTERACTIVE ]]; then return 0; fi

  local branch
  local introText
  local unsupportedHWText
  local unsupportedOSText

  branch="${clonebranch:-HEAD}"
  introText="Additions, improvements or fixes were added to the openHABian configuration tool. Would you like to update now and benefit from them? The update will not automatically apply changes to your system.\\n\\nUpdating is recommended."
  unsupportedHWText="You are running on old hardware that is no longer officially supported.\\nopenHABian may still work with this or not.\\nWe recommend that you replace your hardware with a current SBC such as a RPi4/2GB.\\nDo you really want to continue using openHABian on this system?"
  unsupportedOSText="You are running an old Linux release that is no longer officially supported.\\nWe recommend upgrading to the most current stable release of your distribution (or current Long Term Support version for distributions that offer LTS).\\nDo you really want to continue using openHABian on this system?"

  echo "$(timestamp) [openHABian] openHABian configuration tool version: $(get_git_revision)"
  echo -n "$(timestamp) [openHABian] Checking for changes in origin branch ${branch}... "

  if is_pine64; then
    if ! (whiptail --title "Unsupported hardware" --yes-button "Yes, Continue" --no-button "No, Exit" --defaultno --yesno "$unsupportedHWText" 13 80); then echo "SKIP"; exit 0; fi
  fi
  if is_jessie || is_xenial; then
    if ! (whiptail --title "Unsupported Linux release" --yes-button "Yes, Continue" --no-button "No, Exit" --defaultno --yesno "$unsupportedOSText" 13 80); then echo "SKIP"; exit 0; fi
  fi

  if ! git -C "${BASEDIR:-/opt/openhabian}" config user.email 'openhabian@openHABian'; then echo "FAILED (git email)"; return 1; fi
  if ! git -C "${BASEDIR:-/opt/openhabian}" config user.name 'openhabian'; then echo "FAILED (git user)"; return 1; fi
  if ! git -C "${BASEDIR:-/opt/openhabian}" fetch --quiet origin; then echo "FAILED (fetch origin)"; return 1; fi

  if [[ $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse "$branch") == $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse @\{u\}) ]]; then
    echo "OK"
  else
    echo -n "Updates available... "
    if (whiptail --title "openHABian Update Available" --yes-button "Continue" --no-button "Skip" --yesno "$introText" 11 80); then echo "UPDATING"; else echo "SKIP"; return 0; fi
    openhabian_update
  fi
  openhabian_announcements
  echo -n "$(timestamp) [openHABian] Switching to branch ${clonebranch:-stable}... "
  if git -C "${BASEDIR:-/opt/openhabian}" checkout --quiet "${clonebranch:-stable}"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Updates the current openhabian repository to the most current version of the
## current branch.
##
##    openhabian_update()
##
openhabian_update() {
  local branch
  local current
  local introText
  local key
  local selection
  local shorthashAfter
  local shorthashBefore

  current="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"
  if [[ $current == "master" ]]; then
    introText="You are currently using the very latest (\"master\") version of openHABian.\\nThis is providing you with the latest features but less people have tested it so it is a little more likely that you run into errors.\\nWould you like to step back a little now and switch to use the stable version ?\\nYou can switch at any time by selecting this menu option again or by setting the 'clonebranch=' parameter in '/etc/openhabian.conf'.\\n"
  else
    introText="You are currently using neither the stable version nor the latest (\"master\") version of openHABian.\\nAccess to the latest features would require you to switch to master while the default is to use the stable version.\\nWould you like to step back a little now and switch to use the stable version ?\\nYou can switch versions at any time by selecting this menu option again or by setting the 'clonebranch=' parameter in '/etc/openhabian.conf'.\\n"
  fi

  echo -n "$(timestamp) [openHABian] Updating myself... "

  if [[ -n $INTERACTIVE ]]; then
    if [[ $current == "stable" || $current == "master" ]]; then
      if ! selection="$(whiptail --title "openHABian version" --radiolist "$introText" 14 80 2 stable "recommended standard version of openHABian" ON master "very latest version of openHABian" OFF 3>&1 1>&2 2>&3)"; then return 0; fi
    else
      if ! selection="$(whiptail --title "openHABian version" --radiolist "$introText" 14 80 3 stable "recommended standard version of openHABian" OFF master "very latest version of openHABian" OFF "$current" "some other version you fetched yourself" ON 3>&1 1>&2 2>&3)"; then return 0; fi
    fi
    read -r -t 1 -n 1 key
    if [[ -n $key ]]; then
      echo -e "\\nRemote git branches available:"
      git -C "${BASEDIR:-/opt/openhabian}" branch -r
      read -r -e -p "Please enter the branch to checkout: " branch
      branch="${branch#origin/}"
      if ! git -C "${BASEDIR:-/opt/openhabian}" branch -r | grep -qs "origin/$branch"; then
        echo "FAILED (custom branch does not exist)"
        return 1
      fi
    else
      branch="${selection:-stable}"
    fi
    if ! sed -i 's|^clonebranch=.*$|clonebranch='"${branch}"'|g' "$CONFIGFILE"; then echo "FAILED (configure clonebranch)"; exit 1; fi
  else
    branch="${clonebranch:-stable}"
  fi

  shorthashBefore="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%h' -n 1)"
  if ! cond_redirect update_git_repo "${BASEDIR:-/opt/openhabian}" "$branch"; then echo "FAILED (update git repo)"; return 1; fi
  shorthashAfter="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%h' -n 1)"

  if [[ $shorthashBefore == "$shorthashAfter" ]]; then
    echo "OK - No remote changes detected. You are up to date!"
    return 0
  else
    echo -e "OK - Commit history (oldest to newest):\\n"
    git -C "${BASEDIR:-/opt/openhabian}" --no-pager log --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)<%an>%Creset %C(dim yellow)%G?' --reverse --abbrev-commit --stat "$shorthashBefore..$shorthashAfter"
    echo -e "\\nopenHABian configuration tool successfully updated."
    if [[ -n $INTERACTIVE ]]; then
      echo "Visit the development repository for more details: ${repositoryurl:-https://github.com/openhab/openhabian.git}"
      echo "The tool will now restart to load the updates... OK"
      exec "${BASEDIR:-/opt/openhabian}/$SCRIPTNAME"
      exit 0
    fi
  fi
}

## Check for default system password and if found issue a warning and suggest
## changing the password.
##
##    system_check_default_password()
##
system_check_default_password() {
  if ! is_pi; then return 0; fi

  local algo
  local defaultPassword
  local defaultUser
  local generatedPassword
  local introText
  local originalPassword
  local salt

  if is_pi && id -u pi &> /dev/null; then
    defaultUser="pi"
    defaultPassword="raspberry"
  elif is_pi; then
    defaultUser="openhabian"
    defaultPassword="openhabian"
  fi
  originalPassword="$(grep -w "$defaultUser" /etc/shadow | cut -d: -f2)"
  algo="$(echo "$originalPassword" | cut -d'$' -f2)"
  introText="The default password was detected on your system! That is a serious security concern. Bad guys or malicious programs in your subnet are able to gain root access!\\n\\nPlease set a strong password by typing the command 'passwd ${defaultUser}'!"
  salt="$(echo "$originalPassword" | cut -d'$' -f3)"
  export algo defaultPassword salt
  generatedPassword="$(perl -le 'print crypt("$ENV{defaultPassword}","\$$ENV{algo}\$$ENV{salt}\$")')"

  echo -n "$(timestamp) [openHABian] Checking for default openHABian username:password combination... "
  if ! [[ $(id -u $defaultUser) ]]; then echo "OK (unknown user)"; return 0; fi
  if [[ $generatedPassword == "$originalPassword" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Default Password Detected!" --msgbox "$introText" 11 80
    fi
    echo "FAILED"
  else
    echo "OK"
  fi
}

## Enable / Disable IPv6 according to the users configured option in '$CONFIGFILE'
##
##    config_ipv6()
##
config_ipv6() {
  local aptConf="/etc/apt/apt.conf/S90force-ipv4"
  local sysctlConf="/etc/sysctl.d/99-sysctl.conf"

  if [[ "${ipv6:-enable}" == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Disabling IPv6... "
    if ! grep -qs "^[[:space:]]*# Disable all IPv6 functionality" "$sysctlConf"; then
      echo -e "\\n# Disable all IPv6 functionality\\nnet.ipv6.conf.all.disable_ipv6=1\\nnet.ipv6.conf.default.disable_ipv6=1\\nnet.ipv6.conf.lo.disable_ipv6=1" >> "$sysctlConf"
    fi
    cp "${BASEDIR:-/opt/openhabian}"/includes/S90force-ipv4 "$aptConf"
    if cond_redirect sysctl --load; then echo "OK"; else echo "FAILED"; return 1; fi
  elif [[ "${ipv6:-enable}" == "enable" ]] && grep -qs "^[[:space:]]*# Disable all IPv6 functionality" "$sysctlConf"; then
    echo -n "$(timestamp) [openHABian] Enabling IPv6... "
    sed -i '/# Disable all IPv6 functionality/d; /net.ipv6.conf.all.disable_ipv6=1/d; /net.ipv6.conf.default.disable_ipv6=1/d; /net.ipv6.conf.lo.disable_ipv6=1/d' "$sysctlConf"
    rm -f "$aptConf"
    if cond_redirect sysctl --load; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}
