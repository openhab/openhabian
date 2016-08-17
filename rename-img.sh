#!/bin/sh

for file in raspbian-ua-netinst-*.*
do
   mv -v "$file" "${file//raspbian/openhabian}"
done
