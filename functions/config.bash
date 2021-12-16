#!/usr/bin/env bash
# shellcheck source=/etc/openhabian.conf disable=SC1091,SC2154

## Load, copy, or create a new configuration file for openHABian.
##
##    load_create_config()
##
load_create_config() {
  local questionText="\\nWelcome to openHABian!\\n\\nPlease provide the name of your Linux user i.e. the account you normally log in with.\\n\\nTypical user names are 'pi' or 'ubuntu'."
  local input

  if [[ -f $configFile ]]; then
    echo -n "$(timestamp) [openHABian] Loading configuration file '${configFile}'... "
    # on non Raspi OS image installations the admin user may be missing
    if [[ ! $(getent group "${username:-openhabian}") ]] || ! id -u "${username:-openhabian}" &> /dev/null; then
      create_user_and_group
    fi
  elif ! [[ -f $configFile ]] && [[ -f /boot/installer-config.txt ]]; then
    echo -n "$(timestamp) [openHABian] Copying and loading configuration file '${configFile}'... "
    if ! cond_redirect cp /boot/installer-config.txt "$configFile"; then echo "FAILED (copy configuration)"; exit 1; fi
  elif ! [[ -f $configFile ]] && [[ -n $UNATTENDED ]]; then
    echo "$(timestamp) [openHABian] Error in unattended mode: Configuration file '${configFile}' not found... FAILED" 1>&2
    exit 1
  else
    echo -n "$(timestamp) [openHABian] Setting up and loading configuration file '$configFile' in manual setup... "
    if input="$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$questionText" 14 80 3>&1 1>&2 2>&3)" && id -u "$input" &> /dev/null; then
      if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/build-image/openhabian.conf "$configFile"; then echo "FAILED (copy configuration)"; exit 1; fi
      if ! cond_redirect sed -i -e 's|^username=.*$|username='"${input}"'|g' "$configFile"; then echo "FAILED (configure admin username)"; exit 1; fi
    else
      echo "FAILED"
      echo "$(timestamp) [openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting..." 1>&2
      exit 1
    fi
  fi
  source "$configFile"
  echo "OK"
}

## Removes the password from '$configFile'.
## This is run at the end of a fresh install for security reasons.
##
##    clean_config_userpw()
##
clean_config_userpw() {
  if ! cond_redirect sed -i -e 's|^userpw=.*$|\#userpw=xxxxxx|g' "$configFile"; then return 1; fi
}

## Update requested version of Java in '$configFile'.
## Valid arguments: "11", "17"
##
##    update_config_java(String type)
##
update_config_java() {
  if ! cond_redirect sed -i -e 's|^java_opt.*$|java_opt='"${1}"'|' "$configFile"; then return 1; fi
  source "$configFile"
}
