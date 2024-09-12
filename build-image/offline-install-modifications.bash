#!/usr/bin/env bash
# shellcheck disable=SC1091

export BASEDIR="/opt/openhabian"
export DEBIAN_FRONTEND="noninteractive"
export PREOFFLINE="1"

debfileurl=https://davesteele.github.io/comitup/deb
debfile=davesteele-comitup-apt-source
debfilelatest=latest.deb
debfilestatic=1.2_all.deb
comituprepofile=/etc/apt/sources.list.d/davesteele-comitup.list

source /opt/openhabian/functions/helpers.bash
source /opt/openhabian/functions/java-jre.bash
add_keys "https://openhab.jfrog.io/artifactory/api/gpg/key/public" "openhab"
echo "deb [signed-by=/usr/share/keyrings/openhab.gpg] https://openhab.jfrog.io/artifactory/openhab-linuxpkg stable main" > /etc/apt/sources.list.d/openhab.list

# comitup hotspot
wget -nv "${debfileurl}/${debfile}_${debfilelatest}" -O ${debfile}_${debfilelatest} || wget -nv "${debfileurl}/${debfile}_${debfilestatic}" -O ${debfile}_${debfilelatest}
dpkg -i --force-all "${debfile}_${debfilelatest}"
rm -f "${debfile}*.deb"
if [[ ! -f ${comituprepofile} ]]; then
  echo "deb [signed-by=/usr/share/keyrings/davesteele-archive-keyring.gpg] http://davesteele.github.io/comitup/repo comitup main" > $comituprepofile
fi

# tailscale VPN
curl -fsL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

adoptium_fetch_apt 21

apt-get --quiet update
apt-get --quiet upgrade --yes
apt-get --quiet install --download-only --yes openhab openhab-addons \
  acl amanda-common amanda-server amanda-client apt-transport-https arping \
  avahi-daemon bash-completion bc bzip2 comitup coreutils curl \
  dnsmasq dnsutils dns-root-data dnsmasq-base dirmngr exim4 fontconfig gdisk git \
  htop inetutils-telnet iotop javascript-common jq \
  libblas3 libc6 libcairo2 libgudev-1.0-0 libjs-jquery libmbim-glib4 libgpm2 \
  liblinear4 liblua5.4-0 libmbim-proxy \
  libmm-glib0 libndp0 libnet1 libnm0 libpcre2-32-0 \
  libpixman-1-0 libqmi-glib5 libqmi-proxy libstdc++6 \
  libteamdctl0 libxcb-render0 libxcb-shm0 libxrender1 libyascreen0 \
  make man-db mc mc-data mailcap mailutils modemmanager moreutils multitail \
  nano network-manager nmap nmap-common \
  python3-blinker python3-cairo python3-click python3-colorama python3-flask \
  python3-itsdangerous python3-jinja2 python3-markupsafe \
  python3-networkmanager python3-pyinotify python3-simplejson python3-werkzeug \
  python3 python3-pip python3-wheel python3-setuptools \
  samba screen sysstat tailscale telnet usbutils util-linux \
  unzip vfu vfu-yascreen vim vim-runtime wget whiptail xz-utils zip zlib1g

source /opt/openhabian/functions/nodejs-apps.bash
nodejs_setup

apt-get --quiet autoremove --yes
rm -f /var/lib/apt/lists/lock
rm -f /var/cache/apt/archives/lock
rm -f /var/lib/dpkg/lock*
exit
