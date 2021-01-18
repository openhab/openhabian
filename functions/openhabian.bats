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
  
  # Wait 5 seconds so that webservice becomes ready
  sleep 5s

  # Call webservice to trigger service startet
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] openHABian dashboard calling webservice...${COL_DEF}" >&3
  run wget -S --spider https://127.0.0.1:9090 --no-check-certificate 2>&1
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] webservice call succesful.${COL_DEF}" >&3
  
  # Check if cockpit service becames active after wget call
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if cockpit service is running...${COL_DEF}" >&3
  run systemctl is-active --quiet cockpit.service
  if [ "$status" -ne 0 ]; then systemctl status cockpit.service; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] cockpit service is running.${COL_DEF}" >&3

  # Check if wget call initiated a new https instance of the webservice
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] Checking if cockpit-wsinstance-https is running...${COL_DEF}" >&3
  run systemctl is-active --quiet cockpit-wsinstance-https*.service
  if [ "$status" -ne 0 ]; then echo "Error cockpit-wsinstance-https* is not running. It seams like the wget call was not succesful.${COL_DEF}" >&3; systemctl status cockpit-wsinstance-https*.service; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] cockpit-wsinstance-https* is running.${COL_DEF}" >&3

  # Check if openHABian dashboard is available
  echo -e "# ${COL_CYAN}$(timestamp) [openHABian] openHABian dashboard calling dashboard application...${COL_DEF}" >&3
  run wget -S --spider https://127.0.0.1:9090/openhabian --no-check-certificate 2>&1
  if [ "$status" -ne 0 ]; then echo "$output" >&3; fi
  [ "$status" -eq 0 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] openhabian dashboard call succesful.${COL_DEF}" >&3

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
  [ "$(ls /usr/share/cockpit/openhabian/ | wc -l)" -eq 7 ]
  echo -e "# ${COL_GREEN}$(timestamp) [openHABian] openHABian dashboard html files are fine.${COL_DEF}" >&3

}
