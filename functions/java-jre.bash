#!/usr/bin/env bash

## Install Java version from dpkg repositories dynamically.
## This function is a wrapper for the OpenJDK and Adoptium Eclipse Temurin JDK install functions.
## Valid arguments: "11", "17", "Temurin17", "Temurin21"
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
    adoptium_fetch_apt "${1/Temurin/}"
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
  if ! apt-cache show "temurin-${1}-jre" &> /dev/null; then
    local keyName="adoptium"

    if ! add_keys "https://packages.adoptium.net/artifactory/api/gpg/key/public" "$keyName"; then return 1; fi

    echo -n "$(timestamp) [openHABian] Adding Adoptium repository to apt... "
    if ! echo "deb https://packages.adoptium.net/artifactory/deb ${osrelease:-bookworm} main" > /etc/apt/sources.list.d/adoptium.list; then echo "FAILED"; return 1; fi
    if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Fetching Adoptium Eclipse Temurin JDK... "
  if cond_redirect apt-get install --download-only --yes "temurin-${1}-jre"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Install Adoptium Eclipse Temurin JDK builds (AdoptOpenJDK) using APT repository.
##
##    adoptium_install_apt()
##
adoptium_install_apt() {
  if ! dpkg -s "temurin-${1}-jre" &> /dev/null; then # Check if already is installed
    adoptium_fetch_apt "$1"
    echo -n "$(timestamp) [openHABian] Installing Adoptium Eclipse Temurin JDK... "
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" "temurin-${1}-jre"; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s "temurin-${1}-jre" &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Reconfiguring Adoptium Eclipse Temurin JDK... "
    cond_redirect java_alternatives_reset
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
  if ! apt-cache show "openjdk-${1}-jre-headless" &> /dev/null; then
    if is_pi; then
      echo "deb http://archive.raspberrypi.org/debian/ ${osrelease:-bookworm} main" > /etc/apt/sources.list.d/java.list
    else
      echo "deb http://deb.debian.org/debian/ stable main" > /etc/apt/sources.list.d/java.list
    fi
    cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
    cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

    # important to avoid release mixing:
    # prevent RPi from using the Debian distro for normal Raspbian packages
    # echo -e "Package: *\\nPin: release a=unstable\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-unstable
  fi

  dpkg --configure -a
  echo -n "$(timestamp) [openHABian] Fetching OpenJDK ${1}... "
  if cond_redirect apt-get install --download-only --yes "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Install OpenJDK using APT repository.
##
##    openjdk_install_apt()
##
openjdk_install_apt() {
  if ! dpkg -s "openjdk-${1}-jre-headless" &> /dev/null; then # Check if already is installed
    openjdk_fetch_apt "$1"
    echo -n "$(timestamp) [openHABian] Installing OpenJDK ${1}... "
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s "openjdk-${1}-jre-headless" &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Reconfiguring OpenJDK ${1}... "
    cond_redirect java_alternatives_reset
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

  # shellcheck disable=SC2016
  cond_redirect find "$jdkBin" -maxdepth 1 -perm -111 -type f -exec bash -c 'update-alternatives --quiet --remove-all $(basename {})' \;
}
