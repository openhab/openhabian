#!/usr/bin/env bash
# shellcheck disable=SC2181

## Function for installing NodeJS for frontail and other addons.
##
##    nodejs_setup()
##
nodejs_setup() {
  if [[ -x $(command -v npm) ]] && [[ $(node --version) == "v12"* ]] && ! is_armv6l; then return 0; fi

  local link="https://unofficial-builds.nodejs.org/download/release/v12.19.1/node-v12.19.1-linux-armv6l.tar.xz"
  local myDistro
  local temp

  if ! [[ -x $(command -v lsb_release) ]]; then
    echo -n "$(timestamp) [openHABian] Installing NodeJS prerequsites (lsb-release)... "
    if cond_redirect apt-get install --yes lsb-release; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  myDistro="$(lsb_release -sc)"
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  if [[ -z $PREOFFLINE ]] && is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing NodeJS... "
    if ! cond_redirect wget -qO "$temp" "$link"; then echo "FAILED (download)"; rm -f "$temp"; return 1; fi
    if ! cond_redirect tar -Jxf "$temp" --strip-components=1 -C /usr; then echo "FAILED (extract)"; rm -f "$temp"; return 1; fi
    if cond_redirect rm -f "$temp"; then echo "OK"; else echo "FAILED (cleanup)"; return 1; fi
  else
    if [[ -z $OFFLINE ]]; then
      if ! add_keys "https://deb.nodesource.com/gpgkey/nodesource.gpg.key"; then return 1; fi

      echo -n "$(timestamp) [openHABian] Adding NodeSource repository to apt... "
      echo "deb https://deb.nodesource.com/node_12.x $myDistro main" > /etc/apt/sources.list.d/nodesource.list
      echo "deb-src https://deb.nodesource.com/node_12.x $myDistro main" >> /etc/apt/sources.list.d/nodesource.list
      if [[ -n $PREOFFLINE ]]; then
        if cond_redirect apt-get --quiet update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi
      else
        if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi
      fi
    fi

    echo -n "$(timestamp) [openHABian] Installing NodeJS... "
    if [[ -n $PREOFFLINE ]]; then
      if cond_redirect apt-get --quiet install --download-only --yes nodejs; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if cond_redirect apt-get install --yes nodejs; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
}

## Function for installing frontail to enable the openHAB log viewer web application.
##
##    frontail_setup()
##
##  	$1 is the theme, valid options are: light and dark
frontail_setup() {
  local frontailBase
  local frontailUser="frontail"
  local frontailTheme

  # ask for light or dark theme
  if [[ $1 == "light" ]]; then
    frontailTheme="openhab"
  elif [[ $1 == "dark" ]]; then
    frontailTheme="openhab_dark"
  else
    echo "$(timestamp) [openHABian] openHAB Log Viewer Theme option vas not valid, setting to default light theme... "
    frontailTheme="openhab" # set to default light theme when no user input
  fi

  if ! [[ -x $(command -v npm) ]] || [[ $(node --version) != "v12"* ]] || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing Frontail prerequsites (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  frontailBase="$(npm list -g | head -n 1)/node_modules/frontail"

  if ! (id -u ${frontailUser} &> /dev/null || cond_redirect useradd --groups "${username:-openhabian}",openhab -s /bin/bash -d /var/tmp ${frontailUser}); then echo "FAILED (adduser)"; return 1; fi
  if [[ -x $(command -v frontail) ]]; then
    echo -n "$(timestamp) [openHABian] Updating openHAB Log Viewer (frontail)... "
    if cond_redirect npm update --force -g frontail; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    echo -n "$(timestamp) [openHABian] Installing openHAB Log Viewer (frontail)... "
    if [[ -d $frontailBase ]]; then
      cond_echo "Removing any old installations..."
      cond_redirect npm uninstall -g frontail
    fi

    if ! cond_redirect npm install --force -g frontail; then echo "FAILED (install)"; return 1; fi
    if cond_redirect npm update --force -g frontail; then echo "OK"; else echo "FAILED (update)"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Configuring openHAB Log Viewer (frontail)... "
  if ! cond_redirect mkdir -p "$frontailBase"/preset "$frontailBase"/web/assets/styles; then echo "FAILED (create directory)"; return 1; fi
  if ! cond_redirect rm -rf "${frontailBase:?}"/preset/* "${frontailBase:?}"/web/assets/styles/*; then echo "FAILED (clean directory)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/frontail-preset.json "$frontailBase"/preset/openhab.json; then echo "FAILED (copy light presets)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/frontail-preset_dark.json "$frontailBase"/preset/openhab_dark.json; then echo "FAILED (copy dark presets)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/frontail-theme.css "$frontailBase"/web/assets/styles/openhab.css; then echo "FAILED (copy light theme)"; return 1; fi
  if cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/frontail-theme_dark.css "$frontailBase"/web/assets/styles/openhab_dark.css; then echo "OK"; else echo "FAILED (copy dark theme)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up openHAB Log Viewer (frontail) service, theme:" ${frontailTheme} "... "
  if ! (sed -e "s|%FRONTAILBASE|${frontailBase}|g" -e "s|%FRONTAILTHEME|${frontailTheme}|g" "${BASEDIR:-/opt/openhabian}"/includes/frontail.service > /etc/systemd/system/frontail.service); then echo "FAILED (service file creation)"; return 1; fi;
  if ! cond_redirect chmod 644 /etc/systemd/system/frontail.service; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now frontail.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart frontail.service; then echo "OK"; else echo "Failed (restart service)"; return 1; fi # restart the service to make the change visible

  if openhab_is_installed; then
    dashboard_add_tile "frontail"
  fi
}

## Function for installing Node-RED a flow based programming interface for IoT devices.
##
##    nodered_setup()
##
nodered_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] Node-RED setup must be run in interactive mode! Canceling Node-RED setup!"
    echo "CANCELED"
    return 0
  fi

  local temp

  if ! [[ -x $(command -v npm) ]] || [[ $(node --version) != "v12"* ]] || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing Frontail prerequsites (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if ! dpkg -s 'build-essential' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing Node-RED required packages (build-essential)... "
    if cond_redirect apt-get install --yes build-essential; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Downloading Node-RED setup script... "
  if cond_redirect wget -qO "$temp" https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered; then
     echo "OK"
  else
    echo "FAILED"
    rm -f "$temp"
    return 1
  fi

  echo -n "$(timestamp) [openHABian] Setting up Node-RED... "
  whiptail --title "Node-RED Setup" --msgbox "The installer is about to ask for information in the command line, please fill out each line." 8 80 3>&1 1>&2 2>&3
  chmod 755 "$temp"
  if sudo -u "${username:-openhabian}" -H bash -c "$temp"; then echo "OK"; rm -f "$temp"; else echo "FAILED"; rm -f "$temp"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing Node-RED addons... "
  if ! cond_redirect npm install -g node-red-contrib-bigtimer; then echo "FAILED (install bigtimer addon)"; return 1; fi
  if ! cond_redirect npm update -g node-red-contrib-bigtimer; then echo "FAILED (update bigtimer addon)"; return 1; fi
  if ! cond_redirect npm install -g node-red-contrib-openhab2; then echo "FAILED (install openhab2 addon)"; return 1; fi
  if cond_redirect npm update -g node-red-contrib-openhab2; then echo "OK"; else echo "FAILED (update openhab2 addon)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up Node-RED service... "
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable --now nodered.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  if openhab_is_installed; then
    dashboard_add_tile "nodered"
  fi
}
