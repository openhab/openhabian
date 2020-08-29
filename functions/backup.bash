#!/usr/bin/env bash

filebrowser() {
  bkppath=/var/lib/openhab2/backups
  # shellcheck disable=SC2164,SC2012
  bkpfile=$(cd ${bkppath}; ls -lthp openhab2-backup-* 2> /dev/null | head -20 | awk -F ' ' '{ print $9 " " $5 }')
}

backup_openhab_config() {
  infotext="You have successfully created a backup of your openHAB configuration."
  out=$(openhab-cli backup | tail -2 | head -1 | awk -F ' ' '{print $NF}')
  msg="${infotext}\\n\\nFile is ${out}"
  whiptail --title "Created openHAB config backup" --msgbox "$msg" 11 78
}

restore_openhab_config() {
  filebrowser
  if [[ -z "$bkpfile" ]]; then whiptail --title "Could not find backup" --msgbox "We could not find any configuration backup file in the storage dir ${bkppath}" 8 80; return 0; fi
  # shellcheck disable=SC2086
  if ! fileselect=$(whiptail --title "Restore openHAB config" --cancel-button Cancel --ok-button Select  --menu "\\nSelect your backup from most current 20 files below:" 30 60 20 $bkpfile 3>&1 1>&2 2>&3); then return 0; fi
  cond_redirect systemctl stop openhab2
  if echo "y" | openhab-cli restore "${bkppath}/${fileselect}"; then
    whiptail --msgbox "Your selected openHAB configuration was successfully restored." 8 70
  else
    whiptail --msgbox "Sadly, there was a problem restoring your selected openHAB configuration." 8 70
  fi
  cond_redirect systemctl start openhab2
}

create_backup_config() {
  local config=$1
  local confdir=/etc/amanda/${config}
  local backupuser=$2
  local adminmail=$3
  local tapes=$4
  local size=$5
  local storage=$6
  local S3site=$7
  local S3bucket=$8
  local S3accesskey=$9
  local S3secretkey=${10}
  local dumptype


  TMP="/tmp/.amanda-setup.$$"

  local introtext="We need to prepare (to \"label\") your removable storage media."

  grep -v "${config}" /etc/cron.d/amanda > $TMP; mv $TMP /etc/cron.d/amanda

  mkdir -p "${confdir}"
  touch "${confdir}"/tapelist
  hostname=$(hostname)
  { echo "${hostname} ${backupuser}"; echo "${hostname} root amindexd amidxtaped"; echo "localhost ${backupuser}"; echo "localhost root amindexd amidxtaped"; } >> /var/backups/.amandahosts

  infofile="/var/lib/amanda/${config}/curinfo"       # Database directory
  logdir="/var/log/amanda/${config}"                 # Log directory
  indexdir="/var/lib/amanda/${config}/index"         # Index directory
  mkdir -p "${infofile}" "${logdir}" "${indexdir}"
  chown -R "${backupuser}":backup /var/backups/.amandahosts "${confdir}" "${infofile}" "${logdir}" "${indexdir}"
  if [ "${config}" = "openhab-dir" ]; then
    chown -R "${backupuser}":backup /var/backups/.amandahosts "${storage}"
    chmod -R g+rwx "${storage}"
    mkdir "${storage}"/slots # folder needed for following symlinks
    chown "${backupuser}":backup "${storage}"/slots
    ln -s "${storage}"/slots "${storage}"/slots/drive0
    ln -s "${storage}"/slots "${storage}"/slots/drive1    # taper-parallel-write 2 so we need 2 virtual drives
    tpchanger="\"chg-disk:${storage}/slots\"    # The tape-changer glue script"
    tapetype="DIRECTORY"
  else
    tpchanger="\"chg-multi:s3:${S3bucket}/openhab-AWS/slot-{$(seq -s, 1 "${tapes}")}\" # Number of virtual containers in your tapecycle"
    tapetype="AWS"
  fi

  sed -e "s|%CONFIG|${config}|g" -e "s|%CONFDIR|${confdir}|g" -e "s|%ADMIN|${adminmail}|g" -e "s|%TAPES|${tapes}|g" -e "s|%SIZE|${size}|g" -e "s|%TAPETYPE|${tapetype}|g" -e "s|%TPCHANGER|${tpchanger}|g" "${BASEDIR:-/opt/openhabian}"/includes/amanda.conf_template >"${confdir}"/amanda.conf

  if [ "${config}" = "openhab-AWS" ]; then
    { echo "device_property \"S3_BUCKET_LOCATION\" \"${S3site}\"                                # Your S3 bucket location (site)"; \
    echo "device_property \"STORAGE_API\" \"AWS4\""; \
    echo "device_property \"VERBOSE\" \"YES\""; \
    echo "device_property \"S3_ACCESS_KEY\" \"${S3accesskey}\"                        # Your S3 Access Key"; \
    echo "device_property \"S3_SECRET_KEY\" \"${S3secretkey}\"        # Your S3 Secret Key"; \
    echo "device_property \"S3_SSL\" \"YES\"                                                  # Curl needs to have S3 Certification Authority (Verisign today) in its CA list. If connection fails, try setting this no NO"; } >>"${confdir}"/amanda.conf
  fi

  if [ "${config}" = "openhab-local-SD" ] || [ "${config}" = "openhab-dir" ]; then
    rm -f "${confdir}"/disklist

    # don't backup SD by default as this can cause problems for large cards
    if [[ -n $INTERACTIVE ]]; then
      if (whiptail --title "Backup raw SD card, too ?" --yes-button "Backup SD" --no-button "Do not backup SD." --yesno "Do you want to create raw disk backups of your SD card ? Only recommended if it's 16GB or less, otherwise this can take too long. You can change this at any time by editing ${confdir}/disklist." 15 80); then
        echo "${hostname}  /dev/mmcblk0              comp-amraw" >>"${confdir}"/disklist
      fi
    fi

    dumptype=user-tar
  else
    dumptype=comp-user-tar
  fi
  { echo "${hostname}  /boot                                 ${dumptype}";\
    echo "${hostname}  /etc                                  ${dumptype}";\
    echo "${hostname}  /var/lib/openhab2                     ${dumptype}";\
    echo "${hostname}  /opt/zram/persistence.bind            ${dumptype}"; } >>"${confdir}"/disklist 

  if [[ -d /etc/homegear ]]; then
    echo "${hostname}  /var/lib/homegear                     ${dumptype}" >>"${confdir}"/disklist 
  fi

  echo "index_server \"localhost\"" >"${confdir}"/amanda-client.conf
  echo "tapedev \"changer\"" >"${confdir}"/amanda-client.conf
  echo "auth \"local\"" >"${confdir}"/amanda-client.conf

  introtext="${introtext}\\nFor permanent storage such as USB or NAS mounted storage, as well as for cloud based storage, we will create ${tapes} virtual containers."
  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Storage container creation" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80); then echo "CANCELED"; return 0; fi
  fi

  # create virtual 'tapes'
  counter=1
  while [ ${counter} -le "${tapes}" ]; do
    if [ "${config}" = "openhab-dir" ]; then
      mkdir -p "${storage}"/slots/slot${counter}
      chown "${backupuser}":backup "${storage}"/slots/slot${counter}
    else
      su - "${backupuser}" -c "/usr/sbin/amlabel ${config} ${config}-${counter} slot ${counter}"
    fi
    ((counter += 1))
  done

  # create cronjob to save copies of the Amanda database
  echo "0 1 * * * ${backupuser} /usr/sbin/amdump ${config} &> /dev/null" > /etc/cron.d/amanda
  echo "0 18 * * * ${backupuser} /usr/sbin/amcheck -m ${config} &> /dev/null" >> /etc/cron.d/amanda
  if [ "${tapetype}" = "DIRECTORY" ]; then
    mkdir -p "${storage}"/amanda-backups
    chown "${backupuser}":backup "${storage}"/amanda-backups
    echo "0 2 * * * root (cd /; /bin/tar czf ${storage}/amanda-backups/amanda_data_\$(date +\\%Y\\%m\\%d\\%H\\%M\\%S).tar.gz etc/amanda var/lib/amanda var/log/amanda; find ${storage} -name amanda_data_\\* -mtime +30 -delete) &> /dev/null" >> /etc/cron.d/amanda
  fi
}

amanda_setup() {
  local matched
  local canceled
  local backupuser="backup"
  local config=${storageconfig:-openhab-dir}
  local tapes=${storagetapes:-15}
  local size=${storagecapacity:-1024}
  local dir=${storagedir:-1024}
  local querytext="So you are about to install the Amanda backup solution.\\nDocumentation is available at the previous openHABian menu point,\\nat /opt/openhabian/docs/openhabian-amanda.md or at https://github.com/openhab/openhabian/blob/master/docs/openhabian-amanda.md\\nHave you read this document ?"
  local introtext="This will setup a backup mechanism to allow for saving your openHAB setup and modifications to either USB attached or Amazon cloud storage.\\nYou can add your own files/directories to be backed up, and you can store and create clones of your openHABian SD card to have an all-ready replacement in case of card failures."
  local successtext="Setup was successful. Amanda backup tool is now taking backups at 01:00. For further readings, start at http://wiki.zmanda.com/index.php/User_documentation."

 
  # shellcheck disable=SC2154
  if [[ -z $INTERACTIVE ]] && [[ -z "$backupdrive" ]]; then return 0; fi

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Amanda backup installation" --yes-button "Yes" --no-button "No, I'll go read it" --defaultno --yesno "$querytext" 10 80); then return 0; fi

    if ! [[ -x $(command -v exim) ]]; then
      if (whiptail --title "No exim mail transfer agent" --yes-button "Install EXIM4" --no-button "MTA already exist, ignore installation" --defaultyes --yesno "Seems exim is not installed as a mail transfer agent.\\nAmanda needs one to be able to send emails.\\nOnly choose to ignore if you know there's a working mail transfer agent other than exim on your system.\\nDo you want to continue with EXIM4 installation ?" 15 80); then
         exim_setup
      fi
    fi
    adminmail=$(whiptail --title "Admin reports" --inputbox "Enter the email address to send backup reports to." 10 60 3>&1 1>&2 2>&3)
    if [ -z "$adminmail" ]; then
       adminmail="root@$(hostname)"
    fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up the Amanda backup system ... "
  cond_redirect apt-get -q -y install amanda-common amanda-server amanda-client

  matched=false
  canceled=false
  if [[ -n $INTERACTIVE ]]; then
    while [ "$matched" = false ] && [ "$canceled" = false ]; do
      password=$(whiptail --title "Authentication Setup" --passwordbox "Enter a password for user ${backupuser}.\\nRemember to select a safe password as you (and others) can use this to login to your openHABian box." 15 80 3>&1 1>&2 2>&3)
      secondpassword=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the password" 15 80 3>&1 1>&2 2>&3)
      if [ "$password" = "$secondpassword" ] && [ -n "$password" ]; then
        matched=true
      else
        password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
      fi
    done
  fi

  chpasswd <<< "${backupuser}:${password:-backup}"
  chsh -s /bin/bash ${backupuser}
  if getent passwd openhabian; then
    usermod -a -G backup openhabian
  fi

  rm -f /etc/cron.d/amanda; /usr/bin/touch /etc/cron.d/amanda

  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "Create file storage area based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on locally attached or NAS mounted storage." 15 80); then
      dir=$(whiptail --title "Storage directory" --inputbox "What's the directory to store backups into?\\nYou can specify any locally accessible directory, no matter if it's located on the internal SD card, an external USB-attached device such as a USB stick or HDD, or a NFS or CIFS share mounted off a NAS or other server in the network." 10 60 "$dir" 3>&1 1>&2 2>&3)
      capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 "$capacity" 3>&1 1>&2 2>&3)

    fi
  fi
  ((size=capacity/tapes))
  create_backup_config "${config}" "${backupuser}" "${adminmail}" "${tapes}" "${size}" "${dir}"

  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "Create Amazon S3 based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on Amazon Web Services. You can get 5 GB of S3 cloud storage for free on https://aws.amazon.com/. For hints see http://markelov.org/wiki/index.php?title=Backup_with_Amanda:_tape,_NAS,_Amazon_S3#Amazon_S3\\n\\nPlease setup your S3 bucket on Amazon Web Services NOW if you have not done so. Remember the name has to be unique in AWS namespace.\\nContinue with Amanda installation ?" 15 80); then
      config=openhab-AWS
      S3site=$(whiptail --title "S3 bucket location site" --inputbox "Enter the S3 site (e.g. \"eu-central-1\") you want to use:" 10 60 3>&1 1>&2 2>&3)
      S3bucket=$(whiptail --title "S3 bucket" --inputbox "Enter the bucket name you created on S3 to use (only the part after last : of the ARN):" 10 60 3>&1 1>&2 2>&3)
      S3accesskey=$(whiptail --title "S3 access key" --inputbox "Enter the S3 access key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
      S3secretkey=$(whiptail --title "S3 secret key" --inputbox "Enter the S3 secret key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
      tapes=15
      capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 3>&1 1>&2 2>&3)
      size="$((capacity / tapes))"

      create_backup_config "${config}" "${backupuser}" "${adminmail}" "${tapes}" "${size}" AWS "${S3site}" "${S3bucket}" "${S3accesskey}" "${S3secretkey}"
    fi

    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi

  echo "OK"
}


## "raw" copy partition using dd or mount and use rsync to sync "diff"
## Valid arguments: "raw", "diff"
## Periodically activated by systemd timer units (raw copy on 1st of month, rsync else)
##
##    mirror_SD(String method)
##
mirror_SD() {
  local src
  local dest
  local start
  local syncMount="/storage/syncmount"


  src="/dev/mmcblk0"
  if [[ -n "$INTERACTIVE" ]]; then
    select_blkdev "^sd" "Setup SD mirroring" "Select the USB attached disk device to copy the internal SD card data to"
    # shellcheck disable=SC2154
    if [[ -z "$retval" ]]; then return 0; fi
    dest="/dev/$retval"
  else
    dest="${backupdrive}"
  fi
  if [[ "${src}" == "${dest}" ]]; then
    echo "FAILED (source = destination)"
    return 1
  fi
  if [[ ! $(blockdev --getsize64 "${dest}") ]]; then
    echo "FAILED (bad destination)"
    return 1
  fi
  # shellcheck disable=SC2143
  if [[ $(mount | grep "${dest}" &>/dev/null) ]]; then
    echo "FAILED (destination mounted)"
    return 1
  fi
  if [[ "$1" == "raw" ]]; then
    echo "Creating a raw partition copy, be prepared this may take long such as 20-30 minutes for a 16 GB SD card"
    if ! cond_redirect dd if="${src}" bs=1M of="${dest}"; then echo "FAILED (raw device copy)"; return 1; fi
    if ! cond_redirect fsck -y -t vfat "${dest}1"; then echo "FAILED (fsck /boot)"; return 1; fi
    if ! cond_redirect fsck -y -t ext4 "${dest}2"; then echo "FAILED (fsck root)"; return 1; fi
    echo "OK"
    return 0;
  fi

  if [[ "$1" == "diff" ]]; then
    if [[ ! -d $syncMount ]]; then
      mkdir -p "$syncMount"
    fi
    if [[ -n "$INTERACTIVE" ]]; then
      select_blkdev "^-sd" "select partition" "Select the partition to copy the internal SD card data to"
      dest="/dev/$retval"
    else
      dest="${dest}2"
    fi
    
    mount "$dest" "$syncMount"
    rsync --one-file-system -avRh "/" "$syncMount"
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
  local dest
  local srcSize
  local destSize
  local minSize
  local targetDir="/etc/systemd/system/"
  local storageDir="${storagedir:-/storage}"
  local sizeError="your destination SD card device does not have enough space, it needs to have at least twice as much as the source"
  local infoText1="DANGEROUS OPERATION, USE WITH PRECAUTION!\\n\\nThis will *copy* your system root from your SD card to a USB attached card writer device. Are you sure"
  local infoText2="is an SD card writer device equipped with a dispensible SD card ? Are you this will destroy all data on that card and you want to proceed writing to this device ?"


  echo -n "$(timestamp) [openHABian] Setting up automated SD mirroring and backup ... "
  if [[ "$1" == "remove" ]]; then
    rm -f ${targetDir}/sdr*.{service,timer}
    cond_redirect systemctl -q daemon-reload &> /dev/null
    return 0
  fi
  if [[ "$1" != "install" ]]; then echo "FAILED"; return 1; fi

  if ! is_pi; then
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Incompatible hardware detected" --msgbox "Mirror SD: this option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi

  # shellcheck disable=SC2154
  if [[ -n "$UNATTENDED" ]] && [[ -z "$backupdrive" ]]; then return 0; fi

  if [[ -n "$INTERACTIVE" ]]; then
    select_blkdev "^sd" "Setup SD mirroring" "Select USB device to copy the internal SD card data to"
    if [[ -z "$retval" ]]; then return 0; fi
    dest="/dev/${retval}"
  else
    # shellcheck disable=SC2154
    dest="${backupdrive}"
  fi
  if [[ ! $(blockdev --getsize64 "${dest}") ]]; then
    echo "FAILED (bad destination)"
    return 1
  fi
  # shellcheck disable=SC2143
  if [[ $(mount | grep "${dest}" &>/dev/null) ]]; then
    echo "FAILED (destination mounted)"
    return 1
  fi

  size=$(fdisk -l /dev/mmcblk0 | head -1 | cut -d' ' -f3)	# in GBytes
  infoText="$infoText1 $dest $infoText2"
  srcSize="$(blockdev --getsize64 /dev/mmcblk0)"
  minSize="$((19 * srcSize / 10))"	# to accomodate for slight differences in SD sizes
  destSize="$(blockdev --getsize64 "$dest")"
  if [[ "$destSize" -lt "$minSize" ]]; then
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "insufficient space" --msgbox "$sizeError" 9 80
    fi
    echo "FAILED (insufficient space)"; return 1;
  fi

  # copy partition table
  sfdisk -d /dev/mmcblk0 | sfdisk "$dest"
  start=$(fdisk -l /dev/mmcblk0 | head -1 | cut -d' ' -f7)
  # pipe input to fdisk as if used "interactively"
  # create Linux partition for /storage on the remaining space
  fdisk "$dest" &> /dev/null <<EOF
n
p
3
$start

t
3
83
w
EOF

  partprobe
  cond_redirect mke2fs -F -t ext4 "${dest}3"
  mkdir -p "${storageDir}"
  if ! sed -e "s|%DEVICE|${backupdrive}3|g" -e "s|%BKPDIR|${storageDir}|g" "${BASEDIR:-/opt/openhabian}"/includes/storage.mount >${targetDir}/storage.mount; then echo "FAILED (create storage mount)"; fi
  if ! cond_redirect systemctl enable --now storage.mount; then echo "FAILED (enable storage mount)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Copy system root to $dest" --yes-button "Continue" --no-button "Back" --yesno "$infoText" 22 116); then echo "CANCELED"; return 0; fi
  fi

  if ! sed -e "s|%DEST|${dest}|g" "${BASEDIR:-/opt/openhabian}"/includes/sdrawcopy.service_template >"${targetDir}"/sdrawcopy.service; then echo "FAILED (create sync service)"; fi
  if cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/{sdrsync.service,sd*.timer} "${targetDir}"/; then echo "OK"; else rm -f "${targetDir}/sdr*.service"; echo "FAILED (setup copy timers)"; return 1; fi
  if ! cond_redirect install -m 755 "${BASEDIR:-/opt/openhabian}"/includes/mirror_SD /usr/local/sbin; then echo "FAILED (install mirror_SD)"; return 1; fi
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable --now sdrawcopy.timer sdrsync.timer; then echo "FAILED (enable timed SD sync start)"; return 1; fi

  echo "OK"
}


