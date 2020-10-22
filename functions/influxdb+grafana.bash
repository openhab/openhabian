#!/usr/bin/env bash

## Function to install and configure InfluxDB and Grafana, and integrate them with openHAB.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    influxdb_grafana_setup()
##
influxdb_grafana_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] InfluxDB and Grafana setup must be run in interactive mode! Canceling InfluxDB and Grafana setup!"
    return 0
  fi
  if is_armv6l; then
    echo "$(timestamp) [openHABian] InfluxDB and Grafana setup cannot be run on armv6l! Canceling InfluxDB and Grafana setup!"
    whiptail --title "Incompatible selection detected!" --msgbox "You are attempting to install Grafana on a(n) SBC which has an older armv6l instruction set, such as a RPi0W.\\n\\nThis requires you to install a special package.\\n\\nAs such, openHABian does not support this configuration, however, you can still go for a manual install.\\n\\nGrafana software downloads are available at https://grafana.com/grafana/download?platform=arm" 14 80
    return 0
  fi

  local introText
  local lowMemText
  local successText
  local influxDBText
  local influxDBDatabaseName
  local influxDBUsernameOH
  local influxDBPasswordOH influxDBPasswordOH1 influxDBPasswordOH2
  local influxDBUsernameGrafana
  local influxDBPasswordGrafana influxDBPasswordGrafana1 influxDBPasswordGrafana2
  local influxDBUsernameAdmin
  local influxDBPasswordAdmin influxDBPasswordAdmin1 influxDBPasswordAdmin2
  local influxDBReturnCode
  local influxDBAddressText
  local grafanaPasswordAdmin grafanaPasswordAdmin1 grafanaPasswordAdmin2
  local integrationOH

  introText="This will install and configure InfluxDB and Grafana. For more information please consult this discussion thread:\\nhttps://community.openhab.org/t/13761/1\\n\\nNOTE for existing installations:\\n - Grafana password will be reset and configuration adapated.\\n - If local installation of InfluxDB is choosen, passwords will be reset and configuration files will be changed."
  lowMemText="WARNING: InfluxDB and Grafana tend to use a lot of RAM. Your machine reports less than 1 GB of RAM, therefore we STRICTLY RECOMMEND NOT TO PROCEED!\\n\\nDISCLAIMER: Proceed at your own risk and do NOT report tickets if you run into problems. Please consider upgrading your hardware for Grafana/InfluxDB."
  successText="Setup was successful.\\n\\nPlease continue with the instructions you can find here:\\nhttps://community.openhab.org/t/13761/1"
  influxDBText="Would you like to setup a new instance of InfluxDB locally?\\n\\nAs an alternative, a preexisting installation of InfluxDB can be used.\\n\\nPlease choose what you would like have configured:"
  influxDBReturnCode="0"
  influxDBAddressText="\\nEnter your InfluxDB instance's network address: [protocol:address:port]\\n\\nFor example: https://192.168.1.100:8086"
  integrationOH="false"

  echo -n "$(timestamp) [openHABian] Beginning setup of InfluxDB and Grafana... "
  if ! (whiptail --title "InfluxDB and Grafana installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 14 80); then echo "CANCELED"; return 0; fi
  if has_lowmem; then
    if ! (whiptail --title "WARNING, Continue?" --yes-button "Continue" --no-button "Cancel" --defaultno --yesno "$lowMemText" 11 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  echo -n "$(timestamp) [openHABian] Configuring InfluxDB... "
  if ! (whiptail --title "InfluxDB installation?" --yes-button "Setup InfluxDB" --no-button "Preexisting Installation" --yesno "$influxDBText" 11 80); then
    if ! (whiptail --title "InfluxDB database configuration?" --yes-button "Create new" --no-button "Use existing" --yesno "Shall a new user and database be configured on the InfluxDB instance automatically or shall existing existing ones be used?" 8 80); then
      # Existing InfluxDB - Manual configuration
      if ! influxDBDatabaseName="$(whiptail --title "InfluxDB database name?" --inputbox "\\nopenHAB needs to use a specific InfluxDB database.\\n\\nPlease enter a configured InfluxDB database name:" 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      if ! influxDBUsernameOH="$(whiptail --title "InfluxDB openHAB username?" --inputbox "\\nopenHAB needs read/write access to the previously defined database.\\n\\nPlease enter an InfluxDB username for openHAB to use:" 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      if ! influxDBPasswordOH="$(whiptail --title "InfluxDB openHAB password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameOH':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      if ! influxDBUsernameGrafana="$(whiptail --title "InfluxDB Grafana username?" --inputbox "\\nGrafana needs read access to the previously defined database.\\n\\nPlease enter an InfluxDB username for Grafana to use:" 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      if ! influxDBPasswordGrafana="$(whiptail --title "InfluxDB Grafana password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameGrafana':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
    else
      # Existing InfluxDB - Automatic configuration
      if ! influxDBUsernameAdmin="$(whiptail --title "InfluxDB admin username?" --inputbox "\\nAn InfluxDB admin account must be used for automatic database configuration.\\n\\nPlease enter an InfluxDB admin username:" 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      if ! influxDBPasswordAdmin="$(whiptail --title "InfluxDB admin password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameAdmin':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
    fi
    while [[ $influxDBReturnCode != "204" ]]; do
      if ! influxDBAddress="$(whiptail --title "InfluxDB network address?" --inputbox "$influxDBAddressText" 13 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 1; fi
      influxDBReturnCode="$(curl -s -k -m 6 -I -o /dev/null -w "%{http_code}" "${influxDBAddress}/ping")"
      influxDBAddressText="\\nSorry, but I could not connect to the specified InfluxDB instance.\\n\\nEnter your InfluxDB instance's network address: [protocol:address:port]\\n\\nFor example: https://192.168.1.100:8086"
    done
  else
    # New InfluxDB - Manual configuration
    if ! influxDBUsernameAdmin="$(whiptail --title "InfluxDB admin username?" --inputbox "\\nEnter a username for InfluxDB to use as an admin:" 9 80 admin 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    while [[ -z $influxDBPasswordAdmin ]]; do
      if ! influxDBPasswordAdmin1="$(whiptail --title "InfluxDB admin password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameAdmin':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if ! influxDBPasswordAdmin2="$(whiptail --title "InfluxDB admin password?" --passwordbox "\\nPlease confirm the password for InfluxDB account '$influxDBUsernameAdmin':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if [[ $influxDBPasswordAdmin1 == "$influxDBPasswordAdmin2" ]] && [[ ${#influxDBPasswordAdmin1} -ge 8 ]] && [[ ${#influxDBPasswordAdmin2} -ge 8 ]]; then
        influxDBPasswordAdmin="$influxDBPasswordAdmin1"
      else
        whiptail --title "InfluxDB admin password?" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
  fi
  if [[ -z $influxDBUsernameOH ]]; then
    if ! influxDBUsernameOH="$(whiptail --title "InfluxDB openHAB username?" --inputbox "\\nEnter a username for openHAB to use with InfluxDB:" 9 80 openhab 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    while [[ -z $influxDBPasswordOH ]]; do
      if ! influxDBPasswordOH1="$(whiptail --title "InfluxDB openHAB password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameOH':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if ! influxDBPasswordOH2="$(whiptail --title "InfluxDB openHAB password?" --passwordbox "\\nPlease confirm the password for InfluxDB account '$influxDBUsernameOH':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if [[ $influxDBPasswordOH1 == "$influxDBPasswordOH2" ]] && [[ ${#influxDBPasswordOH1} -ge 8 ]] && [[ ${#influxDBPasswordOH2} -ge 8 ]]; then
        influxDBPasswordOH="$influxDBPasswordOH1"
      else
        whiptail --title "InfluxDB openHAB password?" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
  fi
  if [[ -z $influxDBUsernameGrafana ]]; then
    if ! influxDBUsernameGrafana="$(whiptail --title "InfluxDB Grafana username?" --inputbox "\\nEnter a username for Grafana to use with InfluxDB:" 9 80 grafana 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    while [[ -z $influxDBPasswordGrafana ]]; do
      if ! influxDBPasswordGrafana1="$(whiptail --title "InfluxDB Grafana password?" --passwordbox "\\nPlease enter the password for InfluxDB account '$influxDBUsernameGrafana':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if ! influxDBPasswordGrafana2="$(whiptail --title "InfluxDB Grafana password?" --passwordbox "\\nPlease confirm the password for InfluxDB account '$influxDBUsernameGrafana':" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if [[ $influxDBPasswordGrafana1 == "$influxDBPasswordGrafana2" ]] && [[ ${#influxDBPasswordGrafana1} -ge 8 ]] && [[ ${#influxDBPasswordGrafana2} -ge 8 ]]; then
        influxDBPasswordGrafana="$influxDBPasswordGrafana1"
      else
        whiptail --title "InfluxDB Grafana password?" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
  fi
  if [[ -z $influxDBDatabaseName ]]; then
    if ! influxDBDatabaseName="$(whiptail --title "InfluxDB database name?" --inputbox "\\nEnter a name for the InfluxDB database:" 9 80 openhab 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Configuring Grafana... "
  while [[ -z $grafanaPasswordAdmin ]]; do
    if ! grafanaPasswordAdmin1="$(whiptail --title "Grafana Admin password?" --passwordbox "\\nPlease enter the password for Grafana Admin account:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! grafanaPasswordAdmin2="$(whiptail --title "Grafana Admin password?" --passwordbox "\\nPlease confirm the password for Grafana Admin account:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if [[ $grafanaPasswordAdmin1 == "$grafanaPasswordAdmin2" ]] && [[ ${#grafanaPasswordAdmin1} -ge 5 ]] && [[ ${#grafanaPasswordAdmin2} -ge 5 ]]; then
      grafanaPasswordAdmin="$grafanaPasswordAdmin1"
    else
      whiptail --title "Grafana Admin password?" --msgbox "Password mismatched, blank, or less than 5 characters... Please try again!" 7 80
    fi
  done
  echo "OK"

  if openhab_is_running; then
    if (whiptail --title "Setup openHAB integration?" --yes-button "Yes" --no-button "No" --yesno "openHAB can use InfluxDB for persistant storage, shall InfluxDB be configured with openHAB?\\n\\nA new config file for openHAB will be created with basic settings." 10 80); then integrationOH="true"; fi
  else
    cond_echo "Integration with openHAB was skipped as openHAB is not running!"
  fi

  if [[ -z $influxDBAddress ]]; then
    echo -n "$(timestamp) [openHABian] Installing InfluxDB... "
    if cond_redirect influxdb_install "$influxDBUsernameAdmin" "$influxDBPasswordAdmin"; then echo "OK"; else echo "FAILED"; return 1; fi
    influxDBAddress="http://localhost:8086"
  fi

  if [[ -n $influxDBUsernameAdmin ]]; then
    echo -n "$(timestamp) [openHABian] Setting up new InfluxDB installation... "

    cond_echo "Creating InfluxDB database ${influxDBDatabaseName}"
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=CREATE DATABASE ${influxDBDatabaseName}"; then echo "FAILED (create database)"; return 1; fi

    cond_echo "Creating InfluxDB user ${influxDBUsernameOH}"
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=CREATE USER ${influxDBUsernameOH} WITH PASSWORD '${influxDBPasswordOH}'"; then echo "FAILED (create ${influxDBUsernameOH})"; return 1; fi
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=SET PASSWORD FOR ${influxDBUsernameOH} = '${influxDBPasswordOH}'"; then echo "FAILED (${influxDBUsernameOH} password)"; return 1; fi # Set password here because create might have failed if user existed before
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=GRANT ALL ON ${influxDBDatabaseName} TO ${influxDBUsernameOH}"; then echo "FAILED (${influxDBUsernameOH} permissions)"; return 1; fi

    cond_echo "Creating InfluxDB user ${influxDBUsernameGrafana}"
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=CREATE USER ${influxDBUsernameGrafana} WITH PASSWORD '${influxDBPasswordGrafana}'"; then echo "FAILED (create ${influxDBUsernameGrafana})"; return 1; fi
    if ! cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=SET PASSWORD FOR ${influxDBUsernameGrafana} = '${influxDBPasswordGrafana}'"; then echo "FAILED (${influxDBUsernameGrafana} password)"; return 1; fi # Set password here because create might have failed if user existed before
    if cond_redirect curl --user "${influxDBUsernameAdmin}:${influxDBPasswordAdmin}" --insecure "${influxDBAddress}/query" --data-urlencode "q=GRANT READ ON ${influxDBDatabaseName} TO ${influxDBUsernameGrafana}"; then echo "OK"; else echo "FAILED (${influxDBUsernameGrafana} permissions)"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Installing Grafana.. "
  if cond_redirect grafana_install "$grafanaPasswordAdmin"; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Connecting Grafana to InfluxDB... "
  if cond_redirect curl  --user "admin:${grafanaPasswordAdmin}" --request POST "http://localhost:3000/api/datasources" --header "Content-Type: application/json" --data '{"name": "openhab_home", "type": "influxdb", "url": "'"${influxDBAddress}"'", "password": "'"${influxDBPasswordGrafana}"'", "user": "'"${influxDBUsernameGrafana}"'", "database": "'"${influxDBDatabaseName}"'", "access": "proxy", "basicAuth":true, "basicAuthUser":"'"${influxDBUsernameGrafana}"'", "basicAuthPassword":"'"${influxDBPasswordGrafana}"'", "withCredentials":false}'; then echo "OK"; else echo "FAILED"; return 1; fi

  if [[ $integrationOH == "true" ]]; then
    echo -n "$(timestamp) [openHABian] Connecting InfluxDB to openHAB... "
    if ! cond_redirect curl --request POST --header "Accept: application/json" --header "Content-Type: application/json" "http://localhost:${OPENHAB_HTTP_PORT:-8080}/rest/extensions/influxdb/install"; then echo "FAILED"; return 1; fi
    {
      echo "url=${influxDBAddress}"; \
      echo "user=${influxDBUsernameOH}"; \
      echo "password=${influxDBPasswordOH}"; \
      echo "db=${influxDBDatabaseName}"; \
      echo "retentionPolicy=autogen"
    } > /etc/openhab/services/influxdb.cfg
    echo "OK"
  fi

  whiptail --title "Operation Successful!" --msgbox "$successText" 10 80

  if openhab_is_installed; then
    dashboard_add_tile "grafana"
  fi
}

## Install local InfluxDB database
##
##    influxdb_install(String adminUsername, String adminPassword)
##
influxdb_install() {
  local address
  local adminUsername
  local adminPassword
  local myOS
  local myRelease

  if ! [[ -x $(command -v lsb_release) ]]; then
    echo -n "$(timestamp) [openHABian] Installing InfluxDB required packages (lsb-release)... "
    if cond_redirect apt-get install --yes lsb-release; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  address="http://localhost:8086"
  adminUsername="$1"
  adminPassword="$2"
  if is_pi; then
    myOS="Debian"
  else
    myOS="$(lsb_release -si)"
  fi
  myRelease="$(lsb_release -sc)"

  if ! dpkg -s 'influxdb' &> /dev/null; then
    if ! add_keys "https://repos.influxdata.com/influxdb.key"; then return 1; fi

    echo "deb https://repos.influxdata.com/${myOS,,} ${myRelease,,} stable" > /etc/apt/sources.list.d/influxdb.list

    echo -n "$(timestamp) [openHABian] Installing InfluxDB... "
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    if cond_redirect apt-get install --yes influxdb; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up InfluxDB service... "
  # Disable authentication, to allow changes in existing installations
  if ! cond_redirect sed -i -e 's|auth-enabled = true|# auth-enabled = false|g' /etc/influxdb/influxdb.conf; then echo "FAILED (disable authentication)"; return 1; fi
  if ! zram_dependency install influxdb; then return 1; fi
  if cond_redirect systemctl enable --now influxdb.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up InfluxDB... "

  cond_echo "\\nConfigure InfluxDB admin account... "
  if ! cond_redirect curl --retry 6 --retry-connrefused --insecure "${address}/query" --data-urlencode "q=CREATE USER ${adminUsername} WITH PASSWORD '${adminPassword}' WITH ALL PRIVILEGES"; then echo "FAILED (create admin user)"; return 1; fi
  if ! cond_redirect curl --insecure "${address}/query" --data-urlencode "q=SET PASSWORD FOR ${adminUsername} = '${adminPassword}'"; then echo "FAILED (admin password)"; return 1; fi # Set password here because create might have failed if user existed before

  cond_echo "\\nDisable InfluxDB external access... "
  if ! cond_redirect sed -i -e '/# Determines whether HTTP endpoint is enabled./ { n ; s/# enabled = true/enabled = true/ }' /etc/influxdb/influxdb.conf; then echo "FAILED (http access)"; return 1; fi
  if ! cond_redirect sed -i -e 's|# bind-address = ":8086"|bind-address = "localhost:8086"|g' /etc/influxdb/influxdb.conf; then echo "FAILED (bind address)"; return 1; fi
  if ! cond_redirect sed -i -e 's|# auth-enabled = false|auth-enabled = true|g' /etc/influxdb/influxdb.conf; then echo "FAILED (enable authentication)"; return 1; fi
  # Disable stats collection to save memory, issue #506
  if ! cond_redirect sed -i -e 's|# store-enabled = true|store-enabled = false|g' /etc/influxdb/influxdb.conf; then echo "FAILED (disable stats)"; return 1; fi
  if ! cond_redirect systemctl restart influxdb.service; then echo "FAILED (restart service)"; return 1; fi

  cond_echo "\\nCheck if InfluxDB is running... "
  if cond_redirect curl --retry 6 --retry-connrefused --user "${adminUsername}:${adminPassword}" --insecure "${address}/query"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Install local Grafana installation
##
##    influxdb_install(String admin_password)
##
grafana_install(){
  local adminPassword

  adminPassword="$1"

  if ! dpkg -s 'grafana' &> /dev/null; then
    if ! add_keys "https://packages.grafana.com/gpg.key"; then return 1; fi

    echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list

    echo -n "$(timestamp) [openHABian] Installing Grafana... "
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    if cond_redirect apt-get install --yes grafana; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up Grafana service... "
  # Workaround for strange behavior in CI
  if ! cond_redirect mkdir -p /var/run/grafana; then echo "FAILED (mkdir)"; return 1; fi
  if ! cond_redirect chmod -R 0750 /var/run/grafana; then echo "FAILED (chmod)"; return 1; fi
  if ! cond_redirect chown -R grafana:grafana /var/run/grafana; then echo "FAILED (chown)"; return 1; fi
  if ! zram_dependency install grafana; then return 1; fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable --now grafana-server.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up Grafana... "
  cond_echo "\\nWait for Grafana to start... "
  if ! (curl -4 --retry 6 --retry-connrefused --silent --head http://localhost:3000); then echo "FAILED (wait for Grafana to start)"; return 1; fi

  # Password reset required if Grafana password was already set before (not first-time install)
  cond_echo "\\nResetting Grafana admin password... "
  if ! cond_redirect chsh --shell /bin/bash "grafana"; then echo "FAILED (chsh grafana)"; return 1; fi
  if ! cond_redirect grafana-cli admin reset-admin-password "${adminPassword}"; then echo "FAILED (admin password)"; return 1; fi

  cond_echo "\\nUpdating Grafana configuration... "
  if ! cond_redirect sed -i -e '/^# disable user signup \/ registration/ { n ; s/^;allow_sign_up = true/allow_sign_up = false/ }' /etc/grafana/grafana.ini; then echo "FAILED (no user signup)"; return 1; fi
  if ! cond_redirect sed -i -e '/^# enable anonymous access/ { n ; s/^;enabled = false/enabled = true/ }' /etc/grafana/grafana.ini; then echo "FAILED (anonymous access)"; return 1; fi

  cond_echo "\\nRestarting Grafana... "
  if ! cond_redirect systemctl restart grafana-server.service; then echo "FAILED (restart service)"; return 1; fi
  if (curl -4 --retry 6 --retry-connrefused --silent --head http://localhost:3000); then echo "OK"; else echo "FAILED (wait for Grafana to start)"; return 1; fi
}

## Function to output Grafana debugging information
##
##    grafana_debug_info()
##
grafana_debug_info() {
  local temp

  temp="$(pgrep -a grafana)"

  echo -e "\\n$(date)\\n---"
  tail -n40 /var/log/grafana/grafana.log | sed 's|^|DEBUG  |'
  echo -e "---\\n${temp:-Grafana NOT running!}" | sed 's|^|DEBUG  |'
  echo "---"
}
