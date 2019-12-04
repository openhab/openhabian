#!/usr/bin/env bash

init_zram_mounts() {
  local introtext="You are about to activate the ZRAM feature.\\nBe aware this is a dangerous operation to apply to your system. Use is at your own risk of data loss.\\nPlease check out the \"ZRAM status\" thread at https://community.openhab.org/t/zram-status/80996 before proceeding."
  if [ "$1" == "install" ]; then
    if [ -z "$UNATTENDED" ]; then
      # ... display warn disclaimer...
      # point to ZRAM status thread on forum
      if ! (whiptail --title "Install ZRAM, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
    fi
    local ZRAMGIT=https://github.com/mstormi/openhabian-zram
    local TAG=openhabian_v1.5
    TMP="$(mktemp -d /tmp/openhabian.XXXXXXXXXX)"

    /usr/bin/git clone -q --branch "$TAG" "$ZRAMGIT" "$TMP"

    cd "$TMP" || return
    /bin/sh ./install.sh
    /usr/bin/install -m 644 "${BASEDIR:=/opt/openhabian}"/includes/ztab /etc/ztab
    service zram-config start
    rm -rf "$TMP"
  else
    service zram-config stop
    /bin/sh /usr/local/share/zram-config/uninstall.sh
    rm -f /etc/ztab
  fi
}
