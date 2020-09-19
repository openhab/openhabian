#!/usr/bin/env bash

export DEBIAN_FRONTEND="noninteractive"

source /opt/openhabian/functions/helpers.bash
add_keys "https://bintray.com/user/downloadSubjectPublicKey?username=openhab"
echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
apt-get update
apt-get upgrade --yes
apt-get install --download-only --yes libattr1-dev libc6 libstdc++6 zlib1g \
  openhab2 openhab2-addons screen vim nano mc vfu bash-completion htop curl \
  multitail git util-linux bzip2 zip unzip xz-utils software-properties-common \
  man-db whiptail acl usbutils dirmngr arping samba
apt-get autoremove --yes
exit
