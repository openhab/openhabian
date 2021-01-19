#!/usr/bin/env bats

load openhabian.bash
load helpers.bash

@test "installation-openhabian-dashboard" {
  #
  # install
  #
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] openHABian dashboard installation startet...${COL_DEF}" >&3
  run openhabian_dashboard_install
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] openHABian dashboard installation successful.${COL_DEF}" >&3
  
  # Check if cockpit socket was loaded after installation
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if cockpit socket is loaded...${COL_DEF}" >&3
  socket_status=$(systemctl status --quiet cockpit.socket || true)
  if [[ "$socket_status" != *"Loaded: loaded"* ]]; then systemctl status cockpit.socket; fi
  [[ "$socket_status" == *"Loaded: loaded"* ]]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] cockpit socket is loaded.${COL_DEF}" >&3

  # Check if cockpit service was loaded after installation
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if cockpit service is loaded...${COL_DEF}" >&3
  service_status=$(systemctl status --quiet cockpit.service || true)
  if [[ "$service_status" != *"Loaded: loaded"* ]]; then systemctl status cockpit.service; fi
  [[ "$service_status" == *"Loaded: loaded"* ]]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] cockpit service is loaded.${COL_DEF}" >&3

  # Check all dashboard script file permissions for "-x" permission
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] openHABian dashboard verifying script file permission...${COL_DEF}" >&3
  for i in /opt/openhabian/dashboard/src/scripts/*.sh; do
    if [[ -s "$i" ]]; then
      [ -x "$i" ]
    fi
  done
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] openHABian dashboard script file permission are fine.${COL_DEF}" >&3

  # Check all dashboard html files
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] openHABian dashboard verifying all html files...${COL_DEF}" >&3
  [ "$(find /usr/share/cockpit/openhabian/ | wc -l)" -eq 8 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] openHABian dashboard html files are fine.${COL_DEF}" >&3

}
