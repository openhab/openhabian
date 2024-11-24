#!/usr/bin/env bash

## Display a nicely formatted git revision.
##
##    get_git_revision()
##
get_git_revision() {
  local branch
  local commitDate
  local shorthash

  branch="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"
  commitDate="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%aI' -n 1)"
  shorthash="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%h' -n 1)"

  echo "[${branch}]{${commitDate}}(${shorthash})"
}

## Cleanup apt after installation.
##
##    install_cleanup()
##
install_cleanup() {
  echo -n "$(timestamp) [openHABian] Cleaning up... "
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect apt-get clean -o DPkg::Lock::Timeout="$APTTIMEOUT"; then echo "FAILED (apt-get clean)"; return 1; fi
  if cond_redirect apt-get autoremove --yes -o DPkg::Lock::Timeout="$APTTIMEOUT"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## If needed, displays announcements that have been created by the openHABian developers.
##
##    openhabian_announcements()
##
openhabian_announcements() {
  if [[ -z $INTERACTIVE ]]; then return 1; fi

  local altReadNews
  local newsFile
  local readNews

  altReadNews="${TMPDIR:-/tmp}/NEWS.md"
  newsFile="${BASEDIR:-/opt/openhabian}/NEWS.md"
  readNews="${BASEDIR:-/opt/openhabian}/docs/NEWS.md"

  if ! cmp --silent "$newsFile" "$readNews" &> /dev/null; then
    # Check if the file has changed since last openHABian update (git update deletes first file)
    if ! cmp --silent "$newsFile" "$altReadNews" &> /dev/null; then
      # shellcheck disable=SC2086
      if (whiptail --title "openHABian announcements" --yes-button "Stop displaying" --no-button "Keep displaying" --defaultno --scrolltext --yesno "$(cat $newsFile)" 27 84); then
        cp "$newsFile" "$readNews"
      fi
    else
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

  whiptail --title "Compatibility warning" --msgbox "$warningText" 13 80
}

## Store a set parameter into openhabian.conf
## Parameter to write into openhabian.conf
##
##    store_in_conf(String parameter)
##
store_in_conf() {
  if [[ -z "$1" ]]; then return 0; fi
  # shellcheck disable=SC2154
  sed -i "s|^${1}=.*$|$1=${!1}|g" "$configFile"
}

## Check openhabian.conf against build-image/openhabian.conf for need to add parameters
## Add a parameter if it's missing or keep it if user provided.
## Cycling through build-image/openhabian.conf will ensure all current and future params are checked for
## Run on every start (to ensure params are up to date at any time)
##
##    update_openhabian_conf()
##
update_openhabian_conf() {
  local configFile="/etc/openhabian.conf"
  local referenceConfig="/opt/openhabian/build-image/openhabian.conf"

  cp $configFile ${configFile}.BAK
  while read -r line; do
    # remove optional leading '#'
    # ensure comments start with '#'
    if [[ $line =~ ^(#)?[a-zA-Z] ]]; then       # if line is a comment or empty
      parsed=$line
      if [[ $line =~ ^#[a-zA-Z] ]]; then parsed=${line:1}; fi

      param=$(echo "$parsed" | cut -d'=' -f1)   # get parameter name first
      if [[ -v $param ]]; then                  # if $param is set it was sourced on start i.e. exists in config
        if [[ ${!param} == *" "* ]]; then
          echo "$param=\"${!param}\""           # if $param contains whitespaces print quotes, too
        else
          echo "$param=${!param}"
        fi
      else
        echo "$line"
        eval "$parsed"
      fi
    else
      echo "$line"
    fi
  done > $configFile < $referenceConfig
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
  local unsupportedOSText

  branch="${clonebranch:-HEAD}"
  introText="Additions, improvements or fixes were added to the openHABian configuration tool. Would you like to update now and benefit from them? The update will not automatically apply changes to your system.\\n\\nUpdating is recommended."
  unsupportedOSText="You are running an old Linux release that is no longer officially supported.\\nWe recommend upgrading to the most current stable release of your distribution (or current Long Term Support version for distributions that offer LTS).\\nDo you really want to continue using openHABian on this system?"

  echo "$(timestamp) [openHABian] openHABian configuration tool version: $(get_git_revision)"
  echo -n "$(timestamp) [openHABian] Checking for changes in origin branch ${branch}... "

  if is_stretch || is_xenial; then
    if ! (whiptail --title "Unsupported Linux release" --yes-button "Yes, Continue" --no-button "No, Exit" --defaultno --yesno "$unsupportedOSText" 13 80); then echo "SKIP"; exit 0; fi
  fi

  if ! git -C "${BASEDIR:-/opt/openhabian}" config user.email 'openhabian@openHABian'; then echo "FAILED (git email)"; return 1; fi
  if ! git -C "${BASEDIR:-/opt/openhabian}" config user.name 'openhabian'; then echo "FAILED (git user)"; return 1; fi
  if ! git -C "${BASEDIR:-/opt/openhabian}" fetch --quiet origin; then echo "FAILED (fetch origin)"; return 1; fi

  if [[ $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse "$branch") == $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse @\{u\}) ]]; then
    echo "OK"
  else
    echo -n "Updates available... "
    if (whiptail --title "openHABian update available" --yes-button "Continue" --no-button "Skip" --yesno "$introText" 11 80); then echo "UPDATING"; else echo "SKIP"; return 0; fi
    openhabian_update "$branch"
  fi
  openhabian_announcements
  echo -n "$(timestamp) [openHABian] Switching to branch ${clonebranch:-openHAB}... "
  if git -C "${BASEDIR:-/opt/openhabian}" checkout --quiet "${clonebranch:-openHAB}"; then echo "OK"; else echo "FAILED"; return 1; fi
  echo "$(timestamp) [openHABian] Checking openHAB Signing Key expiry."
  if ! check_keys openhab; then
    add_keys "https://openhab.jfrog.io/artifactory/api/gpg/key/public" openhab
  fi
}

## Updates the current openhabian repository to the most current version of the
## current branch.
##
##    openhabian_update()
##
openhabian_update() {
  local branch
  local branchLabel
  local current
  local dialogHeight=16
  local radioOptions
  local introText
  local key
  local selection
  local shorthashAfter
  local shorthashBefore

  current="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"
  echo -n "$(timestamp) [openHABian] Updating myself... "
  if [[ $# == 1 ]]; then
    branch="$1"
  elif [[ -n $INTERACTIVE ]]; then
    radioOptions=("release" "most recommended version that supports openHAB 4 (openHAB branch)" "OFF")
    radioOptions+=("latest" "the latest of openHABian, not well tested (main branch)" "OFF")

    case "$current" in
      "openHAB")
        branchLabel="the release version of openHABian"
        radioOptions[2]="ON"
        ;;

      "main")
        branchLabel="the latest version of openHABian"
        radioOptions[5]="ON"
        ;;

      *)
        branchLabel="a custom version of openHABian. If you think this is an error, please report on Github (remember to provide a debug log - see debug guide)."
        radioOptions+=("$current" "some other version you fetched yourself" "ON")
        dialogHeight=18
        ;;
    esac

    introText="You are currently using ${branchLabel}.\\n\\nYou can switch openHABian version at any time by selecting this menu option again or by setting the 'clonebranch=' parameter in '/etc/openhabian.conf'.\\nNote: this menu only changes the version of openHABian and not openHAB. To select the openHAB version, see the 'openHAB Related' menu item."

    if ! selection="$(whiptail --title "openHABian version" --radiolist "$introText" $dialogHeight 90 "$(( ${#radioOptions[@]} / 3 ))" "${radioOptions[@]}" 3>&1 1>&2 2>&3)"; then return 0; fi

    # translate the selection back to the actual git branch name
    case $selection in
      release) selection="openHAB";;
      latest) selection="main";;
    esac

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
      branch="${selection:-openHAB}"
    fi
    if ! sed -i 's|^clonebranch=.*$|clonebranch='"${branch}"'|g' "$configFile"; then echo "FAILED (configure clonebranch)"; exit 1; fi
  else
    branch="${clonebranch:-openHAB}"
  fi

  shorthashBefore="$(git -C "${BASEDIR:-/opt/openhabian}" log --pretty=format:'%h' -n 1)"
  # Enable persistence for NEWS display (git update will delete the file otherwise)
  mv "${BASEDIR:-/opt/openhabian}"/docs/NEWS.md "${TMPDIR:-/tmp}"/NEWS.md
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
  local param
  local defaultPassword
  local defaultUser
  local generatedPassword
  local introText
  local originalPassword
  local salt
  local fields

  if is_pi && id -u pi &> /dev/null; then
    defaultUser="pi"
    defaultPassword="raspberry"
  elif is_pi; then
    defaultUser="${username:-openhabian}"
    defaultPassword="openhabian"
  fi
  originalPassword="$(grep -w "$defaultUser" /etc/shadow | cut -d: -f2)"
  fields=$(echo "$originalPassword" | awk -F'$' '{print NF}')
  case $fields in
    5)
      algo="$(echo "$originalPassword" | cut -d'$' -f2)"
      param="$(echo "$originalPassword" | cut -d'$' -f3)"
      salt="$(echo "$originalPassword" | cut -d'$' -f4)"
      export algo defaultPassword param salt fields
      generatedPassword="$(perl -le 'print crypt("$ENV{defaultPassword}","\$$ENV{algo}\$$ENV{param}\$$ENV{salt}\$")')"
      ;;
    *)
      algo="$(echo "$originalPassword" | cut -d'$' -f2)"
      salt="$(echo "$originalPassword" | cut -d'$' -f3)"
      export algo defaultPassword salt fields
      generatedPassword="$(perl -le 'print crypt("$ENV{defaultPassword}","\$$ENV{algo}\$$ENV{salt}\$")')"
      ;;
  esac

  introText="The default password was detected on your system! That is a serious security concern. Bad guys or malicious programs in your subnet are able to gain root access!\\n\\nPlease set a strong password by typing the command 'passwd ${defaultUser}'!"

  echo -n "$(timestamp) [openHABian] Checking for default openHABian username:password combination... "
  if ! [[ $(id -u "$defaultUser") ]]; then echo "OK (unknown user)"; return 0; fi
  if [[ $generatedPassword == "$originalPassword" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Default password detected" --msgbox "$introText" 11 80
    fi
    echo "FAILED"
  else
    echo "OK"
  fi
}


## Enable / Disable IPv6 according to the users configured option in '$configFile'
## Valid arguments: "enable" or "disable"
##
##    config_ipv6()
##
config_ipv6() {
  local aptConf="/etc/apt/apt.conf.d/S90force-ipv4"
  local sysctlConf="/etc/sysctl.d/99-sysctl.conf"

  echo -n "$(timestamp) [openHABian] Making sure router advertisements are available... "
  if ! grep -qs "net.ipv6.conf.all.accept_ra = 1" "$sysctlConf"; then
    echo -e "\\n# Enable IPv6 route advertisements\\n# This is needed for proper discovery with the Matter binding\\nnet.ipv6.conf.all.accept_ra = 1\\nnet.ipv6.conf.all.accept_ra_rt_info_max_plen = 64" >> "$sysctlConf"
  fi
  if cond_redirect sysctl --load; then echo "OK"; else echo "FAILED"; return 1; fi

  if [[ "${1:-${ipv6:-enable}}" == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Disabling IPv6... "
    if ! grep -qs "^[[:space:]]*# Disable all IPv6 functionality" "$sysctlConf"; then
      echo -e "\\n# Disable all IPv6 functionality\\nnet.ipv6.conf.all.disable_ipv6=1\\nnet.ipv6.conf.default.disable_ipv6=1\\nnet.ipv6.conf.lo.disable_ipv6=1" >> "$sysctlConf"
    fi
    cp "${BASEDIR:-/opt/openhabian}"/includes/S90force-ipv4 "$aptConf"
    if cond_redirect sysctl --load; then echo "OK"; else echo "FAILED"; return 1; fi
  elif [[ "${1:-${ipv6:-enable}}" == "enable" ]] && grep -qs "^[[:space:]]*# Disable all IPv6 functionality" "$sysctlConf"; then
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

## Import configuration
##
##    import_openhab_config()
##
## Valid arguments: file name or URL to import using openhab-cli
##
import_openhab_config() {
  local initialConfig="${1:-${initialconfig:-/boot/initial.zip}}"
  local restoreFile="${initialConfig}"


  if [[ -n $INTERACTIVE ]]; then
    if ! initialConfig=$(whiptail --title "Import configuration" --inputbox "Enter the full filename or URL to retrieve the configuration file from." 9 80 "$initialConfig" 3>&1 1>&2 2>&3); then return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Getting initial openHAB configuration... "
  if [[ "$initialConfig" =~ http:* ]]; then
    restoreFile="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"
    if ! cond_redirect wget -nv -O "$restoreFile" "$initialConfig"; then echo "FAILED (download file)"; rm -f "$restoreFile"; return 1; fi
  fi
  if [[ -n $UNATTENDED ]] && ! [[ -f $restoreFile ]]; then
     echo "SKIPPED (backup not found at ${initialConfig})"
     return 0
  fi
  echo "OK"

  if ! restore_openhab_config "$restoreFile"; then return 1; fi
}
