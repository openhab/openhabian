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
  local text_intro text_fail text_success
  local influxdb_address influxdb_admin_username
  local influxdb_admin_password
  local influxdb_openhab_username
  local influxdb_openhab_password
  local influxdb_grafana_username
  local influxdb_grafana_password
  local influxdb_database_name
  local grafana_admin_password
  local openhab_integration
  local text_influxDB_intro
  local text_influxDB_configure
  local influxdb_returncode
  local text_influxdb_address
  local text_influxDB_admin_password
  local matched
  local password_check
  local text_grafana_admin_password
  local text_openHAB_integration

  FAILED=0
  text_intro="This will install and configure InfluxDB and Grafana. For more information please consult this discussion thread:\\nhttps://community.openhab.org/t/13761/1"
  text_fail="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  text_success="Setup successful. Please continue with the instructions you can find here:\\n\\nhttps://community.openhab.org/t/13761/1"

  echo "$(timestamp) [openHABian] Setting up InfluxDB and Grafana... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$text_intro" 15 80) then echo "CANCELED"; return 0; fi
  fi

  openhab_integration=false
  if [ -n "$INTERACTIVE" ]; then
    text_influxDB_intro="A new InfluxDB instance can be installed locally on the openhabian system or an already running InfluxDB instance can be used. Please choose one of the options. "
    if ! (whiptail --title "InfluxDB" --yes-button "Install locally" --no-button "Use existing instance" --yesno "$text_influxDB_intro" 15 80) then
      text_influxDB_configure="Shall a new user and database be configured on the InfluxDB instance automatically or shall existing existing ones be used?"
      if ! (whiptail --title "InfluxDB" --yes-button "Create new" --no-button "Use existing" --yesno "$text_influxDB_configure" 15 80) then
        # Existing InfluxDB - Manual configuration
        influxdb_database_name=$(whiptail --title "InfluxDB" --inputbox "openHAB need to use a specific InfluxDB database. Please enter a configured InfluxDB database name:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_openhab_username=$(whiptail --title "InfluxDB" --inputbox "openHAB need write/read access to previous defined database. Please enter an InfluxDB username for openHAB:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_openhab_password=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxdb_openhab_username:\"" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_grafana_username=$(whiptail --title "InfluxDB" --inputbox "Grafana need read access to previous defined database. Please enter an InfluxDB username for Grafana:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_grafana_password=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxdb_grafana_username\":" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      else
        # Existing InfluxBD - Automatic configuration
        influxdb_admin_username=$(whiptail --title "InfluxDB" --inputbox "An InfluxDB admin account must be used for automatical database configuration. Please enter a username: " 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_admin_password=$(whiptail --title "InfluxDB" --passwordbox "Password for InfluxDB account \"$influxdb_admin_username\":" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      fi
      # Influx DB server address
      influxdb_returncode=0
      text_influxdb_address="Enter InfluxDB instance adress: [protocol:address:port] \\n eg. https://192.168.1.100:8086"
      while [ "$influxdb_returncode" != "204" ]
      do
        influxdb_address=$(whiptail --title "InfluxDB" --inputbox "$text_influxdb_address" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        influxdb_returncode="$(curl -s -o --max-time 6 --insecure /dev/null -w "%{http_code}" "$influxdb_address"/ping | sed 's/^0*//')"
        text_influxdb_address="Can't establish contact to InfluxDB instance. Please retry to enter InfluxDB instance adress: [protocol:address:port] \\n eg. https://192.168.1.100:8086"
      done
    else
      # Local InfluxDB
      influxdb_admin_username="admin"
      text_influxDB_admin_password="The local InfluxDB installation needs a password for the \"admin\" account. Enter a password:"
      matched=false
      while [ "$matched" = false ]; do
        influxdb_admin_password=$(whiptail --title "InfluxDB - Admin Account" --passwordbox "$text_influxDB_admin_password" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        password_check=$(whiptail --title "InfluxDB - Admin Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxdb_admin_password" = "$password_check" ] && [ -n "$influxdb_admin_password" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
    fi

    if [ -z "$influxdb_openhab_username" ]; then # is empty
      influxdb_database_name="openhab_db"
      influxdb_openhab_username="openhab"
      influxdb_grafana_username="grafana"
      matched=false
      while [ "$matched" = false ]; do
        influxdb_openhab_password=$(whiptail --title "InfluxDB - openHAB Account" --passwordbox "An openHAB specific InfluxDB user will be created \"openhab\". Please enter a password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        password_check=$(whiptail --title "InfluxDB - openHAB Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxdb_openhab_password" = "$password_check" ] && [ -n "$influxdb_openhab_password" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
      matched=false
      while [ "$matched" = false ]; do
        influxdb_grafana_password=$(whiptail --title "InfluxDB - Grafana Account" --passwordbox "A Grafana specific InfluxDB user will be created \"grafana\". Please enter a password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
        password_check=$(whiptail --title "InfluxDB - Grafana Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ $? -eq 1 ]; then echo "CANCELED"; return 0; fi
        if [ "$influxdb_grafana_password" = "$password_check" ] && [ -n "$influxdb_grafana_password" ]; then
          matched=true
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
        fi
      done
    fi

    # Local Grafana
    text_grafana_admin_password="The local Grafana installation needs a password for the \"admin\" account. Enter a password:"
    matched=false
    while [ "$matched" = false ]; do
      grafana_admin_password=$(whiptail --title "Grafana - Admin Account" --passwordbox "$text_grafana_admin_password" 15 80 3>&1 1>&2 2>&3)
      if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      password_check=$(whiptail --title "Grafana - Admin Account" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
      if [ $? = 1 ]; then echo "CANCELED"; return 0; fi
      if [ "$grafana_admin_password" = "$password_check" ] && [ -n "$grafana_admin_password" ]; then
        matched=true
      else
        whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
      fi
    done

    if openhab_is_running; then
      text_openHAB_integration="openHAB can use InfluxDB for persistant storage. Shall InfluxDB be configured with openHAB?
      (A new config file for openHAB will be created with basic settings.)"
      if (whiptail --title "openHAB integration, Continue?" --yes-button "Yes" --no-button "No" --yesno "$text_openHAB_integration" 15 80) then openhab_integration=true ; fi
    else
      cond_echo "openHAB is not running. InfluxDB and grafana openHAB integration is skipped..."
    fi
  fi

  if [ -z "$influxdb_address" ]; then # is empty, install a InfluxDB database
    influxdb_install "$influxdb_admin_password"
    influxdb_address="http://localhost:8086"
  fi  

  if [ -n "$influxdb_admin_username" ]; then # is set, configure database and application users
    echo -n "Setup of inital influxdb database and InfluxDB users... "
    echo -n ""
    influxdb_database_name="openhab_db"
    curl --user "$influxdb_admin_username:$influxdb_admin_password" --insecure $influxdb_address/query --data-urlencode "q=CREATE DATABASE $influxdb_database_name" || FAILED=1
    curl --user "$influxdb_admin_username:$influxdb_admin_password" --insecure $influxdb_address/query --data-urlencode "q=CREATE USER openhab WITH PASSWORD '$influxdb_openhab_password'" || FAILED=1
    curl --user "$influxdb_admin_username:$influxdb_admin_password" --insecure $influxdb_address/query --data-urlencode "q=CREATE USER grafana WITH PASSWORD '$influxdb_grafana_password'" || FAILED=1
    curl --user "$influxdb_admin_username:$influxdb_admin_password" --insecure $influxdb_address/query --data-urlencode "q=GRANT ALL ON openhab_db TO openhab" || FAILED=1
    curl --user "$influxdb_admin_username:$influxdb_admin_password" --insecure $influxdb_address/query --data-urlencode "q=GRANT READ ON openhab_db TO grafana" || FAILED=1
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  fi

  grafana_install "$grafana_admin_password"

  echo -n "Connection Grafana to InfluxDB..."
  curl  --user "admin:$grafana_admin_password" --request POST http://localhost:3000/api/datasources \
        --header "Content-Type: application/json" \
        --data '{"name": "openhab_home", "type": "influxdb", "url": "http://localhost:8086", "password": "'"$influxdb_grafana_password"'", "user": "'"$influxdb_grafana_username"'", "database": "'"$influxdb_database_name"'", "access": "proxy", "basicAuth":true, "basicAuthUser":"'"$influxdb_grafana_username"'", "basicAuthPassword":"'"$influxdb_grafana_password"'", "withCredentials":false}'

  echo -n "Adding openHAB dashboard tile for Grafana... "
  dashboard_add_tile grafana || FAILED=4

  if [ "$openhab_integration" = true ]; then
    echo -n "Adding install InfluxDB with database configuration to openHAB"
    curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" "http://localhost:$OPENHAB_HTTP_PORT/rest/extensions/influxdb/install"
    cond_redirect touch /etc/openhab2/services/influxdb.cfg
    { echo "url=$influxdb_address"; \
    echo "user=$influxdb_openhab_username"; \
    echo "password=$influxdb_openhab_password"; \
    echo "db=$influxdb_database_name"; \
    echo "retentionPolicy=autogen"; } >> /etc/openhab2/services/influxdb.cfg
  fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$text_success" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$text_fail" 10 60
    fi
  fi
}


## Install local InfluxDB database
##
##    influxdb_install(String admin_password)
##

influxdb_install() {
  local influxdb_address
  local influxdb_admin_username
  local dist codename
  
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
  influxdb_address="http://localhost:8086"
  influxdb_admin_username="admin"
  if [ ! -f /etc/influxdb/influxdb.conf ]; then
    cond_redirect apt-get -y install apt-transport-https
    cond_redirect wget -O - https://repos.influxdata.com/influxdb.key | apt-key add - || FAILED=1
    echo "deb https://repos.influxdata.com/$dist $codename stable" > /etc/apt/sources.list.d/influxdb.list || FAILED=1
    cond_redirect apt-get update || FAILED=1
    cond_redirect apt-get -y install influxdb || FAILED=1
    cond_redirect systemctl daemon-reload
    sleep 2
    cond_redirect systemctl enable influxdb.service
    sleep 2
    cond_redirect systemctl restart influxdb.service
    sleep 30
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
    echo -n "Configure InfluxDB admin account... "; echo -n ""
    curl --insecure $influxdb_address/query --data-urlencode "q=CREATE USER admin WITH PASSWORD '$1' WITH ALL PRIVILEGES" || FAILED=1
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
    echo -n "Configure listen on localhost only... "; echo -n ""
    cond_redirect sed -i -e '/# Determines whether HTTP endpoint is enabled./ { n ; s/# enabled = true/enabled = true/ }' /etc/influxdb/influxdb.conf
    cond_redirect sed -i 's/# bind-address = ":8086"/bind-address = "localhost:8086"/g' /etc/influxdb/influxdb.conf
    cond_redirect sed -i 's/# auth-enabled = false/auth-enabled = true/g' /etc/influxdb/influxdb.conf
    # disable stats collection to save memory, issue #506
    cond_redirect sed -i 's/# store-enabled = true/store-enabled = false/g' /etc/influxdb/influxdb.conf
    cond_redirect systemctl restart influxdb.service
    sleep 30
    if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  else
    echo "SKIPPED"
    cond_echo "InfluxDB already installed. Using http://localhost:8086"
  fi
  cond_echo ""
}

## Install local Grafana installation
##
##    influxdb_install(String admin_password)
##

grafana_install(){
  echo -n "Installing Grafana..."
  cond_redirect wget -O - https://packages.grafana.com/gpg.key | apt-key add - || FAILED=2
  echo "deb https://packages.grafana.com/oss/deb stable main" > /etc/apt/sources.list.d/grafana.list || FAILED=2
  cond_redirect apt-get update || FAILED=2
  cond_redirect apt-get -y install grafana || FAILED=2

  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable grafana-server.service
  cond_redirect systemctl start grafana-server.service
  sleep 20
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; return 2; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Updating Grafana admin password..."
  curl --user admin:admin --header "Content-Type: application/json" --request PUT --data "{\"password\":\"$1\"}" http://localhost:3000/api/admin/users/1/password || FAILED=2
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; return 2; else echo -n "OK "; fi

  echo -n "Updating Grafana configuration..."
  cond_redirect sed -i -e '/^# disable user signup \/ registration/ { n ; s/^;allow_sign_up = true/allow_sign_up = false/ }' /etc/grafana/grafana.ini
  cond_redirect sed -i -e '/^# enable anonymous access/ { n ; s/^;enabled = false/enabled = true/ }' /etc/grafana/grafana.ini
  cond_redirect systemctl restart grafana-server.service
  sleep 20
}
