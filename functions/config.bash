#!/usr/bin/env bash

load_create_config() {
  if [ -f "$CONFIGFILE" ]; then
    echo -n "$(timestamp) [openHABian] Loading configuration file '$CONFIGFILE'... "
  elif [ ! -f "$CONFIGFILE" ] && [ -f /boot/installer-config.txt ]; then
    echo -n "$(timestamp) [openHABian] Copying and loading configuration file '$CONFIGFILE'... "
    cp /boot/installer-config.txt "$CONFIGFILE"
  elif [ ! -f "$CONFIGFILE" ] && [ -n "$UNATTENDED" ]; then
    echo "$(timestamp) [openHABian] Error in unattended mode: Configuration file '$CONFIGFILE' not found... FAILED" 1>&2
    exit 1
  else
    echo -n "$(timestamp) [openHABian] Setting up and loading configuration file '$CONFIGFILE' in manual setup... "
    question="Welcome to openHABian!\\n\\nPlease provide the name of your Linux user i.e. the account you normally log in with.\\nTypical user names are 'pi' or 'ubuntu'."
    input=$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$question" 15 80 3>&1 1>&2 2>&3)
    if ! id -u "$input" &>/dev/null; then
      echo "FAILED"
      echo "$(timestamp) [openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting ..." 1>&2
      exit 1
    fi
    cp "$BASEDIR"/openhabian.conf.dist "$CONFIGFILE"
    sed -i "s/username=.*/username=$input/g" "$CONFIGFILE"
  fi
  # shellcheck source=/etc/openhabian.conf disable=SC1091
  source "$CONFIGFILE"
  echo "OK"
}

clean_config_userpw() {
  cond_redirect sed -i "s/^userpw=.*/\\#userpw=xxxxxxxx/g" "$CONFIGFILE"
}

## Update java architecture in config file
## Valid options: "32-bit" & "64-bit"
update_config_java() {
  cond_redirect grep -q '^java_arch' "$CONFIGFILE" && sed -i "s/^java_arch.*/java_arch=$1/" "$CONFIGFILE" || echo "option=$1" >> "$CONFIGFILE"
  # shellcheck disable=SC1090
  source "$CONFIGFILE"
}
