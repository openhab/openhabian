#!/usr/bin/env bash
# shellcheck source=/etc/openhabian.conf disable=SC1091

## Load, copy, or create a new configuration file for openHABian.
##
##    load_create_config()
##
load_create_config() {
  local questionText="\\nWelcome to openHABian!\\n\\nPlease provide the name of your Linux user i.e. the account you normally log in with.\\n\\nTypical user names are 'pi' or 'ubuntu'."
  local input

  if [[ -f $CONFIGFILE ]]; then
    echo -n "$(timestamp) [openHABian] Loading configuration file '${CONFIGFILE}'... "
    # on non Raspi OS image installations the admin user may be missing
    if [[ ! $(getent group "${adminusername:-openhabian}") ]] || ! id -u "${adminusername:-openhabian}" &> /dev/null; then
      create_user_and_group
    fi
  elif ! [[ -f $CONFIGFILE ]] && [[ -f /boot/installer-config.txt ]]; then
    echo -n "$(timestamp) [openHABian] Copying and loading configuration file '${CONFIGFILE}'... "
    if ! cond_redirect cp /boot/installer-config.txt "$CONFIGFILE"; then echo "FAILED (copy configuration)"; exit 1; fi
  elif ! [[ -f $CONFIGFILE ]] && [[ -n $UNATTENDED ]]; then
    echo "$(timestamp) [openHABian] Error in unattended mode: Configuration file '${CONFIGFILE}' not found... FAILED" 1>&2
    exit 1
  else
    echo -n "$(timestamp) [openHABian] Setting up and loading configuration file '$CONFIGFILE' in manual setup... "
    if input="$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$questionText" 14 80 3>&1 1>&2 2>&3)" && id -u "$input" &> /dev/null; then
      if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/openhabian.conf.dist "$CONFIGFILE"; then echo "FAILED (copy configuration)"; exit 1; fi
      if ! cond_redirect sed -i -e 's|^adminusername=.*$|adminusername='"${input}"'|g' "$CONFIGFILE"; then echo "FAILED (configure adminusername)"; exit 1; fi
    else
      echo "FAILED"
      echo "$(timestamp) [openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting..." 1>&2
      exit 1
    fi
  fi
  source "$CONFIGFILE"
  echo "OK"
}

## Removes the password from '$CONFIGFILE'.
## This is run at the end of a fresh install for security reasons.
##
##    clean_config_userpw()
##
clean_config_userpw() {
  if ! cond_redirect sed -i -e 's|^userpw=.*$|\#userpw=xxxxxx|g' "$CONFIGFILE"; then return 1; fi
}

## Update requested version of Java in '$CONFIGFILE'.
## Valid arguments: "Adopt11", "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    update_config_java(String type)
##
update_config_java() {
  if [[ $1 == "Zulu8-64" ]] || [[ $1 == "Zulu11-64" ]]; then
    if ! is_aarch64 || ! is_x86_64 && ! [[ $(getconf LONG_BIT) == 64 ]]; then
      if [[ -n $INTERACTIVE ]]; then
        whiptail --title "Incompatible hardware detected" --msgbox "Zulu OpenJDK 64-bit: this option does not currently work on your platform.\\n\\nDefaulting to Java Zulu 8 32-bit installation." 9 80
      else
        echo "Zulu OpenJDK 64-bit: this option does not currently work on your platform. Defaulting to Java Zulu 8 32-bit installation."
      fi
      if ! cond_redirect sed -i -e 's|^java_opt.*$|java_opt=Zulu8-32|' "$CONFIGFILE"; then return 1; fi
    fi
  else
    if ! cond_redirect sed -i -e 's|^java_opt.*$|java_opt='"${1}"'|' "$CONFIGFILE"; then return 1; fi
  fi
  source "$CONFIGFILE"
}
