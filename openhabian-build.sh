#!/usr/bin/env bash

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

/bin/bash clean.sh
/bin/bash update.sh
/bin/bash build.sh
/bin/bash buildroot.sh

rm -rf raspbian-ua-netinst-*.bz2

for file in raspbian-ua-netinst-*.*
do
   mv -v "$file" "${file//raspbian/openhabian}"
done
