#!/usr/bin/env bash
# shellcheck disable=SC2181

## Install best suitible java version depending on platform. 
## Valid argument choose between: 64-bit, 32-bit
##
##    java_install_and_update(String arch)
##
java_install_or_update(){
  # Make sure we don't overwrite existing none Java Zulu installations 
  if ! [ -x "$(command -v java)" ] || [[ ! "$(java -version)" == *"Zulu"* ]]; then
    cond_redirect systemctl stop openhab2.service

    if [ "$1" == "64-bit" ]; then
      if is_x86_64; then
        java_zulu_enterprise_8_apt
      else
        if java_zulu_tar_update_available; then
          java_zulu_8_tar 64-bit
        fi
      fi

    else # Default to 32-bit installation
      if java_zulu_tar_update_available; then
          java_zulu_8_tar 32-bit
      fi
    fi
    cond_redirect systemctl start openhab2.service
  fi
}

## Install Java Zulu 8 from direct from fetched .TAR file
## Valid argument choose between: 64-bit, 32-bit
##
##    java_zulu_8_tar(String arch)
##
java_zulu_8_tar(){
  local link
  local jdkTempLocation
  local jdkInstallLocation
  local jdkBin
  local jdkLib 
  local jdkArch
  local jdkSecurity
  if [ "$1" == "32-bit" ]; then
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 32-Bit OpenJDK... "
    if is_arm; then 
      #link="$(fetch_zulu_tar_url "arm-32-bit-hf")";
      link="https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch32hf.tar.gz"
      jdkArch="aarch32"
    else 
      #link="$(fetch_zulu_tar_url "x86-32-bit")";
      link="https://cdn.azul.com/zulu/bin/zulu8.42.0.21-ca-jdk8.0.232-linux_i686.tar.gz"
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
    echo -n "$(timestamp) [openHABian] Installing Java Zulu 64-Bit OpenJDK... "
    if is_arm; then 
      #link="$(fetch_zulu_tar_url "arm-64-bit")";
      link="https://cdn.azul.com/zulu-embedded/bin/zulu8.40.0.178-ca-jdk1.8.0_222-linux_aarch64.tar.gz"
      jdkArch="aarch64"
    else 
      #link="$(fetch_zulu_tar_url "x86-64-bit")";
      link="https://cdn.azul.com/zulu/bin/zulu8.42.0.21-ca-jdk8.0.232-linux_x64.tar.gz"
      jdkArch="amd64"
    fi

  else 
    echo -n "[DEBUG] Unvalid argument to function java_zulu_8_tar()"
    exit 1
  fi
  jdkTempLocation="$(mktemp -d /tmp/openhabian.XXXXX)"
  if [ -z "$jdkTempLocation" ]; then echo "FAILED"; exit 1; fi
  jdkInstallLocation="/opt/jdk"
  mkdir -p $jdkInstallLocation

  # Fetch and copy new JAVA runtime
  cond_redirect wget -nv -O "$jdkTempLocation"/zulu8.tar.gz "$link"
  tar -xpzf "$jdkTempLocation"/zulu8.tar.gz -C "${jdkTempLocation}"
  if [ $? -ne 0 ]; then echo "FAILED"; rm -rf "$jdkTempLocation"/zulu8.tar.gz; exit 1; fi
  rm -rf "$jdkTempLocation"/zulu8.tar.gz "${jdkInstallLocation:?}"/*
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

  java_zulu_install_crypto_extension

  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

## Install Azuls Java Zulu Enterprise using APT repository.
## (Updated version only availible on x86-64bit when checked August 2019)
java_zulu_enterprise_8_apt(){ 
  if ! dpkg -s 'zulu-8' >/dev/null 2>&1; then # Check if already is installed
    echo -n "$(timestamp) [openHABian] Installing Zulu Enterprise 64-Bit OpenJDK... "
    cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
    if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi 
    echo "deb http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-enterprise.list
    cond_redirect apt-get update
    if cond_redirect apt-get -y install zulu-8 && java_zulu_install_crypto_extension; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

## Fetches download link for Java Zulu 8.
## Valid architectures: arm-64-bit, arm-32-bit-sf, arm-32-bit-hf, x86-32-bit, x86-64-bit
##
##    fetch_zulu_tar_url(String arch)
##
## TODO: Rewrite using download API when it leaves alpha state. https://www.azul.com/downloads/zulu-community/api/
fetch_zulu_tar_url(){
  local downloadlink
  local filter
  if [ ! -x "$(command -v jq)" ]; then
    apt-get install -y jq
  fi
  filter='.[] | select(.category_slug == "java-8-lts") | select(.latest == 1) | select(.packaging_slug == "jdk") | select(.arch_slug == "'$1'") | .["bundles"] | .[] | select(.extension == "tar.gz") | .["link"]' # Temporary
  # filter='.[] | select(.os == "Linux") | select(.category_slug == "java-8-lts") | select(.latest == 1) | select(.packaging_slug == "jdk") | select(.arch_slug == "'$1'") | select((.os_flavor | index("Debian")) or (.os_flavor == "[]")) | .["bundles"] | .[] | select(.extension == "tar.gz") | .["link"]' # $1 = e.g. "arm-64-bit"  
  # Fetch an JSON array of download candidates from azul and filter them
  # shellcheck disable=SC2006
  downloadlink=`curl 'https://www.azul.com/wp-admin/admin-ajax.php' -s \
        -H 'Accept: */*' \
        -H 'X-Requested-With: XMLHttpRequest' \
        -H 'Content-Type: multipart/form-data; boundary=---------------------------17447165291708986765346780730' \
        -H 'Connection: keep-alive' \
        -H 'Cache-Control: max-age=0' -H 'TE: Trailers' \
        --data-binary $'-----------------------------17447165291708986765346780730\r\nContent-Disposition: form-data; name="action"\r\n\r\nbundles_filter_query\r\n-----------------------------17447165291708986765346780730\r\nContent-Disposition: form-data; name="action"\r\n\r\nsearch_bundles\r\n-----------------------------17447165291708986765346780730--\r\n' \
        | jq -r "$filter"`
  if [ -z "$downloadlink" ]; then return 1; fi
    # shellcheck disable=SC2046,SC2005,SC2006
    echo `echo "$downloadlink" | head -n1`
  return 0   
}

## Check whatever a newer version Zulu version is available.
## Returns 0 / true if new version exist
## TODO: Rewrite using download API when it leaves alpha state. https://www.azul.com/downloads/zulu-community/api/
java_zulu_tar_update_available(){
  if [ ! -x "$(command -v java)" ]; then return 0; fi
  
  local availableVersion # format: "8u222-b10"
  local javaVersion
  local filter
  if [ ! -x "$(command -v jq)" ]; then
    apt-get install -y jq
  fi
  filter='[.[] | select(.category_slug == "java-8-lts") | select(.latest == 1)  | .["openjdk_version"]] | first' # Temporary
  #filter='[.[] | select(.os == "Linux") | select(.category_slug == "java-8-lts") | select(.latest == 1)  | .["openjdk_version"]] | first'
  # Fetch an JSON array of download candidates from azul and filter them
  # shellcheck disable=SC2006
  availableVersion=`curl 'https://www.azul.com/wp-admin/admin-ajax.php' -s \
        -H 'Accept: */*' \
        -H 'X-Requested-With: XMLHttpRequest' \
        -H 'Content-Type: multipart/form-data; boundary=---------------------------17447165291708986765346780730' \
        -H 'Connection: keep-alive' \
        -H 'Cache-Control: max-age=0' -H 'TE: Trailers' \
        --data-binary $'-----------------------------17447165291708986765346780730\r\nContent-Disposition: form-data; name="action"\r\n\r\nbundles_filter_query\r\n-----------------------------17447165291708986765346780730\r\nContent-Disposition: form-data; name="action"\r\n\r\nsearch_bundles\r\n-----------------------------17447165291708986765346780730--\r\n' \
        | jq -r "$filter"`
  availableVersion="${availableVersion:2}" # Strip first two char -> "222-b10"
  javaVersion=$(java -version)
  if [[ $javaVersion == *"$availableVersion"* ]]; then
    # Java updated
    return 1
  fi
  return 0
}

## Install Cryptography Extension Kit to enable cryptos using more then 128 bits
java_zulu_install_crypto_extension(){
  local jdkPath
  local jdkSecurity
  local policyTempLocation
  jdkPath="$(readlink -f "$(command -v java)")"
  jdkSecurity="$(dirname "${jdkPath}")/../lib/security"
  mkdir -p "$jdkSecurity"
  policyTempLocation="$(mktemp -d /tmp/openhabian.XXXXX)"
  if [ -z "$policyTempLocation" ]; then echo "FAILED"; exit 1; fi

  cond_redirect wget -nv -O "$policyTempLocation"/crypto.zip http://cdn.azul.com/zcek/bin/ZuluJCEPolicies.zip
  cond_redirect unzip "$policyTempLocation"/crypto.zip -d "$policyTempLocation"
  cp "$policyTempLocation"/ZuluJCEPolicies/*.jar "$jdkSecurity"

  rm -rf "${policyTempLocation}"
  return 0
}
