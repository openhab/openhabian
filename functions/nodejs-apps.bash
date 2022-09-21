#!/usr/bin/env bash
# shellcheck disable=SC2181

## Function for installing NodeJS for frontail and other addons.
##
##    nodejs_setup()
##
nodejs_setup() {
  if node_is_installed && ! is_armv6l; then return 0; fi

  local keyName="nodejs"
  local link="https://unofficial-builds.nodejs.org/download/release/v14.18.2/node-v14.18.2-linux-armv6l.tar.xz"
  local myDistro
  local temp


  myDistro="$(lsb_release -sc)"
  if [[ "$myDistro" == "n/a" ]]; then
    myDistro=${osrelease:-bullseye}
  fi
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  if [[ -z $PREOFFLINE ]] && is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing NodeJS... "
    if ! cond_redirect wget -qO "$temp" "$link"; then echo "FAILED (download)"; rm -f "$temp"; return 1; fi
    if ! cond_redirect tar -Jxf "$temp" --strip-components=1 -C /usr; then echo "FAILED (extract)"; rm -f "$temp"; return 1; fi
    if cond_redirect rm -f "$temp"; then echo "OK"; else echo "FAILED (cleanup)"; return 1; fi
  else
    if [[ -z $OFFLINE ]]; then
      if ! add_keys "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" "$keyName"; then return 1; fi

      echo -n "$(timestamp) [openHABian] Adding NodeSource repository to apt... "
      echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg] https://deb.nodesource.com/node_16.x $myDistro main" > /etc/apt/sources.list.d/nodesource.list
      echo "deb-src [signed-by=/usr/share/keyrings/${keyName}.gpg] https://deb.nodesource.com/node_16.x $myDistro main" >> /etc/apt/sources.list.d/nodesource.list
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

## Function for downloading frontail to current system
##
##    frontail_download(String prefix)
##
frontail_download() {
  echo -n "$(timestamp) [openHABian] Downloading frontail... "
  if ! [[ -d "${1}/frontail" ]]; then
    cond_echo "\\nFresh Installation... "
    if cond_redirect git clone https://github.com/Interstellar0verdrive/frontail_AEM.git "${1}/frontail"; then echo "OK"; else echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\\nUpdate... "
    if cond_redirect update_git_repo "${1}/frontail" "master"; then echo "OK"; else echo "FAILED (update git repo)"; return 1; fi
  fi
}

## Function for installing frontail to enable the openHAB log viewer web application.
##
##    frontail_setup()
##
frontail_setup() {
  local frontailBase
  local frontailUser="frontail"

  if ! node_is_installed || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing Frontail prerequsites (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  frontailBase="$(npm list -g | head -n 1)/node_modules/frontail"

  if ! (id -u ${frontailUser} &> /dev/null || cond_redirect useradd --groups "${username:-openhabian}",openhab -s /bin/bash -d /var/tmp ${frontailUser}); then echo "FAILED (adduser)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing openHAB Log Viewer (frontail)... "
  if [[ -d $frontailBase ]]; then
    cond_echo "Removing any old installations... "
    cond_redirect npm uninstall -g frontail
  fi

  if ! cond_redirect frontail_download "/opt"; then echo "FAILED (download)"; return 1; fi
  cd /opt/frontail || (echo "FAILED (cd)"; return 1)
  if ! cond_redirect npm install --force -g; then echo "FAILED (install)"; return 1; fi
  if ! cond_redirect npm audit fix --force; then echo "FAILED (install)"; return 1; fi
  if cond_redirect npm update --force -g; then echo "OK"; else echo "FAILED (update)"; return 1; fi
  
  echo -n "$(timestamp) [openHABian] Setting up openHAB Log Viewer (frontail) service... "
  if ! (sed -e "s|%FRONTAILBASE|${frontailBase}|g" "${BASEDIR:-/opt/openhabian}"/includes/frontail.service > /etc/systemd/system/frontail.service); then echo "FAILED (service file creation)"; return 1; fi
  if ! cond_redirect chmod 644 /etc/systemd/system/frontail.service; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now frontail.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart frontail.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi # Restart the service to make the change visible

  if openhab_is_installed; then
    dashboard_add_tile "frontail"
  fi
}

## Function for adding/removing a user specifed log to/from frontail
##
##    custom_frontail_log()
##
custom_frontail_log() {
  local frontailService="/etc/systemd/system/frontail.service"
  local addLog
  local removeLog
  local array

  if ! [[ -f $frontailService ]]; then
    whiptail --title "Frontail not installed" --msgbox "Frontail is not installed!\\n\\nCanceling operation!" 9 80
    return 0
  fi

  if [[ $1 == "add" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      if ! addLog="$(whiptail --title "Enter file path" --inputbox "\\nEnter the path to the logfile that you would like to add to frontail:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    else
      if [[ -n $2 ]]; then addLog="$2"; else return 0; fi
    fi

    for log in "${addLog[@]}"; do
      if [[ -f $log ]]; then
        echo -n "$(timestamp) [openHABian] Adding '${log}' to frontail... "
        if ! cond_redirect sed -i -e "/^ExecStart/ s|$| ${log}|" "$frontailService"; then echo "FAILED (add log)"; return 1; fi
        if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
        if cond_redirect systemctl restart frontail.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi
      else
        if [[ -n $INTERACTIVE ]]; then
          whiptail --title "File does not exist" --msgbox "The specifed file path does not exist!\\n\\nCanceling operation!" 9 80
          return 0
        else
          echo "$(timestamp) [openHABian] Adding '${log}' to frontail... FAILED (file does not exist)"
        fi
      fi
    done
  elif [[ $1 == "remove" ]] && [[ -n $INTERACTIVE ]]; then
    readarray -t array < <(grep -e "^ExecStart.*$" "$frontailService" | awk '{for (i=12; i<=NF; i++) {printf "%s\n\n", $i}}')
    ((count=${#array[@]} + 6))
    removeLog="$(whiptail --title "Select log to remove" --cancel-button Cancel --ok-button Select --menu "\\nPlease choose the log that you would like to remove from frontail:\\n" "$count" 80 0 "${array[@]}" 3>&1 1>&2 2>&3)"
    if ! cond_redirect sed -i -e "s|${removeLog}||" -e '/^ExecStart/ s|[[:space:]]\+| |g' "$frontailService"; then echo "FAILED (remove log)"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
    if cond_redirect systemctl restart frontail.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi
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

  if ! node_is_installed || is_armv6l; then
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
  if ! cond_redirect npm install -g node-red-contrib-openhab3; then echo "FAILED (install openhab3 addon)"; return 1; fi
  if cond_redirect npm update -g node-red-contrib-openhab3; then echo "OK"; else echo "FAILED (update openhab3 addon)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up Node-RED service... "
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable --now nodered.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  if openhab_is_installed; then
    dashboard_add_tile "nodered"
  fi
}

## Function for downloading zigbee2mqtt to current system
##
##    zigbee2mqtt_download(String prefix)
##
zigbee2mqtt_download() {
  echo -n "$(timestamp) [openHABian] Downloading Zigbee2MQTT... "
  if ! cond_redirect mkdir /opt/zigbee2mqtt; then echo "FAILED (mkdir /opt/zigbee2mqtt)"; fi
  if ! cond_redirect chown openhabian /opt/zigbee2mqtt; then echo "FAILED (chown /opt/zigbee2mqtt)"; fi
  if ! cond_redirect chgrp openhab /opt/zigbee2mqtt; then echo "FAILED (chgrp /opt/zigbee2mqtt)"; fi
  if ! cond_redirect sudo -u "${username:-openhabian}" git clone https://github.com/Koenkk/zigbee2mqtt.git "/opt/zigbee2mqtt"; then echo "FAILED (git clone)"; return 1; fi
}

## Function for installing zigbee2mqtt.
##
##    zigbee2mqtt_setup()
##
zigbee2mqtt_setup() {
  local zigbee2mqttBase
  local z2mInstalledText="A configuration for Zigbee2MQTT is already existing.\\n\\nWould you like to update Zigbee2MQTT to the latest version with this configuration?"
  local introText="A MQTT-server is required for Zigbee2mqtt. If you haven't installed one yet, please select <cancel> and come back after installing one (e.g. Mosquitto).\\n\\nZigbee2MQTT will be installed from the official repository.\\n\\nDuration is about 4 minutes... "
  local installText="Zigbee2MQTT is installed from the official repository.\\n\\nPlease wait about 4 minutes... "
  local uninstallText="Zigbee2MQTT is completely removed from the system."
  local adapterText="Please select your zigbee adapter:"
  local mqttUserText="\\nPlease enter your MQTT-User (default = openhabian):"
  local mqttPWText="\\nIf your MQTT-server requires a password, please enter it here:"
  local my_adapters
  local mqttDefaultUser="openhabian"
  local mqttUser
  local serverIP
  local installSuccessText
  local updateSuccessText
  local loopSel=1

  serverIP="$(hostname -I)"; serverIP=${serverIP::-1} # remove trailing space
  installSuccessText="Setup was successful. Zigbee2MQTT is now up and running.\\n\\nFor further Zigbee-settings open frontend (in 2 minutes): \\nhttp://${serverIP}:8081.\n\nDocumentation of ZigBee2MQTT:\\nhttps://www.zigbee2mqtt.io/guide/configuration"
  updateSuccessText="Update successful. \\n\\nFor further Zigbee-settings open frontend (in 2 minutes): \\nhttp://${serverIP}:8081.\n\nDocumentation of Zigbee2MQTT:\\nhttps://www.zigbee2mqtt.io/guide/configuration"
 
  if [[ $1 == "remove" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      if ! (whiptail --title "Zigbee2MQTT Uninstall" --yes-button "Continue" --no-button "Cancel" --yesno "$uninstallText" 7 80); then echo "CANCELED"; return 0; fi
    fi
    echo -n "$(timestamp) [openHABian] Removing Zigbee2MQTT service... "
    if ! cond_redirect systemctl stop zigbee2mqtt.service; then echo "FAILED (disable service)"; return 1; fi
    if ! rm -f /etc/systemd/system/zigbee2mqtt.service; then echo "FAILED (remove service)"; return 1; fi
    if cond_redirect systemctl -q daemon-reload; then echo "OK"; else  echo "FAILED (daemon-reload)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Uninstalling Zigbee2MQTT... "
    if ! cond_redirect npm uninstall zigbee2mqtt ; then echo "FAILED (npm uninstall)"; return 1; fi
    if ! rm -rf /var/log/zigbee2mqtt; then echo "FAILED (remove log)"; return 1; fi
    if rm -rf "/opt/zigbee2mqtt"; then echo "OK"; else echo "FAILED (rm /opt/zigbee2mqtt)"; return 1; fi
    
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Zigbee2MQTT removed" --msgbox "Zigbee2MQTT was removed from your system." 7 80
    fi
    return 0;
  fi
  if [[ $1 != "install" ]]; then return 1; fi

  # if a config file exists do only update and exit
  if [[ -e "/opt/zigbee2mqtt/data/configuration.yaml" ]] ; then
    if [[ -n $INTERACTIVE ]]; then
      if ! (whiptail --title "Zigbee2MQTT installation" --yes-button "Continue" --no-button "Cancel" --yesno "$z2mInstalledText" 14 80); then echo "CANCELED"; return 0; fi
    fi

    echo -n "$(timestamp) [openHABian] Updating Zigbee2MQTT... "
    if ! cond_redirect cd /opt/zigbee2mqtt; then echo "FAILED (cd zigbee2mqtt)"; return 1; fi
    if ! cond_redirect systemctl stop zigbee2mqtt ; then echo "FAILED (stop systemctl)"; fi
    if ! cond_redirect sudo -u "${username:-openhabian}" cp -R data data-backup; then echo "FAILED (cp backup)"; return 1; fi
    if ! cond_redirect sudo -u "${username:-openhabian}" git pull; then echo "FAILED git"; return 1; fi
    if ! cond_redirect sudo -u "${username:-openhabian}" npm install; then echo "FAILED npm"; return 1; fi
    if ! cond_redirect sudo -u "${username:-openhabian}" cp -R data-backup/* data; then echo "FAILED (cp backup)"; return 1; fi
    if ! cond_redirect rm -rf /opt/zigbee2mqtt/data-backup; then echo "FAILED (rm data-backup)"; return 1; fi
    if ! cond_redirect cd /opt ; then echo "FAILED (cd opt)"; return 1; fi
    if ! cond_redirect systemctl start zigbee2mqtt; then echo "FAILED (systemctl start)"; return 1; fi

    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Operation successful" --msgbox "$updateSuccessText" 15 80
    fi
    echo "OK"
    return 0
  fi

  # get usb adapters for radio menu
  while IFS= read -r line; do
    my_adapters="$my_adapters $line $loopSel "
    loopSel=0
  done < <( ls /dev/serial/by-id )
  unset IFS
  
  # ask for user input parameters
  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Zigbee2MQTT installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 14 80); then echo "CANCELED"; return 0; fi
    # shellcheck disable=SC2086
    if ! selectedAdapter=$(whiptail --noitem --title "Zigbee2MQTT installation" --radiolist "$adapterText" 14 100 4 $my_adapters 3>&1 1>&2 2>&3); then return 0; fi
    if ! mqttUser=$(whiptail --title "MQTT User" --inputbox "$mqttUserText" 10 80 "$mqttDefaultUser" 3>&1 1>&2 2>&3); then return 0; fi
    if ! mqttPW=$(whiptail --title "MQTT password" --passwordbox "$mqttPWText" 10 80 3>&1 1>&2 2>&3); then return 0; fi
    if ! (whiptail --title "Zigbee2MQTT installation" --infobox "$installText" 14 80); then echo "CANCELED"; return 0; fi
  fi

  if ! cond_redirect nodejs_setup; then return 1; fi

  echo -n "$(timestamp) [openHABian] Downloading Zigbee2MQTT... "
  zigbee2mqttBase="$(npm list | head -n 1)/node_modules/zigbee2mqtt"
  if [[ -d $zigbee2mqttBase ]]; then
    if cond_redirect systemctl stop zigbee2mqtt.service; then echo "OK (stop service)"; else echo "FAILED (stop service)"; return 1; fi # Stop the service 
    cond_echo "Removing any old installations... "
    cond_redirect npm uninstall zigbee2mqtt
  fi
  if ! cond_redirect zigbee2mqtt_download "/opt"; then echo "FAILED (download)"; return 1; fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Creating log directory... "
  mkdir  /var/log/zigbee2mqtt || (echo "FAILED (create log-directory)"; return 1)
  chown openhabian /var/log/zigbee2mqtt || (echo "FAILED (create log-directory)"; return 1)
  chgrp openhab /var/log/zigbee2mqtt || (echo "FAILED (create log-directory)"; return 1)
  echo "OK"

  echo -n "$(timestamp) [openHABian] Zigbee2MQTT install & config... "
  cd /opt/zigbee2mqtt || (echo "FAILED (cd)"; return 1)
  if ! cond_redirect sudo -u "${username:-openhabian}" npm install ; then echo "FAILED (npm install)"; return 1; fi
  sed -e "s|%adapterName|$selectedAdapter|g" /opt/openhabian/includes/zigbee2mqtt/configuration.yaml | sudo -u "${username:-openhabian}" dd status=none of=/opt/zigbee2mqtt/data/configuration.yaml
  sed -i -e "s|%user%|$mqttUser|g" /opt/zigbee2mqtt/data/configuration.yaml
  sed -i -e "s|%password%|$mqttPW|g" /opt/zigbee2mqtt/data/configuration.yaml 
  
  cd /opt || (echo "FAILED (cd)"; return 1)
  echo "OK"
  
  echo -n "$(timestamp) [openHABian] Setting up Zigbee2MQTT service... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/zigbee2mqtt/zigbee2mqtt.service /etc/systemd/system/; then echo "FAILED (install service)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now zigbee2mqtt.service; then echo "FAILED (enable service)"; return 1; fi
  echo "OK"

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$installSuccessText" 15 80
  fi
}

## Function for installing a npm package for the JS Scripting Automation Add-On
##
##    jsscripting_npm_install(String packageName, String mode)
##    Available values for mode: "update", "install", "uninstall". Defaults to "install".
##
jsscripting_npm_install() {
  if [ "${1}" == "" ]; then echo "FAILED. Provide packageName."; return 1; fi

  local installSuccessText="Installation successful.\\n\\n${1} (npm package) is now available in JS Scripting.\\nFor documentation, visit the JS Scripting docs (https://www.openhab.org/addons/automation/jsscripting/) or https://npmjs.com/package/${1}."
  local updateSuccessText="Update of ${1} (npm package) successful."
  local uninstallSuccessText="Uninstallation of ${1} (npm package) from JS Scripting successful.\\n\\nRemember to check your scripts for dependencies on ${1} and remove those."
  local messageText

  if ! node_is_installed || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing prerequsites for ${1} (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [ "${2}" == "update" ];
  then
    echo -n "$(timestamp) [openHABian] Updating ${1} for JS Scripting... "
    if cond_redirect sudo -u "openhab" npm update --prefix "/etc/openhab/automation/js" "${1}"; then echo "OK"; else echo "FAILED (npm update)"; return 1; fi
    messageText=$updateSuccessText
  elif [ "${2}" == "uninstall" ];
  then
    echo -n "$(timestamp) [openHABian] Uninstalling ${1} from JS Scripting... "
    if cond_redirect sudo -u "openhab" npm remove --prefix "/etc/openhab/automation/js" "${1}"; then echo "OK"; else echo "FAILED (npm remove)"; return 1; fi
    messageText=$uninstallSuccessText
  else
    echo -n "$(timestamp) [openHABian] Installing ${1} for JS Scripting... "
    if ! cond_redirect sudo -u "openhab" mkdir -p /etc/openhab/automation/js; then echo "FAILED (mkdir /etc/openhab/automation/js)"; fi
    if cond_redirect sudo -u "openhab" npm install --prefix "/etc/openhab/automation/js" "${1}"; then echo "OK"; else echo "FAILED (npm install)"; return 1; fi
    messageText=$installSuccessText
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$messageText" 15 80
  fi
}

## Function for checking for updates of a npm package for the JS Scripting Automation Add-On
##
##    jsscripting_npm_check(String packageName)
##
jsscripting_npm_check() {
  if [ "${1}" == "" ]; then echo "FAILED. Provide packageName."; return 1; fi
  # If directory of package doesn't exist, exit.
  if [ ! -d "/etc/openhab/automation/js/node_modules/${1}" ]; then return 0; fi

  local introText="Additions, improvements or fixes were added to ${1} (npm package) for JS Scripting. Would you like to update now and benefit from them?\\nThe update might include breaking changes, please head over to the JS Scripting docs (https://www.openhab.org/addons/automation/jsscripting/) or to https://www.npmjs.com/package/${1}."
  local outdatedReturn

  if ! node_is_installed || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing prerequsites for ${1} for JS Scripting (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Checking for updates of ${1} for JS Scripting... "
  outdatedReturn=$(npm outdated --prefix /etc/openhab/automation/js)

  # Check whether outdatedReturn includes the packageName.
  if [[ "${outdatedReturn}" =~ ${1} ]];
  then
    echo -n "Update available... "
    if [[ -n $INTERACTIVE ]]; then
      if (whiptail --title "Update available for ${1} for JS Scripting" --yes-button "Continue" --no-button "Skip" --yesno "$introText" 15 80); then echo "UPDATING"; else echo "SKIP"; return 0; fi
    fi
    jsscripting_npm_install "${1}" "update"
  else
    echo "No update available."
  fi
}
