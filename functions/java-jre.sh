#!/usr/bin/env bash

java_webupd8() {
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

java_zulu_embedded() {
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK... "
  cond_redirect apt -y install dirmngr
  if is_arm; then _arch="[arch=armhf]"; fi
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  echo "deb $_arch http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-embedded.list
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  cond_redirect apt update
  cond_redirect apt -y install zulu-embedded-8
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

# Unused
java_zulu_embedded_archive() {
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK ARM build (archive)... "
  cond_redirect dpkg --add-architecture armhf
  cond_redirect apt update
  cond_redirect apt -y install libc6:armhf libfontconfig1:armhf # https://github.com/openhab/openhabian/issues/93#issuecomment-279401481
  if [ $? -ne 0 ]; then echo "FAILED (prerequisites)"; exit 1; fi
  # Static link, not up to date: https://www.azul.com/downloads/zulu/zdk-8-ga-linux_aarch32hf.tar.gz
  cond_redirect wget -O ezdk.tar.gz http://cdn.azul.com/zulu-embedded/bin/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf.tar.gz
  if [ $? -ne 0 ]; then echo "FAILED (download)"; exit 1; fi
  cond_redirect mkdir /opt/zulu-embedded
  cond_redirect tar xvfz ezdk.tar.gz -C /opt/zulu-embedded
  if [ $? -ne 0 ]; then echo "FAILED (extract)"; exit 1; fi
  cond_redirect rm -f ezdk.tar.gz
  cond_redirect chown -R 0:0 /opt/zulu-embedded
  cond_redirect update-alternatives --auto java
  cond_redirect update-alternatives --auto javac
  cond_redirect update-alternatives --install /usr/bin/java java /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/java 2162
  cond_redirect update-alternatives --install /usr/bin/javac javac /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/javac 2162
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (setup)"; exit 1; fi
}
