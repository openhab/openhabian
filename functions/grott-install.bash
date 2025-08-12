#!/usr/bin/env bash

## Install the Grott proxy server on the current system
##
##   install_grott(String install|remove, String username, String openhab-ip-address)
##
install_grott() {
  # Validate install type argument
  if [ "$#" -lt 1 ]; then
    echo "Error: Please supply install type."
    echo "Usage: $0 <install|remove> <username> (<openhab-ip>)"
    exit 1
  elif [[ "$1" != "install" && "$1" != "remove" ]]; then
    echo "Error: Invalid install type '$1'. Use 'install' or 'remove'."
    exit 1
  fi
  INSTALL_TYPE="$1"

  # Validate user name argument
  if [ "$#" -lt 2 ]; then
    echo "Error: Please supply user name."
    echo "Usage: $0 <install|remove> <username> (<openhab-ip>)"
    exit 1
  elif ! id "$2" &>/dev/null; then
    echo "Error: User '$2' does not exist."
    exit 1
  fi
  USERNAME="$2"
  INSTALL_DIR="/home/$USERNAME/grott"

  SERVICE_FILE="/etc/systemd/system/grott.service"

  if [[ $INSTALL_TYPE == "install" ]]; then
    # Validate openhab ip address argument
    if [ "$#" -lt 3 ]; then
      echo "Error: Please supply openHAB IP address."
      echo "Usage: $0 <install|remove> <username> <openhab-ip>"
      exit 1
    elif ! [[ "$3" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Error: Invalid IP address format: $3"
      exit 1
    fi
    EXT_URL="http://$3:8080/growatt"

    echo -n "[openHABian] Installing Grott Proxy with extension URL: $EXT_URL "

    # Update system and install dependencies
    sudo apt update
    sudo apt install -y python3 python3-pip
    sudo pip3 install paho-mqtt requests # paho-mqtt is a required dependency (even if disabled)

    # Prepare installation directory and pouplate it with Grott files
    sudo -u "$USERNAME" mkdir -p "$INSTALL_DIR"
    if [ ! -d "$INSTALL_DIR" ]; then
      echo "Error: Installation directory $INSTALL_DIR does not exist."
      exit 1
    fi

    download_grott_files || {
        echo "Failed to download Grott files. Exiting."
        return 1
    }

    # Create grott.service systemd file from template
    if ! sed -e "s|%INSTALL_DIR|$INSTALL_DIR|g" \
             -e "s|%USERNAME|$USERNAME|g" \
            "${BASEDIR:-/opt/openhabian}/includes/grott.service" > "$SERVICE_FILE"; then
        echo "FAILED (sed substitution)"
        return 1
    fi

    # Create grott.ini file from template
    if ! sed -e "s|%EXT_URL|$EXT_URL|g" \
            "${BASEDIR:-/opt/openhabian}/includes/grott.ini" > "$INSTALL_DIR/grott.ini"; then
        echo "FAILED (sed substitution)"
        return 1
    fi

    # Enable and start service
    sudo systemctl daemon-reexec
    sudo systemctl enable grott
    sudo systemctl start grott

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Grott Proxy installed" --msgbox "We installed Grott Proxy on your system." 7 80
    fi

    return 0

  elif [[ $INSTALL_TYPE == "remove" ]]; then
    echo -n "[openHABian] Removing Grott Proxy... "

    # Stop and disable systemd service
    if sudo systemctl is-active --quiet grott; then
      sudo systemctl stop grott
    fi

    if sudo systemctl is-enabled --quiet grott; then
      sudo systemctl disable grott
    fi

    # Remove systemd service file
    if [ -f "$SERVICE_FILE" ]; then
      sudo rm "$SERVICE_FILE"
      sudo systemctl daemon-reload
    fi

    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
      sudo rm -rf "$INSTALL_DIR"
      echo "Removed $INSTALL_DIR"
    else
      echo "Directory $INSTALL_DIR not found."
    fi

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Grott Proxy removed" --msgbox "We removed Grott Proxy from your system." 7 80
    fi

    return 0
  fi
}

download_grott_files() {
  GROTT_FILE_URL="https://raw.githubusercontent.com/johanmeijer/grott/master"
  GROTT_PY_FILES=(
    "grott.py"
    "grottconf.py"
    "grottdata.py"
    "grottproxy.py"
    "grottserver.py"
    "grottsniffer.py"
  )

  for file in "${GROTT_PY_FILES[@]}"; do
    FILE_URL="${GROTT_FILE_URL}/${file}"
    echo "Downloading $file..."
    curl -fsSL "$FILE_URL" -o "${INSTALL_DIR}/${file}" || {
        echo "Failed to download $file"
         return 1
    }
  done
}
