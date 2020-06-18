#!/usr/bin/env bash
# shellcheck disable=SC2181
# shellcheck disable=SC2144
# shellcheck disable=SC2069

## Install appropriate Java version based on current choice.
## Valid arguments: "Adopt11", "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_install_or_update(String type)
##
java_install_or_update() {
  local branch

  branch=$(git -C "/opt/openhabian" rev-parse --abbrev-ref HEAD)

  # Make sure we don't overwrite existing unsupported installations
  if ! [ -x "$(command -v java)" ] || [[ ! "$(java -version 2>&1> /dev/null)" == *"Zulu"* ]] || [[ ! "$(java -version 2>&1> /dev/null)" == *"AdoptOpenJDK"* ]]; then
    if [ "$1" == "Adopt11" ]; then
      cond_redirect adoptopenjdk_install_apt
    elif [ "$1" != "Adopt11" ]; then
      if [[ "$(java -version 2>&1> /dev/null)" == *"AdoptOpenJDK"* ]] && [ -d /opt/jdk/* ]; then
        cond_redirect java_zulu_install "$1"
      fi
      if [ "$1" == "Zulu8-64" ] || [ "$1" == "Zulu11-64" ]; then
        if is_aarch64 || is_x86_64 && [ "$(getconf LONG_BIT)" == "64" ]; then
          if is_x86_64; then
            if [ "$1" == "Zulu8-64" ]; then
              cond_redirect java_zulu_enterprise_apt "8"
            elif [ "$1" == "Zulu11-64" ]; then
              cond_redirect java_zulu_enterprise_apt "11"
            fi
          else
            if [ "$1" == "Zulu8-64" ]; then
              if cond_redirect java_zulu_update_available "Zulu8-64"; then
                echo -n "$(timestamp) [openHABian] Installing Java Zulu 8 64-Bit OpenJDK... "
                cond_redirect java_zulu_prerequisite "Zulu8-64"
                if ! [ -x "$(command -v java)" ] && [ -d /opt/jdk/* ]; then
                  cond_redirect java_zulu_install "Zulu8-64"
                elif [ "$branch" == "stable" ] && [ -z "$UNATTENDED" ]; then
                  java_zulu_stable "Zulu8-64"
                else
                  cond_redirect java_zulu_fetch "Zulu8-64"
                  cond_redirect java_zulu_install "Zulu8-64"
                fi
              fi
            elif [ "$1" == "Zulu11-64" ]; then
              if cond_redirect java_zulu_update_available "Zulu11-64"; then
                echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 64-Bit OpenJDK... "
                cond_redirect java_zulu_prerequisite "Zulu11-64"
                if ! [ -x "$(command -v java)" ] && [ -d /opt/jdk/* ]; then
                  cond_redirect java_zulu_install "Zulu11-64"
                elif [ "$branch" == "stable" ] && [ -z "$UNATTENDED" ]; then
                  java_zulu_stable "Zulu11-64"
                else
                  cond_redirect java_zulu_fetch "Zulu11-64"
                  cond_redirect java_zulu_install "Zulu11-64"
                fi
              fi
            fi
          fi
        else
          if [ -n "$INTERACTIVE" ]; then
            whiptail --title "Incompatible hardware detected" --msgbox "Zulu OpenJDK 64-bit: this option does not currently work on your platform.\\n\\nDefaulting to Java Zulu 8 32-bit installation." 9 80
          else
            echo "$(timestamp) [openHABian] Zulu OpenJDK 64-bit: this option does not currently work on your platform. Defaulting to Java Zulu 8 32-bit installation."
            if cond_redirect java_zulu_update_available "Zulu8-32"; then
              echo -n "$(timestamp) [openHABian] Installing Java Zulu 8 32-Bit OpenJDK... "
              cond_redirect java_zulu_prerequisite "Zulu8-32"
              if ! [ -x "$(command -v java)" ] && [ -d /opt/jdk/* ]; then
                cond_redirect java_zulu_install "Zulu8-32"
              elif [ "$branch" == "stable" ] && [ -z "$UNATTENDED" ]; then
                java_zulu_stable "Zulu8-32"
              else
                cond_redirect java_zulu_fetch "Zulu8-32"
                cond_redirect java_zulu_install "Zulu8-32"
              fi
            fi
          fi
        fi
      else # Default to 32-bit installation
        if [ "$1" == "Zulu11-32" ]; then
          if cond_redirect java_zulu_update_available "Zulu11-32"; then
            echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 32-Bit OpenJDK... "
            cond_redirect java_zulu_prerequisite "Zulu11-32"
            if ! [ -x "$(command -v java)" ] && [ -d /opt/jdk/* ]; then
              cond_redirect java_zulu_install "Zulu11-32"
            elif [ "$branch" == "stable" ] && [ -z "$UNATTENDED" ]; then
              java_zulu_stable "Zulu11-32"
            else
              cond_redirect java_zulu_fetch "Zulu11-32"
              cond_redirect java_zulu_install "Zulu11-32"
            fi
          fi
        elif cond_redirect java_zulu_update_available "Zulu8-32"; then
          echo -n "$(timestamp) [openHABian] Installing Java Zulu 8 32-Bit OpenJDK... "
          cond_redirect java_zulu_prerequisite "Zulu8-32"
          if ! [ -x "$(command -v java)" ] && [ -d /opt/jdk/* ]; then
            cond_redirect java_zulu_install "Zulu8-32"
          elif [ "$branch" == "stable" ] && [ -z "$UNATTENDED" ]; then
            java_zulu_stable "Zulu8-32"
          else
            cond_redirect java_zulu_fetch "Zulu8-32"
            cond_redirect java_zulu_install "Zulu8-32"
          fi
        fi
      fi
    fi
  fi
  if [ -x "$(command -v java)" ]; then
    cond_redirect java -version
    echo "OK"
  fi
}

## Install Java Zulu prerequisite libc
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_prerequisite(String arch)
##
java_zulu_prerequisite() {
  echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (libc, libstdc++, zlib1g)... "
  if [ "$1" == "Zulu8-64" ] || [ "$1" == "Zulu11-64" ]; then
    if is_aarch64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      if dpkg -s 'libc6:arm64' 'libstdc++6:arm64' 'zlib1g:arm64' > /dev/null 2>&1; then echo "OK"; return 0; fi
      dpkg --add-architecture arm64
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:arm64 libstdc++6:arm64 zlib1g:arm64; then echo "OK"; else echo "FAILED"; return 1; fi
    elif is_x86_64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      if dpkg -s 'libc6:amd64' 'libstdc++6:amd64' 'zlib1g:amd64' > /dev/null 2>&1; then echo "OK"; return 0; fi
      dpkg --add-architecture amd64
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:amd64 libstdc++6:amd64 zlib1g:amd64; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    if is_arm; then
      if dpkg -s 'libc6:armhf' 'libstdc++6:armhf' 'zlib1g:armhf' > /dev/null 2>&1; then echo "OK"; return 0; fi
      dpkg --add-architecture armhf
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:armhf libstdc++6:armhf zlib1g:armhf; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if dpkg -s 'libc6:i386' 'libstdc++6:i386' 'zlib1g:i386' > /dev/null 2>&1; then echo "OK"; return 0; fi
      dpkg --add-architecture i386
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:i386 libstdc++6:i386 zlib1g:i386; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
}

## Use special handling when installing Zulu on the stable branch
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_stable(String arch)
##
java_zulu_stable() {
  local updateText
  local consoleText

  updateText="Updating Java may result in issues as it has not recieved extensive testing to verify compatibility.\\n\\nIf you wish to continue and encounter any errors please let us know so we can look into them to improve future compatibility."
  consoleText="[openHABian] WARNING: Untested Java Version, you may experience issues as this version of Java has not recieved extensive testing to verify compatibility."

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --defaultno --title "Untested Version of Java" --no-button "Back" --yes-button "Continue" --yesno "$updateText" 11 80); then echo "CANCELED"; return 0; fi
  else
    echo "$(timestamp) [openHABian] $consoleText"
  fi
  cond_redirect java_zulu_fetch "$1"
  cond_redirect java_zulu_install "$1"
}

## Install Java Zulu directly from fetched files
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_install(String arch)
##
java_zulu_install() {
  local jdkArch
  local jdkBin
  local jdkLib

  if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
    cond_redirect systemctl stop openhab2.service
  fi
  cond_redirect java_alternatives_reset

  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  jdkLib="$(find /opt/jdk/*/lib ... -print -quit)"

  if [ "$1" == "Zulu8-64" ] || [ "$1" == "Zulu11-64" ]; then
    if is_aarch64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      jdkArch="aarch64"
    elif is_x86_64 && [ "$(getconf LONG_BIT)" == "64" ]; then
      jdkArch="amd64"
    fi
  else
    if is_arm; then
      jdkArch="aarch32"
    else
      jdkArch="i386"
    fi
  fi

  cond_redirect update-alternatives --install /usr/bin/java java "$jdkBin"/java 1000000
  cond_redirect update-alternatives --install /usr/bin/jjs jjs "$jdkBin"/jjs 1000000
  cond_redirect update-alternatives --install /usr/bin/keytool keytool "$jdkBin"/keytool 1000000
  cond_redirect update-alternatives --install /usr/bin/pack200 pack200 "$jdkBin"/pack200 1000000
  cond_redirect update-alternatives --install /usr/bin/rmid rmid "$jdkBin"/rmid 1000000
  cond_redirect update-alternatives --install /usr/bin/rmiregistry rmiregistry "$jdkBin"/rmiregistry 1000000
  cond_redirect update-alternatives --install /usr/bin/unpack200 unpack200 "$jdkBin"/unpack200 1000000
  cond_redirect update-alternatives --install /usr/bin/jexec jexec "$jdkLib"/jexec 1000000
  echo "$jdkLib"/"$jdkArch" > /etc/ld.so.conf.d/java.conf
  echo "$jdkLib"/"$jdkArch"/jli >> /etc/ld.so.conf.d/java.conf
  ldconfig
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; return 1; fi

  cond_redirect java_zulu_install_crypto_extension

  if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
    cond_redirect systemctl start openhab2.service
  fi
}

## Fetch Java Zulu 8 directly from Azul API v1
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_fetch(String arch)
##
java_zulu_fetch() {
  local link8
  local link11
  local downloadlink
  local jdkInstallLocation

  jdkInstallLocation="/opt/jdk"
  link11="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?jdk_version=11&ext=tar.gz&os=linux"
  link8="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?jdk_version=8&ext=tar.gz&os=linux"

  if [ "$1" == "Zulu8-32" ]; then
    if is_arm; then
      downloadlink=$(curl "${link8}&arch=arm&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    else
      downloadlink=$(curl "${link8}&arch=x86&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    fi
  elif [ "$1" == "Zulu11-32" ]; then
    if is_arm; then
      downloadlink=$(curl "${link11}&arch=arm&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    else
      downloadlink=$(curl "${link11}&arch=x86&hw_bitness=32" -s -L -I -o /dev/null -w '%{url_effective}' | sed -e 's#32sf#32hf#g')
    fi
  elif [ "$1" == "Zulu8-64" ]; then
    if is_arm; then
      downloadlink=$(curl "${link8}&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    else
      downloadlink=$(curl "${link8}&arch=x86&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    fi
  elif [ "$1" == "Zulu11-64" ]; then
    if is_arm; then
      downloadlink=$(curl "${link11}&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    else
      downloadlink=$(curl "${link11}&arch=x86&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')
    fi
  fi
  if [ -z "$downloadlink" ]; then echo "FAILED (java download link)"; return 1; fi

  mkdir -p $jdkInstallLocation
  rm -rf "${jdkInstallLocation:?}"/*
  cond_redirect wget -qO "$jdkInstallLocation"/zulu.tar.gz "$downloadlink"
  tar -xpzf "$jdkInstallLocation"/zulu.tar.gz -C "$jdkInstallLocation"
  if [ $? -ne 0 ]; then echo "FAILED"; rm -rf "${jdkInstallLocation:?}"/*; return 1; fi
  rm -rf "$jdkInstallLocation"/zulu.tar.gz
}

## Check if a newer version of Java Zulu 8 is available.
## Returns 0 / true if new version exists
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_update_available(String arch)
##
java_zulu_update_available() {
  if [ ! -x "$(command -v java)" ] || [[ "$(java -version 2>&1> /dev/null)" == *"AdoptOpenJDK"* ]]; then return 0; fi

  local availableVersion
  local filter
  local javaArch
  local jdkBin
  local javaVersion
  local link11
  local link8
  local requestedArch

  if ! [ -x "$(command -v jq)" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (jq)... "
    if cond_redirect apt-get install --yes jq; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  filter='[.zulu_version[] | tostring] | join(".")'
  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  javaVersion="$("${jdkBin}"/java -version |& grep -m 1 -o "[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}")"
  link11="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?jdk_version=11&ext=tar.gz&os=linux"
  link8="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?jdk_version=8&ext=tar.gz&os=linux"

  if [ "$1" == "Zulu8-32" ]; then
    if is_arm; then
      requestedArch="aarch32hf"
      availableVersion=$(curl -s -H "Accept: application/json" "${link8}&arch=arm&hw_bitness=32" | jq -r "$filter")
    else
      requestedArch="i686"
      availableVersion=$(curl -s -H "Accept: application/json" "${link8}&arch=x86&hw_bitness=32" | jq -r "$filter")
    fi
  elif [ "$1" == "Zulu11-32" ]; then
    if is_arm; then
      requestedArch="aarch32hf"
      availableVersion=$(curl -s -H "Accept: application/json" "${link11}&arch=arm&hw_bitness=32" | jq -r "$filter")
    else
      requestedArch="i686"
      availableVersion=$(curl -s -H "Accept: application/json" "${link11}&arch=x86&hw_bitness=32" | jq -r "$filter")
    fi
  elif [ "$1" == "Zulu8-64" ]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion=$(curl -s -H "Accept: application/json" "${link8}&arch=arm&hw_bitness=64" | jq -r "$filter")
    else
      requestedArch="x64"
      availableVersion=$(curl -s -H "Accept: application/json" "${link8}&arch=x86&hw_bitness=64" | jq -r "$filter")
    fi
  elif [ "$1" == "Zulu11-64" ]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion=$(curl -s -H "Accept: application/json" "${link11}&arch=arm&hw_bitness=64" | jq -r "$filter")
    else
      requestedArch="x64"
      availableVersion=$(curl -s -H "Accept: application/json" "${link11}&arch=x86&hw_bitness=64" | jq -r "$filter")
    fi
  fi
  if [ -z "$requestedArch" ] && [ -z "$availableVersion" ]; then echo "FAILED (java update available)"; return 1; fi

  if [[ "$("${jdkBin}"/java -version 2>&1> /dev/null)" == *"aarch32hf"* ]]; then javaArch="aarch32hf"; fi
  if [[ "$("${jdkBin}"/java -version 2>&1> /dev/null)" == *"i686"* ]]; then javaArch="i686"; fi
  if [[ "$("${jdkBin}"/java -version 2>&1> /dev/null)" == *"aarch64"* ]]; then javaArch="aarch64"; fi
  if [[ "$("${jdkBin}"/java -version 2>&1> /dev/null)" == *"x64"* ]]; then javaArch="x64"; fi

  if [[ $javaVersion == "$availableVersion" ]] && [[ $javaArch == "$requestedArch" ]]; then
    return 1 # Java is up-to-date
  fi
}

## Install Azul's Java Zulu Enterprise using APT repository.
## (package manager distributions only available on x86-64bit platforms when checked in April 2020)
## Valid arguments: "8" or "11"
##
##    java_zulu_enterprise_apt(String ver)
##
java_zulu_enterprise_apt() {
  if (! dpkg -s 'zulu-8' > /dev/null 2>&1) || (! dpkg -s 'zulu-11' > /dev/null 2>&1); then # Check if already is installed
    echo -n "$(timestamp) [openHABian] Adding Zulu keys to apt... "
    if cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9; then echo "OK"; else echo "FAILED"; return 1; fi

    echo -n "$(timestamp) [openHABian] Adding Zulu repository to apt... "
    if ! echo "deb http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-enterprise.list; then echo "FAILED"; return 1; fi
    if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

    if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
      cond_redirect systemctl stop openhab2.service
    fi
    if [ "$1" == "8" ]; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 8 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes zulu-8; then echo "OK"; else echo "FAILED"; return 1; fi
    elif [ "$1" == "11" ]; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 11 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes zulu-11; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
    if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
      cond_redirect systemctl start openhab2.service
    fi

    java_zulu_install_crypto_extension
  fi
}

## Install Zulu Cryptography Extension Kit to enable cryptos using more then 128 bits
##
java_zulu_install_crypto_extension() {
  local jdkSecurity
  local policyTempLocation

  jdkSecurity="$(dirname "$(readlink -f "$(command -v java)")")/../lib/security"
  policyTempLocation="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Installing Java Zulu Cryptography Extension Kit to enable cryptos using more then 128 bits... "
  mkdir -p "$jdkSecurity"
  if ! cond_redirect wget -qO "$policyTempLocation"/crypto.zip https://cdn.azul.com/zcek/bin/ZuluJCEPolicies.zip; then echo "FAILED (download)"; return 1; fi
  if ! cond_redirect unzip "$policyTempLocation"/crypto.zip -d "$policyTempLocation"; then echo "FAILED (unzip)"; return 1; fi
  if cond_redirect cp "$policyTempLocation"/ZuluJCEPolicies/*.jar "$jdkSecurity"; then echo "OK"; else echo "FAILED (copy)"; return 1; fi

  rm -rf "$policyTempLocation"
}

## Fetch AdoptOpenJDK using APT repository.
##
adoptopenjdk_fetch_apt() {
  if ! dpkg -s 'software-properties-common' > /dev/null 2>&1; then
    if ! cond_redirect apt-get install --yes software-properties-common; then echo "FAILED (AdoptOpenJDK prerequisites)"; return 1; fi
  fi

  if ! add_keys "https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public"; then return 1; fi

  echo -n "$(timestamp) [openHABian] Adding AdoptOpenJDK repository to apt... "
  echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb buster main" > /etc/apt/sources.list.d/adoptopenjdk.list
  if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Fetching AdoptOpenJDK... "
  if cond_redirect apt-get install --download-only --yes adoptopenjdk-11-hotspot-jre; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Install AdoptOpenJDK using APT repository.
##
adoptopenjdk_install_apt() {
  if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
    cond_redirect systemctl stop openhab2.service
  fi
  if ! dpkg -s 'adoptopenjdk-11-hotspot-jre' > /dev/null 2>&1; then # Check if already is installed
    adoptopenjdk_fetch_apt
    echo -n "$(timestamp) [openHABian] Installing AdoptOpenJDK 11... "
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes adoptopenjdk-11-hotspot-jre; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s 'adoptopenjdk-11-hotspot-jre' > /dev/null 2>&1; then
    echo -n "$(timestamp) [openHABian] Reconfiguring AdoptOpenJDK 11... "
    cond_redirect java_alternatives_reset
    if cond_redirect dpkg-reconfigure adoptopenjdk-11-hotspot-jre; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if [ -z "$UNATTENDED" ] && [ -z "$BATS_TEST_NAME" ]; then
    cond_redirect systemctl start openhab2.service
  fi
}

## Reset Java in update-alternatives
##
java_alternatives_reset() {
  update-alternatives --quiet --remove-all java
  update-alternatives --quiet --remove-all jjs
  update-alternatives --quiet --remove-all keytool
  update-alternatives --quiet --remove-all pack200
  update-alternatives --quiet --remove-all policytool
  update-alternatives --quiet --remove-all rmid
  update-alternatives --quiet --remove-all rmiregistry
  update-alternatives --quiet --remove-all unpack200
  update-alternatives --quiet --remove-all jexec
  update-alternatives --quiet --remove-all javac # TODO: remove sometime late 2020
}
