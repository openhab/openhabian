#!/usr/bin/env bash

java_webupd8_archive() {
  echo -n "$(timestamp) [openHABian] Preparing and Installing Oracle Java 8 Web Upd8 repository... "
  cond_redirect apt -y install dirmngr
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  rm -f /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
  if [ $? -ne 0 ]; then echo "FAILED (debconf)"; exit 1; fi
  cond_redirect apt update
  cond_redirect apt -y install oracle-java8-installer
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install oracle-java8-set-default
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

java_zulu() {
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK... "
  cond_redirect apt -y install dirmngr
  if is_arm; then arch="[arch=armhf]"; fi
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  if is_ubuntu; then
    echo "deb $arch http://repos.azulsystems.com/ubuntu stable main" > /etc/apt/sources.list.d/zulu-embedded.list
  else  
    echo "deb $arch http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-embedded.list
  fi
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  cond_redirect apt update
  if is_arm; then
    cond_redirect apt -y install zulu-embedded-8
  else
    cond_redirect apt -y install zulu-8
  fi
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

java_zulu_NEW() {
  local FILE
  local INSTALLROOT
  local TEMPROOT
  local JAVA
  FILE="/var/tmp/.zulu.$$"
  INSTALLROOT=/opt/jdk
  TEMPROOT=/opt/jdk-new
  mkdir ${INSTALLROOT}
  mkdir ${TEMPROOT}

  if is_arm; then
    # Latest version check https://www.azul.com/downloads/zulu-embedded
    JAVA=zulu8.33.0.134-jdk1.8.0_192-linux_aarch32hf
  else
    # Latest version check https://www.azul.com/downloads/zulu-linux
    JAVA=zulu8.33.0.1-jdk8.0.192-linux_x64
  fi
  if [ -n "$INTERACTIVE" ]; then
    whiptail --textbox $BASEDIR/includes/azul_zulu_license.md --scrolltext 27 116
  fi
  
  cond_redirect wget -nv -O $FILE http://cdn.azul.com/zulu-embedded/bin/${JAVA}.tar.gz
  cond_redirect tar -xpzf $FILE -C ${TEMPROOT}
  if [ $? -ne 0 ]; then echo "FAILED (Zulu java)"; rm -f ${FILE}; exit 1; fi
  rm -rf $FILE ${INSTALLROOT:?}/*
  mv ${TEMPROOT}/* ${INSTALLROOT}/; rmdir ${TEMPROOT}
  cond_redirect update-alternatives --install /usr/bin/java java ${INSTALLROOT}/${JAVA}/bin/java 1083000
  cond_redirect update-alternatives --install /usr/bin/javac java ${INSTALLROOT}/${JAVA}/bin/javac 1083000
}
