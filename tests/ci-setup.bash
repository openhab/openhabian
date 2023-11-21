#!/usr/bin/env bash

##########################
#### Load help method ####
##########################
# shellcheck disable=SC1090
source functions/helpers.bash

## This function formats log messages
##
##    echo_process(String message)
##
echo_process() {
  echo -e "${COL_CYAN}$(timestamp) [openHABian] ${*}${COL_DEF}"
}

if [[ $1 == "github" ]]; then
  repoURL="$(git remote get-url origin)"
  repoBranch="$(git rev-parse --abbrev-ref HEAD)"

  if ! [[ $repoURL == "https"* ]]; then
    # Convert URL from SSH to HTTPS
    username="$(echo "$repoURL" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\1#p')"
    if [[ -z $username ]]; then
      echo_process "Could not identify git user while converting to SSH URL. Exiting."
      exit 1
    fi
    reponame="$(echo "$repoURL" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\2#p')"
    if [[ -z $reponame ]]; then
      echo_process "Could not identify git repo while converting to SSH URL. Exiting."
      exit 1
    fi
    repoURL="https://github.com/${username}/${reponame}.git"
  fi

  sed -i 's|repositoryurl=.*$|repositoryurl='"${repoURL}"'|' build-image/*.conf
  if git show-ref --tags "$2" --quiet; then
    sed -i 's|clonebranch=.*$|clonebranch='"${clonebranch:-openHAB}"'|' build-image/*.conf
    exit
  fi
  sed -i 's|clonebranch=.*$|clonebranch='"${repoBranch}"'|' build-image/*.conf
  sed -i 's#debugmode=.*$#debugmode=maximum#' build-image/openhabian.conf
fi
