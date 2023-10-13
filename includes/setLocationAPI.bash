#!/usr/bin/bash

#/usr/bin/echo $@ > /etc/openhab/services/location.cfg
/usr/bin/echo "org.openhab.i18n:location=${1}" > /etc/openhab/services/location.cfg
sed -i "s|location=.*|location=\"${1}\"|;s|apikey=.*|apikey=\"${2}\",|" "${OPENHAB_CONF:-/etc/openhab}/things/wetter.things"
