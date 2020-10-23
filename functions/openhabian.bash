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
    if (whiptail --title "openHABian announcements" --yes-button "Stop Displaying" --no-button "Keep Displaying" --defaultno --scrolltext --yesno "$(cat $newsFile)" 27 100); then
      cp "$newsFile" "$readNews"
    fi
  fi
}

## Displays a warning if the current console may exibit issues displaying the
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


## Check against openhabian.conf for need to update parameters
## Add a parameter if it's missing or keep it if user provided.
## Cycling through openhabian.conf.dist will ensure all current and future params are checked for
## Run on every start (to ensure params are *up to date* whenever the user changes branch or openhabian-config unattended is run)
##
##    update_openhabian_conf()
##
update_openhabian_conf() {
  local config=/etc/openhabian.conf
  local referenceConfig=/opt/openhabian/openhabian.conf.dist

  cp $config ${config}.BAK
  cp /dev/null $config

  while read -r line; do
    if [[ $line =~ ^# ]] || [[ -z "$line" ]]; then  # if line is a comment or empty
      echo "$line"
    else                                            # not fully sure if anything else is a proper param setting but let's assume this
      param=$(echo "$line" | cut -d'=' -f1)         # get parameter name first
      if [[ -z ${!param+x} ]]; then                 # if $param is set (if so it is because it was sourced on start)
        echo "$line"                                # take the param from the default config by printing the default .conf's full line
      elif [[ ${!param} == *" "* ]]; then
      	echo "$param=\"${!param}\""                 # else parameter is set i.e. a line setting it is present in $config so use its value
      else
	echo "$param=${!param}"
      fi
    fi
  done > $config < $referenceConfig
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
  local stable
  local master
  local openHAB3
  local current
  local introText
  local own="yes"
  local key
  local selection
  local shorthashAfter
  local shorthashBefore

  current="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"
  echo -n "$(timestamp) [openHABian] Updating myself... "
  if [[ $# == 1 ]]; then
    branch="$1"
  elif [[ -n $INTERACTIVE ]]; then
    if [[ $current == "master" ]] || [[ $current == "stable" ]]; then
        introText="You are currently using the \"${current}\" openHABian environment version. I will ONLY work with openHAB version 2.\\nIf you want to run openHAB 3 you need to switch to the \"openHAB3\" branch. If that's your intent better let the upgrade function do it for you and validate afterwards you are on openHAB3 branch.\\n\\nThe very latest openHAB 2 version is called \"master\".\\nThis is providing you with the latest (openHAB2 !) features but less people have tested it so it is a little more likely that you run into errors.\\nYou can step back a little and switch to use the stable version now.\\nYou can switch at any time by selecting this menu option again or by setting the 'clonebranch=' parameter in '/etc/openhabian.conf'.\\n"
    else
      if [[ $current == "openHAB3" ]]; then
          introText="You are currently the latest (\"openHAB3\") openHABian environment version.\\nYou will need to be on here (openHAB3) if you want to run openHAB version 3.\\n\\nYou can switch environments at any time by selecting this menu option again or by setting the 'clonebranch=' parameter in '/etc/openhabian.conf'.\\n\\nATTENTION: If you want to upgrade to openHAB 3 you should select \"Cancel\" now and select option 03 from the main menu instead."
      else
          introText="You are currently using an unknown branch of openHABian.\\nThis may be a test version or an error, if so please report on Github (remember to provide a debug log - see debug guide)."
      fi
    fi

    if [[ $current == "stable" ]]; then
      stable="ON"
      master="OFF"
      openHAB3="OFF"
      own="no"
    elif [[ $current == "master" ]]; then
      stable="OFF"
      master="ON"
      openHAB3="OFF"
      own="no"
    elif [[ $current == "openHAB3" ]]; then
      stable="OFF"
      master="OFF"
      openHAB3="ON"
      own="no"
    else
      own="yes"
    fi

    if [[ $own == "no" ]]; then
      if ! selection="$(whiptail --title "openHABian version" --radiolist "$introText" 14 100 3 stable "recommended standard version of openHABian" "$stable" master "very latest version of openHABian" "$master" openHAB3 "openHAB 3.0" "$openHAB3" 3>&1 1>&2 2>&3)"; then return 0; fi
    else
      if ! selection="$(whiptail --title "openHABian version" --radiolist "$introText" 15 100 4 stable "recommended standard version of openHABian" OFF master "very latest version of openHABian" OFF openHAB3 "openHAB 3.0" OFF "$current" "some other version you fetched yourself" ON 3>&1 1>&2 2>&3)"; then return 0; fi
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
    echo -e "\\n${COL_DEF}openHABian configuration tool successfully updated."
    if [[ -n $INTERACTIVE ]]; then
      echo "Visit the development repository for more details: ${repositoryurl:-https://github.com/openhab/openhabian.git}"
      echo "The tool will now restart to load the updates... OK"
      exec "${BASEDIR:-/opt/openhabian}/$SCRIPTNAME" migration
      exit 0
    fi
  fi
}

## Changes files on disk to match the new (changed) openhabian branch
## Valid arguments: "openHAB3" or "openHAB2"
##
##    migrate_installation()
##
migrate_installation() {
  local failText="is already installed on your system !\\n\\nCanceling migration, returning to menu."
  local frontailService="/etc/systemd/system/frontail.service"
  local homegearService="/etc/systemd/system/homegear.service"
  local zramService="/etc/systemd/system/zram-config.service"
  local frontailJSON="/usr/lib/node_modules/frontail/preset/openhab.json"
  local amandaConfigs="/etc/amanda/openhab-*/disklist"
  local ztab="/etc/ztab"
  local serviceDir="/etc/systemd/system"
  local services
  # shellcheck disable=SC2206
  local mountUnits="${serviceDir}/srv-openhab*"
  local from
  local to
  local distro
  local javaVersion

  if [[ -z $INTERACTIVE  ]]; then
    echo "$(timestamp) [openHABian] Migration must be triggered in interactive mode... SKIPPED"
    return 0
  fi

  echo -n "$(timestamp) [openHABian] Preparing openHAB installation... "

  if [[ "$1" == "openHAB3" ]]; then
    if openhab3_is_installed; then
      whiptail --title "openHAB version already installed" --msgbox "openHAB3 $failText" 10 80
      echo "FAILED (openHAB 3 already installed)"
      return 1
    fi
    from="openhab2"
    to="openhab"
    distro="stable"
  else
    if openhab2_is_installed; then
      whiptail --title "openHAB version already installed" --msgbox "openHAB 2 $failText" 10 80
      echo "FAILED (openHAB 2 already installed)"
      return 1
    fi
    from="openhab"
    to="openhab2"
    distro="stable"
  fi
  services="srv-${from}\\x2daddons.mount srv-${from}\\x2dconf.mount srv-${from}\\x2duserdata.mount  srv-${from}\\x2dsys.mount"

  javaVersion="$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | sed -e 's/_.*//g; s/^1\.//g; s/\..*//g; s/-.*//g;')"
  # shellcheck disable=SC2154
  [[ "$zraminstall" != "disable" ]] && [[ -s /etc/ztab ]] && if cond_redirect zram-config "stop"; then echo "OK"; else echo "FAILED (stop ZRAM)"; return 1; fi
  backup_openhab_config

  if [[ -z "$javaVersion" ]] || [[ "${javaVersion}" -lt "11" ]]; then
    echo -n "$(timestamp) [openHABian] WARNING: We were unable to detect Java 11 on your system so we will install the openHABian default (Zulu 11)."
    java_install_or_update "Zulu11-32"
  fi
  echo -n "$(timestamp) [openHABian] Installing openHAB... "
  if openhab_setup "$1" "${distro}"; then echo "OK"; else echo "FAILED (install openHAB)"; cond_redirect systemctl start zram-config.service; return 1; fi

  if [[ -d /var/lib/openhab/persistence/mapdb ]]; then
    echo -n "$(timestamp) [openHABian] Deleting mapdb persistence files... "
    rm -f /var/lib/${to}/persistence/mapdb/storage.mapdb
    echo "OK"
  fi

  echo -n "$(timestamp) [openHABian] Migrating Amanda config... "
  for i in $amandaConfigs; do
    if [[ -s "$i" ]]; then
      sed -i "s|/${from}|/${to}|g" "$i"
    fi
  done
  echo "OK"

  echo -n "$(timestamp) [openHABian] Migrating Samba and mount units... "
  if ! cond_redirect systemctl stop smbd nmbd; then echo "FAILED (stop samba)"; return 1; fi
  # shellcheck disable=SC2086
  if ! cond_redirect systemctl disable --now ${services}; then echo "FAILED (disable mount units)"; fi
  for s in ${mountUnits}; do
    if [[ "$to" == "openhab" ]] || ! grep -q "Description=$to" "$s"; then
      newname=${s//${from}/${to}}
      sed -e "s|${from}|${to}|g" "${s}" > "${newname}"
      rm -f "$s"
    fi
  done

  services=${services//${from}/${to}}
  sed -i "s|/${from}|/${to}|g" /etc/samba/smb.conf

  # shellcheck disable=SC2086
  if cond_redirect systemctl enable --now ${services}; then echo "OK"; else echo "FAILED (reenable mount units)"; return 1; fi
  if cond_redirect systemctl start smbd nmbd; then echo "OK"; else echo "FAILED (reenable samba)"; return 1; fi
  echo -n "$(timestamp) [openHABian] Migrating frontail... "
  sed -i "s|${from}/|${to}/|g" $frontailService
  sed -i "s|${from}/|${to}/|g" $frontailJSON
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl restart frontail.service; then echo "OK"; else echo "FAILED (restart frontail)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Migrating homegear... "
  sed -i "s|${from}/|${to}/|g" $homegearService
  echo "OK"

  if [[ -s /etc/ztab ]]; then
    echo -n "$(timestamp) [openHABian] Migrating ZRAM config... "
    sed -i "s|/${from}|/${to}|g" "$ztab"
    sed -i "s|${from}|${to}|g" "$zramService"
  fi

  # shellcheck disable=SC2154
  [[ "$zraminstall" != "disable" ]] && if cond_redirect systemctl restart zram-config.service; then echo "OK"; else echo "FAILED (restart ZRAM)"; return 1; fi
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
    defaultUser="${username:-openhabian}"
    defaultPassword="openhabian"
  fi
  originalPassword="$(grep -w "$defaultUser" /etc/shadow | cut -d: -f2)"
  algo="$(echo "$originalPassword" | cut -d'$' -f2)"
  introText="The default password was detected on your system! That is a serious security concern. Bad guys or malicious programs in your subnet are able to gain root access!\\n\\nPlease set a strong password by typing the command 'passwd ${defaultUser}'!"
  salt="$(echo "$originalPassword" | cut -d'$' -f3)"
  export algo defaultPassword salt
  generatedPassword="$(perl -le 'print crypt("$ENV{defaultPassword}","\$$ENV{algo}\$$ENV{salt}\$")')"

  echo -n "$(timestamp) [openHABian] Checking for default openHABian username:password combination... "
  if ! [[ $(id -u "$defaultUser") ]]; then echo "OK (unknown user)"; return 0; fi
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
  local aptConf="/etc/apt/apt.conf.d/S90force-ipv4"
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


## Create UNIX user and group for openHABian administration purposes
##
##    create_user_and_group()
##
## IF
## (1) the string/username that the end user entered as "username=" in openhabian.conf is *empty* OR
## (2) the default user ("pi" on RaspiOS, "openhabian" on other OS) does not exist OR
## (3) the user whose name the end user entered as "username=" in openhabian.conf *exists*
##     (and isn't empty because (1) applies, too)
## THEN skip
## ELSE rename the default user and default group to what is defined as username= in openhabian.conf
##
create_user_and_group() {
  local userName="${username:-openhabian}"

  if ! [[ $(id -u "$userName" &> /dev/null) ]]; then
    if ! cond_redirect adduser --quiet --disabled-password --gecos "openHABian,,,,openHAB admin user" --shell /bin/bash --home "/home/${userName}" "$userName"; then echo "FAILED (add default usergroup $userName)"; return 1; fi
    echo "${userName}:${userpw:-openhabian}" | chpasswd
    cond_redirect usermod --append --groups openhab,sudo "$userName" &> /dev/null
  fi
}
