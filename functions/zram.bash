init_zram_mounts() {
  if [ "$1" == "install" ]; then
    local ZRAMGIT=https://github.com/mstormi/zram-config
    local TAG=openhabian_v1.5
    TMP="$(mktemp -d /tmp/.XXXXXXXXXX)"

    /usr/bin/git clone -q --branch "$TAG" "$ZRAMGIT" "$TMP"
    cd ${TMP}

    /bin/sh ./install.sh
    /usr/bin/install -m 644 ${BASEDIR:=/opt/openhabian}/includes/ztab /etc/ztab
    service zram-config start
    rm -rf "$TMP"
  else
    service zram-config stop
    /bin/sh /usr/local/share/zram-config/uninstall.sh
    rm -f /etc/ztab
  fi
}
