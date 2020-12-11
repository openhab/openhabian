#!/usr/bin/env bash

## Install code needed to compile ZRAM tools at installation time this
## can be called standalone from build.bash or during install from init_zram_mounts().
## The argument is the destination directory.
##
##    install_zram_code(String dir)
##
install_zram_code() {
  local zramGit="https://github.com/ecdye/zram-config"

  echo -n "$(timestamp) [openHABian] Installing ZRAM code... "
  if ! cond_redirect mkdir -p "$1"; then echo "FAILED (create directory)"; return 1; fi

  if [[ -d "${1}/zram-config" ]]; then
    if cond_redirect update_git_repo "${1}/zram-config" "openHAB"; then echo "OK"; else echo "FAILED (update zram)"; return 1; fi
  else
    if cond_redirect git clone --recurse-submodules --branch "openHAB" "$zramGit" "$1"/zram-config; then echo "OK"; else echo "FAILED (clone zram)"; return 1; fi
  fi
}

## Setup ZRAM for openHAB specific usage
## Valid arguments: "install" or "uninstall"
##
##    init_zram_mounts(String option)
##
init_zram_mounts() {
  if ! is_arm; then return 0; fi

  local disklistFileAWS="/etc/amanda/openhab-aws/disklist"
  local disklistFileDir="/etc/amanda/openhab-dir/disklist"
  local introText="You are about to activate the ZRAM feature.\\nBe aware you do this at your own risk of data loss.\\nPlease check out the \"ZRAM status\" thread at https://community.openhab.org/t/zram-status/80996 before proceeding."
  local lowMemText="Your system has less than 1 GB of RAM. It is definitely NOT recommended to run ZRAM (AND openHAB) on your box. If you proceed now you will do so at your own risk!"
  local zramInstallLocation="/opt/zram"

  if [[ $1 == "install" ]] && ! [[ -f /etc/ztab ]]; then
    if [[ -n $INTERACTIVE ]]; then
      # display warn disclaimer and point to ZRAM status thread on forum
      if ! (whiptail --title "Install ZRAM, Continue?" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 10 80); then echo "CANCELED"; return 0; fi
      # double check if there's enough RAM to run ZRAM
      if has_lowmem; then
        if ! (whiptail --title "WARNING, Continue?" --yes-button "REALLY Continue" --no-button "Cancel" --yesno --defaultno "$lowMemText" 10 80); then echo "CANCELED"; return 0; fi
      fi
    fi

    if ! dpkg -s 'make' 'libattr1-dev' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing ZRAM required packages (make, libattr1-dev)... "
      if cond_redirect apt-get install --yes make libattr1-dev; then echo "OK"; else echo "FAILED"; return 1; fi
    fi

    install_zram_code "$zramInstallLocation"

    echo -n "$(timestamp) [openHABian] Setting up OverlayFS... "
    if ! cond_redirect make --always-make --directory="$zramInstallLocation"/zram-config/overlayfs-tools; then echo "FAILED (make overlayfs)"; return 1; fi
    if ! cond_redirect mkdir -p /usr/local/lib/zram-config/; then echo "FAILED (create directory)"; return 1; fi
    if cond_redirect install -m 755 "$zramInstallLocation"/zram-config/overlayfs-tools/overlay /usr/local/lib/zram-config/overlay; then echo "OK"; else echo "FAILED (install overlayfs)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Setting up ZRAM... "
    if ! cond_redirect install -m 755 "$zramInstallLocation"/zram-config/zram-config /usr/local/sbin; then echo "FAILED (zram-config)"; return 1; fi
    if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/ztab /etc/ztab; then echo "FAILED (ztab)"; return 1; fi
    if ! cond_redirect mkdir -p /usr/local/share/zram-config/log; then echo "FAILED (create directory)"; return 1; fi
    if cond_redirect install -m 644 "$zramInstallLocation"/zram-config/zram-config.logrotate /etc/logrotate.d/zram-config; then echo "OK"; else echo "FAILED (logrotate)"; return 1; fi

    if [[ -f /etc/systemd/system/find3server.service ]]; then
      echo -n "$(timestamp) [openHABian] Adding FIND3 to ZRAM... "
      if cond_redirect sed -i '/^.*persistence.bind$/a dir	lz4	100M		350M		/opt/find3/server/main		/find3.bind' /etc/ztab; then echo "OK"; else echo "FAILED (sed)"; return 1; fi
    fi
    if ! openhab_is_installed; then
      echo -n "$(timestamp) [openHABian] Removing openHAB persistence from ZRAM... "
      if cond_redirect sed -i '/persistence.bind/d' /etc/ztab; then echo "OK"; else echo "FAILED (sed)"; return 1; fi
    else
      if [[ -f $disklistFileDir ]]; then
        echo -n "$(timestamp) [openHABian] Adding ZRAM to Amanda local backup... "
        if ! cond_redirect sed -i '/zram/d' "$disklistFileDir"; then echo "FAILED (old config)"; return 1; fi
        if (echo "${HOSTNAME}  /opt/zram/persistence.bind    comp-user-tar" >> "$disklistFileDir"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
      fi
      if [[ -f $disklistFileAWS ]]; then
        echo -n "$(timestamp) [openHABian] Adding ZRAM to Amanda AWS backup... "
        if ! cond_redirect sed -i '/zram/d' "$disklistFileAWS"; then echo "FAILED (old config)"; return 1; fi
        if (echo "${HOSTNAME}  /opt/zram/persistence.bind    comp-user-tar" >> "$disklistFileAWS"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
      fi
    fi

    echo -n "$(timestamp) [openHABian] Setting up ZRAM service... "
    if ! cond_redirect install -m 644 "$zramInstallLocation"/zram-config/zram-config.service /etc/systemd/system/zram-config.service; then echo "FAILED (install service)"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi

    if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/sysctl-zram.conf /etc/sysctl.d/zram.conf; then echo "FAILED (add sysctl)"; return 1; fi
    if ! running_in_docker && ! running_on_github; then
      if ! cond_redirect sysctl -q -p /etc/sysctl.d/zram.conf ; then echo "FAILED (set sysctl parameters)"; return 1; fi
      if ! cond_redirect systemctl mask unattended-upgrades.service; then echo "FAILED (mask unattended upgrades service)"; return 1; fi
    fi
    if cond_redirect systemctl enable --now zram-config.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi
  elif [[ $1 == "uninstall" ]]; then
    echo -n "$(timestamp) [openHABian] Removing ZRAM service... "
    if ! cond_redirect zram-config "stop"; then echo "FAILED (stop zram)"; return 1; fi
    if ! cond_redirect systemctl disable zram-config.service; then echo "FAILED (disable service)"; return 1; fi
    if ! cond_redirect rm -f /etc/systemd/system/zram-config.service; then echo "FAILED (remove service)"; return 1; fi
    if ! running_in_docker && ! running_on_github; then
      if ! cond_redirect systemctl unmask unattended-upgrades.service; then echo "FAILED (unmask unattended upgrades service)"; return 1; fi
    fi
    if cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "OK"; else echo "FAILED (daemon-reload)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Removing ZRAM... "
    if ! cond_redirect rm -f /usr/local/sbin/zram-config; then echo "FAILED (zram-config)"; return 1; fi
    if ! cond_redirect rm -f /etc/ztab; then echo "FAILED (ztab)"; return 1; fi
    if ! cond_redirect rm -rf /usr/local/share/zram-config; then echo "FAILED (zram-config share)"; return 1; fi
    if ! cond_redirect rm -rf /usr/local/lib/zram-config; then echo "FAILED (zram-config lib)"; return 1; fi
    if ! cond_redirect rm -rf /etc/sysctl.d/zram.conf; then echo "FAILED (sysctl.d/zram.conf)"; return 1; fi
    if cond_redirect rm -f /etc/logrotate.d/zram-config; then echo "OK"; else echo "FAILED (logrotate)"; return 1; fi

    if [[ -f "$disklistFileDir" ]]; then
      echo -n "$(timestamp) [openHABian] Removing ZRAM from Amanda local backup... "
      if cond_redirect sed -i -e '/zram/d' "$disklistFileDir"; then echo "OK"; else echo "FAILED (old config)"; return 1; fi
    fi
    if [[ -f "$disklistFileAWS" ]]; then
      echo -n "$(timestamp) [openHABian] Removing ZRAM from Amanda AWS backup... "
      if cond_redirect sed -i -e '/zram/d' "$disklistFileAWS"; then echo "OK"; else echo "FAILED (old config)"; return 1; fi
    fi
  else
    echo "$(timestamp) [openHABian] Refusing to install ZRAM as it is already installed, please uninstall and then try again... EXITING"
    return 1
  fi
}

zram_setup() {
  if is_pifour_8GB && ! is_aarch64; then
    echo -n "$(timestamp) [openHABian] You're using the 8GB model of the RPi4. It is known to not work with ZRAM. You may want to try the 64bit openHABian image."
    zraminstall="disable"
  fi
  if [[ -n "$UNATTENDED" ]] && [[ "${zraminstall:-enable}" == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Skipping ZRAM install as requested."
    return 1
  fi
  if is_arm; then
    if ! has_lowmem && ! is_pione && ! is_cmone && ! is_pizero && ! is_pizerow; then
      echo -n "$(timestamp) [openHABian] Installing ZRAM... "
      if cond_redirect init_zram_mounts "install"; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      echo "$(timestamp) [openHABian] Skipping ZRAM install on ARM hardware without enough memory."
    fi
  else
    echo "$(timestamp) [openHABian] Skipping ZRAM install on non-ARM hardware."
  fi
}
