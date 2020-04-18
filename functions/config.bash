#!/usr/bin/env bash

load_create_config() {
  if [ -f "$configfile" ]; then
    echo -n "$(timestamp) [openHABian] Loading configuration file '$configfile'... "
  elif [ ! -f "$configfile" ] && [ -f /boot/installer-config.txt ]; then
    echo -n "$(timestamp) [openHABian] Copying and loading configuration file '$configfile'... "
    cp /boot/installer-config.txt "$configfile"
  elif [ ! -f "$configfile" ] && [ -n "$UNATTENDED" ]; then
    echo "$(timestamp) [openHABian] Error in unattended mode: Configuration file '$configfile' not found... FAILED" 1>&2
    exit 1
  else
    echo -n "$(timestamp) [openHABian] Setting up and loading configuration file '$configfile' in manual setup... "
    question="Welcome to openHABian!\\n\\nPlease provide the name of your Linux user i.e. the account you normally log in with.\\nTypical user names are 'pi' or 'ubuntu'."
    input=$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$question" 15 80 3>&1 1>&2 2>&3)
    if ! id -u "$input" &>/dev/null; then
      echo "FAILED"
      echo "$(timestamp) [openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting ..." 1>&2
      exit 1
    fi
    cp "$BASEDIR"/openhabian.conf.dist "$configfile"
    sed -i "s/username=.*/username=$input/g" "$configfile"
  fi
  # shellcheck source=/etc/openhabian.conf disable=SC1091
  source "$configfile"
  echo "OK"
}

clean_config_userpw() {
  cond_redirect sed -i "s/^userpw=.*/\\#userpw=xxxxxxxx/g" "$configfile"
}

## Update java architecture in config file
## Valid options: "32-bit" & "64-bit"
update_config_java() {
  cond_redirect grep -q '^java_arch' "$configfile" && sed -i "s/^java_arch.*/java_arch=$1/" "$configfile" || echo "java_arch=$1" >> "$configfile"
  # shellcheck disable=SC1090
  source "$configfile"
}
