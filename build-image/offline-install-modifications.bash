#!/usr/bin/env bash
# shellcheck disable=SC1091

export BASEDIR="/opt/openhabian"
export DEBIAN_FRONTEND="noninteractive"
export PREOFFLINE="1"
comitupurl=https://davesteele.github.io/comitup/deb/
comitupfile=davesteele-comitup-apt-source_1.2_all.deb
comituprepofile=/etc/apt/sources.d/comitup.list

source /opt/openhabian/functions/helpers.bash
add_keys "https://openhab.jfrog.io/artifactory/api/gpg/key/public" "openhab"
echo "deb [signed-by=/usr/share/keyrings/openhab.gpg] https://openhab.jfrog.io/artifactory/openhab-linuxpkg stable main" > /etc/apt/sources.list.d/openhab.list

# comitup hotspot
wget -nv "${comitupurl}/$comitupfile"
dpkg -i --force-all "$comitupfile"
rm -f "$comitupfile"
if [[ ! -f ${comituprepofile} ]]; then
  echo "deb http://davesteele.github.io/comitup/repo comitup main" > $comituprepofile
fi

# tailscale VPN
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

apt-get --quiet update
apt-get --quiet upgrade --yes
apt-get --quiet install --download-only --yes libc6 libstdc++6 zlib1g make \
  openhab openhab-addons samba amanda-common amanda-server amanda-client exim4 \
  dnsutils mailutils gdisk screen vim nano mc vfu bash-completion coreutils \
  htop curl wget multitail git util-linux bzip2 zip unzip xz-utils \
  software-properties-common man-db whiptail acl usbutils dirmngr arping \
  apt-transport-https bc sysstat jq moreutils avahi-daemon python3 python3-pip \
  python3-wheel python3-setuptools fontconfig comitup \
  dns-root-data dnsmasq-base javascript-common libcairo2 libgudev-1.0-0 \
  libjs-jquery libmbim-glib4 libmbim-proxy libmm-glib0 libndp0 libnm0 \
  libpixman-1-0 libqmi-glib5 libqmi-proxy libteamdctl0 libxcb-render0 \
  libxcb-shm0 libxrender1 modemmanager network-manager python3-blinker \
  python3-cairo python3-click python3-colorama python3-flask \
  python3-itsdangerous python3-jinja2 python3-markupsafe \
  python3-networkmanager python3-pyinotify python3-simplejson python3-werkzeug \
  openjdk-17-jre-headless tailscale
source /opt/openhabian/functions/nodejs-apps.bash
nodejs_setup
apt-get --quiet autoremove --yes
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
exit
