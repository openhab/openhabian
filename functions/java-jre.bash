#!/usr/bin/env bash

## Install Java version from default repo
## Valid arguments: "11"
##
## java_install(String version)
##
java_install() {
  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi

  if java_zulu_dir; then
    java_alternatives_reset
    rm -rf /opt/jdk
  fi

  openjdk_install_apt "$1"

  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi
}

## Fetch OpenJDK using APT repository.
##
##    openjdk_fetch_apt()
##
openjdk_fetch_apt() {
  echo -n "$(timestamp) [openHABian] Fetching OpenJDK ${1}... "
  if cond_redirect apt-get install --download-only --yes "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Install OpenJDK using APT repository.
##
##    openjdk_install_apt()
##
openjdk_install_apt() {
  if ! dpkg -s "openjdk-${1}-jre-headless" &> /dev/null; then # Check if already is installed
    adoptopenjdk_fetch_apt "$1"
    echo -n "$(timestamp) [openHABian] Installing OpenJDK ${1}... "
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s "openjdk-${1}-jre-headless" &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Reconfiguring OpenJDK ${1}... "
    cond_redirect java_alternatives_reset
    if cond_redirect dpkg-reconfigure "openjdk-${1}-jre-headless"; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

## Reset Java in update-alternatives
##
##    java_alternatives_reset()
##
java_alternatives_reset() {
  local jdkBin

  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"

  cond_redirect find "$jdkBin" -maxdepth 1 -perm -111 -type f -exec bash -c 'update-alternatives --quiet --remove-all $(basename {})' \;
}

## Check if Java Zulu is already in the filesystem
##
##    java_zulu_dir()
##
java_zulu_dir() {
  local dir

  for dir in /opt/jdk/*; do
    if [[ -d $dir ]]; then return 0; fi
  done
  return 1
}
