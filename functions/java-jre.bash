#!/usr/bin/env bash
# shellcheck disable=SC2119,SC2120

## Install appropriate Java version based on current choice.
## Valid arguments: "Adopt11", "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_install_or_update(String type)
##
java_install_or_update() {
  local branch

  branch="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"

  # Make sure we don't overwrite existing unsupported installations
  if ! [[ -x $(command -v java) ]] || [[ "$(java -version 2>&1 > /dev/null)" == *"Zulu"* ]] || [[ "$(java -version 2>&1 > /dev/null)" == *"AdoptOpenJDK"* ]]; then
    if ! [[ -x $(command -v java) ]] && [[ "${cached_java_opt:-Zulu8-32}" == "${java_opt:-Zulu8-32}" ]] && [[ -n $UNATTENDED ]] && java_zulu_dir; then
      echo "$(timestamp) [openHABian] Installing cached version of Java to ensure that some form of Java is installed!"
      java_zulu_prerequisite "${cached_java_opt:-Zulu8-32}"
      java_zulu_install "${cached_java_opt:-Zulu8-32}"
    fi
    if [[ $1 == "Adopt11" ]]; then
      adoptopenjdk_install_apt
    elif [[ $1 != "Adopt11" ]]; then
      if [[ "$(java -version 2>&1 > /dev/null)" == *"AdoptOpenJDK"* ]] && java_zulu_dir; then
        java_zulu_install "$1"
      fi
    fi
    if [[ $1 == "Zulu8-64" ]] || [[ $1 == "Zulu11-64" ]]; then
      if is_aarch64 || is_x86_64 && [[ $(getconf LONG_BIT) == 64 ]]; then
        if is_x86_64; then
          if [[ $1 == "Zulu8-64" ]]; then
            java_zulu_enterprise_apt "8"
          elif [[ $1 == "Zulu11-64" ]]; then
            java_zulu_enterprise_apt "11"
          fi
        else
          if [[ $1 == "Zulu8-64" ]]; then
            if cond_redirect java_zulu_update_available "Zulu8-64"; then
              java_zulu_prerequisite "Zulu8-64"
              if [[ $branch == "stable" ]] && [[ -z $UNATTENDED ]]; then
                java_zulu_stable "Zulu8-64"
              else
                java_zulu_fetch "Zulu8-64"
                java_zulu_install "Zulu8-64"
              fi
            fi
          elif [[ $1 == "Zulu11-64" ]]; then
            if cond_redirect java_zulu_update_available "Zulu11-64"; then
              java_zulu_prerequisite "Zulu11-64"
              if [[ $branch == "stable" ]] && [[ -z $UNATTENDED ]]; then
                java_zulu_stable "Zulu11-64"
              else
                java_zulu_fetch "Zulu11-64"
                java_zulu_install "Zulu11-64"
              fi
            fi
          fi
        fi
      else
        if [[ -n $INTERACTIVE ]]; then
          whiptail --title "Incompatible hardware detected" --msgbox "Zulu OpenJDK 64-bit: this option does not currently work on your platform.\\n\\nDefaulting to Java Zulu 8 32-bit installation." 9 80
        else
          echo "$(timestamp) [openHABian] Zulu OpenJDK 64-bit: this option does not currently work on your platform. Defaulting to Java Zulu 8 32-bit installation."
          if cond_redirect java_zulu_update_available "Zulu8-32"; then
            java_zulu_prerequisite "Zulu8-32"
            if [[ $branch == "stable" ]] && [[ -z $UNATTENDED ]]; then
              java_zulu_stable "Zulu8-32"
            else
              java_zulu_fetch "Zulu8-32"
              java_zulu_install "Zulu8-32"
            fi
          fi
        fi
      fi
    elif [[ $1 != "Adopt11" ]]; then # Default to 32-bit installation
      if [[ $1 == "Zulu11-32" ]]; then
        if cond_redirect java_zulu_update_available "Zulu11-32"; then
          java_zulu_prerequisite "Zulu11-32"
          if [[ $branch == "stable" ]] && [[ -z $UNATTENDED ]]; then
            java_zulu_stable "Zulu11-32"
          else
            java_zulu_fetch "Zulu11-32"
            java_zulu_install "Zulu11-32"
          fi
        fi
      elif cond_redirect java_zulu_update_available "Zulu8-32"; then
        java_zulu_prerequisite "Zulu8-32"
        if [[ $branch == "stable" ]] && [[ -z $UNATTENDED ]]; then
          java_zulu_stable "Zulu8-32"
        else
          java_zulu_fetch "Zulu8-32"
          java_zulu_install "Zulu8-32"
        fi
      fi
    fi
  fi
  if [[ -x $(command -v java) ]]; then
    cond_redirect java -version
  else
    echo "$(timestamp) [openHABian] Somewhere, somehow, something went wrong and Java has not been installed. Until resolved, openHAB will be broken."
  fi
}

## Install Java Zulu prerequisites (libc, libstdc++, zlib1g)
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_prerequisite(String type)
##
java_zulu_prerequisite() {
  echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (libc, libstdc++, zlib1g)... "
  if [[ $1 == "Zulu8-64" ]] || [[ $1 == "Zulu11-64" ]]; then
    if is_aarch64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      if dpkg -s 'libc6:arm64' 'libstdc++6:arm64' 'zlib1g:arm64' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture arm64
      if [[ -z $OFFLINE ]]; then
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes libc6:arm64 libstdc++6:arm64 zlib1g:arm64; then echo "OK"; else echo "FAILED"; return 1; fi
    elif is_x86_64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      if dpkg -s 'libc6:amd64' 'libstdc++6:amd64' 'zlib1g:amd64' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture amd64
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:amd64 libstdc++6:amd64 zlib1g:amd64; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    if is_arm; then
      if dpkg -s 'libc6:armhf' 'libstdc++6:armhf' 'zlib1g:armhf' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture armhf
      if [[ -z $OFFLINE ]]; then
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes libc6:armhf libstdc++6:armhf zlib1g:armhf; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if dpkg -s 'libc6:i386' 'libstdc++6:i386' 'zlib1g:i386' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture i386
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes libc6:i386 libstdc++6:i386 zlib1g:i386; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
}

## Use special handling when installing Zulu on the stable branch
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_stable(String type)
##
java_zulu_stable() {
  local updateText
  local consoleText

  updateText="Updating Java may result in issues as it has not recieved extensive testing to verify compatibility.\\n\\nIf you wish to continue and encounter any errors please let us know so we can look into them to improve future compatibility."
  consoleText="[openHABian] WARNING: Untested Java Version, you may experience issues as this version of Java has not recieved extensive testing to verify compatibility."

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --defaultno --title "Untested Version of Java" --no-button "Back" --yes-button "Continue" --yesno "$updateText" 11 80); then echo "CANCELED"; return 0; fi
  else
    echo "$(timestamp) [openHABian] $consoleText"
  fi
  java_zulu_fetch "$1"
  java_zulu_install "$1"
}

## Install Java Zulu directly from fetched files
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_install(String type)
##
java_zulu_install() {
  local jdkArch
  local jdkBin
  local jdkLib

  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  jdkLib="$(find /opt/jdk/*/lib ... -print -quit)"
  if [[ $1 == "Zulu8-64" ]] || [[ $1 == "Zulu11-64" ]]; then
    if is_aarch64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      jdkArch="aarch64"
    elif is_x86_64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      jdkArch="amd64"
    fi
  else
    if is_arm; then
      jdkArch="aarch32"
    else
      jdkArch="i386"
    fi
  fi

  if [[ $1 == "Zulu8-32" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 8 32-Bit OpenJDK... "
  elif [[ $1 == "Zulu11-32" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 32-Bit OpenJDK... "
  elif [[ $1 == "Zulu8-64" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 8 64-Bit OpenJDK... "
  elif [[ $1 == "Zulu11-64" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 64-Bit OpenJDK... "
  else
    echo "$(timestamp) [openHABian] Installing something that probably won't work... FAILED"
    return 1
  fi

  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi
  cond_redirect java_alternatives_reset

  cond_redirect update-alternatives --install /usr/bin/java java "$jdkBin"/java 1000000
  cond_redirect update-alternatives --install /usr/bin/jjs jjs "$jdkBin"/jjs 1000000
  cond_redirect update-alternatives --install /usr/bin/keytool keytool "$jdkBin"/keytool 1000000
  cond_redirect update-alternatives --install /usr/bin/pack200 pack200 "$jdkBin"/pack200 1000000
  cond_redirect update-alternatives --install /usr/bin/rmid rmid "$jdkBin"/rmid 1000000
  cond_redirect update-alternatives --install /usr/bin/rmiregistry rmiregistry "$jdkBin"/rmiregistry 1000000
  cond_redirect update-alternatives --install /usr/bin/unpack200 unpack200 "$jdkBin"/unpack200 1000000
  cond_redirect update-alternatives --install /usr/bin/jexec jexec "$jdkLib"/jexec 1000000
  if [[ $1 == "Zulu8"* ]]; then
    echo "$jdkLib"/"$jdkArch" > /etc/ld.so.conf.d/java.conf
    echo "$jdkLib"/"$jdkArch"/jli >> /etc/ld.so.conf.d/java.conf
    echo "$jdkLib"/"$jdkArch"/client >> /etc/ld.so.conf.d/java.conf
  elif [[ $1 == "Zulu11"* ]]; then
    echo "$jdkLib" > /etc/ld.so.conf.d/java.conf
    echo "$jdkLib"/jli >> /etc/ld.so.conf.d/java.conf
    echo "$jdkLib"/client >> /etc/ld.so.conf.d/java.conf
  fi
  if ldconfig; then echo "OK"; else echo "FAILED"; return 1; fi

  java_zulu_install_crypto_extension

  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi
}

## Fetch Java Zulu 8 directly from Azul API v1
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_fetch(String type, String prefix)
##
java_zulu_fetch() {
  local downloadLink
  local jdkInstallLocation
  local link

  jdkInstallLocation="${2}/opt/jdk"
  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?os=linux&ext=tar.gz&javafx=false"

  if [[ $1 == "Zulu8-32" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 8 32-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=8&arch=arm&hw_bitness=32&abi=hard_float" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=8&arch=x86&hw_bitness=32&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  elif [[ $1 == "Zulu11-32" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 11 32-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=11&arch=arm&hw_bitness=32&abi=hard_float" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=11&arch=x86&hw_bitness=32&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  elif [[ $1 == "Zulu8-64" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 8 64-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=8&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=8&arch=x86&hw_bitness=64&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  elif [[ $1 == "Zulu11-64" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 11 64-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=11&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=11&arch=x86&hw_bitness=64&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  fi
  if [[ -z $downloadLink ]]; then echo "FAILED (download link)"; return 1; fi

  if ! mkdir -p "$jdkInstallLocation"; then echo "FAILED (create directory)"; return 1; fi
  if ! rm -rf "${jdkInstallLocation:?}"/*; then echo "FAILED (clean directory)"; return 1; fi
  if ! cond_redirect wget -nv -O "$jdkInstallLocation"/zulu.tar.gz "$downloadLink"; then echo "FAILED (download)"; rm -rf "${jdkInstallLocation:?}"/*; return 1; fi
  if ! cond_redirect tar -xpzf "$jdkInstallLocation"/zulu.tar.gz -C "$jdkInstallLocation"; then echo "FAILED (extract)"; rm -rf "${jdkInstallLocation:?}"/*; return 1; fi
  if cond_redirect rm -rf "$jdkInstallLocation"/zulu.tar.gz; then echo "OK"; else echo "FAILED (cleanup)"; return 1; fi
}

## Check if a newer version of Java Zulu 8 is available.
## Returns 0 / true if new version exists
## Valid arguments: "Zulu8-32", "Zulu8-64", "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_update_available(String type)
##
java_zulu_update_available() {
  if ! [[ -x $(command -v java) ]]; then return 0; fi

  local availableVersion
  local filter8
  local filter11
  local javaArch
  local javaVersion
  local jdkBin
  local link
  local requestedArch

  if ! [[ -x $(command -v jq) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (jq)... "
    if cond_redirect apt-get install --yes jq; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  filter8='[.zulu_version[] | tostring] | join(".")'
  filter11='[.jdk_version[] | tostring] | join(".")'
  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  javaVersion="$("${jdkBin}"/java -version |& grep -m 1 -o "[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}[\.+][0-9]\{0,3\}" | head -1 | sed 's|+|.|g')"
  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?os=linux&ext=tar.gz&javafx=false"

  if [[ $1 == "Zulu8-32" ]]; then
    if is_arm; then
      requestedArch="aarch32hf"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=8&arch=arm&hw_bitness=32&abi=hard_float" | jq -r "$filter8")"
    else
      requestedArch="i686"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=8&arch=x86&hw_bitness=32&bundle_type=jre" | jq -r "$filter8")"
    fi
  elif [[ $1 == "Zulu11-32" ]]; then
    if is_arm; then
      requestedArch="aarch32hf"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=arm&hw_bitness=32&abi=hard_float" | jq -r "$filter11")"
    else
      requestedArch="i686"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=x86&hw_bitness=32&bundle_type=jre" | jq -r "$filter11")"
    fi
  elif [[ $1 == "Zulu8-64" ]]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=8&arch=arm&hw_bitness=64" | jq -r "$filter8")"
    else
      requestedArch="x64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=8&arch=x86&hw_bitness=64&bundle_type=jre" | jq -r "$filter8")"
    fi
  elif [[ $1 == "Zulu11-64" ]]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=arm&hw_bitness=64" | jq -r "$filter11")"
    else
      requestedArch="x64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=x86&hw_bitness=64&bundle_type=jre" | jq -r "$filter11")"
    fi
  fi
  if [[ -z $requestedArch ]] || [[ -z $availableVersion ]]; then echo "FAILED (java update available)"; return 1; fi

  if [[ $jdkBin == *"aarch32hf"* ]]; then javaArch="aarch32hf"; fi
  if [[ $jdkBin == *"i686"* ]]; then javaArch="i686"; fi
  if [[ $jdkBin == *"aarch64"* ]]; then javaArch="aarch64"; fi
  if [[ $jdkBin == *"x64"* ]]; then javaArch="x64"; fi

  if [[ $javaVersion == "$availableVersion" ]] && [[ $javaArch == "$requestedArch" ]]; then
    return 1 # Java is up-to-date
  fi
}

## Install Azul's Java Zulu Enterprise using APT repository.
## Package manager distributions are only available on x86-64bit platforms when checked in July 2020
## Valid arguments: "8" or "11"
##
##    java_zulu_enterprise_apt(String ver)
##
java_zulu_enterprise_apt() {
    if ! add_keys "https://www.azul.com/files/0xB1998361219BD9C9.txt"; then return 1; fi

    echo -n "$(timestamp) [openHABian] Adding Zulu repository to apt... "
    if ! echo "deb http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-enterprise.list; then echo "FAILED"; return 1; fi
    if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

    if openhab_is_running; then
      cond_redirect systemctl stop openhab.service
    fi
    if [[ $1 == "8" ]] && ! dpkg -s 'zulu-8' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 8 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes zulu-8; then echo "OK"; else echo "FAILED"; return 1; fi
    elif [[ $1 == "11" ]] && ! dpkg -s 'zulu-11' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 11 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes zulu-11; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
    if openhab_is_installed; then
      cond_redirect systemctl restart openhab.service
    fi

    java_zulu_install_crypto_extension
}

## Install Zulu Cryptography Extension Kit to enable cryptos using more then 128 bits
##
##    java_zulu_install_crypto_extension(String path)
##
java_zulu_install_crypto_extension() {
  if [[ -n $OFFLINE ]]; then
    echo "$(timestamp) [openHABian] Using cached Java Zulu CEK to enable unlimited cipher strength... OK"
    return 0
  fi

  local jdkSecurity
  local policyTempLocation

  jdkSecurity="${1:-"$(realpath /usr/bin/java | sed 's|/java||')/../lib/security"}"
  policyTempLocation="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Installing Java Zulu CEK to enable unlimited cipher strength... "
  if ! cond_redirect mkdir -p "$jdkSecurity"; then echo "FAILED (create directory)"; return 1; fi
  if ! cond_redirect wget -qO "$policyTempLocation"/crypto.zip https://cdn.azul.com/zcek/bin/ZuluJCEPolicies.zip; then echo "FAILED (download)"; rm -rf "$policyTempLocation"; return 1; fi
  if ! cond_redirect unzip "$policyTempLocation"/crypto.zip -d "$policyTempLocation"; then echo "FAILED (unzip)"; rm -rf "$policyTempLocation"; return 1; fi
  if cond_redirect cp -u "$policyTempLocation"/ZuluJCEPolicies/*.jar "$jdkSecurity"; then echo "OK"; else echo "FAILED (copy)"; rm -rf "$policyTempLocation"; return 1; fi

  cond_redirect rm -rf "$policyTempLocation"
}

## Fetch AdoptOpenJDK using APT repository.
##
##    adoptopenjdk_fetch_apt()
##
adoptopenjdk_fetch_apt() {
  if ! dpkg -s 'software-properties-common' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing AdoptOpenJDK prerequisites (software-properties-common)... "
    if ! cond_redirect apt-get install --yes software-properties-common; then echo "FAILED"; return 1; fi
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
##    adoptopenjdk_install_apt()
##
adoptopenjdk_install_apt() {
  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi
  if ! dpkg -s 'adoptopenjdk-11-hotspot-jre' &> /dev/null; then # Check if already is installed
    adoptopenjdk_fetch_apt
    echo -n "$(timestamp) [openHABian] Installing AdoptOpenJDK 11... "
    cond_redirect java_alternatives_reset
    if cond_redirect apt-get install --yes adoptopenjdk-11-hotspot-jre; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s 'adoptopenjdk-11-hotspot-jre' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Reconfiguring AdoptOpenJDK 11... "
    cond_redirect java_alternatives_reset
    if cond_redirect dpkg-reconfigure adoptopenjdk-11-hotspot-jre; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi
}

## Reset Java in update-alternatives
##
##    java_alternatives_reset()
##
java_alternatives_reset() {
  update-alternatives --quiet --remove-all java &> /dev/null
  update-alternatives --quiet --remove-all jjs &> /dev/null
  update-alternatives --quiet --remove-all keytool &> /dev/null
  update-alternatives --quiet --remove-all pack200 &> /dev/null
  update-alternatives --quiet --remove-all rmid &> /dev/null
  update-alternatives --quiet --remove-all rmiregistry &> /dev/null
  update-alternatives --quiet --remove-all unpack200 &> /dev/null
  update-alternatives --quiet --remove-all jexec &> /dev/null
  update-alternatives --quiet --remove-all javac &> /dev/null # TODO: remove sometime late 2020
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
