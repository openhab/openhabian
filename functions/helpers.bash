#!/usr/bin/env bash

# Attention: This file will be sourced earlier than all others

# Colors for later use
ESC="\\033["
COL_DEF=$ESC"39;49;00m"
COL_RED=$ESC"31;01m"
COL_GREEN=$ESC"32;01m"
COL_YELLOW=$ESC"33;01m"
COL_BLUE=$ESC"34;01m"
COL_MAGENTA=$ESC"35;01m"
COL_CYAN=$ESC"36;01m"
COL_LGRAY=$ESC"37;01m"
COL_DGRAY=$ESC"90;01m"
export COL_DEF COL_RED COL_GREEN COL_YELLOW COL_BLUE COL_MAGENTA COL_CYAN COL_LGRAY COL_DGRAY

# Log with timestamp
timestamp() { printf "%(%F_%T_%Z)T\\n" "-1"; }

## This enables printout of both a executed command and its output
##
##    cond_redirect(bash command)
##
cond_redirect() {
  if [[ -n $SILENT ]]; then
    "$@" &> /dev/null
    return $?
  else
    echo -e "\\n${COL_DGRAY}\$ ${*} ${COL_DEF}"
    "$@"
    return $?
  fi
}

cond_echo() {
  if [[ -z $SILENT ]]; then
    echo -e "${COL_YELLOW}${*}${COL_DEF}"
  fi
}

## Add keys to apt for new package sources
## Valid Arguments: URL
##
##    add_keys(String url, String keyFile)
##
add_keys() {
  local repoKey="/usr/share/keyrings/${2}.gpg"

  echo -n "$(timestamp) [openHABian] Adding required keys to apt... "

  if curl -fsSL "$1" | gpg --dearmor > "$repoKey"; then
    echo "OK"
  else
    echo "FAILED"
    rm -f "$repoKey"
    return 1;
  fi
}

## Check key for expiration within 30 days
##
##    check_keys(String keyFile)
##
check_keys() {
  local repoKey="/usr/share/keyrings/${2}.gpg"

  gpgKeys=$(gpg --with-colons --fixed-list-mode --show-keys ${repoKey} | cut -d: -f7 | awk NF)
  currentTime=$(date +%s)
  if [ -n "$gpgKeys" ]; then
    while IFS= read -r keyExpiry; do
      diff=$((keyExpiry - currentTime))
      daysLeft=$((diff/(60*60*24)))
      if [ ${daysLeft} -lt 30 ]; then
        return 1
      fi
    done <<< "${gpgKeys}"
  fi
  return 0
}


## Update given git repo and switch to specfied branch / tag
##
##    update_git_repo(String path, String branch)
##
update_git_repo() {
  local branch
  local path

  branch="$2"
  path="$1"

  echo -n "$(timestamp) [openHABian] Updating $(basename "$path"), ${branch} branch from git... "

  if ! cond_redirect git -C "$path" fetch origin; then echo "FAILED (fetch origin)"; return 1; fi
  if ! cond_redirect git -C "$path" fetch --tags --force --prune; then echo "FAILED (fetch tags)"; return 1; fi
  if ! cond_redirect git -C "$path" reset --hard "origin/${branch}"; then echo "FAILED (reset to origin)"; return 1; fi
  if ! cond_redirect git -C "$path" clean --force -x -d; then echo "FAILED (clean)"; return 1; fi
  if cond_redirect git -C "$path" checkout "${branch}"; then echo "OK"; else echo "FAILED (checkout ${branch})"; return 1; fi
}
## Function to get public IP
## Argument 1 is optional to contain a hostname to resolve
##
##    get_public_ip()
##
get_public_ip() {
  local pubIP
  local localName1="myip.opendns.com"
  local localName2="o-o.myaddr.l.google.com"

  if ! [[ -x $(command -v dig) ]]; then return 1; fi
  if [[ $# -eq 1 ]]; then
    localName1="$1"
    localName2="$2"
  fi
  if ! pubIP="$(dig +short "${localName1}" @resolver1.opendns.com | tail -1)"; then return 1; fi
  if [[ -z $pubIP ]]; then
    if ! pubIP="$(dig -4 +short "${localName1}" @resolver1.opendns.com | tail -1)"; then return 1; fi
  fi
  if [[ -z $pubIP ]]; then
    if ! pubIP="$(dig TXT +short "${localName2}" @ns1.google.com)"; then return 1; fi
    if [[ -z $pubIP ]]; then
      if ! pubIP="$(dig -4 TXT +short "${localName2}" @ns1.google.com)"; then return 1; fi
    fi
  fi
  echo "$pubIP" | tr -dc '0-9.'
}


## Enable or disable the RPi WiFi module
## Valid arguments: "enable" or "disable"
##
##    enable_disable_wifi(String option)
##
enable_disable_wifi() {
  if ! is_pi; then return 0; fi

  if [[ $1 == "enable" ]]; then
    echo -n "$(timestamp) [openHABian] Enabling WiFi... "
    if grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?disable-wifi" /boot/config.txt; then
      if sed -i -E '/^[[:space:]]*dtoverlay=(pi3-)?disable-wifi/d' /boot/config.txt; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
    else
      echo "OK"
    fi
  elif [[ $1 == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Disabling WiFi... "
    if ! grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?disable-wifi" /boot/config.txt; then
      if echo "dtoverlay=disable-wifi" >> /boot/config.txt; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
    else
      echo "OK"
    fi
  fi
}

# fingerprinting based on
# https://www.raspberrypi.org/documentation/hardware/raspberrypi/revision-codes/README.md
is_pizero() {
  # shellcheck disable=SC2154
  if [[ "$hw" == "pi0" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]09[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pizerow() {
  if [[ "$hw" == "pi0w" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[cC][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pizerow2() {
  if [[ "$hw" == "pi0w2" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]12[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pione() {
  if [[ "$hw" == "pi1" ]]; then return 0; fi
  if grep -q "^Revision\\s*:\\s*00[0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo; then
    return 0
  elif grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[0-36][0-9a-fA-F]$" /proc/cpuinfo; then
    return 0
  else
    return 1
  fi
}
is_cmone() {
  # shellcheck disable=SC2154
  if [[ "$hw" == "cm1" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]06[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pitwo() {
  if [[ "$hw" == "pi2" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]04[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pithree() {
  if [[ "$hw" == "pi3" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[8dDeE][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_cmthree() {
  if [[ "$hw" == "cm3" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[aA][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pithreeplus() {
  if [[ "$hw" == "pi3+" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[dDeE][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_cmthreeplus() {
  if [[ "$hw" == "cm3+" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]10[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pifour() {
  if [[ "$hw" == "pi4" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]11[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pifour_8GB() {
  if [[ "$hw" == "pi4_8gb" ]]; then return 0; fi
  totalMemory="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  if is_pifour && [[ $totalMemory -gt 5000000 ]]; then return 0; else return 1; fi
}
is_cmfour() {
  if [[ "$hw" == "cm4" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]14[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pi400() {
  if [[ "$hw" == "pi400" ]]; then return 0; fi
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]13[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pi() {
  if is_pifour || is_cmfour || is_pi400 || is_cmthreeplus || is_cmthree || is_pithreeplus || is_pithree || is_pitwo || is_pione || is_cmone || is_pizerow || is_pizerow2 || is_pizero; then return 0; fi
  return 1
}
is_pi_wlan() {
  if is_pifour || is_pi400 || is_pithreeplus || is_pithree || is_pizerow || is_pizerow2; then return 0; fi
  return 1
}
is_pi_bt() {
  if is_pifour || is_pi400 || is_pithreeplus || is_pithree || is_pizerow || is_pizerow2; then return 0; fi
  return 1
}
is_cm() {
  if is_cmone || is_cmthree || is_cmthreeplus || is_cmfour; then return 0; fi
  return 1
}
is_arm() {
  if is_armv6l || is_armv7l || is_aarch64; then return 0; fi
  return 1;
}
is_arm64() {
  # shellcheck disable=SC2154
  if [[ "$hwarch" == "arm64" ]]; then return 0; fi
  case "$(uname -m)" in
    arm64) return 0 ;;
    *) return 1 ;;
  esac
}
is_armv6l() {
  if [[ "$hwarch" == "armv6l" ]]; then return 0; fi
  case "$(uname -m)" in
    armv6l) return 0 ;;
    *) return 1 ;;
  esac
}
is_armv7l() {
  if [[ "$hwarch" == "armv7l" ]]; then return 0; fi
  case "$(uname -m)" in
    armv7l) return 0 ;;
    *) return 1 ;;
  esac
}
is_aarch64() {
  if [[ "$hwarch" == "aarch64" ]] || [[ "$hwarch" == "arm64" ]]; then return 0; fi
  case "$(uname -m)" in
    aarch64|arm64) return 0 ;;
    *) return 1 ;;
  esac
}
is_x86_64() {
  if [[ "$hwarch" == "x86_64" ]] || [[ "$hwarch" == "amd64" ]]; then return 0; fi
  case "$(uname -m)" in
    x86_64|amd64) return 0 ;;
    *) return 1 ;;
  esac
}
is_ubuntu() {
  # shellcheck disable=SC2154
  if [[ "$osrelease" == "ubuntu" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "Ubuntu" ]]
  return $?
}
is_debian() {
  if [[ "$osrelease" == "debian" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "=debian" ]]
  return $?
}
# 32 bit image returns true (0)
# 64 bit image returns false (1) for now
is_raspbian() {
  if [[ "$osrelease" == "raspbian" ]]; then return 0; fi
  [[ "$(cat /etc/*release*)" =~ "Raspbian" ]]
  return $?
}
# /etc/os-release actually does not reflect the name on 64 bit
is_raspios() {
  if [[ "$osrelease" == "raspios" ]] || is_raspbian || [[ "$(cat /etc/*release*)" =~ "Raspberry Pi OS" ]]; then return 0; fi
  if ! [[ -f /boot/issue.txt ]]; then return 1; fi
  [[ "$(cat /boot/issue.txt)" =~ "Raspberry Pi reference" ]]
  return $?
}
# Debian/Raspbian oldoldoldstable
is_stretch() {
  if [[ "$osrelease" == "stretch" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "stretch" ]]
  return $?
}
# Debian/Raspbian oldoldstable
is_buster() {
  if [[ "$osrelease" == "buster" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "buster" ]]
  return $?
}
# Debian/Raspbian oldstable
is_bullseye() {
  if [[ "$osrelease" == "bullseye" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "bullseye" ]]
  return $?
}
# Debian/Raspbian stable
is_bookworm() {
  if [[ "$osrelease" == "bookworm" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "bookworm" ]]
  return $?
}
# Debian/Raspbian unstable
is_sid() {
  if [[ "$osrelease" == "sid" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "sid" ]]
  return $?
}
# Ubuntu 16, deprecated
is_xenial() {
  if [[ "$osrelease" == "xenial" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "xenial" ]]
  return $?
}
# Ubuntu 18.04 LTS
is_bionic() {
  if [[ "$osrelease" == "bionic" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "bionic" ]]
  return $?
}
# Ubuntu 20.04 LTS
is_focal() {
  if [[ "$osrelease" == "focal" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "focal" ]]
  return $?
}
# Ubuntu 22.04 LTS
is_jellyfish() {
  if [[ "$osrelease" == "jellyfish" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "jellyfish" ]]
  return $?
}
running_in_docker() {
  if [[ -n $DOCKER ]]; then return 0; fi
  if grep -qs 'docker\|lxc' /proc/1/cgroup; then
    return 0
  else
    if [[ -f /.dockerenv ]]; then
      return 0
    fi
    return 1
  fi
}
running_on_github() {
  [[ -n "$GITHUB_RUN_ID" ]]
  return $?
}

## Attempt a command "$1" for either a default of 10 times or
## for "$2" times unless "$1" evaulates to 0.
## Sleeps for 1 second or for "$3" seconds between each attempt.
## Returns number of command attemps remaining.
##
##    tryUntil(String cmd, int attempts, int interval)
##
tryUntil() {
  local cmd
  local attempts
  local interval

  cmd="$1"
  attempts="${2:-10}"
  interval="${3:-1}"

  until [[ $attempts -le 0 ]]; do
    cond_echo "\\nexecuting $cmd \\c"
    eval "$cmd"
    out=$?
    if [[ $out -eq 0 ]]; then break; fi
    sleep "$interval"
    if [[ -z $SILENT ]]; then
      echo -e "#${attempts}. $COL_DEF"
    fi
    ((attempts-=1))
  done
  if [[ -z $SILENT ]]; then
    echo -e "$COL_DEF"
  fi

  return "$attempts"
}

## Returns 0 / true if device has less than 900MB of total memory
## Returns 1 / false if device has more than 900MB of total memory
##
##    has_lowmem()
##
has_lowmem() {
  local totalMemory

  totalMemory="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"

  if [[ -z $totalMemory ]]; then return 1; fi # assume that device does not have low memory
  if [[ $totalMemory -lt 900000 ]]; then return 0; else return 1; fi
}

## Returns 0 / true if device has more than 1500MB of total memory
## Returns 1 / false if device has less than 1500MB of total memory
##
##    has_hasmem()
##
has_highmem() {
  local totalMemory

  totalMemory="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"

  if [[ -z $totalMemory ]]; then return 1; fi # assume that device does not have high memory
  if [[ $totalMemory -gt 1500000 ]]; then return 0; else return 1; fi
}

## Attempt to update apt package lists 10 times
## unless 'apt-get update' evaulates to 0.
## Sleeps for 1 second between each attempt.
##
##    wait_for_apt_to_be_ready()
##
wait_for_apt_to_be_ready() {
  local attempts
  local interval
  local pid

  attempts="10"
  interval="1"

  until [[ $attempts -le 0 ]]; do
    apt-get update &> /dev/null & pid=$!
    if [[ $(eval "$(tail --pid=$pid -f /dev/null)") -eq 0 ]]; then return 0; fi
    sleep "$interval"
    ((attempts-=1))
  done

  return 1
}

## Start 'apt-get update' in the background.
##
##    apt_update()
##
apt_update() {
  nohup apt-get update &> /dev/null & export PID_APT=$!
}

## Wait for background 'apt-get update' process to finish or
## start a new process if it was not already completed.
##
##    wait_for_apt_to_finish_update()
##
wait_for_apt_to_finish_update() {
  local spin='-\|/'
  local i

  if [[ -z $PID_APT ]]; then
    apt_update
  fi
  echo -n "$(timestamp) [openHABian] Updating Linux package information... "
  while kill -0 "$PID_APT" &> /dev/null; do
    i=$(( (i + 1) % 4 ))
    echo -ne "${spin:i:1} ${ESC}2D"
    sleep 0.5
  done
  echo "OK"
}

## Select destination block device
## Argument 1 is a block device name prefix string
## Argument 2 are title and display contents of selection box
##
##    select_blkdev(String, String, String)
##
select_blkdev() {
  if [[ -z "$INTERACTIVE" ]]; then
    return 0;
  fi
  declare -a array=()
  while read -r id foo{,} size foo{,,}; do
    array+=("$id"     "$size" )
  done < <(lsblk -i | tr -d '`\\|' | grep -E "${1}" | tr -d '\\-')

  if [[ ${#array[@]} -eq 0 ]]; then
    retval=0
    whiptail --title "$2" --msgbox "No block device to match pattern \"${1}\" found." 7 75 3>&1 1>&2 2>&3
  else
    ((count=${#array[@]} + 8))
    # shellcheck disable=SC2034
    retval="$(whiptail --title "$2" --cancel-button Cancel --ok-button Select --menu "\\n${3}" "${count}" 76 0 "${array[@]}" 3>&1 1>&2 2>&3)"
  fi
}

## install bind9-dnsutils package if available (currently only in sid and focal)
## else resort to dnsutils
##
##    install_dnsutils()
##
install_dnsutils() {
  apt-get install --yes dnsutils

  return $?
}

## is the comitup WiFi hotspot active
##
##    is_hotspot_connected()
##
is_hotspot() {
  if ! [[ -x $(command -v "comitup-cli") ]]; then return 1; fi
  if echo "q" | comitup-cli | grep -q 'State: HOTSPOT'; then return 0; else return 1; fi
}

## has WiFi been connected to a wireless network by means of a comitup hotspot
##
##    is_wifi_connected()
##
is_wifi_connected() {
  if ! [[ -x $(command -v "comitup-cli") ]]; then return 1; fi
  if echo "q" | comitup-cli | grep -q 'State: CONNECTED'; then return 0; else return 1; fi
}

## Add dependency on zram up: install/uninstall dependencies in zram-config.service
## Argument 1 is "install" or "remove"
## all remaining arguments are service names that zram must be available for to start
##
##    zram_dependency
##
zram_dependency() {
  local zramServiceConfig="/etc/systemd/system/zram.service.d/override.conf"
  local install="yes"

  if ! [[ -f /etc/ztab ]]; then return 0; fi
  if [[ "$1" == "install" ]]; then shift 1; fi
  if [[ "$1" == "remove" ]]; then install="no"; shift 1; fi

  if ! [[ -f $zramServiceConfig ]]; then
    echo -n "$(timestamp) [openHABian] Setting up zram service... "
    if ! cond_redirect mkdir -p /etc/systemd/system/zram.service.d; then echo "FAILED (prepare directory)"; return 1; fi
    if cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/zram-override.conf /etc/systemd/system/zram.service.d/override.conf; then echo "OK"; else echo "FAILED (copy configuration)"; return 1; fi
  fi

  for arg in "$@"; do
    if [[ "$install" == "yes" ]] && ! grep -qs "${arg}.service" $zramServiceConfig; then
      echo -n "$(timestamp) [openHABian] Adding ${arg} to zram service dependencies... "
      if cond_redirect sed -i -e "/^Before/s/$/ ${arg}.service/" $zramServiceConfig; then echo "OK"; else echo "FAILED (sed add dependency)"; return 1; fi
    fi
    if [[ "$install" == "no" ]] && grep -qs "${arg}.service" $zramServiceConfig; then
      echo -n "$(timestamp) [openHABian] Removing ${arg} from zram service dependencies... "
      if cond_redirect sed -i -e "s/ ${arg}.service//g" $zramServiceConfig; then echo "OK"; else echo "FAILED (sed dependency removal)"; return 1; fi
    fi
  done
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
}

## Fix permissions on a file OR recursively on a directory that MIGHT be on zram
## return true even if it does not exist or if zram is not installed
## Argument 1 is directory to fix
## Argument 2 is string to pass to chown i.e. "user:group" e.g. "mosquitto:openhabian"
## Argument 3 & 4 are optional strings to pass to chmod for file(s) (3) and dirs (4) e.g. "0755" "644"
##
##    fix_permissions
##
fix_permissions() {
  if ! [[ -e $1 ]]; then return 0; fi

  if ! chown "$2" "$1"; then return 1; fi
  if [[ -n "$3" ]]; then
    [[ -f $1 ]] && if ! (find "$1" -type f -print0 | xargs -0 chmod "$3"); then return 1; fi
    if [[ -n "$4" ]]; then
      [[ -d $1 ]] && if ! (find "$1" -type d -print0 | xargs -0 chmod "$4"); then return 1; fi
    fi
  fi
  return 0
}

## Function to check if openHAB is running on the current system. Returns
## 0 / true if openHAB is running and 1 / false if not.
##
##    openhab_is_running()
##
openhab_is_running() {
  if openhab_is_installed && [[ $(systemctl is-active openhab) == "active" ]]; then return 0; else return 1; fi
}

## Functions to check it a given supported program is installed should be placed below here

## Function to check if openHAB 2 is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab2_is_installed()
##
openhab2_is_installed() {
  if [[ $(dpkg -s 'openhab2' 2> /dev/null | grep Status | cut -d' ' -f2) =~ ^(install|hold)$ ]]; then return 0; else return 1; fi
}
## Function to check if openHAB 3 is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab3_is_installed()
##
openhab3_is_installed() {
  #if [[ $(dpkg -s 'openhab' 2> /dev/null | grep Status | cut -d' ' -f2) =~ ^(install|hold)$ ]]; then return 0; else return 1; fi
  #if [[ $(dpkg -s 'openhab' 2> /dev/null | grep Config-Version | cut -d ' ' -f2 | cut -d '.' -f1) = 3 ]]; then return 0; else return 1; fi
  if [[ $(dpkg -s 'openhab' 2> /dev/null | grep -E '^Version' | cut -d ' ' -f2 | cut -d '.' -f1) = 3 ]]; then return 0; else return 1; fi
}
## Function to check if openHAB is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab_is_installed()
##
openhab4_is_installed() {
  if [[ $(dpkg -s 'openhab' 2> /dev/null | grep -E '^Version' | cut -d ' ' -f2 | cut -d '.' -f1) = 4 ]]; then return 0; else return 1; fi
}
## Function to check if openHAB is installed on the current system. Returns
## 0 / true if openHAB is installed and 1 / false if not.
##
##    openhab_is_installed()
##
openhab_is_installed() {
  if openhab2_is_installed || openhab3_is_installed || openhab4_is_installed; then return 0; else return 1; fi
}

## Check if amanda is installed
##
##    amanda_is_installed
##
amanda_is_installed() {
  if dpkg -s 'amanda-common' 'amanda-server' 'amanda-client' &> /dev/null; then return 0; fi
  return 1
}

## Check if InfluxDB is installed
##
##    influxdb_is_installed
##
influxdb_is_installed() {
  if dpkg -s 'influxdb' &> /dev/null && [[ -d /var/lib/influxdb ]]; then return 0; fi
  return 1
}

## Check if Grafana is installed
##
##    grafana_is_installed
##
grafana_is_installed() {
  if dpkg -s 'grafana' &> /dev/null && [[ -s /etc/grafana/grafana.ini ]]; then return 0; fi
  return 1
}

## Check if node is installed
##
##    node_is_installed
##
node_is_installed() {
  if [[ -x $(command -v npm) ]] && [[ $(node --version) =~ v1[6-9]* ]]; then return 0; fi
  return 1
}

## Check if samba is installed
##
##    samba_is_installed
##
samba_is_installed() {
  if dpkg -s 'samba' &> /dev/null && [[ -s /etc/samba/smb.conf ]]; then return 0; fi
  return 1
}

## Check if firemotd is installed
##
##    firemotd_is_installed
##
firemotd_is_installed() {
  if [[ -d /opt/firemotd ]] && [[ -x $(command -v FireMotD) ]]; then return 0; fi
  return 1
}

## Check if zigbee2mqtt is installed
##
##    zigbee2mqtt_is_installed
##
zigbee2mqtt_is_installed() {
  if [[ -d /opt/zigbee2mqtt ]] && [[ -s /etc/systemd/system/zigbee2mqtt.service ]]; then return 0; fi
  return 1
}

## Check if exim is installed
##
##    exim_is_installed
##
exim_is_installed() {
  if dpkg -s 'mailutils' 'exim4' &> /dev/null; then return 0; fi
  return 1
}

## Check if homegear is installed
##
##    homegear_is_installed
##
homegear_is_installed() {
  if dpkg -s 'homegear' &> /dev/null && [[ -d /var/lib/homegear ]]; then return 0; fi
  return 1
}

## Check if mosquitto is installed
##
##    mosquitto_is_installed
##
mosquitto_is_installed() {
  if dpkg -s 'mosquitto' 'mosquitto-clients' &> /dev/null; then return 0; fi
  return 1
}

## Check if knxd is installed
##
##    knxd_is_installed
##
knxd_is_installed() {
  if dpkg -s 'knxd' &> /dev/null; then return 0; fi
  return 1
}

## Check if 1wire is installed
##
##    1wire_is_installed
##
1wire_is_installed() {
  if dpkg -s 'owserver' 'ow-shell' &> /dev/null; then return 0; fi
  return 1
}

## Check if miflora is installed
##
##    miflora_is_installed
##
miflora_is_installed() {
  if [[ -d /opt/miflora-mqtt-daemon ]] && [[ -s /etc/systemd/system/miflora.service ]]; then return 0; fi
  return 1
}

## Check if nginx is installed
##
##    nginx_is_installed
##
nginx_is_installed() {
  if dpkg -s 'nginx' && [[ -s /etc/nginx/sites-enabled/openhab ]]; then return 0; fi
  return 1
}

## Check if deconz is installed
##
##    deconz_is_installed
##
deconz_is_installed() {
  if dpkg -s 'deconz' && [[ -s /lib/systemd/system/deconz.service ]]; then return 0; fi
  return 1
}

## Check if zram is installed
##
##    zram_is_installed
##
zram_is_installed() {
  if [[ -s /etc/ztab ]] && [[ -d /opt/zram ]]; then return 0; fi
  return 1
}

## Check if habapp is installed
##
##    habapp_is_installed
##
habapp_is_installed() {
  if [[ -x $(command -v habapp) ]] && [[ -s /etc/systemd/system/habapp.service ]]; then return 0; fi
  return 1
}
