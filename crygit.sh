#!/usr/bin/env bash
set -e

CONFIG_PATH="$HOME/.config/crygit"
KEY_LENGTH=512
CRYFS_CMD="/usr/bin/env CRYFS_NO_UPDATE_CHECK=false /usr/bin/cryfs"

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
	echo -n "Generating key of $KEY_LENGTH bytes ... "
	key=$(/usr/bin/openssl rand -hex $KEY_LENGTH)
	echo done
	cfg[key]=$key

	# generate cryfs config
	echo "Creating cryfs config in $src ... "
	printf "y\n%s\n%s\n" $key $key | $CRYFS_CMD $src $mnt

	# save all to config
	echo "Writing config to $PATH"
	write_config
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

	*)
		echo Invalid subcommand
		show_help
esac
