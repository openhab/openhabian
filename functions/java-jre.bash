#!/usr/bin/env bash

## Install Java version from default repo
## Valid arguments: "11", "17"
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
  if [[ $1 == "BellSoft21" ]]; then
    liberica_install_apt
  else
    openjdk_install_apt "$1"
  fi

  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
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
    update-alternatives --set java /usr/lib/jvm/java-"${1}"-openjdk-armhf/bin/java
  fi
}

## Fetch BellSoft Liberica JDK using APT repository.
##
##    liberica_fetch_apt()
##
liberica_fetch_apt() {
  local pkgname="bellsoft-java21-lite"
  if ! apt-cache show $pkgname &> /dev/null; then
    local keyName="bellsoft_liberica"

    if ! add_keys "https://download.bell-sw.com/pki/GPG-KEY-bellsoft" "$keyName"; then return 1; fi

    echo -n "$(timestamp) [openHABian] Adding BellSoft repository to apt... "

    # architectures available: amd64, i386, arm64, armhf; those could be added to the repo string via [arch=...]
    if ! echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg] https://apt.bell-sw.com/ stable main" > /etc/apt/sources.list.d/bellsoft.list; then echo "FAILED"; return 1; fi
    if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi
  fi
}

## Install BellSoft Liberica JDK using APT repository.
##
##    liberica_install_apt()
##
liberica_install_apt() {
  local pkgname="bellsoft-java21-lite"
  if ! dpkg -s $pkgname &> /dev/null; then # Check if already is installed
    liberica_fetch_apt
    echo -n "$(timestamp) [openHABian] Installing BellSoft Liberica JDK... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" $pkgname; then echo "OK"; else echo "FAILED"; return 1; fi
  elif dpkg -s $pkgname &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Reconfiguring BellSoft Liberica JDK... "
    if cond_redirect dpkg-reconfigure $pkgname; then echo "OK"; else echo "FAILED"; return 1; fi
    # shellcheck disable=SC2012
    update-alternatives --set java "$(ls -d /usr/lib/jvm/bellsoft-java21-lite-* | head -n1)"/bin/java
  fi
}

# LEGACY SECTION

## Install appropriate Java version based on current choice.
## Valid arguments: "Adopt11", "Zulu11-32", or "Zulu11-64"
##
##    java_install_or_update(String type)
##
java_install_or_update() {
  # Just in case it gets called with the new arguments
  if [[ $1 -eq 11 ]] || [[ $1 -eq 17 ]]; then java_install "$1"; return 0; fi

  local branch

  branch="$(git -C "${BASEDIR:-/opt/openhabian}" rev-parse --abbrev-ref HEAD)"

  # Make sure we don't overwrite existing unsupported installations
  if ! [[ -x $(command -v java) ]] || [[ "$(java -version 2>&1 > /dev/null)" == *"Zulu"* ]] || dpkg -s 'openjdk-11-jre-headless' &> /dev/null || dpkg -s 'openjdk-17-jre-headless' &> /dev/null; then
    if ! [[ -x $(command -v java) ]] && [[ "${cached_java_opt:-Zulu11-32}" == "${java_opt:-Zulu11-32}" ]] && [[ -n $UNATTENDED ]] && java_zulu_dir; then
      echo "$(timestamp) [openHABian] Installing cached version of Java to ensure that some form of Java is installed!"
      java_zulu_prerequisite "${cached_java_opt:-Zulu11-32}"
      java_zulu_install "${cached_java_opt:-Zulu11-32}"
    fi
    if [[ $1 == "Zulu11-64" ]] || [[ $1 == "Zulu21-64" ]]; then
      if is_aarch64 || is_x86_64 && [[ $(getconf LONG_BIT) == 64 ]]; then
        if is_x86_64; then
          java_zulu_enterprise_apt "$@"
        else
          if cond_redirect java_zulu_update_available "$1"; then
            java_zulu_prerequisite "$1"
            if [[ $branch == "openHAB3" ]] && [[ -z $UNATTENDED ]]; then
              java_zulu_stable "$1"
            else
              java_zulu_fetch "$1"
              java_zulu_install "$1"
            fi
          fi
        fi
      else
        if [[ -n $INTERACTIVE ]]; then
          whiptail --title "Incompatible hardware detected" --msgbox "Zulu OpenJDK 64-bit: this option does not currently work on your platform.\\n\\nDefaulting to Java Zulu 11 32-bit installation." 9 80
        else
          echo "$(timestamp) [openHABian] Zulu OpenJDK 64-bit: this option does not currently work on your platform. Defaulting to Java Zulu 11 32-bit installation."
          if cond_redirect java_zulu_update_available "Zulu11-32"; then
            java_zulu_prerequisite "Zulu11-32"
            if [[ $branch == "openHAB3" ]] && [[ -z $UNATTENDED ]]; then
              java_zulu_stable "Zulu11-32"
            else
              java_zulu_fetch "Zulu11-32"
              java_zulu_install "Zulu11-32"
            fi
          fi
        fi
      fi
    elif [[ $1 == "BellSoft21" ]]; then
      liberica_install_apt
    else # Default to 32-bit installation
      if cond_redirect java_zulu_update_available "Zulu11-32"; then
        java_zulu_prerequisite "Zulu11-32"
        if [[ $branch == "openHAB3" ]] && [[ -z $UNATTENDED ]]; then
          java_zulu_stable "Zulu11-32"
        else
          java_zulu_fetch "Zulu11-32"
          java_zulu_install "Zulu11-32"
        fi
      fi
    fi
  fi
  if [[ -x $(command -v java) ]]; then
    cond_redirect java --version
  else
    echo "$(timestamp) [openHABian] Somewhere, somehow, something went wrong and Java has not been installed. Until resolved, openHAB will be broken."
  fi
}

## Install Java Zulu prerequisites (libc, libstdc++, zlib1g)
## Valid arguments: "Zulu11-32" or "Zulu11-64"
##
##    java_zulu_prerequisite(String type)
##
java_zulu_prerequisite() {
  echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (libc, libstdc++, zlib1g)... "
  if [[ $1 == "Zulu11-64" ]]; then
    if is_aarch64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      if dpkg -s 'libc6:arm64' 'libstdc++6:arm64' 'zlib1g:arm64' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture arm64
      if [[ -z $OFFLINE ]]; then
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" libc6:arm64 libstdc++6:arm64 zlib1g:arm64; then echo "OK"; else echo "FAILED"; return 1; fi
    elif is_x86_64 && [[ $(getconf LONG_BIT) == 64 ]]; then
      if dpkg -s 'libc6:amd64' 'libstdc++6:amd64' 'zlib1g:amd64' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture amd64
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" libc6:amd64 libstdc++6:amd64 zlib1g:amd64; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    if is_arm; then
      if dpkg -s 'libc6:armhf' 'libstdc++6:armhf' 'zlib1g:armhf' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture armhf
      if [[ -z $OFFLINE ]]; then
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" libc6:armhf libstdc++6:armhf zlib1g:armhf; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if dpkg -s 'libc6:i386' 'libstdc++6:i386' 'zlib1g:i386' &> /dev/null; then echo "OK"; return 0; fi
      dpkg --add-architecture i386
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" libc6:i386 libstdc++6:i386 zlib1g:i386; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
}

## Use special handling when installing Zulu on the stable branch
## Valid arguments: "Zulu11-32" or "Zulu11-64"
##
##    java_zulu_stable(String type)
##
java_zulu_stable() {
  local updateText
  local consoleText

  updateText="Updating Java may result in issues as it has not received extensive testing to verify compatibility.\\n\\nIf you wish to continue and encounter any errors please let us know so we can look into them to improve future compatibility."
  consoleText="[openHABian] WARNING: Untested Java Version, you may experience issues as this version of Java has not received extensive testing to verify compatibility."

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --defaultno --title "Untested Version of Java" --no-button "Back" --yes-button "Continue" --yesno "$updateText" 11 80); then echo "CANCELED"; return 0; fi
  else
    echo "$(timestamp) [openHABian] $consoleText"
  fi
  java_zulu_fetch "$1"
  java_zulu_install "$1"
}

## Install Java Zulu directly from fetched files
## Valid arguments: "Zulu11-32", or "Zulu11-64"
##
##    java_zulu_install(String type)
##
java_zulu_install() {
  local jdkBin
  local jdkLib

  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  jdkLib="$(find /opt/jdk/*/lib ... -print -quit)"

  if [[ $1 == "Zulu11-32" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 32-Bit OpenJDK... "
  elif [[ $1 == "Zulu11-64" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 11 64-Bit OpenJDK... "
  elif [[ $1 == "Zulu21-64" ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 21 64-Bit OpenJDK... "
  else
    echo "$(timestamp) [openHABian] Installing something that probably won't work... FAILED"
    return 1
  fi

  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi

  java_alternatives_reset
  # shellcheck disable=SC2016
  cond_redirect find "$jdkBin" -maxdepth 1 -perm -111 -type f -exec bash -c 'update-alternatives --install  /usr/bin/$(basename {}) $(basename {}) {} 1000000' \;
  echo "$jdkLib" > /etc/ld.so.conf.d/java.conf
  echo "$jdkLib"/jli >> /etc/ld.so.conf.d/java.conf
  echo "$jdkLib"/client >> /etc/ld.so.conf.d/java.conf
  if ldconfig; then echo "OK"; else echo "FAILED"; return 1; fi

  java_zulu_install_crypto_extension "$@"

  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi
}

## Fetch Java Zulu directly from Azul API v1
## Valid arguments: "Zulu11-32" or "Zulu11-64"
##
##    java_zulu_fetch(String type, String prefix)
##
java_zulu_fetch() {
  local downloadLink
  local jdkInstallLocation
  local link
  local temp

  jdkInstallLocation="${2}/opt/jdk"
  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?os=linux&ext=tar.gz&javafx=false"
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  if [[ $1 == "Zulu11-32" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 11 32-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=11&arch=arm&hw_bitness=32&abi=hard_float" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=11&arch=x86&hw_bitness=32&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  elif [[ $1 == "Zulu11-64" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 11 64-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=11&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=11&arch=x86&hw_bitness=64&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  elif [[ $1 == "Zulu21-64" ]]; then
    echo -n "$(timestamp) [openHABian] Downloading Java Zulu 21 64-Bit OpenJDK... "
    if is_arm; then
      downloadLink="$(curl "${link}&jdk_version=21&arch=arm&hw_bitness=64" -s -L -I -o /dev/null -w '%{url_effective}')"
    else
      downloadLink="$(curl "${link}&jdk_version=21&arch=x86&hw_bitness=64&bundle_type=jre" -s -L -I -o /dev/null -w '%{url_effective}')"
    fi
  fi
  if [[ -z $downloadLink ]]; then echo "FAILED (download link)"; return 1; fi

  if ! mkdir -p "$jdkInstallLocation"; then echo "FAILED (create directory)"; return 1; fi
  if ! cond_redirect wget -nv -O "$temp" "$downloadLink"; then echo "FAILED (download)"; rm -f "$temp"; return 1; fi
  if ! cond_redirect tar -xpzf "$temp" -C "$jdkInstallLocation"; then echo "FAILED (extract)"; rm -rf "${jdkInstallLocation:?}/$(basename "$downloadLink" | sed -e 's/.tar.gz//')"; rm -f "$temp"; return 1; fi
  if ! cond_redirect find "$jdkInstallLocation" -mindepth 1 -maxdepth 1 -name "$(basename "$downloadLink" | sed -e 's/.tar.gz//')" -prune -o -exec rm -rf {} \;; then echo "FAILED (clean directory)"; return 1; fi
  if rm -f "$temp"; then echo "OK"; else echo "FAILED (cleanup)"; return 1; fi
}

## Check if a newer version of Java Zulu is available.
## Returns 0 / true if new version exists
## Valid arguments: "Zulu11-32" or "Zulu11-64"
##
##    java_zulu_update_available(String type)
##
java_zulu_update_available() {
  if ! [[ -x $(command -v java) ]]; then return 0; fi

  local availableVersion
  local filter
  local javaArch
  local javaVersion
  local jdkBin
  local link
  local requestedArch

  if ! [[ -x $(command -v jq) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu prerequisites (jq)... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" jq; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  filter='[.jdk_version[] | tostring] | join(".")'
  jdkBin="$(find /opt/jdk/*/bin ... -print -quit)"
  # shellcheck disable=SC1117
  javaVersion="$("${jdkBin}"/java -version |& grep -m 1 -o "[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}[\.+][0-9]\{0,3\}" | head -1 | sed 's|+|.|g')"
  link="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?os=linux&ext=tar.gz&javafx=false"

  if [[ $1 == "Zulu11-32" ]]; then
    if is_arm; then
      requestedArch="aarch32hf"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=arm&hw_bitness=32&abi=hard_float" | jq -r "$filter")"
    else
      requestedArch="i686"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=x86&hw_bitness=32&bundle_type=jre" | jq -r "$filter")"
    fi
  elif [[ $1 == "Zulu11-64" ]]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=arm&hw_bitness=64" | jq -r "$filter")"
    else
      requestedArch="x64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=11&arch=x86&hw_bitness=64&bundle_type=jre" | jq -r "$filter")"
    fi
  elif [[ $1 == "Zulu21-64" ]]; then
    if is_arm; then
      requestedArch="aarch64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=21&arch=arm&hw_bitness=64" | jq -r "$filter")"
    else
      requestedArch="x64"
      availableVersion="$(curl -s -H "Accept: application/json" "${link}&jdk_version=21&arch=x86&hw_bitness=64&bundle_type=jre" | jq -r "$filter")"
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
## Package manager distributions are only available on x86-64bit platforms when checked in January 2021
##
##    java_zulu_enterprise_apt(String ver)
##
java_zulu_enterprise_apt() {
  local keyName="zulu_enterprise"

  if ! add_keys "https://www.azul.com/files/0xB1998361219BD9C9.txt" "$keyName"; then return 1; fi

  echo -n "$(timestamp) [openHABian] Adding Zulu repository to apt... "
  if ! echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg] https://repos.azul.com/zulu/deb/ stable main" > /etc/apt/sources.list.d/zulu-enterprise.list; then echo "FAILED"; return 1; fi
  if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

  if openhab_is_running; then
    cond_redirect systemctl stop openhab.service
  fi
  if [[ $1 == "Zulu21-64" ]]; then
    if ! dpkg -s 'zulu-21' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 21 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" zulu21; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  else
    if ! dpkg -s 'zulu-11' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing Zulu 11 Enterprise 64-Bit OpenJDK... "
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" zulu11; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
  if openhab_is_installed; then
    cond_redirect systemctl restart openhab.service
  fi

  java_zulu_install_crypto_extension "$@"
}

## Install Zulu Cryptography Extension Kit to enable cryptos using more then 128 bits
##
##    java_zulu_install_crypto_extension(String path)
##
# shellcheck disable=SC2120
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
