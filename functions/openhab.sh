#!/usr/bin/env bash

openhab2_stable_setup() {
  echo -n "$(timestamp) [openHABian] Installing openHAB 2.1 (stable)... "
  echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb https://dl.bintray.com/openhab/apt-repo2 testing main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb http://openhab.jfrog.io/openhab/openhab-linuxpkg unstable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect wget -O openhab-key.asc 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab'
  cond_redirect apt-key add openhab-key.asc
  if [ $? -ne 0 ]; then echo "FAILED (key)"; exit 1; fi
  rm -f openhab-key.asc
  cond_redirect apt update
  cond_redirect apt -y install openhab2
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser openhab gpio
  cond_redirect adduser openhab audio
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  if [ -n "$UNATTENDED" ]; then
    cond_redirect systemctl stop openhab2.service || true
  else
    cond_redirect systemctl start openhab2.service || true
  fi
}

openhab2_unstable_setup() {
  introtext="You are about to switch over to the latest openHAB 2 unstable build. The daily snapshot builds contain the latest features and improvements but may also suffer from bugs or incompatibilities.
If prompted if files should be replaced by newer ones, select Yes. Please be sure to take a full openHAB configuration backup first!"
  successtext="The latest unstable/snapshot build of openHAB 2 is now running on your system. If already available, check the function of your configuration now. If you find any problem or bug, please report it and state the snapshot version you are on. To stay up-to-date with improvements and bug fixes you should upgrade your packages regularly."
  echo -n "$(timestamp) [openHABian] Installing or switching to openHAB 2.2 SNAPSHOT (unstable)... "

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo "deb http://openhab.jfrog.io/openhab/openhab-linuxpkg unstable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect apt update
  cond_redirect apt -y install openhab2
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser openhab gpio
  cond_redirect adduser openhab audio
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl restart openhab2.service || true

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
}

# TODO: Unite with function above
openhab2_stable_updowngrade() {
  introtext="You are about to switch over to the stable openHAB 2.1.0 build. When prompted if files should be replaced by newer ones, select Yes. Please be sure to take a full openHAB configuration backup first!"
  successtext="The stable release of openHAB 2.1.0 is now installed on your system. Please test the correct behavior of your setup. Check the \"openHAB 2.1 Release Notes\" and the official announcements to learn about additons, fixes and changes:\n
  ➡ http://www.kaikreuzer.de/2017/06/28/openhab21
  ➡ https://github.com/openhab/openhab-distro/releases/tag/2.1.0"
  echo -n "$(timestamp) [openHABian] Installing or switching to openHAB 2.1.0 (stable)... "

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect wget -O openhab-key.asc 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab'
  cond_redirect apt-key add openhab-key.asc
  if [ $? -ne 0 ]; then echo "FAILED (key)"; exit 1; fi
  rm -f openhab-key.asc
  cond_redirect apt update
  cond_redirect apt -y install openhab2=2.1.0-1
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser openhab gpio
  cond_redirect adduser openhab audio
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl restart openhab2.service || true

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
}

openhab_shell_interfaces() {
  introtext="The openHAB remote console is a powerful tool for every openHAB user. It allows you too have a deeper insight into the internals of your setup. Further details: http://docs.openhab.org/administration/console.html
\nThis routine will bind the console to all interfaces and thereby make it available to other devices in your network. Please provide a secure password for this connection (letters and numbers only! default: habopen):"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="The openHAB remote console was successfully opened on all interfaces. openHAB has been restarted. You should be able to reach the console via:
\n'ssh://openhab:<password>@<openhabian-IP> -p 8101'\n
Please be aware, that the first connection attempt may take a few minutes or may result in a timeout due to key generation."

  echo -n "$(timestamp) [openHABian] Binding the openHAB remote console on all interfaces... "
  if [ -n "$INTERACTIVE" ]; then
    sshPassword=$(whiptail --title "Bind Remote Console, Password?" --inputbox "$introtext" 20 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus -ne 0 ]; then
      echo "aborted"
      return 0
    fi
  fi
  [[ -z "${sshPassword// }" ]] && sshPassword="habopen"

  cond_redirect sed -i "s/sshHost = 127.0.0.1/sshHost = 0.0.0.0/g" /var/lib/openhab2/etc/org.apache.karaf.shell.cfg
  cond_redirect sed -i "s/openhab = .*,/openhab = $sshPassword,/g" /var/lib/openhab2/etc/users.properties
  cond_redirect systemctl restart openhab2.service

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
  echo "OK"
}

vim_openhab_syntax() {
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to vim editor... "
  # these may go to "/usr/share/vim/vimfiles" ?
  mkdir -p /home/$username/.vim/{ftdetect,syntax}
  cond_redirect wget -O /home/$username/.vim/syntax/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/syntax/openhab.vim
  cond_redirect wget -O /home/$username/.vim/ftdetect/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/ftdetect/openhab.vim
  chown -R $username:$username /home/$username/.vim
  echo "OK"
}

nano_openhab_syntax() {
  # add nano syntax highlighting
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to nano editor... "
  cond_redirect wget -O /usr/share/nano/openhab.nanorc https://raw.githubusercontent.com/airix1/openhabnano/master/openhab.nanorc
  echo -e "\n## openHAB files\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc
  echo "OK"
}
