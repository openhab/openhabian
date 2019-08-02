init_zram_mounts() {
  if [ "$1" == "install" ]; then
    local ZRAMGIT=https://github.com/mstormi/zram-config
    local BRANCH=""
    local TAG=openhabian
    TMP="$(mktemp -d /tmp/.XXXXXXXXXX)"

    /usr/bin/git clone ${BRANCH} ${ZRAMGIT} ${TMP}
    cd ${TMP}
    /usr/bin/git fetch --tags
    /usr/bin/git checkout ${TAG}

    /bin/sh ./install.sh
    /usr/bin/install -m 644 ${BASEDIR:=/opt/openhabian}/includes/ztab /etc/ztab
    service zram-config start
    rm -rf "$TMP"
  else
    service zram-config stop
    /usr/local/share/zram-config/uninstall.sh
    rm -f /etc/ztab
  fi
}
