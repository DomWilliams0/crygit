#!/usr/bin/env bash
set -e

CONFIG_PATH="$HOME/.config/crygit"

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
	if config_exists; then
		echo $CONFIG_NAME already exists
		exit 1
	fi

	# TODO generate key and init cryfs

	write_config
}

# ---------------------

if (( $# < 2 )); then
	show_help
fi

ARGC=$#
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
