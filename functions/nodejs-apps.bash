#!/usr/bin/env bash
# shellcheck disable=SC2181

## Function for installing NodeJS for nodered, zigbee2mqtt and other addons.
##
##    nodejs_setup()
##
nodejs_setup() {
  if node_is_installed; then return 0; fi
  sleep 2; # to avoid conflict with lock from previous apt commands
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs 
  npm install -g pnpm
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

## Function for removing frontail as its insecure and not maintained.
##
##    frontail_remove()
##
frontail_remove() {
  local frontailBase
  local frontailDir="/opt/frontail"
  local removeText="Frontail is a log viewer that is not maintained and has security issues. As of openHAB 4.3 there is a built in log viewer which replaces it.\\n\\nWould you like to remove it from your system? If not, be aware that it is not recommended to use it and is no longer a supported feature of openHABian."
  local rememberChoice="Would you like to remember this choice for future runs of openHABian?"

  frontailBase="$(npm list -g | head -n 1)/node_modules/frontail"

  if ! dpkg --compare-versions "$(sed -n 's/openhab-distro\s*: //p' /var/lib/openhab/etc/version.properties)" gt "4.3.0"; then return 0; fi
  # shellcheck disable=SC2154
  if [[ -z $INTERACTIVE ]] || [[ $frontail_remove == "true" ]]; then return 0; fi


  if [[ -d $frontailBase ]] || [[ -d $frontailDir ]]; then
    if (whiptail --title "Frontail Removal" --yes-button "Remove" --no-button "Keep" --yesno "$removeText" 27 84); then
      echo -n "$(timestamp) [openHABian] Removing openHAB Log Viewer frontail... "
      if [[ $(systemctl is-active frontail.service) == "active" ]]; then
        if ! cond_redirect systemctl stop frontail.service; then echo "FAILED (stop service)"; return 1; fi
      fi
      if ! cond_redirect systemctl disable frontail.service; then echo "FAILED (disable service)"; return 1; fi
      cond_redirect npm uninstall -g frontail
      rm -f /etc/systemd/system/frontail.service
      rm -rf /var/log/frontail
      rm -rf /opt/frontail

      if grep -qs "frontail-link" "/etc/openhab/services/runtime.cfg"; then
        cond_redirect sed -i -e "/frontail-link/d" "/etc/openhab/services/runtime.cfg"
      fi
      if cond_redirect systemctl -q daemon-reload; then echo "OK"; else echo "FAILED (daemon-reload)"; return 1; fi
    elif (whiptail --title "Frontail Removal" --yes-button "Don't show again" --no-button "Keep showing" --yesno "$rememberChoice" 10 84); then
        # shellcheck source=/etc/openhabian.conf disable=SC2154
        sed -i -e "s/^.*frontail_remove.*$/frontail_remove=true/g" "${configFile}"
    fi
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
  # npm arguments explained:
  #   --omit=dev ignores the dev dependencies (we do not require them for production usage)
  # Do NOT catch exit 1 for npm audit fix, because it's thrown when a vulnerability can't be fixed. Happens when a fix requires an upgrade to a new major release with possible breaking changes.
  cond_redirect npm audit fix --omit=dev
  if ! cond_redirect npm update --audit=false --omit=dev; then echo "FAILED (update)"; return 1; fi
  if cond_redirect npm install --global --audit=false --omit=dev; then echo "OK"; else echo "FAILED (install)"; return 1; fi

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
    if [[ -n $INTERACTIVE ]]; then  whiptail --title "Frontail not installed" --msgbox "Frontail is not installed!\\n\\nCanceling operation!" 9 80; fi
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
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" build-essential; then echo "OK"; else echo "FAILED"; return 1; fi
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
  if ! cond_redirect install -o openhabian -g openhabian -m 755 "${BASEDIR:-/opt/openhabian}"/includes/nodered-override.conf /etc/systemd/system/; then echo "FAILED (systemd setup)"; return 1; fi
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

  if ! cond_redirect mkdir -p /opt/zigbee2mqtt; then echo "FAILED (mkdir -p /opt/zigbee2mqtt)"; fi
  if ! cond_redirect chown "${username:-openhabian}:openhab" /opt/zigbee2mqtt; then echo "FAILED (chown /opt/zigbee2mqtt)"; fi
  cd /opt/zigbee2mqtt || (echo "FAILED (cd)"; return 1)
  if ! cond_redirect sudo -u "${username:-openhabian}" git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git "/opt/zigbee2mqtt"; then echo "FAILED (git clone)"; return 1; fi
  if ! cond_redirect sed -i -e "s|8080|8081|g" "/opt/zigbee2mqtt/lib/util/onboarding.ts"; then echo "FAILED (change z2m onboarding port)"; fi
}



## Function for installing zigbee2mqtt.
##
##    zigbee2mqtt_setup()
##
zigbee2mqtt_setup() {
  local serverIP z2mVersion
  local installSuccessText updateSuccessText
  local z2mInstalledText="A configuration for Zigbee2MQTT is already existing.\\n\\nWould you like to update Zigbee2MQTT to the latest version with this configuration?"
  local introText="A MQTT-server is required for Zigbee2mqtt. If you haven't installed one yet, please select <cancel> and come back after installing one (e.g. Mosquitto).\\n\\nZigbee2MQTT will be installed from the official repository.\\n\\nDuration is about 2 minutes... "
  local uninstallText="Zigbee2MQTT will be completely removed from the system."
  local updateManualText="The update to v2 has to be done manually due to some breaking changes in v2. \\nSee details unter \\n\\nhttps://github.com/Koenkk/zigbee2mqtt/discussions/24198"

  z2mVersion=$(jq -r .version /opt/zigbee2mqtt/package.json 2>/dev/null || echo "0")
  serverIP=$(hostname -I | awk '{print $1}')
  installSuccessText="Setup was successful. Wait 1 minute and Zigbee2MQTT is up and running.\\n\\nPlease complete the initial configuration in the onboarding frontend at \\n\\nhttp://${serverIP}:8081\\n\\n\\nFurther docs see: https://www.zigbee2mqtt.io/guide/configuration"
  updateSuccessText="Update successful.\\n\\nFrontend: http://${serverIP}:8081\\n\\nnDocs: https://www.zigbee2mqtt.io/guide/configuration"

  # Remove mode
  if [[ $1 == "remove" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      if ! whiptail --title "Zigbee2MQTT Uninstall" --yes-button "Continue" --no-button "Cancel" --yesno "$uninstallText" 7 80; then
        echo "CANCELLED"
        return 0
      fi
    fi
    systemctl disable --now zigbee2mqtt.service &>/dev/null
    rm -f /etc/systemd/system/zigbee2mqtt.service /opt/zigbee2mqtt/data/zigbee2mqtt.env
    rm -rf /opt/zigbee2mqtt /var/log/zigbee2mqtt
    systemctl daemon-reload
    [[ -n $INTERACTIVE ]] && whiptail --title "Zigbee2MQTT removed" --msgbox "Zigbee2MQTT was removed." 7 80
    return 0
  fi

  [[ $1 != "install" ]] && return 1

  # Existing config -> update
  if [[ -e "/opt/zigbee2mqtt/data/configuration.yaml" ]]; then
    if [[ $z2mVersion =~ ^2 ]]; then
      [[ -n $INTERACTIVE ]] && whiptail --title "Zigbee2MQTT installation" --yes-button "Continue" --no-button "Cancel" --yesno "$z2mInstalledText" 14 80 || return 0
      sudo -u "${username:-openhabian}" /opt/zigbee2mqtt/update.sh
      [[ -n $INTERACTIVE ]] && whiptail --title "Update successful" --msgbox "$updateSuccessText" 15 80
    else
      [[ -n $INTERACTIVE ]] && whiptail --title "Update message" --msgbox "$updateManualText" 15 80
    fi
    return 0
  fi

  # Interactive input
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Zigbee2MQTT installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 14 80 || return 0
  fi

  # Dependencies & download
  cond_redirect nodejs_setup || return 1
  cond_redirect zigbee2mqtt_download || return 1

  # Log dir & .env
  mkdir -p /var/log/zigbee2mqtt /opt/zigbee2mqtt/data
  chown "${username:-openhabian}:openhab" /var/log/zigbee2mqtt /opt/zigbee2mqtt/data

  cat <<EOF >/opt/zigbee2mqtt/data/zigbee2mqtt.env
ZIGBEE2MQTT_CONFIG_FRONTEND_ENABLED=true
ZIGBEE2MQTT_CONFIG_FRONTEND_PORT=8081
ZIGBEE2MQTT_CONFIG_FRONTEND_PACKAGE=zigbee2mqtt-frontend
ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_DIRECTORY=/var/log/zigbee2mqtt/%TIMESTAMP%
ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_FILE=log.txt
ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_LEVEL=warning
ZIGBEE2MQTT_CONFIG_ADVANCED_CHANNEL=26
EOF

  chown "${username:-openhabian}:openhab" /opt/zigbee2mqtt/data/zigbee2mqtt.env
  chmod 640 /opt/zigbee2mqtt/data/zigbee2mqtt.env

  # Install systemd service
  install -o "${username:-openhabian}" -g openhab -m 644 "${BASEDIR:-/opt/openhabian}/includes/zigbee2mqtt/zigbee2mqtt.service" /etc/systemd/system/
  sed -i -e "s|%user%|${username:-openhabian}|g" "/etc/systemd/system/zigbee2mqtt.service"

  # Install node_modules inkl. prepack scripts
  cd /opt/zigbee2mqtt || (echo "FAILED (cd)"; return 1)
  cond_redirect sudo -u "${username:-openhabian}" /usr/bin/pnpm install --frozen-lockfile --ignore-scripts=false

  systemctl daemon-reload
  systemctl enable --now zigbee2mqtt.service

  [[ -n $INTERACTIVE ]] && whiptail --title "Operation successful" --msgbox "$installSuccessText" 15 80
  return 0
}


## Function for installing a npm package for the JS Scripting Automation Add-On
##
##    jsscripting_npm_install(String packageName, String mode)
##    Available values for mode: "update", install", "uninstall". Defaults to "install".
##
jsscripting_npm_install() {
  if [ "${1}" == "" ]; then echo "FAILED. Provide packageName."; return 1; fi

  local openhabJsText="A version of the openHAB JavaScript is included in the JS Scripting add-on, therefore there is no general need for manual installation it.\\n\\nPlease only continue if you know what you want."

  if ! node_is_installed || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing prerequisites for ${1} (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [ "${2}" == "uninstall" ];
  then
    echo -n "$(timestamp) [openHABian] Uninstalling ${1} from JS Scripting... "
    if cond_redirect sudo -u "openhab" npm remove --prefix "/etc/openhab/automation/js" "${1}@latest"; then echo "OK"; else echo "FAILED (npm remove)"; return 1; fi
  else
    echo -n "$(timestamp) [openHABian] Installing ${1} for JS Scripting... "
    if [[ "${1}" == "openhab" ]] && [[ "${2}" != "update" ]] && [[ -n $INTERACTIVE ]]; then
      if (whiptail --title "Installation of openhab for JS Scripting" --yes-button "Continue" --no-button "Cancel" --yesno "${openhabJsText}" 15 80); then echo -n "INSTALLING "; else echo "SKIP"; return 0; fi
    fi
    if ! cond_redirect sudo -u "openhab" mkdir -p /etc/openhab/automation/js; then echo "FAILED (mkdir /etc/openhab/automation/js)"; fi
    if cond_redirect sudo -u "openhab" npm install --prefix "/etc/openhab/automation/js" "${1}@latest"; then echo "OK"; else echo "FAILED (npm install)"; return 1; fi
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

  local introText="Additions, improvements or fixes were added to ${1} (npm package) for JS Scripting. Would you like to update now and benefit from them?"
  local breakingText="\\n\\nThis update includes BREAKING CHANGES!"
  local data
  local wantedVersion
  local latestVersion

  if ! node_is_installed || is_armv6l; then
    echo -n "$(timestamp) [openHABian] Installing prerequsites for ${1} for JS Scripting (NodeJS)... "
    if cond_redirect nodejs_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Checking for updates of ${1} for JS Scripting... "
  data=$(npm outdated --prefix /etc/openhab/automation/js --json)

  # Check whether data includes the packageName.
  if [[ "${data}" =~ \"${1}\" ]];
  then
    echo -n "Update available... "
    wantedVersion=$(echo "${data}" | jq ".${1}" | jq '.wanted' | sed -r 's/"//g' | sed -r 's/.[0-9].[0-9]//g')
    latestVersion=$(echo "${data}" | jq ".${1}" | jq '.latest' | sed -r 's/"//g' | sed -r 's/.[0-9].[0-9]//g')
    if [[ "${wantedVersion}" -lt "${latestVersion}" ]]; then
      echo "New major version... "
      if [[ -n $INTERACTIVE ]]; then
        if [[ "$1" == "openhab" ]]; then breakingText+="\\nPlease read the changelog (https://github.com/openhab/openhab-js/blob/main/CHANGELOG.md)."; fi
        if (whiptail --title "Update available for ${1} for JS Scripting" --yes-button "Continue" --no-button "Skip" --yesno "${introText}${breakingText}" 15 80); then echo "UPDATING"; else echo "SKIP"; return 0; fi
      fi
    else
      echo
      if [[ -n $INTERACTIVE ]]; then
        if [[ "$1" == "openhab" ]]; then introText+="\\nYou may read the changelog (https://github.com/openhab/openhab-js/blob/main/CHANGELOG.md)."; fi
        if (whiptail --title "Update available for ${1} for JS Scripting" --yes-button "Continue" --no-button "Skip" --yesno "${introText}" 15 80); then echo "UPDATING"; else echo "SKIP"; return 0; fi
      fi
    fi
    jsscripting_npm_install "${1}" "update"
  else
    echo "No update available."
  fi
}
