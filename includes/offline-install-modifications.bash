#!/usr/bin/env bash

export BASEDIR="/opt/openhabian"
export DEBIAN_FRONTEND="noninteractive"
export PREOFFLINE="1"

source /opt/openhabian/functions/helpers.bash
add_keys "https://bintray.com/user/downloadSubjectPublicKey?username=openhab"
echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
apt-get update
apt-get upgrade --yes
apt-get install --download-only --yes libattr1-dev libc6 libstdc++6 zlib1g \
  openhab2 openhab2-addons samba amanda-common amanda-server amanda-client \
  exim4 dnsutils mailutils
source /opt/openhabian/functions/system.bash
basic_packages
needed_packages
source /opt/openhabian/functions/packages.bash
firemotd_setup
source /opt/openhabian/functions/nodejs-apps.bash
nodejs_setup
apt-get autoremove --yes
exit
