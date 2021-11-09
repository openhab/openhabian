#!/usr/bin/env bats

load vpn.bash
load helpers.bash

setup_file() {
  export BASEDIR="${BATS_TEST_DIRNAME}/.."
}

teardown_file() {
  systemctl kill wg-quick@wg0.service || true
}

@test "destructive-wireguard_install" {
  if is_ubuntu; then skip "Not executing Wireguard test because it currently does not support Ubuntu."; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN installation starting...${COL_DEF}" >&3
  echo "osrelease = $osrelease" 
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN installation starting...${COL_DEF}" >&3
  cat /etc/*release)

  run install_wireguard install 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard VPN installation successful.${COL_DEF}" >&3

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN setup starting...${COL_DEF}" >&3
  run setup_wireguard 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard VPN setup successful.${COL_DEF}" >&3

  # cloning/removing interfaces will not work inside Docker ...
  #echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Wireguard service is running...${COL_DEF}" >&3
  #run systemctl is-active wg-quick@wg0.service 3>&-
  #if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  #[ "$status" -eq 0 ]
  #echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard service is running.${COL_DEF}" >&3
  #
  #echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN removal starting...${COL_DEF}" >&3
  #run install_wireguard remove 3>&-
  #if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  #[ "$status" -eq 0 ]
  #echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard VPN removal successful...${COL_DEF}" >&3
  #
  #echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if Wireguard service is running...${COL_DEF}" >&3
  #run systemctl is-active wg-quick@wg0.service 3>&-
  #if [ "$status" -eq 0 ]; then echo "$output" >&3; fi
  #[ "$status" -ne 0 ]
  #echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard service is not running...${COL_DEF}" >&3
}
