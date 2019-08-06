#!/usr/bin/env bash

java_webupd8_archive() {
  echo -n "$(timestamp) [openHABian] Preparing and Installing Oracle Java 8 Web Upd8 repository... "
  cond_redirect apt-get -y install dirmngr
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  rm -f /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
  if [ $? -ne 0 ]; then echo "FAILED (debconf)"; exit 1; fi
  cond_redirect apt-get update
  cond_redirect apt-get -y install oracle-java8-installer
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt-get -y install oracle-java8-set-default
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

java_zulu(){
  cond_redirect systemctl stop openhab2.service
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver while installing Java Zulu)"; exit 1; fi
  if is_ubuntu; then
    echo "deb $arch http://repos.azulsystems.com/ubuntu stable main" > /etc/apt/sources.list.d/zulu-enterprise.list
  else
    echo "deb $arch http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-enterprise.list
  fi

  if is_arm; then
    echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK... "
    cond_redirect apt-get update -qq
    cond_redirect apt-get -y install zulu-embedded-8
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  else
    echo -n "$(timestamp) [openHABian] Installing Zulu Enterprise OpenJDK... "
    cond_redirect apt-get update
    cond_redirect apt-get -y install zulu-8
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
  if [ -f /usr/lib/systemd/system/openhab2.service ]; then
    cond_redirect systemctl start openhab2.service
  fi
}
