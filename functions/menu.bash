#!/usr/bin/env bash

show_about() {
  whiptail --title "About openHABian and openhabian-config" --msgbox "openHABian Configuration Tool $(get_git_revision)
This tool provides a little help to make your openHAB experience as comfortable as possible.
\\nMake sure you have read the README and know about the Debug and Backup guides in /opt/openhabian/docs.
\\nMenu 01 to select the standard (\"stable\") or the very latest (\"master\") openHABian version.
Menu 40 to select the standard release, milestone or very latest development version of openHAB and
Menu 03 to install or upgrade it.
Menu 02 will upgrade all of your OS and applications to the latest versions, including openHAB.
Menu 10 provides a number of system tweaks. These are already active after a standard installation while
Menu 30 allows for changing system configuration to match your hardware.
Note that the raspi-config tool was intentionally removed to not interfere with openhabian-config.
Menu 50 provides options to backup and restore either your openHAB configuration or the whole system.
Note backups are NOT active per default so remember to set them up right at the beginning of your journey.
\\nVisit these sites for more information:
  - Documentation: https://www.openhab.org/docs/installation/openhabian.html
  - Development: http://github.com/openhab/openhabian
  - Discussion: https://community.openhab.org/t/13379" 25 116
  RET=$?
  if [ $RET -eq 255 ]; then
    # <Esc> key pressed.
    return 0
  fi
}

show_main_menu() {
  local choice
  local version

  choice=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 18 116 11 --cancel-button Exit --ok-button Execute \
  "00 | About openHABian"        "Information about the openHABian project and this tool" \
  "" "" \
  "01 | Select Branch"           "Select the openHABian config tool version (\"branch\") to run" \
  "02 | Upgrade System"          "Upgrade all installed software packages (incl. openHAB) to their latest version" \
  "03 | Install openHAB"         "Install or upgrade to openHAB release 3" \
  "" "" \
  "10 | Apply Improvements"      "Apply the latest improvements to the basic openHABian setup ►" \
  "20 | Optional Components"     "Choose from a set of optional software components ►" \
  "30 | System Settings"         "A range of system and hardware related configuration steps ►" \
  "40 | openHAB Related"         "Switch the installed openHAB version or apply tweaks ►" \
  "50 | Backup/Restore"          "Manage backups and restore your system ►" \
  3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ] || [ $RET -eq 255 ]; then
    # "Exit" button selected or <Esc> key pressed two times
    return 255
  fi

  if [[ "$choice" == "" ]]; then
    true

  elif [[ "$choice" == "00"* ]]; then
    show_about

  elif [[ "$choice" == "01"* ]]; then
    openhabian_update

  elif [[ "$choice" == "02"* ]]; then
    wait_for_apt_to_finish_update
    system_upgrade

  elif [[ "$choice" == "03"* ]]; then
    wait_for_apt_to_finish_update
    openhab_setup openHAB3 "stable"

  elif [[ "$choice" == "10"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Apply Improvements" 13 116 6 --cancel-button Back --ok-button Execute \
    "11 | Packages"               "Install needed and recommended system packages" \
    "12 | Bash&Vim Settings"      "Update customized openHABian settings for bash, vim and nano" \
    "13 | System Tweaks"          "Add /srv mounts and update settings typical for openHAB" \
    "14 | Fix Permissions"        "Update file permissions of commonly used files and folders" \
    "15 | FireMotD"               "Upgrade the program behind the system overview on SSH login" \
    "16 | Samba"                  "Install the Samba file sharing service and set up openHAB shares" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    wait_for_apt_to_finish_update
    case "$choice2" in
      11\ *) basic_packages && needed_packages ;;
      12\ *) bashrc_copy && vimrc_copy && vim_openhab_syntax && nano_openhab_syntax && multitail_openhab_scheme ;;
      13\ *) srv_bind_mounts && misc_system_settings ;;
      14\ *) permissions_corrections ;;
      15\ *) firemotd_setup ;;
      16\ *) samba_setup ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "20"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Optional Components" 20 116 13 --cancel-button Back --ok-button Execute \
    "21 | Log Viewer"            "openHAB Log Viewer webapp (frontail)" \
    "22 | miflora-mqtt-daemon"   "Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon" \
    "23 | Mosquitto"             "MQTT broker Eclipse Mosquitto" \
    "24 | InfluxDB+Grafana"      "A powerful persistence and graphing solution" \
    "25 | Node-RED"              "Flow-based programming for the Internet of Things" \
    "26 | Homegear"              "Homematic specific, the CCU2 emulation software Homegear" \
    "27 | knxd"                  "KNX specific, the KNX router/gateway daemon knxd" \
    "28 | 1wire"                 "1wire specific, owserver and related packages" \
    "29 | FIND 3"                "Framework for Internal Navigation and Discovery" \
    "   | Monitor Mode"          "Patch firmware to enable monitor mode (ALPHA/DANGEROUS)" \
    "2A | Telldus Core"          "Telldus Core service for Tellstick USB devices" \
    "2B | Install HABApp"        "Python 3 integration and rule engine for openHAB" \
    "   | Remove HABApp"         "Remove HABApp from this system" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    wait_for_apt_to_finish_update
    case "$choice2" in
      21\ *) frontail_setup ;;
      22\ *) miflora_setup ;;
      23\ *) mqtt_setup ;;
      24\ *) influxdb_grafana_setup ;;
      25\ *) nodered_setup ;;
      26\ *) homegear_setup ;;
      27\ *) knxd_setup ;;
      28\ *) 1wire_setup ;;
      29\ *) find3_setup ;;
      *Monitor\ Mode) setup_monitor_mode ;;
      2A\ *) telldus_core_setup ;;
      2B\ *) habapp_setup install;;
      *Remove\ HABApp*) habapp_setup remove;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "30"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "System Settings" 24 118 17 --cancel-button Back --ok-button Execute \
    "31 | Change hostname"        "Change the name of this system, currently '$(hostname)'" \
    "32 | Set system locale"      "Change system language, currently '$(env | grep "^[[:space:]]*LANG=" | sed 's|LANG=||g')'" \
    "33 | Set system timezone"    "Change the your timezone, execute if it's not '$(date +%H:%M)' now" \
    "   | Enable NTP"             "Enable time synchronization via systemd-timesyncd to NTP servers" \
    "   | Disable NTP"            "Disable time synchronization via systemd-timesyncd to NTP servers" \
    "34 | Change passwords"       "Change passwords for Samba, openHAB Console or the system user" \
    "35 | Serial port"            "Prepare serial ports for peripherals like Razberry, SCC, Pine64 ZWave, ..." \
    "36 | WiFi setup"             "Configure wireless network connection" \
    "   | Disable WiFi"           "Disable wireless network connection" \
    "37 | Move root to USB"       "Move the system root from the SD card to a USB device (SSD or stick)" \
    "38 | Use ZRAM"               "Use compressed RAM/disk sync for active directories to avoid SD card corruption" \
    "   | Uninstall ZRAM"         "Don't use compressed memory (back to standard Raspberry Pi OS filesystem layout)" \
    "39 | Setup Exim Mail Relay"  "Install Exim4 to relay mails via public email provider" \
    "3A | Setup Tailscale VPN"    "Establish or join a WireGuard based VPN using the Tailscale service" \
    "   | Remove Tailscale VPN"   "Remove the Tailscale VPN service" \
    "   | Install WireGuard"      "Setup WireGuard to enable secure remote access to this openHABian system" \
    "   | Remove WireGuard"       "Remove WireGuard VPN from this system" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    wait_for_apt_to_finish_update
    case "$choice2" in
      31\ *) hostname_change ;;
      32\ *) locale_setting ;;
      33\ *) timezone_setting ;;
      *Enable\ NTP) setup_ntp "enable" ;;
      *Disable\ NTP) setup_ntp "disable" ;;
      34\ *) change_password ;;
      35\ *) prepare_serial_port ;;
      36\ *) configure_wifi setup;;
      *Disable\ WiFi) configure_wifi disable ;;
      37\ *) move_root2usb ;;
      38\ *) init_zram_mounts "install" ;;
      *Uninstall\ ZRAM) init_zram_mounts "uninstall" ;;
      39\ *) exim_setup ;;
      3A\ *) if install_tailscale install; then setup_tailscale; fi;;
      *Remove\ Tailscale*) install_tailscale remove;;
      *Install\ WireGuard*) if install_wireguard install; then setup_wireguard; fi;;
      *Remove\ WireGuard*) install_wireguard remove;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "40"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "openHAB Related" 19 116 12 --cancel-button Back --ok-button Execute \
    "41 | openHAB release"        "Install or switch to the latest openHAB release" \
    "   | openHAB testing"        "Install or switch to the latest openHAB testing build" \
    "   | openHAB snapshot"       "Install or switch to the latest openHAB SNAPSHOT build" \
    "42 | Upgrade to openHAB 3"   "Upgrade OS environment to openHAB 3 release" \
    "   | Downgrade to openHAB 2" "Downgrade OS environment from openHAB 3 back to openHAB 2 stable" \
    "43 | Remote Console"         "Bind the openHAB SSH console to all external interfaces" \
    "44 | Reverse Proxy"          "Setup Nginx with password authentication and/or HTTPS access" \
    "45 | Delay rules load"       "Delay loading rules to speed up overall startup" \
    "   | Default order"          "Reset config load order to default (random)" \
    "46 | Zulu 11 OpenJDK 32-bit" "Install Zulu 11 32-bit OpenJDK as primary Java provider" \
    "   | Zulu 11 OpenJDK 64-bit" "Install Zulu 11 64-bit OpenJDK as primary Java provider" \
    "   | AdoptOpenJDK 11"        "Install AdoptOpenJDK 11 as primary Java provider" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    wait_for_apt_to_finish_update
    version="$(openhab3_is_installed && echo "openHAB3" || echo "openHAB2")"
    # shellcheck disable=SC2154
    case "$choice2" in
      41\ *) openhab_setup "$version" "stable";;
      *openHAB\ testing) openhab_setup "$version" "testing";;
      *openHAB\ snapshot) openhab_setup "$version" "unstable";;
      42\ *) migrate_installation openHAB3 "stable" && openhabian_update "openHAB3";;
      *Downgrade\ to\ openHAB\ 2) migrate_installation openHAB2 "stable" && openhabian_update "stable";;
      43\ *) openhab_shell_interfaces;;
      44\ *) nginx_setup;;
      *Delay\ rules\ load) create_systemd_dependencies && delayed_rules "yes";;
      *Default\ order) create_systemd_dependencies && delayed_rules "no";;
      *Zulu\ 11\ OpenJDK\ 32-bit) update_config_java "Zulu11-32" && java_install_or_update "Zulu11-32";;
      *Zulu\ 11\ OpenJDK\ 64-bit) update_config_java "Zulu11-64" && java_install_or_update "Zulu11-64";;
      *AdoptOpenJDK\ 11) update_config_java "Adopt11" && java_install_or_update "Adopt11";;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "50"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Backup/Restore" 14 116 7 --cancel-button Back --ok-button Execute \
    "50 | Backup openHAB config"      "Backup the current active openHAB configuration" \
    "51 | Restore an openHAB config"  "Restore a previous openHAB configuration from backup" \
    "52 | Amanda System Backup"       "Set up Amanda to comprehensively backup your complete openHABian box" \
    "53 | Setup SD mirroring"         "Setup mirroring of internal to external SD card" \
    "   | Remove SD mirroring"        "Disable mirroring of SD cards" \
    "54 | Raw copy SD"                "Raw copy internal SD to external disk / SD card" \
    "55 | Sync SD"                    "Rsync internal SD to external disk / SD card" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      50\ *) backup_openhab_config ;;
      51\ *) restore_openhab_config ;;
      52\ *) wait_for_apt_to_finish_update && amanda_setup ;;
      53\ *) setup_mirror_SD "install" ;;
      *Remove\ SD\ mirroring*) setup_mirror_SD "remove" ;;
      54\ *) mirror_SD "raw" ;;
      55\ *) mirror_SD "diff" ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\\n  \"$choice2\"" 8 80 ;;
    esac
  else
    whiptail --msgbox "Error: unrecognized option \"$choice\"" 10 60
  fi

  # shellcheck disable=SC2154,SC2181
  if [ $? -ne 0 ]; then whiptail --msgbox "There was an error or interruption during the execution of:\\n  \"$choice\"\\n\\nPlease try again. If the error persists, please read /opt/openhabian/docs/openhabian-DEBUG.md or https://github.com/openhab/openhabian/blob/master/docs/openhabian-DEBUG.md how to proceed." 14 80; return 0; fi
}
