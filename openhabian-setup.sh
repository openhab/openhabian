#!/usr/bin/env bash

# This file is a temporary fix to update installed system to new root file of openhabian, i.e. openhabian-setup.bash

# Make sure only root can run our script
echo -n "$ [openHABian] Checking for root privileges... "
if [[ $EUID -ne 0 ]]; then
  echo ""
  echo "This script must be run as root. Did you mean 'sudo openhabian-config'?" 1>&2
  echo "More info: https://www.openhab.org/docs/installation/openhabian.html"
  exit 1
else
  echo "OK"
fi

ln -sfn /opt/openhabian/openhabian-setup.bash /usr/local/bin/openhabian-config
/opt/openhabian/openhabian-setup.bash
