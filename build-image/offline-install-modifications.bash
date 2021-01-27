#!/usr/bin/env bash

export BASEDIR="/opt/openhabian"
export DEBIAN_FRONTEND="noninteractive"
export PREOFFLINE="1"

source /opt/openhabian/functions/helpers.bash
add_keys "https://bintray.com/user/downloadSubjectPublicKey?username=openhab"
echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
add_keys https://davesteele.github.io/key-366150CE.pub.txt
echo "deb http://davesteele.github.io/comitup/repo comitup main" > /etc/apt/sources.list.d/comitup.list
apt-get --quiet update
apt-get --quiet upgrade --yes
apt-get --quiet install --download-only --yes libattr1-dev libc6 libstdc++6 \
  zlib1g make openhab openhab-addons samba amanda-common amanda-server \
  amanda-client exim4 dnsutils mailutils gdisk screen vim nano mc vfu \
  bash-completion htop curl wget multitail git util-linux bzip2 zip unzip \
  xz-utils software-properties-common man-db whiptail acl usbutils dirmngr \
  arping apt-transport-https bc sysstat jq moreutils avahi-daemon python3 \
  python3-pip python3-wheel python3-setuptools avahi-autoipd fontconfig \
  comitup dns-root-data dnsmasq-base javascript-common libcairo2 \
  libgudev-1.0-0 libjs-jquery libmbim-glib4 libmbim-proxy libmm-glib0 \
  libndp0 libnm0 libpixman-1-0 libqmi-glib5 libqmi-proxy libteamdctl0 \
  libxcb-render0 libxcb-shm0 libxrender1 modemmanager  network-manager \
  python3-blinker python3-cairo python3-click python3-colorama \
  python3-flask python3-itsdangerous python3-jinja2 python3-markupsafe \
  python3-networkmanager python3-pyinotify python3-simplejson python3-werkzeug
source /opt/openhabian/functions/nodejs-apps.bash
nodejs_setup
apt-get --quiet autoremove --yes
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
exit
