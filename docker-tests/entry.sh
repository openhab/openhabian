#!/bin/bash

set -m

# This command only works in privileged container

if ip link add dummy0 type dummy &> /dev/null; then
	PRIVILEGED=true
	# clean the dummy0 link
    ip link delete dummy0 &> /dev/null
else
	PRIVILEGED=false
fi

# Send SIGTERM to child processes of PID 1.
function signal_handler()
{
	kill "$pid"
}

function start_udev()
{
	if [ "$UDEV" == "on" ]; then
		if [ "$INITSYSTEM" != "on" ]; then
			if command -v udevd &>/dev/null; then
				unshare --net udevd --daemon &> /dev/null
			else
				unshare --net /lib/systemd/systemd-udevd --daemon &> /dev/null
			fi
			udevadm trigger &> /dev/null
		fi
	else
		if [ "$INITSYSTEM" == "on" ]; then
			systemctl mask systemd-udevd
		fi
	fi
}

function mount_dev()
{
	tmp_dir='/tmp/tmpmount'
	mkdir -p "$tmp_dir"
	mount -t devtmpfs none "$tmp_dir"
	mkdir -p "$tmp_dir/shm"
	mount --move /dev/shm "$tmp_dir/shm"
	mkdir -p "$tmp_dir/mqueue"
	mount --move /dev/mqueue "$tmp_dir/mqueue"
	mkdir -p "$tmp_dir/pts"
	mount --move /dev/pts "$tmp_dir/pts"
	touch "$tmp_dir/console"
	mount --move /dev/console "$tmp_dir/console"
	umount /dev || true
	mount --move "$tmp_dir" /dev

	# Since the devpts is mounted with -o newinstance by Docker, we need to make
	# /dev/ptmx point to its ptmx.
	# ref: https://www.kernel.org/doc/Documentation/filesystems/devpts.txt
	ln -sf /dev/pts/ptmx /dev/ptmx
	mount -t debugfs nodev /sys/kernel/debug
}

function init_systemd()
{
	GREEN='\033[0;32m'
	echo -e "${GREEN}Systemd init system enabled."
	for var in $(compgen -e); do
		printf '%q=%q\n' "$var" "${!var}"
	done > /etc/docker.env
	echo 'source /etc/docker.env' >> ~/.bashrc

	printf '#!/bin/bash\n exec ' > /etc/resinApp.sh
	printf '%q ' "$@" >> /etc/resinApp.sh
	chmod +x /etc/resinApp.sh

	mkdir -p /etc/systemd/system/resin.service.d
	cat <<-EOF > /etc/systemd/system/resin.service.d/override.conf
		[Service]
		WorkingDirectory=$(pwd)
	EOF

	sleep infinity &
	exec env DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket SYSTEMD_LOG_LEVEL=info /sbin/init quiet systemd.show_status=0
}

function init_non_systemd()
{
	# trap the stop signal then send SIGTERM to user processes
	trap signal_handler SIGRTMIN+3 SIGTERM

	# echo error message, when executable file doesn't exist.
	if CMD=$(command -v "$1" 2>/dev/null); then
		shift
		"$CMD" "$@" &
		pid=$!
		wait "$pid"
		exit_code=$?
		fg &> /dev/null || exit "$exit_code"
	else
		echo "Command not found: $1"
		exit 1
	fi
}

INITSYSTEM=$(echo "$INITSYSTEM" | awk '{print tolower($0)}')

case "$INITSYSTEM" in
	'1' | 'true')
		INITSYSTEM='on'
	;;
esac

UDEV=$(echo "$UDEV" | awk '{print tolower($0)}')

case "$UDEV" in
	'1' | 'true')
		UDEV='on'
	;;
esac

if $PRIVILEGED; then
	# Only run this in privileged container
	mount_dev
	start_udev
fi

if [ "$INITSYSTEM" = "on" ]; then
	init_systemd "$@"
else
	init_non_systemd "$@"
fi
