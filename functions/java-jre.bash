#!/usr/bin/env bash

## Install Java version from dpkg repositories dynamically.
## This function is a wrapper for the OpenJDK and Adoptium Eclipse Temurin JDK install functions.
## Valid arguments: "17", "21", "Temurin17", "Temurin21", 11 (legacy)
##
## java_install(String version)
##
java_install() {
  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi

  if [[ -d /opt/jdk ]]; then
    java_alternatives_reset
    rm -rf /opt/jdk
  fi
  if [[ $1 == Temurin* ]]; then
    adoptium_install_apt "${1/Temurin/}"
  else
    openjdk_install_apt "$1"
  fi

  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi
}

## Fetch Adoptium Eclipse Temurin JDK builds (AdoptOpenJDK) using APT repository.
##
##    adoptium_fetch_apt()
##
adoptium_fetch_apt() {
  local keyName="adoptium"
  local URL="https://openems.io/download/"
  local cachedir="/var/cache/apt/archives"
  local pkgfile="temurin-21-jre-armhf_21.0.6+2.deb"
  local cachefile="temurin-21-jre_21.0.6+2_armhf.deb"


  echo -n "$(timestamp) [openHABian] Fetching Adoptium Eclipse Temurin JDK... "
  if ! cond_redirect add_keys "https://packages.adoptium.net/artifactory/api/gpg/key/public" "$keyName"; then echo "FAILED (add keys)"; return 1; fi
  echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg] https://packages.adoptium.net/artifactory/deb ${osrelease:-bookworm} main" > /etc/apt/sources.list.d/adoptium.list
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi

  # if on 32 bit OS, install unsupported Adoptium 32 bit from OpenEMS community project
  if [[ $1 == "21" ]] && [[ $(getconf LONG_BIT) == 32 ]]; then
    if ! cond_redirect wget -nv -O "${cachedir}/${cachefile}" "${URL}/${pkgfile}"; then echo "FAILED (download JVM pkg)"; rm -f "${cachedir}/${cachefile}"; return 1; fi
  else
    if ! cond_redirect dpkg --configure -a --confnew; then echo "FAILED (dpkg)"; return 1; fi
    if cond_redirect apt-get install --download-only --yes "temurin-${1}-jre"; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

## Install Adoptium Eclipse Temurin JDK builds (AdoptOpenJDK) using APT repository.
##
##    adoptium_install_apt()
##
adoptium_install_apt() {
  local cachedir="/var/cache/apt/archives"
  local cachefile="temurin-21-jre_21.0.6+2_armhf.deb"
  local Java32bitMsg="You are still running a 32 bit operating system. There is no regular Java Virtual machine available.\\nWe've installed an experimental package for you but note this is unsupported by openHABian and the openHAB project.\\nWe ask you to migrate (reinstall) to a 64bit OS as soon as possible. See openHAB 5 release notes."


  if ! dpkg -s "temurin-${1}-jre" &> /dev/null; then # Check if already is installed
    adoptium_fetch_apt "$1"
    echo -n "$(timestamp) [openHABian] Installing Adoptium Eclipse Temurin JDK... "
    cond_redirect java_alternatives_reset
    if ! cond_redirect apt-get --yes install adoptium-ca-certificates; then echo "FAILED (install Java certificate)"; return 1; fi
    if ! cond_redirect apt-get --yes install java-common libxi6 libxrender1 libxtst6 ; then echo "FAILED (install Java commons)"; return 1; fi
    if [[ $(getconf LONG_BIT) == 32 ]]; then
      if ! cond_redirect dpkg -i "${cachedir}/${cachefile}"; then echo "FAILED (install experimental JVM pkg)"; return 1; fi
      if [[ -n "$INTERACTIVE" ]]; then
        whiptail --title "unsupported JVM was installed" --msgbox "${Java32bitMsg}" 9 80
      fi
    else
      # this will NOT work when cached pkg file is there but not indexed by apt
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" "temurin-${1}-jre"; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    echo -n "$(timestamp) [openHABian] Reconfiguring Adoptium Eclipse Temurin JDK... "
    if cond_redirect dpkg-reconfigure "temurin-${1}-jre"; then echo "OK"; else echo "FAILED"; return 1; fi
    if is_aarch64; then
      update-alternatives --set java /usr/lib/jvm/temurin-"${1}"-jre-arm64/bin/java
    elif is_armv6l || is_armv7l; then
      update-alternatives --set java /usr/lib/jvm/temurin-"${1}"-jre-armhf/bin/java
    fi
  fi
}

## Fetch OpenJDK using APT repository.
##
##    openjdk_fetch_apt()
##
openjdk_fetch_apt() {
  local keyName="debian-bookworm"

  echo -n "$(timestamp) [openHABian] Fetching OpenJDK ${1}... "
  if [[ $1 == "21" ]]; then
    if ! cond_redirect add_keys "https://ftp-master.debian.org/keys/archive-key-12.asc" "$keyName"; then echo "FAILED (add keys)"; return 1; fi # Add keys for older systems that need them
    echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg]  http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/java.list
    # Avoid release mixing: prevent RPi from using the Debian distro for normal Raspbian packages
    echo -e "Package: *\\nPin: release a=unstable\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-unstable
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi

    if ! cond_redirect dpkg --configure -a --force-confnew; then echo "FAILED (dpkg)"; return 1; fi
    if cond_redirect apt-get install --download-only --yes -t unstable "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED (download)"; return 1; fi
  else
    if ! cond_redirect dpkg --configure -a --force-confnew; then echo "FAILED (dpkg)"; return 1; fi
    if cond_redirect apt-get install --download-only --yes "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED (download)"; return 1; fi
  fi
}

## Install OpenJDK using APT repository.
##
##    openjdk_install_apt()
##
openjdk_install_apt() {
  if ! dpkg -s "openjdk-${1}-jre-headless" &> /dev/null; then # Check if already is installed
    openjdk_fetch_apt "$1"
    echo -n "$(timestamp) [openHABian] Installing OpenJDK ${1}... "
    if [[ $1 == "21" ]]; then
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" -t unstable "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    echo -n "$(timestamp) [openHABian] Reconfiguring OpenJDK ${1}... "
    if cond_redirect dpkg-reconfigure "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
    if is_aarch64; then
      update-alternatives --set java /usr/lib/jvm/java-"${1}"-openjdk-arm64/bin/java
    elif is_armv6l || is_armv7l; then
      update-alternatives --set java /usr/lib/jvm/java-"${1}"-openjdk-armhf/bin/java
    fi
  fi
}

## Reset Java in update-alternatives
##
##    java_alternatives_reset()
##
java_alternatives_reset() {
  local jdkBin

  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  if [[ -z "$jdkBin" ]]; then
    return 0
  fi

  # shellcheck disable=SC2016
  cond_redirect find "$jdkBin" -maxdepth 1 -perm -111 -type f -exec bash -c 'update-alternatives --quiet --remove-all $(basename {})' \;
}
