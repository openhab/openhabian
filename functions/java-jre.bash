#!/usr/bin/env bash
# shellcheck disable=SC2181
# shellcheck disable=SC2144

## Install appropriate Java version based on current choice.
## Valid arguments: AdoptOpenJDK, Zulu32, Zulu64
##
##    java_install_and_update(String type)
##
java_install_or_update(){
  # Make sure we don't overwrite existing unsupported installations
  if ! [ -x "$(command -v java)" ] || [[ ! "$(java -version > /dev/null 2>&1)" == *"Zulu"* ]] || [[ ! "$(java -version > /dev/null 2>&1)" == *"AdoptOpenJDK"* ]]; then
    if [ "$1" == "AdoptOpenJDK" ]; then
      adoptopenjdk_install_apt
    elif ! [ "$1" == "AdoptOpenJDK" ]; then
      if [[ "$(java -version > /dev/null 2>&1)" == *"AdoptOpenJDK"* ]] && [ -d /opt/jdk/* ]; then
        cond_redirect systemctl stop openhab2.service
        cond_redirect java_alternatives_reset "Zulu"
        cond_redirect systemctl start openhab2.service
      else
        if [ "$1" == "Zulu64" ]; then
          if is_x86_64; then
            java_zulu_enterprise_8_apt
          else
            if java_zulu_tar_update_available 64-bit; then
              java_zulu_8_tar 64-bit
            fi
          fi
        else # Default to 32-bit installation
          if java_zulu_tar_update_available 32-bit; then
            java_zulu_8_tar 32-bit
          fi
        fi
      fi
    fi
  fi
  cond_redirect java -version
}

## Install Java Zulu 8 directly from fetched .tar.gz file
## Valid arguments: "32-bit" or "64-bit"
##
##    java_zulu_8_tar(String arch)
##
java_zulu_8_tar(){
  local link
  local jdkTempLocation
  local jdkInstallLocation
  local jdkLib
  local jdkArch

  cond_redirect systemctl stop openhab2.service

  if [ "$1" == "32-bit" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 32-Bit OpenJDK... "
    link=$(fetch_zulu_tar_url 32-bit)
    if is_arm; then
      jdkArch="aarch32"
    else
      jdkArch="i386"
    fi

    if is_aarch64; then
      dpkg --add-architecture armhf
      cond_redirect apt-get --yes install libc6:armhf libncurses5:armhf libstdc++6:armhf
    fi

    if is_x86_64; then
      dpkg --add-architecture i386
      cond_redirect apt-get --yes install libc6:i386 libncurses5:i386 libstdc++6:i386
    fi

  elif [ "$1" == "64-bit" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 64-Bit OpenJDK... "
    link=$(fetch_zulu_tar_url 64-bit)
    if is_aarch64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      jdkArch="aarch64"
    elif is_x86_64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      jdkArch="amd64"
    else
      if [ -n "$INTERACTIVE" ]; then
        whiptail --title "Incompatible hardware detected" --msgbox "Zulu OpenJDK 64-bit: this option does not currently work on your platform.\\n\\nDefaulting to 32-bit installation." 10 60
      else
        echo "Zulu OpenJDK 64-bit: this option does not currently work on your platform. Defaulting to 32-bit installation."
      fi
      link=$(fetch_zulu_tar_url 32-bit)
      if is_arm; then
        jdkArch="aarch32"
      else
        jdkArch="i386"
      fi
    fi

  else
    echo -n "[DEBUG] Invalid argument to function java_zulu_8_tar()"
    exit 1
  fi
  jdkTempLocation="$(mktemp -d /tmp/openhabian.XXXXX)"
  if [ -z "$jdkTempLocation" ]; then echo "FAILED"; exit 1; fi
  jdkInstallLocation="/opt/jdk"
  mkdir -p $jdkInstallLocation

  # Fetch and copy new Java Zulu 8 runtime
  cond_redirect wget -nv -O "$jdkTempLocation"/zulu8.tar.gz "$link"
  tar -xpzf "$jdkTempLocation"/zulu8.tar.gz -C "${jdkTempLocation}"
  if [ $? -ne 0 ]; then echo "FAILED"; rm -rf "$jdkTempLocation"/zulu8.tar.gz; exit 1; fi
  rm -rf "$jdkTempLocation"/zulu8.tar.gz "${jdkInstallLocation:?}"/*
  mv "${jdkTempLocation}"/* "${jdkInstallLocation}"/

  rmdir "${jdkTempLocation}"

  # Update system with new installation
  jdkLib=$(find "${jdkInstallLocation}"/*/lib ... -print -quit)
  cond_redirect java_alternatives_reset "Zulu"
  cond_redirect update-alternatives --remove-all javac ## TODO: remove sometime in late 2020
  echo "$jdkLib"/"$jdkArch" > /etc/ld.so.conf.d/java.conf
  echo "$jdkLib"/"$jdkArch"/jli >> /etc/ld.so.conf.d/java.conf
  ldconfig

  cond_redirect java_zulu_install_crypto_extension

  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl start openhab2.service
}

## Install Azul's Java Zulu Enterprise using APT repository.
## (package manager distributions only available on x86-64bit platforms when checked in April 2020)
##
java_zulu_enterprise_8_apt(){
  if ! dpkg -s 'zulu-8' >/dev/null 2>&1; then # Check if already is installed
  echo -n "$(timestamp) [openHABian] Adding Zulu keys to apt... "
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  cond_redirect systemctl stop openhab2.service
  echo -n "$(timestamp) [openHABian] Installing Zulu Enterprise 64-Bit OpenJDK... "
  echo "deb http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-enterprise.list
  cond_redirect apt-get update
  if cond_redirect apt-get --yes install zulu-8 && java_zulu_install_crypto_extension; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl start openhab2.service
fi
}

## Fetch Java Zulu 8 directly from Azul API v1
## Valid arguments: "32-bit" or "64-bit"
##
##    fetch_zulu_tar_url(String arch)
##
fetch_zulu_tar_url(){
  local link
  local downloadlink

  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?jdk_version=8&ext=tar.gz&os=linux"

  if [ "$1" == "32-bit" ]; then
    if is_arm; then
      downloadlink=$(curl "${link}&arch=arm&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    else
      downloadlink=$(curl "${link}&arch=x86&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    fi

  elif [ "$1" == "64-bit" ]; then
    if is_arm; then
      downloadlink=$(curl "${link}&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    else
      downloadlink=$(curl "${link}&arch=x86&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    fi

  else
    echo -n "[DEBUG] Invalid argument to function fetch_zulu_tar_url()"
    exit 1
  fi

  if [ -z "$downloadlink" ]; then return 1; fi
  echo "$downloadlink"
  return 0
}

## Check if a newer version of Java Zulu 8 is available.
## Returns 0 / true if new version exists
## Valid arguments: "32-bit" or "64-bit"
##
##    java_zulu_tar_update_available(String arch)
##
java_zulu_tar_update_available(){
  if [ ! -x "$(command -v java)" ] || [[ "$(java -version 2>&1)" == *"AdoptOpenJDK"* ]]; then return 0; fi
  local availableVersion
  local javaVersion
  local filter
  local link
  if [ ! -x "$(command -v jq)" ]; then
    cond_redirect apt-get install --yes jq
  fi

  filter='[.zulu_version[] | tostring] | join(".")'
  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?jdk_version=8&ext=tar.gz&os=linux"
  javaVersion=$(java -version 2>&1 | grep -m 1 -o "[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}")

  if [ "$1" == "32-bit" ]; then
    if is_arm; then
      availableVersion=$(curl -s -H "Accept: application/json" "${link}&arch=arm&hw_bitness=32" | jq -r "$filter")
    else
      availableVersion=$(curl -s -H "Accept: application/json" "${link}&arch=x86&hw_bitness=32" | jq -r "$filter")
    fi

  elif [ "$1" == "64-bit" ]; then
    if is_arm; then
      availableVersion=$(curl -s -H "Accept: application/json" "${link}&arch=arm&hw_bitness=64" | jq -r "$filter")
    else
      availableVersion=$(curl -s -H "Accept: application/json" "${link}&arch=x86&hw_bitness=64" | jq -r "$filter")
    fi

  else
    if [ $? -ne 0 ]; then echo "FAILED (java update available)"; exit 1; fi
  fi

  if [[ $javaVersion == "$availableVersion" ]]; then
    return 1 # Java is up-to-date
  fi
  return 0
}

## Install Zulu Cryptography Extension Kit to enable cryptos using more then 128 bits
##
java_zulu_install_crypto_extension(){
  local jdkPath
  local jdkSecurity
  local policyTempLocation
  jdkPath="$(readlink -f "$(command -v java)")"
  jdkSecurity="$(dirname "${jdkPath}")/../lib/security"
  mkdir -p "$jdkSecurity"
  policyTempLocation="$(mktemp -d /tmp/openhabian.XXXXX)"
  if [ -z "$policyTempLocation" ]; then echo "FAILED"; exit 1; fi

  cond_redirect wget -nv -O "$policyTempLocation"/crypto.zip https://cdn.azul.com/zcek/bin/ZuluJCEPolicies.zip
  cond_redirect unzip "$policyTempLocation"/crypto.zip -d "$policyTempLocation"
  cp "$policyTempLocation"/ZuluJCEPolicies/*.jar "$jdkSecurity"

  rm -rf "${policyTempLocation}"
  return 0
}

## Fetch AdoptOpenJDK using APT repository.
##
adoptopenjdk_fetch_apt(){
  local adoptKey="/tmp/adoptopenjdk.asc"
  echo -n "$(timestamp) [openHABian] Adding AdoptOpenJDK keys to apt... "
  cond_redirect wget -qO "$adoptKey" https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public
  if cond_redirect apt-key add "$adoptKey"; then
    echo "OK"
  else
    echo "FAILED (keyserver)"
    rm -f "$adoptKey"
    exit 1;
  fi
  echo -n "$(timestamp) [openHABian] Fetching AdoptOpenJDK... "
  echo "deb http://adoptopenjdk.jfrog.io/adoptopenjdk/deb buster main" > /etc/apt/sources.list.d/adoptopenjdk.list
  cond_redirect apt-get update
  if cond_redirect apt-get install --download-only adoptopenjdk-8-hotspot-jre; then echo "OK"; else echo "FAILED"; exit 1; fi
}

## Install AdoptOpenJDK using APT repository.
##
adoptopenjdk_install_apt(){
  if ! dpkg -s 'adoptopenjdk-8-hotspot-jre' > /dev/null 2>&1; then # Check if already is installed
    echo -n "$(timestamp) [openHABian] Installing AdoptOpenJDK... "
    adoptopenjdk_fetch_apt
    cond_redirect systemctl stop openhab2.service
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes adoptopenjdk-8-hotspot-jre; then echo "OK"; else echo "FAILED"; exit 1; fi
    cond_redirect systemctl start openhab2.service
  elif dpkg -s 'adoptopenjdk-8-hotspot-jre' >/dev/null 2>&1; then
    cond_redirect systemctl stop openhab2.service
    cond_redirect java_alternatives_reset
    if cond_redirect dpkg-reconfigure adoptopenjdk-8-hotspot-jre; then echo "OK"; else echo "FAILED"; exit 1; fi
    cond_redirect systemctl start openhab2.service
  fi
}

## Reset Java in update-alternatives
## Valid arguments: "Zulu"
##
##    java_alternatives_reset(String opt)
##
java_alternatives_reset(){
  update-alternatives --remove-all java
  update-alternatives --remove-all jjs
  update-alternatives --remove-all keytool
  update-alternatives --remove-all orbd
  update-alternatives --remove-all pack200
  update-alternatives --remove-all policytool
  update-alternatives --remove-all rmid
  update-alternatives --remove-all rmiregistry
  update-alternatives --remove-all servertool
  update-alternatives --remove-all tnameserv
  update-alternatives --remove-all unpack200
  update-alternatives --remove-all jexec
  if [[ "$1" == "Zulu" ]]; then
    local jdkBin
    local jdkLib
    jdkBin=$(find /opt/jdk/*/bin ... -print -quit)
    jdkLib=$(find /opt/jdk/*/lib ... -print -quit)
    update-alternatives --install /usr/bin/java java "$jdkBin"/java 1000000
    update-alternatives --install /usr/bin/jjs jjs "$jdkBin"/jjs 1000000
    update-alternatives --install /usr/bin/keytool keytool "$jdkBin"/keytool 1000000
    update-alternatives --install /usr/bin/orbd orbd "$jdkBin"/orbd 1000000
    update-alternatives --install /usr/bin/pack200 pack200 "$jdkBin"/pack200 1000000
    update-alternatives --install /usr/bin/policytool policytool "$jdkBin"/policytool 1000000
    update-alternatives --install /usr/bin/rmid rmid "$jdkBin"/rmid 1000000
    update-alternatives --install /usr/bin/rmiregistry rmiregistry "$jdkBin"/rmiregistry 1000000
    update-alternatives --install /usr/bin/servertool servertool "$jdkBin"/servertool 1000000
    update-alternatives --install /usr/bin/tnameserv tnameserv "$jdkBin"/tnameserv 1000000
    update-alternatives --install /usr/bin/unpack200 unpack200 "$jdkBin"/unpack200 1000000
    update-alternatives --install /usr/bin/jexec jexec "$jdkLib"/jexec 1000000
  fi
}
