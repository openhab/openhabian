#!/usr/bin/env bash
# shellcheck disable=SC2181

## Install best suitible java version depending on platform.
## Valid argument choose between: 64-bit, 32-bit
##
##    java_install_and_update(String arch)
##
java_install_or_update(){
  # Make sure we don't overwrite existing none Java installations
  if ! [ -x "$(command -v java)" ] || [[ ! "$(java -version)" == *"Zulu"* ]] || [[ ! "$(java -version)" == *"AdoptOpenJDK"* ]]; then
    cond_redirect systemctl stop openhab2.service

    if [ "$1" == "64-bit" ]; then
      java_adoptopenjdk_8_tar 64-bit

    else # Default to 32-bit installation
      java_adoptopenjdk_8_tar 32-bit
    fi

    cond_redirect systemctl start openhab2.service
  fi
}

## Install Java AdoptOpenJDK 8 from direct from fetched .TAR file
## Valid argument choose between: 64-bit, 32-bit
##
##    java_adoptopenjdk_8_tar(String arch)
##
java_adoptopenjdk_8_tar(){
  local link
  local jdkTempLocation
  local jdkInstallLocation
  local jdkBin
  local jdkLib
  local jdkArch
  if [ "$1" == "32-bit" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java AdoptOpenJDK 32-Bit OpenJDK... "
    if is_arm; then
      link="https://api.adoptopenjdk.net/v3/binary/latest/8/ga/linux/arm/jdk/hotspot/normal/adoptopenjdk?project=jdk"
      jdkArch="aarch32"
    else
      link="https://api.adoptopenjdk.net/v3/binary/latest/8/ga/linux/x32/jdk/hotspot/normal/adoptopenjdk?project=jdk"
      jdkArch="i386"
    fi

    if is_aarch64; then
      dpkg --add-architecture armhf
      cond_redirect apt-get update
      cond_redirect apt -y install libc6:armhf libncurses5:armhf libstdc++6:armhf
    fi

    if is_x86_64; then
      dpkg --add-architecture i386
      cond_redirect apt update
      cond_redirect apt -y install libc6:i386 libncurses5:i386 libstdc++6:i386
    fi

  elif [ "$1" == "64-bit" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java AdopyOpenJDK 64-Bit OpenJDK... "
    if is_arm; then
      link="https://api.adoptopenjdk.net/v3/binary/latest/8/ga/linux/aarch64/jdk/hotspot/normal/adoptopenjdk?project=jdk"
      jdkArch="aarch64"
    else
      link="https://api.adoptopenjdk.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/adoptopenjdk?project=jdk"
      jdkArch="amd64"
    fi

  else
    echo -n "[DEBUG] Unvalid argument to function java_adoptopenjdk_8_tar()"
    exit 1
  fi
  jdkTempLocation="$(mktemp -d /tmp/openhabian.XXXXX)"
  if [ -z "$jdkTempLocation" ]; then echo "FAILED"; exit 1; fi
  jdkInstallLocation="/opt/jdk"
  mkdir -p $jdkInstallLocation

  # Fetch and copy new JAVA runtime
  cond_redirect wget -nv -O "$jdkTempLocation"/adoptopenjdk8.tar.gz "$link"
  tar -xpzf "$jdkTempLocation"/adoptopenjdk8.tar.gz -C "${jdkTempLocation}"
  if [ $? -ne 0 ]; then echo "FAILED"; rm -rf "$jdkTempLocation"/adoptopenjdk8.tar.gz; exit 1; fi
  rm -rf "$jdkTempLocation"/adoptopenjdk8.tar.gz "${jdkInstallLocation:?}"/*
  mv "${jdkTempLocation}"/* "${jdkInstallLocation}"/

  rmdir "${jdkTempLocation}"

  # Update system with new installation
  jdkBin=$(find "${jdkInstallLocation}"/*/bin ... -print -quit)
  jdkLib=$(find "${jdkInstallLocation}"/*/lib ... -print -quit)
  cond_redirect update-alternatives --remove-all java
  cond_redirect update-alternatives --remove-all javac
  cond_redirect update-alternatives --install /usr/bin/java java "$jdkBin"/java 1083000
  cond_redirect update-alternatives --install /usr/bin/javac javac "$jdkBin"/javac 1083000
  echo "$jdkLib"/"$jdkArch" > /etc/ld.so.conf.d/java.conf
  echo "$jdkLib"/"$jdkArch"/jli >> /etc/ld.so.conf.d/java.conf
  ldconfig

  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}
