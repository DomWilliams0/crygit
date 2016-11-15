#!/usr/bin/env bash

CONFIG_NAME=".crygit"

show_help() {
	echo "Usage: $0 <name> <subcommand>"
	exit 0
}

validate_name() {
	[ -n "${cfg[name]}" ]
}

config_exists() {
	[ -f $CONFIG_NAME ]
}

write_config() {
	{
		echo "# crygit config last updated $(date)" >&3
		for key in ${!cfg[@]}; do
			echo $key=${cfg[$key]} >&3
		done
	} 3>$CONFIG_NAME
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
