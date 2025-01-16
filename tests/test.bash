#!/usr/bin/env bash

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
elif [[ $1 == "docker-install" ]]; then
  if [[ -n $2 ]]; then
    saved_java_opt="$(ggrep -oP 'java_opt=\K.*' build-image/openhabian.conf)"
    gsed -i 's|java_opt=.*$|java_opt='"${2}"'|' build-image/openhabian.conf
  fi
  if [[ -n $3 ]]; then
    saved_debugmode="$(ggrep -oP 'debugmode=\K.*' build-image/openhabian.conf)"
    gsed -i 's|debugmode=.*$|debugmode='"${3}"'|' build-image/openhabian.conf
  fi
  docker buildx build --tag openhabian/install-openhabian -f tests/Dockerfile.rpi5-installation --platform linux/arm64 .
  docker run --privileged --rm --platform linux/arm64 --name openhabian -d openhabian/install-openhabian:latest
  docker exec -i "openhabian" bash -c './build.bash local-test && /boot/first-boot.bash'
  docker stop openhabian
  if [[ -n $2 ]]; then
    gsed -i 's|java_opt=.*$|java_opt='"${saved_java_opt}"'|' build-image/openhabian.conf
  fi
  if [[ -n $3 ]]; then
    gsed -i 's|debugmode=.*$|debugmode='"${saved_debugmode}"'|' build-image/openhabian.conf
  fi
else
  echo_process "Please provide a valid test profile, \"shellcheck\". Exiting"
  exit 0
fi
