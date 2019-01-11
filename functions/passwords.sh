#!/usr/bin/env bash

## Function for changing various password related to openHAB or this system instance.
## The function can be invoked either INTERACTIVE with userinterface UNATTENDED.
##
## When called UNATTENDED it will change all passwords. Notice that implies that the system is installed.
## Make sure the password is at least 10 characters long to ensure compability with all services.
##
##    change_password(String password)
##

change_password() {
  introtext="Choose which services to change passwords for:"
  failtext="Something went wrong in the password change process. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."

  matched=false
  canceled=false
  allAccounts=("Linux system" "openHAB Console" "Samba" "Amanda backup")
  FAILED=0

  # BUILD LIST WITH INSTALLED SERVICES
  whipParams=( --title "Change password function" --ok-button "Execute" --cancel-button "Back" --checklist "$introtext" 20 90 10)
  whipParams+=("Linux system" "Account; \"$username\" used for login to this computer" off )
  whipParams+=("openHAB Console" "Remote console account; \"openhab\" for manage openHAB" off )
  whipParams+=("Samba" "Fileshare account; \"$username\" for configuration files" off )
  whipParams+=("Amanda backup" "User account; \"backup\" which could handle openHAB backups " off )

  if [ -f /etc/nginx/.htpasswd ]; then
    nginxuser="$(cut -d: -f1 /etc/nginx/.htpasswd)"
    whipParams+=("Ngnix HTTP/HTTPS" "User; \"$nginxuser\" used for logon to openHAB web services " off )
    allAccounts+=( "Ngnix HTTP/HTTPS" )
  fi

  if [ -f /etc/influxdb/influxdb.conf ]; then
    whipParams+=("InfluxDB" "User; \"admin\" used for database configuration " off )
    allAccounts+=( "InfluxDB" )
  fi

  if [ -f /etc/grafana/grafana.ini ]; then
    whipParams+=("Grafana" "User; \"admin\" used for manage graphs and the server " off )
    allAccounts+=( "Grafana" )
  fi

  if [ -n "$INTERACTIVE" ]; then
    accounts="$(whiptail "${whipParams[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?

    # COLLECT NEW PASSWORD
    if [ $exitstatus = 0 ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        passwordChange="$(whiptail --title "Authentication Setup" --passwordbox "Enter a new password: " 15 80 3>&1 1>&2 2>&3)"
        if [[ "$?" == 1 ]]; then return 0; fi
        if [ ! ${#passwordChange} -ge 10 ]; then
          whiptail --title "Authentication Setup" --msgbox "Password must at least be 10 characters long... Please try again!" 15 80 3>&1 1>&2 2>&3
        else
          secondpasswordChange="$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the new password:" 15 80 3>&1 1>&2 2>&3)"
          if [[ "$?" == 1 ]]; then return 0; fi
          if [ "$passwordChange" = "$secondpasswordChange" ] && [ ! -z "$passwordChange" ]; then
            matched=true
          else
            whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3
          fi
        fi
      done
    else
      return 0
    fi
  else
    # NON INTERACTIVE FUNCTION INVOKED
    passwordChange=$1
    accounts=allAccounts
  fi

  # CHANGE CHOOSEN PASSWORDS
  if [[ $accounts == *"Linux system"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for linux account \"$username\"... "
    echo "$username:$passwordChange" | chpasswd
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"Samba"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for samba (fileshare) account \"$username\"... "
    (echo "$passwordChange"; echo "$passwordChange") | /usr/bin/smbpasswd -s -a "$username"
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"openHAB Console"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for openHAB console account \"openhab\"... "
    sed -i "s/openhab = .*,/openhab = $passwordChange,/g" /var/lib/openhab2/etc/users.properties
    cond_redirect systemctl restart openhab2.service
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"Amanda backup"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for linux account \"backup\"... "
    echo "backup:$passwordChange" | chpasswd
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"Ngnix HTTP/HTTPS"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for nginx web authentication account \"$nginxuser\"... "
    echo "$passwordChange" | htpasswd -i /etc/nginx/.htpasswd $nginxuser
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"InfluxDB"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for InfluxDB administration account \"admin\"... "
    sed -i "s/.*auth-enabled = .*/  auth-enabled = false/g" /etc/influxdb/influxdb.conf
    cond_redirect systemctl restart influxdb.service
    sleep 1
    influx -execute "SET PASSWORD FOR admin = '$passwordChange'"
    sed -i "s/.*auth-enabled = .*/  auth-enabled = true/g" /etc/influxdb/influxdb.conf
    cond_redirect systemctl restart influxdb.service
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi
  if [[ $accounts == *"Grafana"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Grafana admininistration account \"admin\"... "
    grafana-cli admin reset-admin-password --homepath "/usr/share/grafana" --config "/etc/grafana/grafana.ini" $passwordChange
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi


  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "Password successfully set for: $accounts" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}
