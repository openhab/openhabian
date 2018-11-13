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

java_zulu() {
  FILE="/var/tmp/.zulu.$$"

  if is_arm; then
    JAVA=zulu8.31.1.122-jdk1.8.0_181-linux_aarch32hf
  else
    JAVA=zulu8.31.0.1-jdk8.0.181-linux_x64
  fi
  querytext="Downloading Zulu implies to agree to Azul Systems' Terms of Use. Display them now or proceed with downloading."
  while ! (whiptail --title "Download Zulu Java" --yes-button "Download and Install" --no-button "Read Terms of Use" --defaultno --yesno "$querytext" 10 80) ; do
    whiptail --textbox /opt/openhabian/docs/azul-zulu-license.md --scrolltext 27 116
  done

  wget -nv -O $FILE http://cdn.azul.com/zulu-embedded/bin/${JAVA}.tar.gz
  cd /usr/lib/jvm; tar xpzf $FILE
  cond_redirect update-alternatives --install /usr/bin/java java /usr/lib/jvm/${JAVA}/bin/java 1083000
  cond_redirect update-alternatives --install /usr/bin/javac java /usr/lib/jvm/${JAVA}/bin/javac 1083000
  rm -f $FILE
}

# Unused
java_zulu_embedded_archive() {
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK... "
  cond_redirect apt -y install dirmngr
  if is_arm; then arch="[arch=armhf]"; fi
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  echo "deb $arch http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-embedded.list
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  cond_redirect apt update
  if is_arm; then
    cond_redirect apt -y install zulu-embedded-8
  else
    cond_redirect apt -y install zulu-8
  fi
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  if [[ is_pi || is_pine64 ]]; then
    cond_echo "Optimizing Java to run on low memory single board computers... "
    sed -i 's#^EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS="-Xms400m -Xmx400m"#g' /etc/default/openhab2
  fi
}

