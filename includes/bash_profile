# ~/.bash_profile: executed by bash(1) for interactive shells.

if [ -f "/opt/openHABian-install-failed" ]; then
  echo ""
  echo -e -n "\e[31;01mAttention! \e[39;49;00m"
  echo "The openHABian setup process seems to have failed on your system."
  echo "Sorry, this shouldn't happen! Please restart the installation process. Chances"
  echo "are high setup will succeed on the second try."
  echo ""
  echo "In order to find the cause of the problem, have a look at the installation log:"
  echo -e "   \e[90;01msudo cat /boot/first-boot.log\e[39;49;00m"
  echo ""
  echo "Contact the openHAB community forum for help if the problem persists:"
  echo -e "\e[94;04mhttps://community.openhab.org/tags/openhabian\e[39;49;00m"
  echo ""
  return 0
elif [ -f "/opt/openHABian-install-inprogress" ]; then
  echo ""
  echo -e -n "\e[36;01mAttention! \e[39;49;00m"
  echo "The openHABian setup process is not finished yet."
  if [ -f /boot/first-boot.log ]; then watch cat /boot/first-boot.log; echo -e "\nProgress log:\n"; cat /boot/first-boot.log; echo -e "\n"; fi
  echo -e "\nPlease wait for a few more minutes, all preparation steps will be finished shortly."
  return 0
fi

if [ ! -f "/usr/bin/raspi-config" ]; then
  alias raspi-config="echo 'raspi-config is not part of openHABian, please use openhabian-config instead.'"
fi

if [ -f /opt/FireMotD/FireMotD ]; then
  echo
  bash /opt/FireMotD/FireMotD -HV --theme gray
fi

OHVERSION=$(dpkg-query --showformat='${Version}' --show openhab2)
OHBUILD=$(sed -n 's/build-no\s*: //p' /var/lib/openhab2/etc/version.properties)
if [ "$OHBUILD" == "- release build -" ]; then OHBUILD="Release Build"; fi

cat << 'EOF'

              Welcome to            __  _____    ____  _
            ____  ____  ___  ____  / / / /   |  / __ )(_)___ _____
           / __ \/ __ \/ _ \/ __ \/ /_/ / /| | / __  / / __ `/ __ \
          / /_/ / /_/ /  __/ / / / __  / ___ |/ /_/ / / /_/ / / / /
          \____/ .___/\___/_/ /_/_/ /_/_/  |_/_____/_/\__,_/_/ /_/
              /_/
EOF
echo "                  openHAB $OHVERSION ($OHBUILD)"
echo ""
echo ""
echo "Looking for a place to get started? Check out 'sudo openhabian-config' and the"
echo "documentation at https://www.openhab.org/docs/installation/openhabian.html"
echo "The openHAB dashboard can be reached at http://$(hostname):8080"
echo "To interact with openHAB on the command line, execute: 'openhab-cli --help'"
echo ""

# vim: filetype=sh
