#!/usr/bin/env bash
set -e

##########################
#### Load help method ####
##########################
# shellcheck disable=SC1090
source "$(dirname "$0")"/functions/helpers.bash

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
if [[ $1 == "docker-full" ]]; then
  echo_process "Starting Docker installation test for amd64..."
  cond_redirect docker stop install-test || true
  cond_redirect docker rm install-test || true
  cond_redirect docker build --tag openhabian/install-openhabian -f Dockerfile.amd64 .
  cond_redirect docker run --name "install-test" --privileged -d openhabian/install-openhabian
  cond_redirect docker exec -i "install-test" bash -c "./build.bash local-test && mv ~/.profile ~/.bash_profile && /boot/first-boot.bash"
  echo_process "Test complete, please review result in terminal. Access tested container by executing: \"docker exec -it install-test bash\""

  echo_process "Starting Docker BATS tests for amd64..."
  cond_redirect docker build --tag openhabian/bats-openhabian -f Dockerfile.amd64 .
  cond_redirect docker run --rm --name "unit-tests" -i openhabian/bats-openhabian bash -c 'bats --tap --recursive --filter "unit-." .'
  cond_redirect docker run --rm --name "installation-tests" -i openhabian/bats-openhabian bash -c 'bats --tap --recursive --filter "installation-." .'
  cond_redirect docker run --rm --name "destructive-tests" -i openhabian/bats-openhabian bash -c 'bats --tap --recursive --filter "destructive-." .'
  cond_redirect echo_process "Test complete, please review result in terminal."
  exit 0
elif [[ $1 == "shellcheck" ]]; then
  shellcheck -x -s bash openhabian-setup.sh
  shellcheck -x -s bash functions/*.bash
  shellcheck -x -s bash build-image/*.bash
  shellcheck -x -s bash build.bash ci-setup.bash
else
  echo_process "Please provide a valid test profile, \"docker-full\" or \"shellcheck\". Exiting"
  exit 0
fi
