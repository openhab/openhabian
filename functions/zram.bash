#!/usr/bin/env bash

## Install code needed to compile zram tools at installation time this
## can be called standalone from build.bash or during install from init_zram_mounts().
## The argument is the destination directory.
##
##    install_zram_code(String dir)
##
install_zram_code() {
  local zramGit="https://github.com/ecdye/zram-config"

  echo -n "$(timestamp) [openHABian] Installing zram code... "
  if ! cond_redirect mkdir -p "$1"; then echo "FAILED (create directory)"; return 1; fi

  if [[ -d "${1}/zram-config" ]]; then
    if cond_redirect update_git_repo "${1}/zram-config" "openHAB"; then echo "OK"; else echo "FAILED (update zram)"; return 1; fi
  else
    if cond_redirect git clone --branch "openHAB" "$zramGit" "$1"/zram-config; then echo "OK"; else echo "FAILED (clone zram)"; return 1; fi
  fi
}

## Setup zram for openHAB specific usage
## Valid arguments: "install" or "uninstall"
##
##    init_zram_mounts(String option)
##
init_zram_mounts() {
  if ! is_arm; then return 0; fi

  local introText="You are about to activate the zram feature.\\nBe aware you do this at your own risk of data loss.\\nPlease check out the \"zram status\" thread at https://community.openhab.org/t/zram-status/80996 before proceeding."
  local lowMemText="Your system has less than 1 GB of RAM. It is definitely NOT recommended to run zram (AND openHAB) on your box. If you proceed now you will do so at your own risk!"
  local zramInstallLocation="/opt/zram"

  if [[ $1 == "install" ]] && ! [[ -f /etc/ztab ]]; then
    if [[ -n $INTERACTIVE ]]; then
      # display warn disclaimer and point to zram status thread on forum
      if ! (whiptail --title "Install zram" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 10 80); then echo "CANCELED"; return 0; fi
      # double check if there's enough RAM to run zram
      if has_lowmem; then
        if ! (whiptail --title "WARNING, continue?" --yes-button "REALLY Continue" --no-button "Cancel" --yesno --defaultno "$lowMemText" 10 80); then echo "CANCELED"; return 0; fi
      fi
    fi

    if ! dpkg -s 'make' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing zram required package (make)... "
      if cond_redirect apt-get install --yes make; then echo "OK"; else echo "FAILED"; return 1; fi
    fi

    install_zram_code "$zramInstallLocation"

    echo -n "$(timestamp) [openHABian] Setting up OverlayFS... "
    if ! cond_redirect make --always-make --directory="$zramInstallLocation"/zram-config/overlayfs-tools; then echo "FAILED (make overlayfs)"; return 1; fi
    if ! cond_redirect mkdir -p /usr/local/lib/zram-config/; then echo "FAILED (create directory)"; return 1; fi
    if cond_redirect install -m 755 "$zramInstallLocation"/zram-config/overlayfs-tools/overlay /usr/local/lib/zram-config/overlay; then echo "OK"; else echo "FAILED (install overlayfs)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Setting up zram... "
    if ! cond_redirect install -m 755 "$zramInstallLocation"/zram-config/zram-config /usr/local/sbin; then echo "FAILED (zram-config)"; return 1; fi
    if has_highmem; then
      if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/ztab-lm /etc/ztab; then echo "FAILED (ztab)"; return 1; fi
    else
      if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/ztab /etc/ztab; then echo "FAILED (ztab)"; return 1; fi
    fi
    if ! cond_redirect mkdir -p /usr/local/share/zram-config/log; then echo "FAILED (create directory)"; return 1; fi
    if ! cond_redirect ln -s /usr/local/share/zram-config/log /var/log/zram-config; then echo "FAILED (link directory)"; return 1; fi
    if cond_redirect install -m 644 "$zramInstallLocation"/zram-config/service/zram-config.logrotate /etc/logrotate.d/zram-config; then echo "OK"; else echo "FAILED (logrotate)"; return 1; fi
    echo "ReadWritePaths=/usr/local/share/zram-config/log" >> /lib/systemd/system/logrotate.service

    if [[ -f /etc/systemd/system/find3server.service ]]; then
      echo -n "$(timestamp) [openHABian] Adding FIND3 to zram... "
      if cond_redirect sed -i '/^.*persistence.*$/a dir	zstd		150M		350M		/opt/find3/server/main		/find3.bind' /etc/ztab; then echo "OK"; else echo "FAILED (sed)"; return 1; fi
    fi
    if [[ -f /lib/systemd/system/influxdb.service ]]; then
      echo -n "$(timestamp) [openHABian] Adding InfluxDB to zram... "
      if cond_redirect sed -i '/^.*persistence.*$/a dir	zstd		150M		350M		/var/lib/influxdb		/influxdb.bind' /etc/ztab; then echo "OK"; else echo "FAILED (sed)"; return 1; fi
    fi
    
    mkdir -p /var/log/nginx   # ensure it exists on lowerfs else nginx may fail to start if zram is not synced after nginx install
    
    if ! openhab_is_installed; then 
      echo -n "$(timestamp) [openHABian] Removing openHAB persistence from zram... "
      if cond_redirect sed -i '/^.*persistence.*$/d' /etc/ztab; then echo "OK"; else echo "FAILED (sed)"; return 1; fi
    fi

    echo -n "$(timestamp) [openHABian] Setting up zram service... "
    if ! cond_redirect install -m 644 "$zramInstallLocation"/zram-config/service/SystemD/zram-config.service /etc/systemd/system/zram-config.service; then echo "FAILED (install service)"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi

    if ! running_in_docker && ! running_on_github; then
      if ! cond_redirect systemctl mask unattended-upgrades.service; then echo "FAILED (mask unattended upgrades service)"; return 1; fi
    fi
    if cond_redirect systemctl enable --now zram-config.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi
  elif [[ $1 == "uninstall" ]]; then
    echo -n "$(timestamp) [openHABian] Removing zram service... "
    if ! cond_redirect systemctl stop zram-config.service; then echo "FAILED (stop zram)"; return 1; fi
    if ! cond_redirect systemctl disable zram-config.service; then echo "FAILED (disable service)"; return 1; fi
    if ! cond_redirect rm -f /etc/systemd/system/zram-config.service; then echo "FAILED (remove service)"; return 1; fi
    if ! cond_redirect sed -i '\|^ReadWritePaths=/usr/local/share/zram-config/log$|d' /lib/systemd/system/logrotate.service; then echo "FAILED (sed)"; return 1; fi
    if ! running_in_docker && ! running_on_github; then
      if ! cond_redirect systemctl unmask unattended-upgrades.service; then echo "FAILED (unmask unattended upgrades service)"; return 1; fi
    fi
    if cond_redirect systemctl -q daemon-reload; then echo "OK"; else echo "FAILED (daemon-reload)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Removing zram... "
    if ! cond_redirect rm -f /usr/local/sbin/zram-config; then echo "FAILED (zram-config)"; return 1; fi
    if ! cond_redirect rm -f /etc/ztab; then echo "FAILED (ztab)"; return 1; fi
    if ! cond_redirect rm -rf /usr/local/share/zram-config; then echo "FAILED (zram-config share)"; return 1; fi
    if ! cond_redirect rm -f /var/log/zram-config; then echo "FAILED (zram-config link)"; return 1; fi
    if ! cond_redirect rm -rf /usr/local/lib/zram-config; then echo "FAILED (zram-config lib)"; return 1; fi
    if cond_redirect rm -f /etc/logrotate.d/zram-config; then echo "OK"; else echo "FAILED (logrotate)"; return 1; fi
  elif [[ -f /etc/ztab ]]; then
    echo -n "$(timestamp) [openHABian] Updating zram service... "
    if ! cond_redirect systemctl stop zram-config.service; then echo "FAILED (stop zram)"; return 1; fi
    if cond_redirect install_zram_code "$zramInstallLocation"; then echo "OK"; else echo "FAILED (update)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Updating OverlayFS... "
    if ! cond_redirect make --always-make --directory="$zramInstallLocation"/zram-config/overlayfs-tools; then echo "FAILED (make overlayfs)"; return 1; fi
    if ! cond_redirect mkdir -p /usr/local/lib/zram-config/; then echo "FAILED (create directory)"; return 1; fi
    if cond_redirect install -m 755 "$zramInstallLocation"/zram-config/overlayfs-tools/overlay /usr/local/lib/zram-config/overlay; then echo "OK"; else echo "FAILED (install overlayfs)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Updating zram... "
    if ! cond_redirect install -m 755 "$zramInstallLocation"/zram-config/zram-config /usr/local/sbin; then echo "FAILED (zram-config)"; return 1; fi
    if ! cond_redirect install -m 644 "$zramInstallLocation"/zram-config/service/SystemD/zram-config.service /etc/systemd/system/zram-config.service; then echo "FAILED (install service)"; return 1; fi
    if ! cond_redirect mkdir -p /usr/local/share/zram-config/log; then echo "FAILED (create directory)"; return 1; fi
    if ! [[ -h /var/log/zram-config ]]; then
      if ! cond_redirect ln -s /usr/local/share/zram-config/log /var/log/zram-config; then echo "FAILED (link directory)"; return 1; fi
    fi
    if ! cond_redirect install -m 644 "$zramInstallLocation"/zram-config/service/zram-config.logrotate /etc/logrotate.d/zram-config; then echo "FAILED (logrotate)"; return 1; fi
    if ! grep -qs "ReadWritePaths=/usr/local/share/zram-config/log" /lib/systemd/system/logrotate.service; then
      echo "ReadWritePaths=/usr/local/share/zram-config/log" >> /lib/systemd/system/logrotate.service
    fi
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
    if cond_redirect systemctl restart zram-config.service; then echo "OK"; else echo "FAILED (start service)"; return 1; fi
  else
    echo "$(timestamp) [openHABian] Refusing to update zram as it is not installed, please install and then try again... EXITING"
    return 1
  fi
}

zram_setup() {
  if [[ -n "$UNATTENDED" ]] && [[ "${zraminstall:-enable}" == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Skipping zram install as requested."
    return 1
  fi
  if is_arm; then
    if ! has_lowmem && ! is_pione && ! is_cmone && ! is_pizero && ! is_pizerow && ! is_pizerow2; then
      echo -n "$(timestamp) [openHABian] Installing zram... "
      if cond_redirect init_zram_mounts "install"; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      echo "$(timestamp) [openHABian] Skipping zram install on ARM hardware without enough memory."
    fi
  else
    echo "$(timestamp) [openHABian] Skipping zram install on non-ARM hardware."
  fi
}
