#!/usr/bin/env bash

## Install the Grott proxy server on the current system
##
##   install_grott(String install|remove)
##
install_grott() {
  # Fail on errors
  set -e

  # Validate install type argument
  if [ "$#" -lt 1 ]; then
    echo "Error: Please supply install type."
    echo "Usage: $0 <install|remove>"
    exit 1
  elif [[ "$1" != "install" && "$1" != "remove" ]]; then
    echo "Error: Invalid install type '$1'. Use 'install' or 'remove'."
    exit 1
  fi

  local INSTALL_TYPE="$1"
  local USERNAME=${username:-openhabian}
  local INSTALL_DIR="/home/${USERNAME}/grott"
  local SERVICE_FILE="/etc/systemd/system/grott.service"

  if [[ $INSTALL_TYPE == "install" ]]; then
    # Get default IPv4 address
    local ipAddress
    ipAddress="$(ip route get 8.8.8.8 | awk '{print $7}' | xargs)"
    if ! [[ "$ipAddress" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Error: Invalid IP address format: $ipAddress"
      exit 1
    fi
    local EXT_URL="http://${ipAddress}:8080/growatt"

    echo "$(timestamp) [openHABian] Installing Grott Proxy with extension URL: $EXT_URL "

    # Update system and install dependencies. NOTE: paho-mqtt is a required dependency (even if disabled)
    sudo apt update
    sudo apt install -y python3 python3-pip python3-paho-mqtt python3-requests

    # Prepare installation directory
    sudo -u "$USERNAME" mkdir -p -m 755 "$INSTALL_DIR"
    if [ ! -d "$INSTALL_DIR" ]; then
      echo "Error: Installation directory $INSTALL_DIR does not exist."
      exit 1
    fi

    # Download Grott Python files to installation directory
    download_grott_files "$INSTALL_DIR" || {
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
            "${BASEDIR:-/opt/openhabian}/includes/grott.ini" > "${INSTALL_DIR}/grott.ini"; then
        echo "FAILED (sed substitution)"
        return 1
    fi

    # Enable and start service
    sudo systemctl enable grott --now
    sudo systemctl daemon-reload

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Grott Proxy installed" --msgbox "We installed Grott Proxy on your system." 7 80
    fi

    return 0

  elif [[ $INSTALL_TYPE == "remove" ]]; then
    echo "$(timestamp) [openHABian] Removing Grott Proxy... "

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

## Download the Grott Proxy Python files
##
##   download_grott_files(String install_directory)
##
download_grott_files() {
  local INSTALL_DIR="$1"
  local GROTT_FILE_URL="https://raw.githubusercontent.com/johanmeijer/grott/master"
  local GROTT_PY_FILES=(
      "grott.py"
      "grottconf.py"
      "grottdata.py"
      "grottproxy.py"
      "grottserver.py"
      "grottsniffer.py"
  )
  local GROTT_EXT_PY_FILE="grottext.py"
  local file url

  echo "Installing files to $INSTALL_DIR "

  # Download Grott main program Python files
  for file in "${GROTT_PY_FILES[@]}"; do
    url="${GROTT_FILE_URL}/${file}"
    echo "Downloading $file"
    curl -fsSL "$url" -o "${INSTALL_DIR}/${file}" || {
      echo "Failed to download $file"
      return 1
    }
  done

  # Download Grott extension Python file
  file="$GROTT_EXT_PY_FILE"
  url="${GROTT_FILE_URL}/examples/Extensions/${file}"
  echo "Downloading $file"
  curl -fsSL "$url" -o "${INSTALL_DIR}/${file}" || {
    echo "Failed to download $file"
    return 1
  }
}
