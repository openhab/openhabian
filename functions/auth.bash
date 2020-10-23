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
  local accounts
  local chosenAccounts
  local nginxUsername
  local pass
  local pass1
  local pass2
  local whipParams

  accounts=("Linux system" "openHAB Console" "Samba" "Amanda backup")
  # BUILD LIST WITH INSTALLED SERVICES
  whipParams=("Linux system"    "Account: \"${username:-openhabian}\" used for login to this computer" OFF)
  whipParams+=("openHAB Console" "Remote console account: \"openhab\" used for managing openHAB" OFF)
  whipParams+=("Samba"           "Fileshare account: \"${username:-openhabian}\" used for remote openHAB configuration" OFF)
  whipParams+=("Amanda backup"   "User account: \"backup\" used for managing backup configuration" OFF)
  if [[ -f /etc/nginx/.htpasswd ]]; then
    nginxUsername="$(cut -d: -f1 /etc/nginx/.htpasswd | head -1)"
    accounts+=("Ngnix proxy")
    whipParams+=("Ngnix proxy"     "Nginx user: \"${nginxUsername}\" used for logging into openHAB web services" OFF)
  fi
  if [[ -f /etc/influxdb/influxdb.conf ]]; then
    accounts+=("InfluxDB")
    whipParams+=("InfluxDB"        "InfluxDB user: \"admin\" used for database configuration" OFF)
  fi
  if [[ -f /etc/grafana/grafana.ini ]]; then
    accounts+=("Grafana")
    whipParams+=("Grafana"         "Grafana user: \"admin\" used for managing graphs and the server" OFF)
  fi

  if [[ -n $INTERACTIVE ]]; then
    if ! chosenAccounts="$(whiptail --title "Change password function" --checklist "\\nChoose which services to change passwords for:" 15 100 7 --ok-button "Continue" --cancel-button "Cancel" "${whipParams[@]}" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi

    # COLLECT NEW PASSWORD
    while [[ -z $pass ]]; do
      if ! pass1="$(whiptail --title "Authentication Setup" --passwordbox "\\nEnter a new password:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if ! pass2="$(whiptail --title "Authentication Setup" --passwordbox "\\nPlease confirm the password:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if [[ $pass1 == "$pass2" ]] && [[ ${#pass1} -ge 8 ]] && [[ ${#pass2} -ge 8 ]]; then
        pass="$pass1"
      else
        whiptail --title "Authentication Setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
  else
    # NON INTERACTIVE FUNCTION INVOKED
    if [[ ${#1} -le 7 ]]; then echo "FAILED (invalid password, password must be greater than 8 characters)"; return 1; fi
    pass="$1"
    chosenAccounts="${accounts[*]}"
  fi

  # CHANGE CHOOSEN PASSWORDS
  if [[ $chosenAccounts == *"Linux system"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Linux account \"${username:-openhabian}\"... "
    if echo "${username:-openhabian}:${pass}" | cond_redirect chpasswd; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if [[ $chosenAccounts == *"Samba"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Samba (fileshare) account \"${username:-openhabian}\"... "
    if (echo "$pass"; echo "$pass") | smbpasswd -s -a "${username:-openhabian}" &> /dev/null; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if [[ $chosenAccounts == *"openHAB Console"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for openHAB console account \"openhab\"... "
    if sed -i 's|openhab = .*,|openhab = '"${pass}"',|g' /var/lib/openhab/etc/users.properties; then echo "OK"; else echo "FAILED"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
    cond_redirect systemctl restart openhab.service
  fi
  if [[ $chosenAccounts == *"Amanda backup"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Linux account \"backup\"... "
    if echo "backup:${pass}" | cond_redirect chpasswd; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if [[ $chosenAccounts == *"Ngnix proxy"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Nginx web authentication account \"${nginxUsername}\"... "
    if echo "$pass" | htpasswd -i /etc/nginx/.htpasswd "${nginxUsername}"; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if [[ $chosenAccounts == *"InfluxDB"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for InfluxDB administration account \"admin\"... "
    sed -i "s/.*auth-enabled = .*/  auth-enabled = false/g" /etc/influxdb/influxdb.conf
    if ! cond_redirect systemctl restart influxdb.service; then echo "FAILED (InfluxDB restart)"; return 1; fi
    sleep 1
    influx -execute "SET PASSWORD FOR admin = '$pass'"
    sed -i "s/.*auth-enabled = .*/  auth-enabled = true/g" /etc/influxdb/influxdb.conf
    if cond_redirect systemctl restart influxdb.service; then echo "OK"; else echo "FAILED (InfluxDB restart)"; return 1; fi
  fi
  if [[ $chosenAccounts == *"Grafana"* ]]; then
    echo -n "$(timestamp) [openHABian] Changing password for Grafana admininistration account \"admin\"... "
    if grafana-cli admin reset-admin-password --homepath "/usr/share/grafana" --config "/etc/grafana/grafana.ini" "$pass"; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "Password(s) successfully changed for: $chosenAccounts" 8 80
  fi
}


## Function to download SSH key pair for remote access
##
## The function can be invoked during UNATTENDED installation only.
## It downloads a ssh key from a user specified location and allows the key owner to login as the admin user
##
##    add_admin_ssh_key()
##
add_admin_ssh_key() {
  local userName=${adminusername:-openhabian}
  local sshDir="~${userName}/.ssh/"
  local keyFile="${sshDir}/authorized_keys"
  local karafKeys="/var/lib/openhab/etc/keys.properties"

  # shellcheck disable=SC2154
  if [[ -z "${adminkeyurl}" ]]; then return 0; fi
  if ! [[ -d "${sshDir}" ]]; then echo "FAILED (.ssh directory missing)"; return 1; fi
  if ! cond_redirect wget --no-check-certificate -O "${keyFile}.NEW" "${adminkeyurl}"; then rm -f "${keyFile}.NEW"; echo "FAILED (wget $adminkeyurl)"; return 1; fi
  if [[ -s ${keyFile}.NEW ]]; then
    if [[ -f ${keyFile} ]]; then
      mv "${keyFile}" "${keyFile}.ORIG"
    fi
    mv "${keyFile}.NEW" "${keyFile}"
    chown "${userName}:${userName}" "${keyFile}" "${keyFile}.NEW"
    chmod 600 "${keyFile}" "${keyFile}.NEW"
  fi
  (echo -n "openhab="; awk '{ printf $2 }' "${keyFile}"; echo ",_g_:admingroup") >> $karafKeys
}
