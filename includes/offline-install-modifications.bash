#!/usr/bin/env bash

export BASEDIR="/opt/openhabian"
export DEBIAN_FRONTEND="noninteractive"
export PREOFFLINE="1"

source /opt/openhabian/functions/helpers.bash
add_keys "https://bintray.com/user/downloadSubjectPublicKey?username=openhab"
echo "deb https://openhab.jfrog.io/openhab/openhab-linuxpkg testing main" > /etc/apt/sources.list.d/openhab.list    # Use testing on OH3 branch to allow for proper testing of functionality until stable OH3 builds are available
apt-get --quiet update
apt-get --quiet upgrade --yes
apt-get --quiet install --download-only --yes libattr1-dev libc6 libstdc++6 \
  zlib1g make openhab openhab-addons samba amanda-common amanda-server \
  amanda-client exim4 dnsutils mailutils gdisk screen vim nano mc vfu \
  bash-completion htop curl wget multitail git util-linux bzip2 zip unzip \
  xz-utils software-properties-common man-db whiptail acl usbutils dirmngr \
  arping apt-transport-https bc sysstat jq moreutils avahi-daemon python3 \
  python3-pip python3-wheel python3-setuptools avahi-autoipd fontconfig
source /opt/openhabian/functions/nodejs-apps.bash
nodejs_setup
apt-get --quiet autoremove --yes
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
exit
