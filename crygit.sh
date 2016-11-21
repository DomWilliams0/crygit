#!/usr/bin/env bash
set -e

CONFIG_PATH="$HOME/.config/crygit"
KEY_LENGTH=512

run_cryfs() {
	env CRYFS_NO_UPDATE_CHECK=false cryfs ${cfg[src]} ${cfg[mnt]}
}

run_git() {
	git --git-dir ${cfg[src]}/.git --work-tree ${cfg[src]} "$@"
}

has_any_remotes() {
	[ $(run_git remote | wc -l) != "0" ]
}

show_help() {
	echo "Usage: $0 <name> <subcommand>"
	exit 0
}

validate_name() {
	[ -n $NAME ]
}

create_config_dir() {
	mkdir -p $CONFIG_PATH
}

config_exists() {
	[ -f $CFG_PATH ]
}

load_config() {
	if ! config_exists; then
		echo "Config for $NAME not found at $CFG_PATH"
		exit 1
	fi

	while read line
	do
		if echo $line | grep -F = &>/dev/null; then
			varname=$(echo "$line" | cut -d '=' -f 1)
			cfg[$varname]=$(echo "$line" | cut -d '=' -f 2-)
		fi
	done < $CFG_PATH
}

write_config() {
	create_config_dir
	{
		echo "# crygit config last updated $(date)" >&3
		for key in ${!cfg[@]}; do
			echo $key=${cfg[$key]} >&3
		done
	} 3>$CFG_PATH
}

cmd_init() {
	if (( $ARGC != 2 )); then
		echo "Usage: $0 $SCMD <encrypted fs path> <fs mount point>"
		exit 1
	fi

	src=$(readlink -f ${ARGV[0]})
	mnt=$(readlink -f ${ARGV[1]})

	if config_exists; then
		echo $NAME already exists
		exit 1
	fi

	# set mount points in config
	cfg[src]=$src
	cfg[mnt]=$mnt

	# generate key
	echo "Generating key of $KEY_LENGTH bytes"
	key=$(openssl rand -hex $KEY_LENGTH)
	cfg[key]=$key

	# generate cryfs config
	echo "Creating cryfs config in $src"
	printf "y\n%s\n%s\n" $key $key | run_cryfs

	# create git repo
	echo "Creating git repo"
	git init $src
	run_git add -A 1>/dev/null
	run_git commit -a -m "Create filesystem"

	# save all to config
	echo "Writing config to $CFG_PATH"
	write_config
	chmod 600 $CFG_PATH
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
	fusermount -u ${cfg[mnt]}
	echo Unmounted $NAME
}

cmd_mount() {
	prepare_mount_change
	printf "%s\n" ${cfg[key]} | run_cryfs
	echo Mounted $NAME
}

remote_ensure_cmd() {
	if [ -z $1 ] || [ $1 != $2 ]; then
		echo "Invalid command"
		exit 1
	fi
}

cmd_remote() {
	load_config
	arg1=${ARGV[0]}
	arg2=${ARGV[1]}
	arg3=${ARGV[2]}

	case $ARGC in
		0)
			if ! has_any_remotes; then
				echo No remotes
			else
				run_git remote -v
			fi
			;;
		2)
			remote_ensure_cmd $arg1 "rm"
			run_git remote rm "$arg2"
			;;
		3)
			remote_ensure_cmd $arg1 "add"
			run_git remote add "$arg2" "$arg3"
			;;
		*)
			remote_ensure_cmd
			;;
	esac
}

cmd_sync() {
	if (( $ARGC != 0 )); then
		echo "Usage: $0 $SCMD"
		exit 1
	fi

	load_config

	run_git add -A >/dev/null

	set +e
	run_git commit -a -m "Update files" >/dev/null

	has_any_remotes || { echo "No remotes to sync to"; exit 1; }
	for remote in $(run_git remote); do
		echo Syncing to $remote
		run_git push --all $remote
		echo done
	done

	set -e
}

cmd_bigsync() {
	if (( $ARGC != 0 )); then
		echo "Usage: $0 $SCMD"
		exit 1
	fi

	load_config

	run_git add -A >/dev/null

	set +e
	echo Committing in small chunks
	commit_msg="Update files (inconsistent state)"
	for i in $(seq 0 15 | xargs printf "%X "); do
		run_git commit -m "$commit_msg" $(find ${cfg[src]} -maxdepth 1 -name "$i*" -printf "%f "); 1>/dev/null 2>&1
	done
	run_git commit -a -m "$commit_msg" >/dev/null

	has_any_remotes || { echo "No remotes to sync to"; exit 1; }
	for remote in $(run_git remote); do
		echo "Syncing one-by-one to $remote"

		for commit in $(run_git log --branches --not --remotes --reverse --pretty=format:"%H"); do
			run_git push "$remote" "$commit":master
		done
	done

	set -e
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
CFG_PATH="$CONFIG_PATH/$NAME"

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
	remote)
		cmd_remote
		;;
	sync)
		cmd_sync
		;;
	bigsync)
		cmd_bigsync
		;;
	*)
		echo Invalid subcommand
		show_help
esac
