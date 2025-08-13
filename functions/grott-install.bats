#!/usr/bin/env bats

load 'install_grott.bash'
load 'helpers.bash'

# Define some common variables
INSTALL_TYPE="install"
USERNAME="testuser"
INSTALL_DIR="/home/${USERNAME}/grott"
SERVICE_FILE="/etc/systemd/system/grott.service"
TEMP_BASEDIR="/tmp/openhabian_test_bats"

setup() {
  # Create a temporary directory for the installation
  mkdir -p "$BATS_TEST_TMPDIR/home/$USERNAME"

  # Set INSTALL_DIR to the temporary location for isolation
  INSTALL_DIR="$BATS_TEST_TMPDIR/home/$USERNAME/grott"

  # Override SERVICE_FILE for testing
  SERVICE_FILE="$BATS_TEST_TMPDIR/etc/systemd/system/grott.service" 
  mkdir -p "$BATS_TEST_TMPDIR/etc/systemd/system"

  # Create mock systemd service and grott.ini templates
  mkdir -p "${TEMP_BASEDIR}/includes"
  echo "[Unit]" > "${TEMP_BASEDIR}/includes/grott.service"
  echo "Description=Grott Proxy" >> "${TEMP_BASEDIR}/includes/grott.service"
  echo "User=%USERNAME" >> "${TEMP_BASEDIR}/includes/grott.service"
  echo "WorkingDirectory=%INSTALL_DIR" >> "${TEMP_BASEDIR}/includes/grott.service"

  echo "[Grott]" > "${TEMP_BASEDIR}/includes/grott.ini"
  echo "exturl=%EXT_URL" >> "${TEMP_BASEDIR}/includes/grott.ini"

  # Redirect BASEDIR to the temporary location
  export BASEDIR="$TEMP_BASEDIR"

  # Mock external commands
  export -f ip=mock_ip_route_get
  export -f apt=mock_apt_update # Mock apt update and apt install through apt
  export -f sudo=mock_sudo_command # Wrap sudo
  export -f pip3=mock_pip3_install # Mock pip3 install
  export -f curl=mock_curl
  export -f systemctl=mock_systemctl_command # Wrap systemctl
  export -f whiptail=mock_whiptail
  
  # Set username for the script to use our testuser
  export username="$USERNAME"
}

teardown() {
  # Clean up the temporary installation directory
  rm -rf "$INSTALL_DIR"
  rm -rf "$TEMP_BASEDIR"
  rm -rf "$BATS_TEST_TMPDIR/etc"

  # Unset mocked functions
  unset -f ip
  unset -f apt
  unset -f sudo
  unset -f pip3
  unset -f curl
  unset -f systemctl
  unset -f whiptail
  unset username
}

# Helper for wrapping sudo
mock_sudo_command() {
  local cmd="$1"
  shift
  case "$cmd" in
    apt)
      mock_apt_update "$@"
      ;;
    pip3)
      mock_pip3_install "$@"
      ;;
    rm)
      mock_sudo_rm "$@"
      ;;
    systemctl)
      mock_systemctl_command "$@"
      ;;
    *)
      # Default behavior for unmocked sudo commands
      sudo "$cmd" "$@"
      ;;
  esac
}

# Helper for wrapping systemctl commands
mock_systemctl_command() {
  local cmd="$1"
  shift
  case "$cmd" in
    daemon-reexec)
      mock_systemctl_daemon_reexec "$@"
      ;;
    enable)
      mock_systemctl_enable "$@"
      ;;
    start)
      mock_systemctl_start "$@"
      ;;
    is-active)
      mock_systemctl_is_active "$@"
      ;;
    is-enabled)
      mock_systemctl_is_enabled "$@"
      ;;
    daemon-reload)
      echo "systemctl daemon-reload"
      return 0
      ;;
    *)
      # Default behavior for unmocked systemctl commands
      systemctl "$cmd" "$@"
      ;;
  esac
}

@test "install_grott: Install with valid 'install' argument" {
  run install_grott "install"

  assert_equal "$status" 0 
  assert_output --partial "[openHABian] Installing Grott Proxy"

  # Verify directories and files were created
  run stat "$INSTALL_DIR"
  assert_equal "$status" 0

  run stat "$INSTALL_DIR/grott.py"
  assert_equal "$status" 0

  run stat "$INSTALL_DIR/grottext.py"
  assert_equal "$status" 0

  run stat "$SERVICE_FILE"
  assert_equal "$status" 0

  run stat "$INSTALL_DIR/grott.ini"
  assert_equal "$status" 0

  # Verify the service file content
  run cat "$SERVICE_FILE"
  assert_output --partial "Description=Grott Proxy"
  assert_output --partial "User=${USERNAME}"
  assert_output --partial "WorkingDirectory=${INSTALL_DIR}"

  # Verify grott.ini content (check EXT_URL substitution)
  run cat "$INSTALL_DIR/grott.ini"
  assert_output --partial "exturl=http://192.168.1.100:8080/growatt"
}

@test "install_grott: Remove Grott with 'remove' argument" {
  # Simulate an existing installation
  mkdir -p "$INSTALL_DIR"
  touch "$INSTALL_DIR/grott.py"
  echo "Unit]Description=Grott Proxy" > "$SERVICE_FILE"

  run install_grott "remove"

  assert_equal "$status" 0
  assert_output --partial "[openHABian] Removing Grott Proxy..."

  # Verify files and directories are removed
  run stat "$INSTALL_DIR"
  assert_equal "$status" 1 # Should indicate the directory doesn't exist

  run stat "$SERVICE_FILE"
  assert_equal "$status" 1 # Should indicate the file doesn't exist
}

@test "install_grott: Invalid install type argument" {
  run install_grott "invalid_type"

  assert_equal "$status" 1
  assert_output --partial "Error: Invalid install type 'invalid_type'."
}

@test "install_grott: Missing install type argument" {
  run install_grott

  assert_equal "$status" 1
  assert_output --partial "Error: Please supply install type."
}

@test "install_grott: handle invalid IP address" {
  # Override the mock to return an invalid IP
  mock_ip_route_get() {
    echo "something is not an ip address"
  }
  export -f ip=mock_ip_route_get

  run install_grott "install"
  assert_equal "$status" 1
  assert_output --partial "Error: Invalid IP address format or range:"
}

@test "install_grott: handle mkdir failure" {
  # Mock sudo mkdir to fail
  mock_sudo_mkdir() {
    return 1
  }
  export -f sudo=mock_sudo_mkdir

  run install_grott "install"
  assert_equal "$status" 1
  assert_output --partial "Error: Failed to create installation directory"
}

@test "install_grott: handle download_grott_files failure" {
  # Mock curl to fail
  mock_curl() {
    return 1
  }
  export -f curl=mock_curl

  run install_grott "install"
  assert_equal "$status" 1
  assert_output --partial "Failed to download Grott files."
}

@test "download_grott_files: Verify files are downloaded" {
  local temp_dir="$BATS_TEST_TMPDIR/downloads"
  mkdir -p "$temp_dir"

  run download_grott_files "$temp_dir"
  assert_equal "$status" 0

  # Verify all expected files were touched by the mock curl
  run stat "$temp_dir/grott.py"
  assert_equal "$status" 0

  run stat "$temp_dir/grottext.py"
  assert_equal "$status" 0
}
