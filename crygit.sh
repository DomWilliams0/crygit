#!/usr/bin/env bash

CONFIG_NAME=".crygit"

show_help() {
	echo "Usage: $0 <name> <subcommand>"
	exit 0
}

validate_name() {
	[ -n "$NAME" ]
}

config_exists() {
	[ -f $CONFIG_NAME ]
}

cmd_init() {
	echo initting $NAME
}

# ---------------------

if (( $# < 2 )); then
	show_help
fi

ARGC=$#
NAME="$1"
SCMD="$2"


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
