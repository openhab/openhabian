#!/usr/bin/env bash

## Generate systemd dependencies for ZRAM, Frontail and others to start together with OH
## This is done using /etc/systemd/system/openhab.service.d/override.conf
##
##    create_systemd_dependencies()
##
create_systemd_dependencies() {
  local targetDir="/etc/systemd/system/openhab.service.d"

  echo -n "$(timestamp) [openHABian] Creating dependencies to jointly start services that depend on each other... "
  if ! cond_redirect mkdir -p $targetDir; then echo "FAILED (prepare directory)"; return 1; fi
  if ! cond_redirect rm -f "${targetDir}"/override.conf; then echo "FAILED (clean directory)"; return 1; fi
  if cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/openhab2-override.conf "${targetDir}"/override.conf; then echo "OK"; else echo "FAILED (copy configuration)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (reload configuration)"; return 1; fi
}


## Function to quickly rename openHAB rules back and forth after two minutes to
## speed up startup of openHAB.
## This is done using /etc/systemd/system/openhab.service.d/override.conf
## Valid arguments: "yes" or "no"
##
##    delayed_rules()
##
delayed_rules() {
  if ! openhab_is_installed; then return 0; fi

  local targetDir="/etc/systemd/system/openhab.service.d"

  if [[ $1 == "yes" ]]; then
    echo -n "$(timestamp) [openHABian] Adding delay on loading openHAB rules... "
    if (cat "${BASEDIR:-/opt/openhabian}"/includes/delayed-rules.conf >> "${targetDir}"/override.conf); then echo "OK"; else echo "FAILED (copy configuration)"; return 1; fi
  elif [[ $1 == "no" ]]; then
    echo "$(timestamp) [openHABian] Removing delay on loading openHAB rules... OK"
    rm -rf ${targetDir}/override.conf
  fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then return 1; fi
}

## Function to install / upgrade / downgrade the installed openHAB version
## Valid arguments: "openHAB3" or "openHAB2"
## Valid arguments: "unstable", "stable", or "testing"
##
##    openhab_setup(String version, String release)
##
openhab_setup() {
  local introText
  local successText
  local repo
  local openhabVersion

  if [[ "$1" == "openHAB3" ]]; then
     ohPkgName="openhab"
  else
     ohPkgName="openhab2"
  fi

  if [[ $2 == "unstable" ]]; then
    introText="Proceed with caution!\\n\\nYou are about to switch over to the latest $1 unstable snapshot build. The daily snapshot builds contain the latest features and improvements but might also suffer from bugs or incompatibilities. Please be sure to take a full openHAB configuration backup first!"
    successText="The latest unstable snapshot build of $1 is now running on your system.\\n\\nPlease test the correct behavior of your setup. You might need to adapt your configuration, if available. If you made changes to the files in '/var/lib/${ohPkgName}' they were replaced, but you can restore them from backup files next to the originals.\\n\\nIf you find any problems or bugs, please report them and state the snapshot version you are on. To stay up-to-date with improvements and bug fixes you should upgrade your packages (using menu option 02) regularly."
    repo="deb https://openhab.jfrog.io/artifactory/openhab-linuxpkg unstable main"
  elif [[ $2 == "stable" ]]; then
    introText="You are about to install or change to the latest stable $1 release.\\n\\nPlease be aware that downgrading from a newer unstable snapshot build is not officially supported. Please consult with the documentation or community forum and be sure to take a full openHAB configuration backup first!"
    successText="The stable release of $1 is now installed on your system.\\n\\nPlease test the correct behavior of your setup. You might need to adapt your configuration, if available. If you made changes to the files in '/var/lib/${ohPkgName}' they were replaced, but you can restore them from backup files next to the originals.\\n\\nCheck the \"openHAB Release Notes\" and the official announcements to learn about additons, fixes and changes."
    repo="deb https://dl.bintray.com/openhab/apt-repo2 stable main"
  elif [[ $2 == "testing" ]]; then
    introText="You are about to install or change to the latest milestone (testing) $1 build. It contains the latest features and is supposed to run stable, but if you experience bugs or incompatibilities, please help with enhancing openHAB by posting them on the community forum or by raising a GitHub issue.\\n\\nPlease be aware that downgrading from a newer build is not officially supported.\\n\\nPlease consult with the documentation or community forum and be sure to take a full openHAB configuration backup first!"
    successText="The testing release of $1 is now installed on your system.\\n\\nPlease test the correct behavior of your setup. You might need to adapt your configuration, if available. If you made changes to the files in '/var/lib/${ohPkgName}' they were replaced, but you can restore them from backup files next to the originals.\\n\\nCheck the \"openHAB Release Notes\" and the official announcements to learn about additons, fixes and changes."
    repo="deb https://openhab.jfrog.io/artifactory/openhab-linuxpkg testing main"
  fi

  if [[ $2 == "unstable" ]]; then
    echo -n "$(timestamp) [openHABian] Beginning install of latest $1 snapshot (unstable)... "
  elif [[ $2 == "stable" ]]; then
    echo -n "$(timestamp) [openHABian] Beginning install of latest $1 release (stable)... "
  elif [[ $2 == "testing" ]]; then
    echo -n "$(timestamp) [openHABian] Beginning install of latest $1 milestone release (testing)... "
  fi

  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "openHAB software change, Continue?" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 15 80); then echo "OK"; else echo "CANCELED"; return 1; fi
    export DEBIAN_FRONTEND=noninteractive
  else
    echo "OK"
  fi

  if running_in_docker || [[ -z $OFFLINE ]]; then
    if ! add_keys "https://bintray.com/user/downloadSubjectPublicKey?username=openhab"; then return 1; fi

    rm -f /etc/apt/sources.list.d/${ohPkgName}*.list
    echo "$repo" > /etc/apt/sources.list.d/${ohPkgName}.list

    echo -n "$(timestamp) [openHABian] Installing selected $1 version... "
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    openhabVersion="$(apt-cache madison ${ohPkgName} | head -n 1 | cut -d'|' -f2 | xargs)"
    if cond_redirect apt-get install --allow-downgrades --yes --option Dpkg::Options::="--force-confnew" "${ohPkgName}=${openhabVersion}" "${ohPkgName}-addons=${openhabVersion}"; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    echo -n "$(timestamp) [openHABian] Installing cached openHAB version... "
    if cond_redirect apt-get install --yes --option Dpkg::Options::="--force-confnew" ${ohPkgName} ${ohPkgName}-addons; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  # shellcheck disable=SC2154
  gid="$(id -g "$username")"
  cond_redirect usermod -g "openhab" "$username" &> /dev/null
  cond_redirect usermod -aG "$gid" "$username" &> /dev/null

  echo -n "$(timestamp) [openHABian] Setting up openHAB service... "
  if ! zram_dependency install ${ohPkgName}; then return 1; fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable ${ohPkgName}.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  openhab_misc
  create_systemd_dependencies
  if [[ "$1" == "openHAB3" ]]; then
    delayed_rules "no"
  else
    delayed_rules "yes"
  fi
  dashboard_add_tile "openhabiandocs"
  
  # see https://github.com/openhab/openhab-core/issues/1937
  if cond_redirect systemctl restart ${ohPkgName}.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    export DEBIAN_FRONTEND=
    whiptail --title "Operation Successful!" --msgbox "$successText" 15 80
  fi
}

## Function that binds openHAB console to interfaces making it available over the network
##
##    openhab_shell_interfaces()
##
openhab_shell_interfaces() {
  local introText
  local sshPass
  local sshPass1
  local sshPass2
  local successText

  introText="\\nThe openHAB remote console is a powerful tool for every openHAB user. For details see https://www.openhab.org/docs/administration/console.html\\n\\nThis menu option will make the console available on all interfaces of your system. Please provide a secure password for this connection. Blank input will get you the default password \"habopen\"."
  successText="The openHAB remote console was successfully activated on all interfaces and openHAB has been restarted. You can reach the console using\\n\\nssh openhab@$HOSTNAME -p 8101\\n\\nBe aware that the first connection attempt may take a few minutes or may result in a timeout due to key generation.\\nThe default password is \"habopen\"."
  echo -n "$(timestamp) [openHABian] Activating the openHAB console on all interfaces... "

  if [[ -n $INTERACTIVE ]]; then
    while [[ -z $sshPass ]]; do
      if ! sshPass1="$(whiptail --title "Authentication Setup" --passwordbox "$introText" 15 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if ! sshPass2="$(whiptail --title "Authentication Setup" --passwordbox "\\nPlease confirm the password:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
      if [[ $sshPass1 == "$sshPass2" ]] && [[ ${#sshPass1} -ge 8 ]] && [[ ${#sshPass2} -ge 8 ]]; then
        sshPass="$sshPass1"
      else
        whiptail --title "Authentication Setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
  fi
  if [[ -z $sshPass ]]; then
    sshPass="habopen"
  fi

  if ! cond_redirect sed -i -e 's|^sshHost = 127.0.0.1.*$|sshHost = 0.0.0.0|g' /var/lib/openhab/etc/org.apache.karaf.shell.cfg; then echo "FAILED (sshHost)"; return 1; fi
  if cond_redirect sed -i -e 's|openhab = .*,|openhab = '"${sshPass}"',|g' /var/lib/openhab/etc/users.properties; then echo "OK"; else echo "FAILED (sshPass)"; return 1; fi
  cond_redirect systemctl restart openhab.service

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successText" 15 80
  fi
}

## Function to download and install special vim syntax for openHAB files.
##
##    vim_openhab_syntax()
##
vim_openhab_syntax() {
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to vim editor... "
  if ! cond_redirect mkdir -p /home/"${username:-openhabian}"/.vim/{ftdetect,syntax}; then echo "FAILED (prepare dirs)"; return 1; fi
  if ! cond_redirect wget -O "/home/${username:-openhabian}/.vim/syntax/openhab.vim" https://github.com/cyberkov/openhab-vim/raw/master/syntax/openhab.vim; then echo "FAILED (syntax)"; return 1; fi
  if ! cond_redirect wget -O "/home/${username:-openhabian}/.vim/ftdetect/openhab.vim" https://github.com/cyberkov/openhab-vim/raw/master/ftdetect/openhab.vim; then echo "FAILED (ftdetect)"; return 1; fi
  if chown -R "${username:-openhabian}:${username:-openhabian}" /home/"${username:-openhabian}"/.vim; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi
}

## Function to download and install special nano syntax for openHAB files.
##
##    nano_openhab_syntax()
##
nano_openhab_syntax() {
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to nano editor... "
  if ! cond_redirect wget -O /usr/share/nano/openhab.nanorc https://github.com/airix1/openhabnano/raw/master/openhab.nanorc; then echo "FAILED (download)"; return 1; fi
  if echo -e "\\n## openHAB syntax\\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc; then echo "OK"; else echo "FAILED (nanorc)"; return 1; fi
}

## Function to install a special multitail theme for openHAB logs.
##
##    multitail_openhab_scheme()
##
multitail_openhab_scheme() {
  echo -n "$(timestamp) [openHABian] Adding openHAB scheme to multitail... "
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/multitail.openhab.conf /etc/multitail.openhab.conf; then echo "FAILED (copy)"; return 1; fi
  if ! cond_redirect sed -i -e '/^.*multitail.*openhab.*$/d' /etc/multitail.conf; then echo "FAILED (remove default configuration)"; return 1; fi
  if cond_redirect sed -i -e 's|^# misc.*$|# openHAB logs\\ninclude:/etc/multitail.openhab.conf\\n#\\n# misc|g' /etc/multitail.conf; then echo "OK"; else echo "FAILED (include)"; return 1; fi
}

## Function to check if openHAB 2 is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab2_is_installed()
##
openhab2_is_installed() {
  if [[ $(dpkg -s 'openhab2' 2> /dev/null | grep Status | cut -d' ' -f2) == "install" ]]; then return 0; else return 1; fi
}
## Function to check if openHAB 3 is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab3_is_installed()
##
openhab3_is_installed() {
  if [[ $(dpkg -s 'openhab' 2> /dev/null | grep Status | cut -d' ' -f2) == "install" ]]; then return 0; else return 1; fi
}
## Function to check if openHAB is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab_is_installed()
##
openhab_is_installed() {
  if openhab2_is_installed || openhab3_is_installed; then return 0; else return 1; fi
}

## Function to check if openHAB is running on the current system. Returns
## 0 / true if openHAB is running and 1 / false if not.
##
##    openhab_is_running()
##
openhab_is_running() {
  if openhab_is_installed && [[ $(systemctl is-active openhab) == "active" ]]; then return 0; else return 1; fi
}

## Optimize openHAB Java for low memory SBC's and set HTTP/HTTPS ports
##
##    openhab_misc()
##
openhab_misc() {
  if ! is_arm; then return 0; fi

  echo -n "$(timestamp) [openHABian] Optimizing openHAB to run on low memory single board computers... "
  if has_lowmem; then
    if cond_redirect sed -i -e 's|^EXTRA_JAVA_OPTS=.*$|EXTRA_JAVA_OPTS="-Xms16m -Xmx256m"|g' /etc/default/openhab2; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    if cond_redirect sed -i -e 's|^EXTRA_JAVA_OPTS=.*$|EXTRA_JAVA_OPTS="-Xms192m -Xmx320m"|g' /etc/default/openhab2; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting openHAB HTTP/HTTPS ports... "
  if ! cond_redirect sed -i -e 's|^#*.*OPENHAB_HTTP_PORT=.*$|OPENHAB_HTTP_PORT=8080|g' /etc/default/openhab; then echo "FAILED"; return 1; fi
  if cond_redirect sed -i -e 's|^#*.*OPENHAB_HTTPS_PORT=.*$|OPENHAB_HTTPS_PORT=8443|g' /etc/default/openhab; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Create a openHAB dashboard title and image for the input application.
## Valid arguments: "grafana", "frontail", "nodered", "find", or "openhabiandocs"
##
##    dashboard_add_tile(String application)
##
dashboard_add_tile() {
  local application
  local dashboardConfig
  local openhabConfig
  local tileDesc
  local tileImg
  local tileURL

  application="$1"
  openhabConfig="/etc/openhab"
  dashboardConfig="${openhabConfig}/services/dashboard.cfg"
  tileDesc="$(grep "^[[:space:]]*tile_desc_${application}" "${BASEDIR:-/opt/openhabian}"/includes/dashboard-imagedata | sed 's|tile_desc_'"${application}"'=||g; s|"||g')"
  tileImg="$(grep "^[[:space:]]*tile_imagedata_${application}" "${BASEDIR:-/opt/openhabian}"/includes/dashboard-imagedata | sed 's|tile_imagedata_'"${application}"'=||g; s|"||g')"
  tileURL="$(grep "^[[:space:]]*tile_url_${application}" "${BASEDIR:-/opt/openhabian}"/includes/dashboard-imagedata | sed 's|tile_url_'"${application}"'=||g; s|"||g')"

  echo -n "$(timestamp) [openHABian] Adding an openHAB dashboard tile for '${application}'... "

  case $application in
    grafana|frontail|nodered|find|find3|openhabiandocs)
      true ;;
    *)
      echo "FAILED (tile name not valid)"; return 1 ;;
  esac
  if ! openhab_is_installed || ! [[ -d "${openhabConfig}/services" ]]; then
    echo "FAILED (openHAB or config folder missing)"
    return 1
  fi

  touch $dashboardConfig
  if grep -qs "${application}.link" $dashboardConfig; then
    echo -n "Replacing... "
    cond_redirect sed -i -e '/^'"${application}"'.link.*$/d' $dashboardConfig
  fi

  if [[ -z $tileDesc ]] || [[ -z $tileURL ]] || [[ -z $tileImg ]]; then
    echo "FAILED (data missing)"
    return 1
  fi

  if echo -e "\\n${application}.link-name=${tileDesc}\\n${application}.link-url=${tileURL}\\n${application}.link-imageurl=${tileImg}" >> $dashboardConfig; then echo "OK"; else echo "FAILED"; return 1; fi
}
