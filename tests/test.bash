#!/usr/bin/env bash
set -e

## This function formats log messages
##
##    echo_process(String message)
##
echo_process() {
  echo -e "${COL_CYAN}$(timestamp) [openHABian] ${*}${COL_DEF}"
}

###########################
#### Test script start ####
###########################

# What test case should be run?
if [[ $1 == "shellcheck" ]]; then
  shellcheck -x -s bash openhabian-setup.sh
  shellcheck -x -s bash functions/*.bash
  shellcheck -x -s bash build-image/*.bash
  shellcheck -x -s bash build.bash tests/ci-setup.bash
else
  echo_process "Please provide a valid test profile, \"shellcheck\". Exiting"
  exit 0
fi
