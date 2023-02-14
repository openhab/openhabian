#!/usr/bin/env bash

## Create a backup of the current openHAB configuration using openHAB's builtin tool
##
##    backup_openhab_config()
##
backup_openhab_config() {
  if ! openhab_is_installed; then
    echo "$(timestamp) [openHABian] openHAB is not installed! Canceling openHAB config backup creation!"
    return 0
  fi

  local filePath
  local introText="This will create an export (a backup) of your openHAB configuration using openHAB's builtin openhab-cli tool.\\n\\nWould you like to proceed?"
  local successText

  if [[ -n "$INTERACTIVE" ]] && [[ $# == 0 ]]; then
    if (whiptail --title "openHAB config export" --yes-button "Continue" --no-button "Skip" --yesno "$introText" 10 80); then echo "OK"; else echo "SKIPPED"; return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Creating openHAB config backup... "
  if filePath="$(openhab-cli backup | awk -F ' ' '/Success/ { print $NF }')"; then echo "OK"; else echo "FAILED"; return 1; fi
  # shellcheck disable=SC2012
  ln -sf "${filePath}" "$(dirname "${filePath}")"/latest.zip
  successText="A backup of your openHAB configuration has successfully been made.\\n\\nIt is stored in ${filePath}."

  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Operation successful!" --msgbox "$successText" 10 90
  else
    echo "$(timestamp) [openHABian] ${successText}"
  fi
}

## Restore a backup of the openHAB configuration using openHAB's builtin tool
##
##    backup_openhab_config(String filePath)
##
restore_openhab_config() {
  if ! openhab_is_installed; then
    echo "$(timestamp) [openHABian] openHAB is not installed! Canceling openHAB backup restoration!"
    return 0
  fi

  local backupList
  local backupPath="${OPENHAB_BACKUPS:-/var/lib/openhab/backups}"
  local filePath=${1:-${initialconfig:-/boot/initial.zip}}
  local fileSelect
  local storageText="Only text input files *.things *.items *.rules will be restored from the backup zipfile.\\nConfig elements that were defined using the GUI will not be restored."

  echo -n "$(timestamp) [openHABian] Choosing openHAB backup zipfile to restore from... "
  if [[ -n "$INTERACTIVE" ]]; then
    if [[ $# -gt 0 ]]; then
      if ! [[ -s "$1" ]]; then
        echo "FAILED (restore config $1)"
        whiptail --title "Restore failed" --msgbox "Restoration of selected openHAB configuration failed." 7 80
        return 1
      fi
      filePath="$1"
      echo "OK"
    else
      # shellcheck disable=SC2012
      readarray -t backupList < <(ls -alh "${backupPath}"/*zip 2> /dev/null | head -20 | awk -F ' ' '{ print $9 " " $5 }' | xargs -d '\n' -L1 basename | awk -F ' ' '{ print $1 "\n" $1 " " $2 }')
      if [[ -z "${backupList[*]}" ]]; then
        whiptail --title "Could not find backup!" --msgbox "We could not find any configuration backup file in the storage directory $backupPath" 8 80
        echo "CANCELED"
        return 0
      fi
      if fileSelect="$(whiptail --title "Choose openHAB configuration to restore" --cancel-button "Cancel" --ok-button "Continue" --notags --menu "\\nSelect your backup from most current 20 files below:" 22 80 13 "${backupList[@]}" 3>&1 1>&2 2>&3)"; then echo "OK"; else echo "CANCELED"; return 0; fi
      filePath="${backupPath}/${fileSelect}"
    fi
  fi

  echo -n "$(timestamp) [openHABian] Restoring openHAB backup... "
  if [[ "$2" == "textonly" ]]; then
    if [[ -n "$INTERACTIVE" ]]; then
      if ! (whiptail --title "Restore text config only" --yes-button "Continue" --no-button "Cancel" --yesno "$storageText" 10 80); then echo "CANCELED"; return 0; fi
    fi
    if ! (yes | cond_redirect "${OPENHAB_RUNTIME:-/usr/share/openhab/runtime}"/bin/restore --textonly "$filePath"); then echo "FAILED (restore)"; return 1; fi
  else
    if ! cond_redirect systemctl stop openhab.service; then echo "FAILED (stop openHAB)"; return 1; fi
    if ! (yes | cond_redirect openhab-cli restore "$filePath"); then echo "FAILED (restore)"; return 1; fi
    if ! (yes | cond_redirect openhab-cli clean-cache); then echo "FAILED (cache cleaning)"; fi
    if cond_redirect systemctl restart openhab.service; then echo "OK"; else echo "FAILED (restart openHAB)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Operation successful!" --msgbox "Restoration of selected openHAB configuration was successful!" 7 80
  fi
}

## Install Amanda and configure backup user
##
##    amanda_install(String backupPass)
##
amanda_install() {
  local backupUser="backup"
  local backupPass="${1:-backup}"

  echo -n "$(timestamp) [openHABian] Configuring Amanda backup system prerequisites... "

  if ! (echo "${backupUser}:${backupPass}" | cond_redirect chpasswd); then echo "FAILED (change password)"; return 1; fi

  if grep -qs "^[[:space:]]*backup:" /etc/group; then
    if ! cond_redirect usermod --append --groups "backup" "${username:-openhabian}"; then echo "FAILED (${username:-openhabian} backup)"; return 1; fi
    if ! cond_redirect usermod --append --groups "backup" "$backupUser"; then echo "FAILED (${backupUser} backup)"; return 1; fi
  else
    if ! groupadd backup; then echo "FAILED (add group)"; return 1; fi
    if ! cond_redirect usermod --append --groups "backup" "${username:-openhabian}"; then echo "FAILED (${username:-openhabian} backup)"; return 1; fi
    if ! cond_redirect usermod --append --groups "backup" "$backupUser"; then echo "FAILED (${backupUser} backup)"; return 1; fi
  fi

  if cond_redirect chsh --shell /bin/bash "$backupUser"; then echo "OK"; else echo "FAILED (chsh ${backupUser})"; return 1; fi

  if ! amanda_is_installed; then
    echo -n "$(timestamp) [openHABian] Installing Amanda backup system... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" amanda-common amanda-server amanda-client; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if ! dpkg -s 'exim4' &> /dev/null; then
    if ! exim_setup; then return 1; fi
  fi

}


## Create a Amanda configuration using given inputs.
##
##    create_amanda_config(String config, String backupUser, String adminMail,
##                         String tapes, String tapeSize, String storageLoc,
##                         String awsSite, String awsBucket, String awsAccessKey,
##                         String awsSecretKey)
##
create_amanda_config() {
  local adminMail
  local amandaHosts="/var/backups/.amandahosts"
  local amandaSecurityConf="/etc/amanda-security.conf"
  local amandaIncludesDir="${BASEDIR:-/opt/openhabian}/includes/amanda"
  local awsAccessKey
  local awsBucket
  local awsSecretKey
  local awsSite
  local backupUser
  local config
  local configDir
  local databaseDir
  local dumpType="comp-user-tar"
  local indexDir
  local logDir
  local serviceTargetDir="/etc/systemd/system"
  local storageLoc
  local storageText
  local tapeChanger
  local tapes
  local tapeSize
  local tapeType

  config="$1"
  backupUser="$2"
  adminMail="$3"
  tapes="$4"
  tapeSize="$5"
  storageLoc="$6"
  awsSite="$7"
  awsBucket="$8"
  awsAccessKey="$9"
  awsSecretKey="${10}"
  configDir="/etc/amanda/${config}"
  databaseDir="/var/lib/amanda/${config}/curinfo"
  indexDir="/var/lib/amanda/${config}/index"
  logDir="/var/log/amanda/${config}"
  storageText="We need to prepare (\"label\") your storage media.\\n\\nFor permanent storage such as USB or NAS mounted storage, as well as for cloud based storage, we will create ${tapes} virtual containers."

  echo -n "$(timestamp) [openHABian] Creating Amanda filesystem... "
  if ! cond_redirect mkdir -p "$configDir" "$databaseDir" "$logDir" "$indexDir"; then echo "FAILED (create directories)"; return 1; fi
  if ! cond_redirect touch "${configDir}/tapelist"; then echo "FAILED (touch tapelist)"; return 1; fi
  ip=$(dig +short "$HOSTNAME")
  revip=$(host "${ip}" | cut -d' ' -f1)
  if [[ -n "$revip" ]]; then (echo -e "${ip} ${backupUser} amdump\\n${revip} ${backupUser} amdump" > "$amandaHosts"); fi
  # shellcheck disable=SC2154
  if ! (echo -e "${hostname} ${backupUser} amdump\\n${hostname} root amindexd amidxtaped\\nlocalhost ${backupUser}\\nlocalhost root amindexd amidxtaped" >> "$amandaHosts"); then echo "FAILED (Amanda hosts)"; return 1; fi
  if is_aarch64; then GNUTAR=/bin/tar; else GNUTAR=/usr/bin/tar; fi
  if ! (echo -e "amgtar:gnutar_path=$GNUTAR\\n" >> "$amandaSecurityConf"); then echo "FAILED (amanda-security.conf)"; return 1; fi
  if ! cond_redirect chown --recursive "${backupUser}:backup" "$amandaHosts" "$configDir" "$databaseDir" "$indexDir" /var/log/amanda; then echo "FAILED (chown)"; return 1; fi
  if [[ $config == "openhab-dir" ]]; then
    if ! cond_redirect chown --recursive "${backupUser}:backup" "$storageLoc"; then echo "FAILED (chown)"; return 1; fi
    if ! cond_redirect chmod --recursive g+rxw "$storageLoc"; then echo "FAILED (chmod)"; return 1; fi
    if ! cond_redirect sudo -u "${backupUser}" mkdir "${storageLoc}/slots"; then echo "FAILED (storage write access for user backup - bad NAS uid mapping ?)"; return 1; fi
    if ! cond_redirect chown --recursive "${backupUser}:backup" "${storageLoc}/slots"; then echo "FAILED (chown slots)"; return 1; fi
    if ! cond_redirect ln -sf "${storageLoc}/slots" "${storageLoc}/slots/drive0"; then echo "FAILED (link drive0)"; return 1; fi
    if ! cond_redirect ln -sf "${storageLoc}/slots" "${storageLoc}/slots/drive1"; then echo "FAILED (link drive1)"; return 1; fi    # tape-parallel-write 2 so we need 2 virtual drives
    tapeChanger="\"chg-disk:${storageLoc}/slots\"    # The tape-changer glue script"
    tapeType="DIRECTORY"
  elif [[ $config == "openhab-AWS" ]]; then
    tapeChanger="\"chg-multi:s3:${awsBucket}/openhab-AWS/slot-{$(seq -s, 1 "$tapes")}\"    # Number of virtual containers in your tapecycle"
    tapeType="AWS"
  else
    echo "FAILED (invalid configuration: ${config})"
    return 1
  fi
  if ! sed -e 's|%CONFIGDIR|'"${configDir}"'|g; s|%CONFIG|'"${config}"'|g; s|%ADMINMAIL|'"${adminMail}"'|g; s|%TAPESIZE|'"${tapeSize}"'|g; s|%TAPETYPE|'"${tapeType}"'|g; s|%TAPECHANGER|'"${tapeChanger}"'|g; s|%TAPES|'"${tapes}"'|g; s|%BACKUPUSER|'"${backupUser}"'|g' "${amandaIncludesDir}/amanda.conf-template" > "${configDir}/amanda.conf"; then echo "FAILED (amanda config)"; return 1; fi
  if [[ -z $adminMail ]]; then
    if ! cond_redirect sed -i -e '/mailto/d' "${configDir}/amanda.conf"; then echo "FAILED (remove mailto)"; return 1; fi
  fi
  if [[ $config = "openhab-AWS" ]]; then
    {
      echo "device_property \"S3_BUCKET_LOCATION\" \"${awsSite}\"    # Your S3 bucket location (site)"; \
      echo "device_property \"STORAGE_API\" \"AWS4\""; \
      echo "device_property \"VERBOSE\" \"YES\""; \
      echo "device_property \"S3_ACCESS_KEY\" \"${awsAccessKey}\"    # Your S3 Access Key"; \
      echo "device_property \"S3_SECRET_KEY\" \"${awsSecretKey}\"    # Your S3 Secret Key"; \
      echo "device_property \"S3_SSL\" \"YES\"    # cURL needs to have S3 Certification Authority in its CA list. If connection fails, try setting this to NO"
    } >> "${configDir}/amanda.conf"
  fi
  if cond_redirect chmod 644 "${configDir}/amanda.conf"; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Creating Amanda configuration... "
  if [[ $config == "openhab-dir" ]]; then
    if ! cond_redirect rm -f "${configDir}/disklist"; then echo "FAILED (clean disklist)"; return 1; fi
    # Don't backup full SD by default as this can cause issues with large cards
    if [[ -n $INTERACTIVE ]]; then
      if (whiptail --title "Backup raw SD card" --defaultno --yes-button "Yes" --no-button "No" --yesno "Do you want to create raw disk backups of your SD card?\\n\\nThis is only recommended if your SD card is 16GB or less, otherwise this can take too long.\\n\\nYou can change this at any time by editing:\\n'${configDir}/disklist'" 13 80); then
        echo "${hostname}  /dev/mmcblk0                  comp-amraw" >> "${configDir}/disklist"
      fi
    fi
  fi
  {
    echo "${hostname}  /boot                         ${dumpType}"; \
    echo "${hostname}  /etc                          ${dumpType}"
  } >> "${configDir}/disklist"
  if [[ -d /var/lib/openhab ]]; then
    echo "${hostname}  /var/lib/openhab              ${dumpType}" >> "${configDir}/disklist"
  fi
  if [[ -d /var/lib/homegear ]]; then
    echo "${hostname}  /var/lib/homegear             ${dumpType}" >> "${configDir}/disklist"
  fi
  if [[ -d /opt/find3/server/main ]]; then
    echo "${hostname}  /opt/find3/server/main        ${dumpType}" >> "${configDir}/disklist"
  fi
  {
    echo "index_server \"localhost\""; \
    echo "tapedev \"changer\""; \
    echo "auth \"local\""
  } > "${configDir}/amanda-client.conf"
  if cond_redirect chmod 644 "${configDir}/disklist" "${configDir}/amanda-client.conf"; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Preparing storage location... "
  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Storage container creation" --yes-button "Continue" --no-button "Cancel" --yesno "$storageText" 10 80); then echo "CANCELED"; return 0; fi
  fi
  until [[ $tapes -le 0 ]]; do
    if [[ $config == "openhab-dir" ]]; then
      if ! cond_redirect mkdir -p "${storageLoc}/slots/slot${tapes}"; then echo "FAILED (slot${tapes})"; return 1; fi
      if ! cond_redirect chown --recursive "${backupUser}:backup" "${storageLoc}/slots/slot${tapes}"; then echo "FAILED (chown slot${tapes})"; return 1; fi
    elif [[ $config == "openhab-AWS" ]]; then
      if ! cond_redirect su - "$backupUser" -c "amlabel ${config} ${config}-$(printf "%02d" "${tapes}") slot ${tapes}"; then echo "FAILED (amlabel)"; return 1; fi
    else
      echo "FAILED (invalid configuration: ${config})"
      return 1
    fi
    ((tapes-=1))
  done
  echo "OK"

  if ! sed -e "s|%CONFIG|${config}|g" "${amandaIncludesDir}/amdump.service-template" > "${serviceTargetDir}/amdump-${config}.service"; then echo "FAILED (create Amanda ${config} backup service)"; return 1; fi
  if ! sed -e "s|%CONFIG|${config}|g" "${amandaIncludesDir}/amdump.timer-template" > "${serviceTargetDir}/amdump-${config}.timer"; then echo "FAILED (create Amanda ${config} timer)"; return 1; fi
  if ! cond_redirect chmod 644 "${serviceTargetDir}/amdump-${config}".*; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now "amdump-${config}.timer"; then echo "FAILED (amdump-${config} timer enable)"; return 1; fi
  if [[ $tapeType == "DIRECTORY" ]]; then
    if ! cond_redirect mkdir -p "${storageLoc}/amanda-backups"; then echo "FAILED (create amanda-backups)"; return 1; fi
    if ! cond_redirect chown --recursive "${backupUser}:backup" "${storageLoc}/amanda-backups"; then echo "FAILED (chown amanda-backups)"; return 1; fi
    if ! sed -e "s|%STORAGE|${storageLoc}|g" "${amandaIncludesDir}/amandaBackupDB.service-template" > "${serviceTargetDir}/amandaBackupDB.service"; then echo "FAILED (create Amanda DB backup service)"; return 1; fi
    if ! cond_redirect chmod 644 "${serviceTargetDir}/amandaBackupDB.service"; then echo "FAILED (permissions)"; return 1; fi
    if ! install -m 644 "${amandaIncludesDir}/amandaBackupDB.timer" "${serviceTargetDir}"; then echo "FAILED (create Amanda DB backup timer)"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
    if ! cond_redirect systemctl enable --now "amandaBackupDB.timer"; then echo "FAILED (Amanda DB backup timer enable)"; return 1; fi
  fi
}


## Setup a Amanda based backup using local storage, AWS, or a set of SD cards.
##
##    amanda_setup()
##
amanda_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] Amanda backup setup must be run in interactive mode! Cancelling Amanda backup setup."
    return 0
  fi

  local config
  local backupUser="backup"
  local tapes
  local tapeSize
  local storageLoc
  local adminMail="${adminmail:-root@${hostname}}"
  local awsSite
  local awsBucket
  local awsAccessKey
  local awsSecretKey
  local backupPass
  local backupPass1
  local backupPass2
  local queryText="You are about to install the Amanda backup solution.\\nDocumentation is available at '/opt/openhabian/docs/openhabian-amanda.md' or https://github.com/openhab/openhabian/blob/main/docs/openhabian-amanda.md\\nHave you read this document? If not, please do so now, as you will need to follow the instructions provided there in order to successfully complete installation of Amanda.\\n\\nProceeding will setup a backup mechanism to allow for saving your openHAB setup and modifications to either USB attached or Amazon cloud storage.\\nYou can add your own files/directories to be backed up, and you can store and create clones of your openHABian SD card to have an pre-prepared replacement in case of card failures.\\n\\nWARNING: running this setup will overwrite any previous Amanda backup configurations.\\n\\nWould you like to begin setup?"
  local successText="Setup was successful.\\n\\nAmanda backup tool is now taking backups around 01:00. For further readings, start at http://wiki.zmanda.com/index.php/User_documentation."

  echo -n "$(timestamp) [openHABian] Beginning setup of the Amanda backup system... "
  if (whiptail --title "Amanda backup installation" --yes-button "Continue" --no-button "Cancel" --defaultno --yesno "$queryText" 24 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  while [[ -z $backupPass ]]; do
    if ! backupPass1="$(whiptail --title "Authentication setup" --passwordbox "\\nEnter a password for ${backupUser}:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! backupPass2="$(whiptail --title "Authentication setup" --passwordbox "\\nPlease confirm the password:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if [[ $backupPass1 == "$backupPass2" ]] && [[ ${#backupPass1} -ge 8 ]] && [[ ${#backupPass2} -ge 8 ]]; then
      backupPass="$backupPass1"
    else
      whiptail --title "Authentication setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
    fi
  done

  if ! amanda_install "$backupPass"; then return 1; fi

  if ! adminMail="$(whiptail --title "Reporting address" --inputbox "\\nEnter a mail address to have Amanda send reports to:" 9 80 "${adminMail}" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  if (whiptail --title "Backup using locally attached storage" --yes-button "Yes" --no-button "No" --yesno "Would you like to setup a backup mechanism based on locally attached or NAS mounted storage?" 8 80); then
    config="openhab-dir"
    if ! storageLoc="$(whiptail --title "Storage directory" --inputbox "\\nWhat is the directory backups should be stored in?\\n\\nYou can specify any locally accessible directory, no matter if it's located on the internal SD card, an external USB-attached device such as a USB stick, HDD, or a NFS/CIFS share." 13 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! cond_redirect sudo -u "${backupUser}" touch "${storageLoc}/TEST"; then 
        echo "FAILED (storage write access for user backup)"
        whiptail --title "Amanda storage setup failed" --msgbox "Amanda storage setup failed.\\n\\nThe designated storage area ${storageLoc} you entered is not writeable for the Linux user ${backupUser}.\\nPlease ensure it is. If it is located on a NAS or NFS server, search the Amanda docs for the term no_root_squash.\\nopenHABian will now make the directory world-writable as a workaround but do not forget to fix it properly, please." 15 80 3>&1 1>&2 2>&3
        chmod 1777 "${storageLoc}"
    fi
    rm -f "${storageLoc}/TEST"
    tapes="15"
    if ! tapeSize="$(whiptail --title "Storage capacity" --inputbox "\\nHow much storage do you want to dedicate to your backup in megabytes?\\n\\nRecommendation: 2-3 times the amount of data to be backed up." 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    ((tapeSize/=tapes))
    if ! create_amanda_config "$config" "$backupUser" "${adminMail}" "$tapes" "$tapeSize" "$storageLoc"; then return 1; fi
    whiptail --title "Amanda config setup successful" --msgbox "$successText" 10 80
  fi
  if (whiptail --title "Backup using Amazon AWS" --yes-button "Yes" --no-button "No"  --defaultno --yesno "Would you like to setup a backup mechanism based on Amazon Web Services?\\n\\nYou can get 5 GB of S3 cloud storage for free on https://aws.amazon.com/. For hints see http://markelov.org/wiki/index.php?title=Backup_with_Amanda:_tape,_NAS,_Amazon_S3#Amazon_S3\\nPlease setup your S3 bucket on Amazon Web Services NOW if you have not done so. Remember the name has to be unique in AWS namespace." 14 90); then
    config="openhab-AWS"
    if ! awsSite="$(whiptail --title "AWS bucket site location" --inputbox "\\nEnter the AWS site location you want to use (e.g. \"eu-central-1\"):" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! awsBucket="$(whiptail --title "AWS bucket name" --inputbox "\\nEnter the bucket name you created on AWS (only the part after the last ':' of the ARN):" 10 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! awsAccessKey="$(whiptail --title "AWS access key" --inputbox "\\nEnter the AWS access key you obtained at S3 setup time:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! awsSecretKey="$(whiptail --title "AWS secret key" --inputbox "\\nEnter the AWS secret key you obtained at S3 setup time:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    tapes="15"
    if ! tapeSize="$(whiptail --title "Storage capacity" --inputbox "\\nHow much storage do you want to dedicate to your backup in megabytes?\\n\\nRecommendation: 2-3 times the amount of data to be backed up." 11 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    ((tapeSize/=tapes))
    if ! create_amanda_config "$config" "$backupUser" "${adminmail:-root@${hostname}}" "$tapes" "$tapeSize" "AWS" "$awsSite" "$awsBucket" "$awsAccessKey" "$awsSecretKey"; then return 1; fi
    whiptail --title "Amanda config setup successful" --msgbox "$successText" 10 80
  fi
}


## "raw" copy partition using dd or mount and use rsync to sync "diff"
## Valid "method" arguments: "raw", "diff"
## Periodically activated by systemd timer units (raw copy on 1st of month, rsync else)
##
##    mirror_SD(String method, String destinationDevice)
##
mirror_SD() {
  local src="/dev/mmcblk0"
  local dest="${2:-${backupdrive}}"
  local start
  local destPartsLargeEnough="true"
  local storageDir="${storagedir:-/storage}"
  local syncMount="${storageDir}/syncmount"
  local dirty="no"
  local repartitionText
  local dumpInfoText="For your information as the operator of this openHABian system:\\nA timed background job to run semiannually has just created a full raw device copy of your RPI's internal SD card.\\nOnly partitions to contain openHABian (/boot and / partitions 1 & 2) were copied."
  local partUUID
  
  if [[ $# -eq 1 ]] && [[ -n "$INTERACTIVE" ]]; then
    select_blkdev "^sd" "Setup SD mirroring" "Select USB device to copy the internal SD card data to"
    # shellcheck disable=SC2154
    dest="/dev/${retval}"
  fi
  if [[ $src == "$dest" ]]; then
    echo "FAILED (source = destination)"
    return 1
  fi
  if ! [[ $(blockdev --getsize64 "$dest") ]]; then
    echo "FAILED (bad destination)"
    return 1
  fi
  # shellcheck disable=SC2016
  if mount | grep -Eq '$dest[12]'; then
    echo "FAILED (destination mounted)"
    return 1
  fi
  if ! [[ -d $syncMount ]]; then
    mkdir -p "$syncMount"
  fi

  if [[ $1 == "raw" ]]; then
    for i in 1 2 3; do
      sfdisk -d ${src} | grep -q "^${src}p${i}" || continue
      srcSize="$(blockdev --getsize64 "$src"p${i})"
      destSize="$(blockdev --getsize64 "$dest"${i})"
      if [[ "$destSize" -lt "$srcSize" ]]; then
        echo -n "raw device copy of ${src}p${i} is larger than ${dest}${i}... "
        destPartsLargeEnough=false
      fi
    done
    if ! [[ $destPartsLargeEnough == "true" ]]; then
      srcSize="$(blockdev --getsize64 "$src")"
      destSize="$(blockdev --getsize64 "$dest")"
      if [[ "$destSize" -lt "$srcSize" ]]; then
        echo "FAILED (cannot duplicate internal SD card ${src}, it is larger than external ${dest})"
        if [[ -z "$INTERACTIVE" ]]; then return 1; fi
        repartitionText="One or more of the selected destination partition(s) are smaller than their equivalents on the internal SD card so you cannot simply replicate that. The physical size is sufficient though.\\n\\nDo you want the destination ${dest} to be overwritten to match the partitions of the internal SD card?"
        if ! (whiptail --title "Repartition $dest" --yes-button "Repartition" --no-button "Cancel" --yesno "$repartitionText" 12 116); then echo "CANCELED"; return 0; fi
      fi
      sfdisk -d /dev/mmcblk0 | sfdisk --force "$dest"
      partprobe
    fi
    echo "Taking a raw partition copy, be prepared this may take long such as 20-30 minutes for a 16 GB SD card"
    if ! cond_redirect dd if="${src}p1" bs=1M of="${dest}1" status=progress; then echo "FAILED (raw device copy of ${dest}1)"; dirty="yes"; fi
    if ! cond_redirect dd if="${src}p2" bs=1M of="${dest}2" status=progress; then echo "FAILED (raw device copy of ${dest}2)"; dirty="yes"; fi
    sfdisk -d ${src} | grep -q "^${src}p3" && if ! cond_redirect dd if="${src}p3" bs=1M of="${dest}3" status=progress; then echo "FAILED (raw device copy of ${dest}3)"; dirty="yes"; fi
    origPartUUID="$(blkid "${src}p2" | sed -n 's|^.*PARTUUID="\(\S\+\)".*|\1|p' | sed -e 's/-02//g')"
    if ! partUUID="$(yes | cond_redirect set-partuuid "${dest}2" random | awk '/^PARTUUID/ { print substr($7,1,length($7) - 3) }')"; then echo "FAILED (set random PARTUUID)"; dirty="yes"; fi
    if ! cond_redirect e2fsck -y "${dest}2" -U random; then echo "FAILED (e2fsck)"; dirty="yes"; fi
    if ! cond_redirect tune2fs "${dest}2" -U random; then echo "FAILED (set random UUID)"; dirty="yes"; fi
    while umount -q "${dest}1"; do : ; done
    mount "${dest}1" "$syncMount"
    sed -i "s|${origPartUUID}|${partUUID}|g" "$syncMount"/cmdline.txt
    umount "$syncMount"
    while umount -q "${dest}2"; do : ; done
    mount "${dest}2" "$syncMount"
    sed -i "s|${origPartUUID}|${partUUID}|g" "$syncMount"/etc/fstab
    [[ -f "${syncMount}/etc/systemd/system/${storageDir}".mount ]] && sed -i 's|^What=.*|What=/dev/mmcblk0p3|g' "${syncMount}/etc/systemd/system/${storageDir}".mount
    umount "$syncMount"
    if ! cond_redirect fsck -y -t ext4 "${dest}2"; then echo "OK (dirty bit on fsck ${dest}2 is normal)"; dirty="yes"; fi
    if [[ "$dirty" == "no" ]]; then
      echo "OK"
    fi
    # shellcheck disable=SC2154
    [[ -n "$adminmail" ]] && echo -e "${dumpInfoText}" | mail -s "SD card raw copy dump" "$adminmail"
    return 0
  fi

  if [[ "$1" == "diff" ]]; then
    if pgrep "dd if=${src}"; then
      echo "FAILED (raw device dump of ${dest} is running)"
      return 1
    fi
    if [[ -n "$INTERACTIVE" ]]; then
      select_blkdev "^-sd" "select partition" "Select the partition to copy the internal SD card data to"
      # shellcheck disable=SC2154
      dest="/dev/$retval"
    else
      dest="${dest}2"
    fi
    mount "$dest" "$syncMount"
    if ! (mountpoint -q "$syncMount"); then echo "FAILED (${dest} is not mounted as ${syncMount})"; return 1; fi
    cond_redirect rsync --one-file-system --exclude={'/etc/fstab','/etc/systemd/system/*.mount','/opt/zram','/srv/*'} --delete -aKRh "/" "$syncMount"
    cond_redirect rsync --one-file-system --exclude={'/etc/fstab','/etc/systemd/system/*.mount','/opt/zram','/srv/*'} --delete -aKh "/var/lib/openhab/persistence" "${syncMount}/var/lib/openhab"
    if ! (umount "$syncMount" &> /dev/null); then
      sleep 1
      umount -l "$syncMount" &> /dev/null
    fi
  fi
}


## setup mirror/sync of boot and / partitions
##
##   setup_mirror_SD()
##
setup_mirror_SD() {
  local src="/dev/mmcblk0"
  local srcSize
  local dest
  local destSize
  local infoText1="DANGEROUS OPERATION, USE WITH PRECAUTION!\\n\\nThis will *copy* your system root from your SD card to a USB attached card writer device. Are you sure"
  local infoText2="is an SD card writer device equipped with a dispensible SD card? Are you sure, this will destroy all data on that card and you want to proceed writing to this device?"
  local minStorageSize=4000000000                  # 4 GB
  local sdIncludesDir="${BASEDIR:-/opt/openhabian}/includes/SD"
  local serviceTargetDir="/etc/systemd/system"
  local sizeError="your destination SD card device does not have enough space"
  local storageDir="${storagedir:-/storage}"
  local sDir=${storageDir:1}
  local storageRemovalQuery="Do you also want to remove the storage mount for ${storageDir}?\\nIf you do not but remove the physical device it is located on, you will have trouble every time you restart your system.\\nRemember though it might also contain data you might want to keep such as your Amanda backup data. If ${storageDir} is not where your mount is, stop now and enter your mountpoint in /etc/openhabian.conf as the storagedir= parameter."
  local svcname

  if ! cond_redirect install -m 755 "${sdIncludesDir}/set-partuuid" /usr/local/sbin; then echo "FAILED (install set-partuuid)"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up automated SD mirroring and backup... "

  if [[ -n "$UNATTENDED" ]] && [[ -z "$backupdrive" ]]; then
    echo "SKIPPED (no configuration provided)"
    return 0
  fi

  if [[ $1 == "remove" ]]; then
    cond_redirect systemctl disable sdrsync.service sdrawcopy.service sdrsync.timer sdrawcopy.timer
    rm -f "$serviceTargetDir"/sdr*.{service,timer}

    # ATTENTION: the mountpoint may also have a different name than the default "/storage"
    svcname="${sDir//[\/]/\\x2d}.mount"     # remove leading '/' and replace all '/' by \\x2d as required by systemd for full pathnames 
    if [[ -f "$serviceTargetDir"/"$svcname" ]]; then
        # ATTENTION: may not be desired to remove on SD mirror disabling because it may still be in use for Amanda storage => ask for confirmation
        # [is there a possibility that this routine might be run non-interactively ?]
        if (whiptail --title "Remove $storageDir" --yes-button "Remove" --no-button "Keep" --yesno "$storageRemovalQuery" 12 116); then 
            cond_redirect systemctl disable --now "${svcname}"
            rm -f "$serviceTargetDir"/"$svcname"
        fi
    fi

    cond_redirect systemctl -q daemon-reload
    return 0
  fi

  if [[ $1 != "install" ]]; then echo "FAILED"; return 1; fi

  if ! is_pi; then
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Incompatible hardware detected" --msgbox "Mirror SD: this option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi

  mkdir -p "$storageDir"
  if ! cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" gdisk; then echo "FAILED (install gdisk)"; return 1; fi

  if [[ -n "$INTERACTIVE" ]]; then
    select_blkdev "^sd" "Setup SD mirroring" "Select USB device to copy the internal SD card data to"
    if [[ -z $retval ]]; then return 0; fi
    dest="/dev/${retval}"
  else
    dest="$backupdrive"
  fi
  if ! [[ $(blockdev --getsize64 "$dest") ]]; then
    echo "FAILED (bad destination)"
    return 1
  fi
  # shellcheck disable=SC2016
  if mount | grep -Eq '$dest[12]'; then
    echo "FAILED (destination mounted)"
    return 1
  fi

  infoText="$infoText1 $dest $infoText2"
  srcSize="$(blockdev --getsize64 "$src")"
  minStorageSize="$((minStorageSize + srcSize))"    # to ensure we have at least 4GB for storage partition plus space for the main partitions
  destSize="$(blockdev --getsize64 "$dest")"
  if [[ "$destSize" -lt "$srcSize" ]]; then
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "insufficient space" --msgbox "$sizeError" 9 80
    fi
    echo "FAILED (insufficient space)"; return 1;
  fi

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Copy internal SD to $dest" --yes-button "Continue" --no-button "Back" --yesno "$infoText" 12 116); then echo "CANCELED"; return 0; fi
  fi

  mountUnit="$(basename "${storageDir}").mount"
  systemctl stop "${mountUnit}"
  if sfdisk -d $src | grep -q "^${src}p3"; then
    # copy partition table with all 3 partitions
    sfdisk -d $src | sfdisk --force "$dest"
  else
    if [[ "$destSize" -ge "$minStorageSize" ]]; then
      # create 3rd partition and filesystem on dest
      start="$(fdisk -l /dev/mmcblk0 | head -1 | cut -d' ' -f5)"
      ((destSize-=start))
      ((start/=512))
      destSizeSector=$destSize
      ((destSizeSector/=512))
      (sfdisk -d /dev/mmcblk0; echo "/dev/mmcblk0p3 : start=${start},size=${destSizeSector}, type=83") | sfdisk --force "$dest"
      partprobe
      cond_redirect mke2fs -F -t ext4 "${dest}3"
      if ! sed -e "s|%DEVICE|${dest}3|g" -e "s|%STORAGE|${storageDir}|g" "${sdIncludesDir}/storage.mount-template" > "${serviceTargetDir}/${mountUnit}"; then echo "FAILED (create storage mount)"; fi
      if ! cond_redirect chmod 644 "${serviceTargetDir}/${mountUnit}"; then echo "FAILED (permissions)"; return 1; fi
      if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
      if ! cond_redirect systemctl enable --now "$mountUnit"; then echo "FAILED (enable storage mount)"; return 1; fi
    fi
  fi
  mirror_SD "raw" "$dest"

  if ! sed -e "s|%DEST|${dest}|g" "${sdIncludesDir}/sdrawcopy.service-template" > "${serviceTargetDir}/sdrawcopy.service"; then echo "FAILED (create raw SD copy service)"; fi
  if ! sed -e "s|%DEST|${dest}|g" "${sdIncludesDir}/sdrsync.service-template" > "${serviceTargetDir}/sdrsync.service"; then echo "FAILED (create rsync service)"; fi
  if ! cond_redirect install -m 644 -t "${serviceTargetDir}" "${sdIncludesDir}"/sdr*.timer; then rm -f "$serviceTargetDir"/sdr*.{service,timer}; echo "FAILED (setup copy timers)"; return 1; fi
  if ! cond_redirect install -m 755 "${sdIncludesDir}/mirror_SD" /usr/local/sbin; then echo "FAILED (install mirror_SD)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now sdrawcopy.timer sdrsync.timer; then echo "FAILED (enable timed SD sync start)"; return 1; fi

  echo "OK"

  if [[ -z $INTERACTIVE ]] && [[ "$destSize" -ge "$minStorageSize" ]]; then
    amanda_install
    create_amanda_config "${storageconfig:-openhab-dir}" "backup" "${adminmail:-root@${hostname}}" "${storagetapes:-15}" "${storagecapacity:-1024}" "${storageDir}"
  fi
}
