#!/usr/bin/env bash

change_password() {
  introtext="Choose which services to change the password for:"
  failtext="Something went wrong in the password change process. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."

  matched=false
  canceled=false
  FAILED=0

  if [ -n "$INTERACTIVE" ]; then
    accounts=$(whiptail --title "Choose accounts" --yes-button "Continue" --no-button "Back" --checklist "$introtext" 20 90 10 \
          "Linux account" "The account to login to this computer" off \
          "openHAB Console" "The remote console which is used to manage openHAB" off \
          "Samba" "The fileshare for configuration files" off \
          3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        passwordChange=$(whiptail --title "Authentication Setup" --passwordbox "Enter a new password:" 15 80 3>&1 1>&2 2>&3)
        if [[ "$?" == 1 ]]; then return 0; fi
        secondpasswordChange=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the new password:" 15 80 3>&1 1>&2 2>&3)
        if [[ "$?" == 1 ]]; then return 0; fi
        if [ "$passwordChange" = "$secondpasswordChange" ] && [ ! -z "$passwordChange" ]; then
          matched=true
        else
          password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
        fi
      done
    else
        return 0
    fi
  else
    passwordChange=$1
    accounts=("Linux account" "openHAB Console" "Samba")
  fi

  for i in "${accounts[@]}"
  do
    if [[ $i == *"Linux account"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for linux account \"$username\"... "
      echo "$username:$passwordChange" | chpasswd
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [[ $i == *"Samba"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for samba (fileshare) account \"$username\"... "
      (echo "$passwordChange"; echo "$passwordChange") | /usr/bin/smbpasswd -s -a $username
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [[ $i == *"openHAB Console"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for openHAB console account \"openhab\"... "
      sed -i "s/openhab = .*,/openhab = $passwordChange,/g" /var/lib/openhab2/etc/users.properties
      cond_redirect systemctl restart openhab2.service
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
  done

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "Password successfully set for: $accounts" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}
