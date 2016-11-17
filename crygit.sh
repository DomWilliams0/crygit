#!/usr/bin/env bash
set -e

CONFIG_PATH="$HOME/.config/crygit"
KEY_LENGTH=512

run_cryfs() {
	/usr/bin/env CRYFS_NO_UPDATE_CHECK=false /usr/bin/cryfs ${cfg[src]} ${cfg[mnt]}
}

run_git() {
	/usr/bin/git --git-dir ${cfg[src]}/.git --work-tree ${cfg[src]} "$@"
}

show_help() {
	echo "Usage: $0 <name> <subcommand>"
	exit 0
}

validate_name() {
	[ -n $NAME ]
}

create_config_dir() {
	/usr/bin/mkdir -p $CONFIG_PATH
}

config_exists() {
	[ -f $PATH ]
}

load_config() {
	if ! config_exists; then
		echo "Config for $NAME not found at $PATH"
		exit 1
	fi

	while read line
	do
		if echo $line | /usr/bin/grep -F = &>/dev/null; then
			varname=$(echo "$line" | /usr/bin/cut -d '=' -f 1)
			cfg[$varname]=$(echo "$line" | /usr/bin/cut -d '=' -f 2-)
		fi
	done < $PATH
}

write_config() {
	create_config_dir
	{
		echo "# crygit config last updated $(/usr/bin/date)" >&3
		for key in ${!cfg[@]}; do
			echo $key=${cfg[$key]} >&3
		done
	} 3>$PATH
}

cmd_init() {
	if (( $ARGC != 2 )); then
		echo "Usage: $0 $SCMD <encrypted fs path> <fs mount point>"
		exit 1
	fi

	src=${ARGV[0]}
	mnt=${ARGV[1]}

	if config_exists; then
		echo $NAME already exists
		exit 1
	fi

	# set mount points in config
	cfg[src]=$src
	cfg[mnt]=$mnt

	# generate key
	echo "Generating key of $KEY_LENGTH bytes"
	key=$(/usr/bin/openssl rand -hex $KEY_LENGTH)
	cfg[key]=$key

	# generate cryfs config
	echo "Creating cryfs config in $src"
	printf "y\n%s\n%s\n" $key $key | run_cryfs

	# create git repo
	echo "Creating git repo"
	/usr/bin/git init $src
	run_git add -A 1>/dev/null
	run_git commit -a -m "Create filesystem"

	# save all to config
	echo "Writing config to $PATH"
	write_config
	/usr/bin/chmod 600 $PATH
}

prepare_mount_change() {
	if (( $ARGC != 0 )); then
		echo "Usage: $0 $SCMD"
		exit 1
	fi

	load_config
}

cmd_unmount() {
	prepare_mount_change
	/usr/bin/fusermount -u ${cfg[mnt]}
	echo Unmounted $NAME
}

cmd_mount() {
	prepare_mount_change
	printf "%s\n" ${cfg[key]} | run_cryfs
	echo Mounted $NAME
}

# ---------------------

if (( $# < 2 )); then
	show_help
fi

ARGC=$(($#-2))
ARGV=("${@:3}")
SCMD="$2"
typeset -A cfg
cfg=(
	[name]="$1"
)

NAME=${cfg[name]}
PATH="$CONFIG_PATH/$NAME"

if ! validate_name; then
	echo Invalid name
	exit 1
fi

case $SCMD in
	init)
		cmd_init
		;;
	unmount)
		cmd_unmount
		;;
	mount)
		cmd_mount
		;;

	*)
		echo Invalid subcommand
		show_help
esac
