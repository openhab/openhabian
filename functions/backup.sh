#!/usr/bin/env bash

create_backup_config() {
  config=$1
  confdir=/etc/amanda/${config}
  backupuser=$2
  tapes=$3
  size=$4
  storage=$5
  s3accesskey=$6
  s3secretkey=$7

  introtext="We need to prepare (to \"label\") your removable storage media."
  if [ "${config}" = "openhab-local-SD" ]; then
     introtext="${introtext}\nWe will ask you to insert a specific SD card number (or USB stick) into the device ${storage} and prompt you to confirm it's plugged in. This procedure will be repeated ${tapes} times as that is the number of media you specified to be in rotational use for backup purposes."
  else
     introtext="${introtext}\nFor permanent storage such as USB or NAS mounted storage, as well as for cloud based storage, we will create ${tapes} virtual containers."
  fi
  if [ -n "$INTERACTIVE" ]; then
      if ! (whiptail --title "Storage container creation" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi
  # create virtual 'tapes'
  ln -s ${storage}/slots ${storage}/slots/drive0;ln -s ${storage}/slots ${storage}/slots/drive1    # taper-parallel-write 2 so we need 2 virtual drives
  counter=1
  while [ ${counter} -le ${tapes} ]; do
      if [ "${config}" = "openhab-dir" ]; then
          mkdir -p ${storage}/slots/slot${counter}

          tpchanger="\"chg-disk:${storage}/slots\"    # The tape-changer glue script"
          tapetype="DIRECTORY"
      else
          if [ "${config}" = "openhab-local-SD" ]; then
              introtext="Please insert your removable storage medium number ${counter}."
              if [ -n "$INTERACTIVE" ]; then
            if ! (whiptail --title "Correct SD card inserted?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
                  /bin/su - ${backupuser} -c "/usr/sbin/amlabel ${config} ${config}-${counter} slot ${counter}"
              fi
              tpchanger="\"chg-single:${sddev}\""
              tapetype="SD"
          else
              /bin/su - ${backupuser} -c "/usr/sbin/amlabel ${config} ${config}-${counter} slot ${counter}"
              tpchanger="\"chg-multi:s3:${s3accesskey}-backup/openhab-AWS/slot-{`seq -s, 1 ${tapes}`}\" # Number of virtual containers in your tapecycle"
              tapetype="AWS"
          fi
      fi

      let counter+=1
  done

# no mailer configured for now
#  if [ -n "$INTERACTIVE" ]; then
#     adminmail=$(whiptail --title "Admin reports" --inputbox "Enter the EMail address to send backup reports to. Note: Mail relaying is not enabled in openHABian yet." 10 60 3>&1 1>&2 2>&3)
#  fi

  /bin/grep -v ${config} /etc/cron.d/amanda; /usr/bin/touch /etc/cron.d/amanda

  echo "0 1 * * * ${backupuser} /usr/sbin/amdump ${config} &>/dev/null" >> /etc/cron.d/amanda
  echo "0 18 * * * ${backupuser} /usr/sbin/amcheck -m ${config} &>/dev/null" >> /etc/cron.d/amanda

  mkdir -p ${confdir}
  touch ${confdir}/tapelist
  hostname=`/bin/hostname`
  echo "${hostname} ${backupuser}" > /var/backups/.amandahosts
  echo "${hostname} root amindexd amidxtaped" >> /var/backups/.amandahosts
  echo "localhost ${backupuser}" >> /var/backups/.amandahosts
  echo "localhost root amindexd amidxtaped" >> /var/backups/.amandahosts


  infofile="/var/lib/amanda/${config}/curinfo"       # Database directory
  logdir="/var/log/amanda/${config}"                 # Log directory
  indexdir="/var/lib/amanda/${config}/index"         # Index directory
  /bin/mkdir -p $infofile $logdir $indexdir
  /bin/chown -R ${backupuser}:${backupuser} /var/backups/.amandahosts ${confdir} ${storage} $infofile $logdir $indexdir
  /bin/chmod -R g+rwx ${storage}


  /bin/sed -e "s|%CONFIG|${config}|g" -e "s|%CONFDIR|${confdir}|g" -e "s|%BKPDIR|${bkpdir}|g" -e "s|%ADMIN|${adminmail}|g" -e "s|%TAPES|${tapes}|g" -e "s|%SIZE|${size}|g" -e "s|%TAPETYPE|${tapetype}|g" -e "s|%TPCHANGER|${tpchanger}|g" ${BASEDIR}/includes/amanda.conf_template >${confdir}/amanda.conf

  if [ "${config}" = "openhab-AWS" ]; then
      echo "device_property \"S3_ACCESS_KEY\" \"${S3accesskey}\"  # Your S3 Access Key" >>${confdir}/amanda.conf
      echo "device_property \"S3_SECRET_KEY\" \"${S3secretkey}\"  # Your S3 Secret Key" >>${confdir}/amanda.conf
      echo "device_property \"S3_SSL\" \"YES\"  # Curl needs to have S3 Certification Authority (Verisign today) in its CA list. If connection fails, try setting this no NO" >>${confdir}/amanda.conf
  fi

  hostname=`/bin/hostname`
  if [ "${config}" = "openhab-local-SD" -o "${config}" = "openhab-dir" ]; then
      /bin/rm -f ${confdir}/disklist
      # don't backup SD by default as this can cause problems for large cards
      if [ -n "$INTERACTIVE" ]; then
          if (whiptail --title "Backup raw SD card, too ?" --yes-button "Backup SD" --no-button "Do not backup SD." --yesno "Do you want to create raw disk backups of your SD card ? Only recommended if it's 8GB or less, otherwise this can take too long. You can change this at any time by editing ${confdir}/disklist." 15 80) then
            echo "${hostname}  /dev/mmcblk0              amraw" >>${confdir}/disklist
        fi
      fi

      echo "${hostname}  /etc/openhab2             user-tar" >>${confdir}/disklist
      echo "${hostname}  /var/lib/openhab2         user-tar" >>${confdir}/disklist
  else
      echo "${hostname}  /etc/openhab2             comp-user-tar" >${confdir}/disklist
      echo "${hostname}  /var/lib/openhab2         comp-user-tar" >>${confdir}/disklist
  fi

  echo "index_server \"localhost\"" >${confdir}/amanda-client.conf
  echo "tapedev \"changer\"" >${confdir}/amanda-client.conf
  echo "auth \"local\"" >${confdir}/amanda-client.conf
}

amanda_setup() {

  querytext="So you are about to install the Amanda backup solution.\nDocumentation is available at the previous openHABian menu point,\nat /opt/openhabian/docs/openhabian-amanda.md or at https://github.com/openhab/openhabian/blob/master/docs/openhabian-amanda.md\nHave you read this document ?"
  introtext="This will setup a backup mechanism to allow for saving your openHAB setup and modifications to either USB attached or Amazon cloud storage.\nYou can add your own files/directories to be backed up, and you can store and create clones of your openHABian SD card to have an all-ready replacement in case of card failures."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful. Amanda backup tool is now taking backups at 01:00. For further readings, start at http://wiki.zmanda.com/index.php/User_documentation."

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Amanda backup installation" --yes-button "Yes" --no-button "No, I'll go read it" --defaultno --yesno "$querytext" 10 80) then return 0; fi
    whiptail --msgbox "$introtext" 25 132
  fi

  echo -n "$(timestamp) [openHABian] Setting up the Amanda backup system ... "
  backupuser="backup"

  cond_redirect apt -y install amanda-common amanda-server amanda-client || FAILED=1

  matched=false
  canceled=false
  if [ -n "$INTERACTIVE" ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
            password=$(whiptail --title "Authentication Setup" --passwordbox "Enter a password for user ${backupuser}.\nRemember to select a safe password as you (and others) can use this to login to your openHABian box." 15 80 3>&1 1>&2 2>&3)
            secondpassword=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the password" 15 80 3>&1 1>&2 2>&3)
            if [ "$password" = "$secondpassword" ] && [ ! -z "$password" ]; then
                matched=true
            else
                password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
            fi
      done
  fi

  /usr/sbin/usermod -a -G backup openhabian
  /usr/sbin/chpasswd <<< "${backupuser}:${password}"
  /usr/bin/chsh -s /bin/bash ${backupuser}

  /bin/rm -f /etc/cron.d/amanda; /usr/bin/touch /etc/cron.d/amanda

# no SD set based config for now, requires latest Amanda which is not available as a package yet
#  if [ -n "$INTERACTIVE" ]; then
#    if (whiptail --title "Create SD card set based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on a locally attached SD card writer and a set of SD cards. You can also use USB sticks, BUT you must ensure that the device name to access ALWAYS is the same. This is not guaranteed if you use different USB ports." 15 80) then
#        config=openhab-local-SD
#        sddev=$(whiptail --title "Card writer device" --inputbox "What's the device name of your SD card writer?" 10 60 3>&1 1>&2 2>&3)
#        tapes=$(whiptail --title "Number of SD cards in rotation" --inputbox "How many SD cards will you have available in rotation for backup purposes ?" 10 60 3>&1 1>&2 2>&3)
#        size=$(whiptail --title "SD card capacity" --inputbox "What's your backup SD card capacity in megabytes? If you use different sizes, specify the smallest one. The remaining capacity will remain unused." 10 60 3>&1 1>&2 2>&3)
#        create_backup_config ${config} ${backupuser} ${tapes} ${size} ${sddev}
#    fi
#  fi

  if [ -n "$INTERACTIVE" ]; then
    if (whiptail --title "Create file storage area based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on locally attached or NAS mounted storage." 15 80) then
        config=openhab-dir
        dir=$(whiptail --title "Storage directory" --inputbox "What's the directory to store backups into?\nYou can specify any locally accessible directory, no matter if it's located on the internal SD card, an external USB-attached device such as a USB stick or HDD, or a NFS or CIFS share mounted off a NAS or other server in the network." 10 60 3>&1 1>&2 2>&3)
        tapes=15
        capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 3>&1 1>&2 2>&3)
        let size=${capacity}/${tapes}

        create_backup_config ${config} ${backupuser} ${tapes} ${size} ${dir}
    fi
  fi

  if [ -n "$INTERACTIVE" ]; then
    if (whiptail --title "Create Amazon S3 based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on Amazon Web Services. You can get 5 GB of S3 cloud storage for free on https://aws.amazon.com/. See also http://wiki.zmanda.com/index.php/How_To:Backup_to_Amazon_S3" 15 80) then
      config=openhab-AWS
      S3accesskey=$(whiptail --title "S3 access key" --inputbox "Enter the S3 access key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
      S3secretkey=$(whiptail --title "S3 secret key" --inputbox "Enter the S3 secret key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
      tapes=15
      capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 3>&1 1>&2 2>&3)
      let size=${capacity}/${tapes}

      create_backup_config ${config} ${backupuser} ${tapes} ${size} AWS ${S3accesskey} ${S3secretkey}
    fi
  fi
}
