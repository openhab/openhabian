#!/usr/bin/env bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# log everything to a file
exec &> >(tee -a "openhabian-build-$(date +%Y-%m-%d_%H%M%S).log")

/bin/bash clean.sh
/bin/bash update.sh
/bin/bash build.sh
/bin/bash buildroot.sh

rm -rf raspbian-ua-netinst-*.bz2 &>/dev/null
rm -rf raspbian-ua-netinst-*.xz &>/dev/null

for file in raspbian-ua-netinst-*.*
do
  mv -v "$file" "${file//raspbian/openhabian}"
done
