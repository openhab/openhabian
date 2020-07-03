#!/usr/bin/env bash

## Function for installing and configure InfluxDB and Grafana while also integrate it to openHAB.
## The function can be invoked either INTERACTIVE with userinterface UNATTENDED.
##
## When called UNATTENDED it will install both InfluxDB and Grafana on the local system.
##
##    influxdb_grafana_setup()
##

influxdb_grafana_setup() {
  local FAILED
  local textIntro textUnsupported textLowMem textFail textFailLowMem textSuccess
  local influxDBAddress influxDBAdminUsername influxDBAdminPassword
  local influxDBopenhabUsername influxDBopenhabPassword
  local influxDBGrafanaUsername influxDBGrafanaPassword
  local influxDBDatabaseName
  local GrafanaAdminPassword
  local openhabIntegration
  local textInfluxDBintro
  local textInfluxDBconfigure
  local influxDBReturnCode
  local textInfluxDBAddress
  local textInfluxDBAdminPassword
  local matched
  local passwordCheck
  local textGrafanaAdminPassword
  local textOpenhabIntegration
  local lowmemory

  FAILED=0
  textIntro="This will install and configure InfluxDB and Grafana. For more information please consult this discussion thread:\\nhttps://community.openhab.org/t/13761/1\\n\\nNOTE for existing installations:\\n - Grafana password will be reset and configuration adapated\\n - If local installation of InfluxDB is choosen, passwords will be reset and config files will be changed"
  textUnsupported="You are attempting to install Grafana on a SBC which has an older ARMv6l set instruction set only, such as a RPi0W.\\nThis requires you to install a special package.\\n openHABian does not support that. You can still go for a manual install.\\n\\nGrafana software downloads are available at https://grafana.com/grafana/download?platform=arm"
  textLowMem="WARNING: InfluxDB and Grafana tend to use a lot of memory. Your machine reports less than 1 GB memory, and we STRICTLY RECOMMEND NOT TO PROCEED!\\n\\nDISCLAIMER: Proceed at your own risk and do NOT report tickets if you run into problems."
  textFail="Sadly there was a problem setting up the selected option. Please report this problem on the openHAB community forum or as a openHABian Github issue."
  textFailLowMem="Sadly there was a problem setting up the selected option. Your machine reports less than 1 GB memory, please consider upgrading your hardware for Grafana/InfluxDB."
  textSuccess="Setup successful. Please continue with the instructions you can find here:\\n\\nhttps://community.openhab.org/t/13761/1"

  echo "$(timestamp) [openHABian] Setting up InfluxDB and Grafana... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$textIntro" 15 80); then echo "CANCELED"; return 0; fi
    if is_armv61; then
      whiptail --title "Unsupported Hardware" --msgbox "$textUnsupported" 14 80
      echo "CANCELED"
      return 0
    fi
    # now check if hardware is recommended for Grafana/InfluxDB, SBCs with < 1 GB such as RPi0W and RPi1 are not really suited to run it together with OH
    lowmemory=false
    if has_lowmem; then
      lowmemory=true
      if ! (whiptail --title "WARNING, Continue?" --yes-button "Continue" --no-button "Back" --yesno --defaultno "$textLowMem" 15 80); then echo "CANCELED"; return 0; fi
    fi
  fi

  openhabIntegration=false
  if [ -n "$INTERACTIVE" ]; then
    textInfluxDBintro="A new InfluxDB instance can be installed locally on the openHABian system or an already running InfluxDB instance can be used. Please choose one of the options. "
    if ! (whiptail --title "InfluxDB" --yes-button "Install locally" --no-button "Use existing instance" --yesno "$textInfluxDBintro" 15 80); then
      textInfluxDBconfigure="Shall a new user and database be configured on the InfluxDB instance automatically or shall existing existing ones be used?"
      if ! (whiptail --title "InfluxDB" --yes-button "Create new" --no-button "Use existing" --yesno "$textInfluxDBconfigure" 15 80); then
        # Existing InfluxDB - Manual configuration
        influxDBDatabaseName=$(whiptail --title "InfluxDB" --inputbox "openHAB need to use a specific InfluxDB database. Please enter a configured InfluxDB database name:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBopenhabUsername=$(whiptail --title "InfluxDB" --inputbox "openHAB need write/read access to previous defined database. Please enter an InfluxDB username for openHAB:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBopenhabPassword=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxDBopenhabUsername:\"" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBGrafanaUsername=$(whiptail --title "InfluxDB" --inputbox "Grafana need read access to previous defined database. Please enter an InfluxDB username for Grafana:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBGrafanaPassword=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxDBGrafanaUsername\":" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      else
        # Existing InfluxBD - Automatic configuration
        influxDBAdminUsername=$(whiptail --title "InfluxDB" --inputbox "An InfluxDB admin account must be used for automatical database configuration. Please enter a username: " 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBAdminPassword=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxDBAdminUsername\":" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      fi
      # Influx DB server address
      influxDBReturnCode=0
      textInfluxDBAddress="Enter InfluxDB instance adress: [protocol:address:port] \\n eg. https://192.168.1.100:8086"
      while [ "$influxDBReturnCode" != "204" ]
      do
        influxDBAddress=$(whiptail --title "InfluxDB" --inputbox "$textInfluxDBAddress" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxDBReturnCode="$(curl -s -o --max-time 6 --insecure /dev/null -w "%{http_code}" "$influxDBAddress"/ping | sed 's/^0*//')"
        textInfluxDBAddress="Can't establish contact to InfluxDB instance. Please retry to enter InfluxDB instance adress: [protocol:address:port] \\n eg. https://192.168.1.100:8086"
      done
    else
      # Local InfluxDB
      influxDBAdminUsername="admin"
      textInfluxDBAdminPassword="The local InfluxDB installation needs a password for the \"admin\" account. Enter a password:"
      matched=false
      while [ "$matched" = false ]; do
        influxDBAdminPassword=$(whiptail --title "InfluxDB - Admin Account" --passwordbox "$textInfluxDBAdminPassword" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        passwordCheck=$(whiptail --title "InfluxDB - Admin Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxDBAdminPassword" = "$passwordCheck" ] && [ -n "$influxDBAdminPassword" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
    fi

    if [ -z "$influxDBopenhabUsername" ]; then # is empty
      influxDBDatabaseName="openhab_db"
      influxDBopenhabUsername="openhab"
      influxDBGrafanaUsername="grafana"
      matched=false
      while [ "$matched" = false ]; do
        influxDBopenhabPassword=$(whiptail --title "InfluxDB - openHAB Account" --passwordbox "An openHAB specific InfluxDB user will be created \"openhab\". Please enter a password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        passwordCheck=$(whiptail --title "InfluxDB - openHAB Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxDBopenhabPassword" = "$passwordCheck" ] && [ -n "$influxDBopenhabPassword" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
      matched=false
      while [ "$matched" = false ]; do
        influxDBGrafanaPassword=$(whiptail --title "InfluxDB - Grafana Account" --passwordbox "A Grafana specific InfluxDB user will be created \"grafana\". Please enter a password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        passwordCheck=$(whiptail --title "InfluxDB - Grafana Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? -eq 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxDBGrafanaPassword" = "$passwordCheck" ] && [ -n "$influxDBGrafanaPassword" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
    fi

    # Local Grafana
    textGrafanaAdminPassword="The local Grafana installation needs a password for the \"admin\" account. NOTE: min. 5 characters. Enter a password:"
    matched=false
    while [ "$matched" = false ]; do
      GrafanaAdminPassword=$(whiptail --title "Grafana - Admin Account" --passwordbox "$textGrafanaAdminPassword" 15 80 3>&1 1>&2 2>&3)
      if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      if [ ${#GrafanaAdminPassword} -gt 4 ]; then
        passwordCheck=$(whiptail --title "Grafana - Admin Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$GrafanaAdminPassword" = "$passwordCheck" ] && [ -n "$GrafanaAdminPassword" ]; then
          matched=true
        fi
        if [ "$matched" = false ]; then
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or too short... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      fi
    done

    if openhab_is_running; then
      textOpenhabIntegration="openHAB can use InfluxDB for persistant storage. Shall InfluxDB be configured with openHAB?
      (A new config file for openHAB will be created with basic settings.)"
      if (whiptail --title "openHAB integration, Continue?" --yes-button "Yes" --no-button "No" --yesno "$textOpenhabIntegration" 15 80); then openhabIntegration=true ; fi
    else
      cond_echo "openHAB is not running. InfluxDB and Grafana openHAB integration is skipped..."
    fi
  fi

  if [ -z "$influxDBAddress" ]; then # is empty, install a InfluxDB database
    influxdb_install "$influxDBAdminPassword"
    influxDBAddress="http://localhost:8086"
  fi

  if [ -n "$influxDBAdminUsername" ]; then # is set, configure database and application users
    echo -n "Setup of inital influxdb database and InfluxDB users... "
    echo -n ""
    influxDBDatabaseName="openhab_db"
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=CREATE DATABASE $influxDBDatabaseName" || FAILED=1
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=CREATE USER openhab WITH PASSWORD '$influxDBopenhabPassword'" || FAILED=1
    # set password, create might have failed if user existed before
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=SET PASSWORD FOR openhab = '$influxDBopenhabPassword'" || FAILED=1
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=CREATE USER grafana WITH PASSWORD '$influxDBGrafanaPassword'" || FAILED=1
    # set password, create might have failed if user existed before
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=SET PASSWORD FOR grafana = '$influxDBGrafanaPassword'" || FAILED=1
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=GRANT ALL ON openhab_db TO openhab" || FAILED=1
    curl --user "$influxDBAdminUsername:$influxDBAdminPassword" --insecure $influxDBAddress/query --data-urlencode "q=GRANT READ ON openhab_db TO grafana" || FAILED=1
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  fi

  grafana_install "$GrafanaAdminPassword"

  echo -n "Connection Grafana to InfluxDB..."
  curl  --user "admin:$GrafanaAdminPassword" --request POST http://localhost:3000/api/datasources \
        --header "Content-Type: application/json" \
        --data '{"name": "openhab_home", "type": "influxdb", "url": "http://localhost:8086", "password": "'"$influxDBGrafanaPassword"'", "user": "'"$influxDBGrafanaUsername"'", "database": "'"$influxDBDatabaseName"'", "access": "proxy", "basicAuth":true, "basicAuthUser":"'"$influxDBGrafanaUsername"'", "basicAuthPassword":"'"$influxDBGrafanaPassword"'", "withCredentials":false}'

  echo -n "Adding openHAB dashboard tile for Grafana... "
  dashboard_add_tile grafana || FAILED=4

  if [ "$openhabIntegration" = true ]; then
    echo -n "Adding install InfluxDB with database configuration to openHAB"
    curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" "http://localhost:$OPENHAB_HTTP_PORT/rest/extensions/influxdb/install"
    cond_redirect touch /etc/openhab2/services/influxdb.cfg
    { echo "url=$influxDBAddress"; \
    echo "user=$influxDBopenhabUsername"; \
    echo "password=$influxDBopenhabPassword"; \
    echo "db=$influxDBDatabaseName"; \
    echo "retentionPolicy=autogen"; } >> /etc/openhab2/services/influxdb.cfg
  fi
  cond_echo ""

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$textSuccess" 15 80
    else
      if [ $lowmemory = "false" ]; then
        whiptail --title "Operation Failed!" --msgbox "$textFail" 10 60
      else
        whiptail --title "Operation Failed!" --msgbox "$textFailLowMem" 10 60
      fi
    fi
  fi
}


## Install local InfluxDB database
##
##    influxdb_install(String admin_password)
##

influxdb_install() {
  local influxDBAddress
  local influxDBAdminUsername
  local dist
  local codename

  cond_echo ""
  echo "Installing InfluxDB..."
  dist="debian"
  codename="buster"
  if is_ubuntu; then
    dist="ubuntu"
    codename="$(lsb_release -sc)"
  elif is_debian; then
    dist="debian"
    codename="$(lsb_release -sc)"
  fi
  influxDBAddress="http://localhost:8086"
  influxDBAdminUsername="admin"
#  if [ ! -f /etc/influxdb/influxdb.conf ]; then
    cond_redirect wget -O - https://repos.influxdata.com/influxdb.key | apt-key add - || FAILED=1
    echo "deb https://repos.influxdata.com/${dist} ${codename} stable" > /etc/apt/sources.list.d/influxdb.list || FAILED=1
    cond_redirect apt-get update || FAILED=1
    cond_redirect apt-get install --yes influxdb || FAILED=1

    # disable authentication, to allow changes in existing installations
    cond_redirect sed -i 's/auth-enabled = true/# auth-enabled = false/g' /etc/influxdb/influxdb.conf || FAILED=1

    cond_redirect systemctl -q daemon-reload &>/dev/null
    sleep 2
    cond_redirect systemctl enable influxdb.service
    sleep 2
    cond_redirect systemctl restart influxdb.service
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
    echo -n "Configure InfluxDB admin account... "; echo -n ""
    sleep 2
    curl --retry 6 --retry-connrefused --insecure $influxDBAddress/query --data-urlencode "q=CREATE USER admin WITH PASSWORD '$1' WITH ALL PRIVILEGES" || FAILED=1
    # if it already existed, setting the password did not succeed
    curl --insecure $influxDBAddress/query --data-urlencode "q=SET PASSWORD FOR admin = '$1'" || FAILED=1
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
    echo -n "Configure listen on localhost only... "; echo -n ""
    cond_redirect sed -i -e '/# Determines whether HTTP endpoint is enabled./ { n ; s/# enabled = true/enabled = true/ }' /etc/influxdb/influxdb.conf || FAILED=1
    cond_redirect sed -i 's/# bind-address = ":8086"/bind-address = "localhost:8086"/g' /etc/influxdb/influxdb.conf || FAILED=1
    cond_redirect sed -i 's/# auth-enabled = false/auth-enabled = true/g' /etc/influxdb/influxdb.conf || FAILED=1
    # disable stats collection to save memory, issue #506
    cond_redirect sed -i 's/# store-enabled = true/store-enabled = false/g' /etc/influxdb/influxdb.conf || FAILED=1
    cond_redirect systemctl restart influxdb.service
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
    # check if service is running
    echo -n "Waiting for InfluxDB service... "
    curl --retry 6 --retry-connrefused -s --insecure --user "admin:$1" $influxDBAddress/query >/dev/null || FAILED=1
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
#  else
#    echo "SKIPPED"
#    cond_echo "InfluxDB already installed. Using http://localhost:8086"
#  fi
  cond_echo ""
}

## Install local Grafana installation
##
##    influxdb_install(String admin_password)
##

grafana_debug_info() {
  echo
  date
  echo ---
  cond_redirect tail -n40 /var/log/grafana/grafana.log | sed "s/^/DEBUG  /"
  echo ---
  local TMP
  TMP=$(pgrep -a grafana)
  # shellcheck disable=SC2001
  echo "${TMP:-Grafana NOT running!}"| sed "s/^/DEBUG  /"
  echo ---
  echo
}

grafana_install(){
  local FAILED
  FAILED=0
  echo -n "Installing Grafana... "
  cond_redirect wget -O - https://packages.grafana.com/gpg.key | apt-key add - || FAILED=2
  echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list || FAILED=2
  cond_redirect apt-get update || FAILED=1
  cond_redirect apt-get install --yes grafana || FAILED=2

  # workaround for strange behavior in CI
  # shellcheck disable=SC2174
  mkdir -p -m 750 /var/run/grafana/ && chown grafana:grafana /var/run/grafana/

  cond_redirect systemctl -q daemon-reload &>/dev/null
  cond_redirect systemctl enable grafana-server.service
  cond_redirect systemctl start grafana-server.service
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Wait for Grafana to start... "
  tryUntil "curl -s http://localhost:3000 >/dev/null" 10 10 && FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; curl -s -S http://localhost:3000; grafana_debug_info; return 2; else echo -n "OK "; fi
  sleep 5
  cond_echo ""

  # password reset required if Grafana password was already set before (no first-time install)
  echo -n "Resetting Grafana admin password... "
  cond_redirect su -s /bin/bash -c "grafana-cli admin reset-admin-password admin" grafana || FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  cond_echo ""

  sleep 2
  echo -n "Restarting Grafana... "
  cond_redirect systemctl restart grafana-server.service || FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  tryUntil "curl -s http://localhost:3000 >/dev/null" 10 10 && FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  sleep 2

  echo -n "Updating Grafana admin password... "
  cond_redirect curl --user admin:admin --header "Content-Type: application/json" --request PUT --data "{\"password\":\"$1\"}" http://localhost:3000/api/admin/users/1/password || FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Updating Grafana configuration... "
  cond_redirect sed -i -e '/^# disable user signup \/ registration/ { n ; s/^;allow_sign_up = true/allow_sign_up = false/ }' /etc/grafana/grafana.ini || FAILED=2
  cond_redirect sed -i -e '/^# enable anonymous access/ { n ; s/^;enabled = false/enabled = true/ }' /etc/grafana/grafana.ini || FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  cond_redirect systemctl restart grafana-server.service
  sleep 2
  # check if service is running
  echo -n "Waiting for Grafana service... "
  tryUntil "curl -s http://localhost:3000 >/dev/null" 10 10 && FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; grafana_debug_info; return 2; else echo -n "OK "; fi
  cond_echo ""
}
