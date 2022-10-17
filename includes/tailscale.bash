#!/bin/bash

BASEDIR=/opt/openhabian
source ${BASEDIR}/functions/helpers.bash
source ${BASEDIR}/functions/vpn.bash

setup_tailscale $*
