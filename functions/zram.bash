#!/usr/bin/env bash

## install code needed to compile ZRAM tools at installation time
## can be called standalone from build.bash or during install from init_zram_mounts()
## argument is destination directory
##
##   install_zram_code(String dir)
##
install_zram_code() {
  local ZRAMGIT=https://github.com/mstormi/openhabian-zram
  local OVERLAYFSGIT=https://github.com/kmxz/overlayfs-tools
  local TAG=openhabian_v1.6
  cond_redirect apt-get install -y -q --no-install-recommends make libattr1-dev

  mkdir -p "$1"
  git clone -q "$OVERLAYFSGIT" "$1"/overlayfs-tools
  git clone -q --branch "$TAG" "$ZRAMGIT" "$1"/openhabian-zram
}

init_zram_mounts() {
  local introtext="You are about to activate the ZRAM feature.\\nBe aware you do this at your own risk of data loss.\\nPlease check out the \"ZRAM status\" thread at https://community.openhab.org/t/zram-status/80996 before proceeding."
  local text_lowmem="Your system has less than 1 GB of RAM. It is definitely NOT recommended to run ZRAM (AND openHAB) on your box. If you proceed now you will do so at your own risk !"
  local ZRamInstallLocation

  if [ "$1" == "install" ]; then
    if [ -z "$UNATTENDED" ]; then
      # display warn disclaimer and point to ZRAM status thread on forum
      if ! (whiptail --title "Install ZRAM, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
      # double check if there's enough RAM to run ZRAM
      if has_lowmem; then
        if ! (whiptail --title "WARNING, Continue?" --yes-button "REALLY Continue" --no-button "Step Back" --yesno --defaultno "$text_lowmem" 15 80) then echo "CANCELED"; return 0; fi
      fi
    fi

    ZRamInstallLocation=/opt/zram

    install_zram_code "$ZRamInstallLocation"
    cd "$ZRamInstallLocation"/overlayfs-tools || return 1
    make
    cd "$ZRamInstallLocation" || return 1
    /bin/sh ./install.sh
    /usr/bin/install -m 644 "${BASEDIR:=/opt/openhabian}"/includes/ztab /etc/ztab

    cond_redirect systemctl start zram-config
  else
    cond_redirect systemctl stop zram-config
    /bin/sh /usr/local/share/zram-config/uninstall.sh
    rm -f /etc/ztab
  fi
}

zram_setup() {
  if is_arm; then
    if ! has_lowmem && ! is_pione && ! is_cmone && ! is_pizero && ! is_pizerow; then
      cond_redirect systemctl stop openhab2

      echo "$(timestamp) [openHABian] Installing ZRAM ..."
      cond_redirect init_zram_mounts install
      cond_redirect systemctl start openhab2
    else
      echo "$(timestamp) [openHABian] Skipping ZRAM install on ARM hardware without enough memory."
    fi
  else
    echo "$(timestamp) [openHABian] Skipping ZRAM install on non-ARM hardware."
  fi
}
