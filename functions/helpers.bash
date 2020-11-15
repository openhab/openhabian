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
timestamp() { date +"%F_%T_%Z"; }

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
##    add_keys(String url)
##
add_keys() {
  local repoKey

  repoKey="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Adding required keys to apt... "
  cond_redirect wget -qO "$repoKey" "$1"
  if cond_redirect apt-key add "$repoKey"; then
    echo "OK"
    rm -f "$repoKey"
  else
    echo "FAILED"
    rm -f "$repoKey"
    return 1;
  fi
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
##
##    get_public_ip()
##
get_public_ip() {
  local pubIP

  if ! [[ -x $(command -v dig) ]]; then return 1; fi

  if pubIP="$(dig +short myip.opendns.com @resolver1.opendns.com | tail -1)"; then echo "$pubIP"; return 0; else return 1; fi
  if [[ -z $pubIP ]]; then
    if pubIP="$(dig -4 +short myip.opendns.com @resolver1.opendns.com | tail -1)"; then echo "$pubIP"; return 0; else return 1; fi
  fi
  if [[ -z $pubIP ]]; then
    if pubIP="$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')"; then echo "$pubIP"; return 0; else return 1; fi
    if [[ -z $pubIP ]]; then
      if pubIP="$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')"; then echo "$pubIP"; return 0; else return 1; fi
    fi
  fi
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
  grep -q "^Revision\\s*:\\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]08[0-9a-fA-F]$" /proc/cpuinfo
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
is_pi() {
  if is_pizero || is_pizerow || is_pione || is_cmone || is_pitwo || is_pithree || is_cmthree || is_pithreeplus || is_cmthreeplus || is_pifour || is_cmfour; then return 0; fi
  return 1
}
is_cm() {
  if is_cmone || is_cmthree || is_cmthreeplus || is_cmfour; then return 0; fi
  return 1
}
is_pine64() {
  [[ $(uname -r) =~ "pine64-longsleep" ]]
  return $?
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
  if [[ "$release" == "ubuntu" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "Ubuntu" ]]
  return $?
}
# introduction of Raspberry Pi OS:
# 32 bit returns false (1)
# 64 bit returns true (0)
is_debian() {
  if [[ "$release" == "debian" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "Debian" ]]
  return $?
}
# introduction of Raspberry Pi OS:
# 32 bit returns true (0)
# 64 bit returns false (1)
is_raspbian() {
  if [[ "$release" == "raspbian" ]]; then return 0; fi
  [[ "$(cat /etc/*release*)" =~ "Raspbian" ]]
  return $?
}
# TODO: Not official yet, update when os-release file actually reflects the name change
is_raspios() {
  if [[ "$release" == "raspios" ]]; then return 0; fi
  [[ "$(cat /etc/*release*)" =~ "Raspberry Pi OS" ]]
  return $?
}
# Debian/Raspbian, to be deprecated, LTS ends 2020-06-30
is_jessie() {
  if [[ "$release" == "jessie" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "jessie" ]]
  return $?
}
# Debian/Raspbian oldstable
is_stretch() {
  if [[ "$release" == "stretch" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "stretch" ]]
  return $?
}
# Debian/Raspbian stable
is_buster() {
  if [[ "$release" == "buster" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "buster" ]]
  return $?
}
# Debian/Raspbian testing
is_bullseye() {
  if [[ "$release" == "bullseye" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "bullseye" ]]
  return $?
}
# Debian/Raspbian unstable
is_sid() {
  if [[ "$release" == "sid" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "sid" ]]
  return $?
}
# Ubuntu 14, deprecated
is_trusty() {
  if [[ "$release" == "trusty" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "trusty" ]]
  return $?
}
# Ubuntu 16, deprecated
is_xenial() {
  if [[ "$release" == "xenial" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "xenial" ]]
  return $?
}
# Ubuntu 18.04 LTS
is_bionic() {
  if [[ "$release" == "bionic" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "bionic" ]]
  return $?
}
# Ubuntu 20.04 LTS
is_focal() {
  if [[ "$release" == "focal" ]]; then return 0; fi
  [[ $(cat /etc/*release*) =~ "focal" ]]
  return $?
}
running_in_docker() {
  grep -q 'docker\|lxc' /proc/1/cgroup
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
  apt-get update &> /dev/null & PID_APT=$!
}

## Wait for background 'apt-get update' process to finish or
## start a new process if it was not already completed.
##
##    wait_for_apt_to_finish_update()
##
wait_for_apt_to_finish_update() {
  echo -n "$(timestamp) [openHABian] Updating Linux package information... "
  if [[ -z $PID_APT ]]; then
    apt_update
  fi
  if tail --pid=$PID_APT -f /dev/null; then echo "OK"; else echo "FAILED"; return 1; fi
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
  if apt-cache show bind9-dnsutils &>/dev/null; then
    apt-get install --yes bind9-dnsutils
  else
    apt-get install --yes dnsutils
  fi

  return $?
}

## is the comitup WiFi hotspot active
##
##    is_hotspot_connected()
is_hotspot() {
  if ! [[ -x $(command -v "comitup-cli") ]]; then return 1; fi
  if echo "q" | comitup-cli | grep -q 'State: HOTSPOT'; then return 0; else return 1; fi
}

## has WiFi been connected to a wireless network by means of a comitup hotspot
##
##    is_wifi_connected()
is_wifi_connected() {
  if ! [[ -x $(command -v "comitup-cli") ]]; then return 1; fi
  if echo "q" | comitup-cli | grep -q 'State: CONNECTED'; then return 0; else return 1; fi
}

