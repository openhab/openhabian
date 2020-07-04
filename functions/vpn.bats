#!/usr/bin/env bats

load vpn.bash
load helpers.bash

teardown_file() {
  systemctl kill wgquick@wg0.service || true
}

@test "destructive-wireguard" {
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN installation starting...${COL_DEF}" >&3
  run install_wireguard install 3>&-
  run setup_wireguard
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] Wireguard VPN installation successful.${COL_DEF}" >&3
  run systemctl is-active wg-quick@wg0.service 3>&-
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi

  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Wireguard VPN uninstalling...${COL_DEF}" >&3
  run install_wireguard remove 3>&-
  run systemctl is-active wg-quick@wg0.service 3>&-
  if [ "$status" -eq 0 ]; then echo "$output" >&3; fi
}
