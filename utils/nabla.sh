#!/bin/sh

# backup machine configurations

# shellcheck disable=SC2034 # ignore unused variables
FG_BLUE="\33[34m"
FG_GREEN="\33[32m"
FG_RED="\33[31m"
RESET="\33[0m"

NABLA_CONF="etc/nabla.conf"
RSYNC_FILE="/tmp/rsync.txt"

for arg in "$@"
do
	case $arg in

		-n)
		DRY_RUN="$arg"
		;;

		-f)
		FORCE_REBUILD=1
		;;

		*)
		printf "Usage: %s [options]\n", $0
		printf "\t options ::= -f (force rebuild), -n (dry-run)\n"
		exit 1;
		;;

	esac
done

# mutually exclusive
[ -n "$DRY_RUN" ] && FORCE_REBUILD=0

current_dir=$(pwd)
cd ~/nabla/config || exit 2

# shellcheck source=/dev/null # just a configuration file
# shellcheck disable=SC3028 # HOSTNAME loaded from configuration file
for s in ~/*/system.conf
do
	# load machine configuration
	. "$s"
	# machine is online
	if ssh -o ConnectTimeout=2 -q "root@$HOSTNAME" true; then
		printf "${FG_GREEN}Pulling %s configuration${RESET}\n" "$HOSTNAME"
		git checkout "$HOSTNAME" || exit 3
		# get the current configuration file first
		# shellcheck disable=SC2086 # word splitting is necessary
		rsync -clprt \
			"root@$HOSTNAME:/$NABLA_CONF" \
			"./$NABLA_CONF" || exit 4
		# load config file
		. "$NABLA_CONF"
		# create file list
		echo "$NABLA_SYNC_DIRECTORIES" | tr ' \t' '\n\0' > "$RSYNC_FILE"

		[ $FORCE_REBUILD -eq 1 ] && rm -fr *

		# now synchronize whole machine
		# shellcheck disable=SC2086 # word splitting is necessary
		rsync $DRY_RUN \
			-clprtv --delete --files-from "$RSYNC_FILE" \
			"root@$HOSTNAME:/" \
			./ || exit 6
		# revert change if this is just a dry run
		[ -n "$DRY_RUN" ] && git checkout "$NABLA_CONF" >/dev/null 2>&1 

		status=$(git status --porcelain)
		if [ -n "$status" ]; then
			untracked=$(echo "$status" | awk '/^[?]{2} / {print $2}')
			[ -n "$untracked" ] && ( git add $untracked || exit 7 )
			m="config auto-sync $(date +"%F %T")"
			git commit -a -m "$m" || exit 8
		fi
	else
		printf "${FG_BLUE}Skipping %s${RESET}\n" "$HOSTNAME"
	fi
	rm -f "$RSYNC_FILE"
done

cd "$current_dir" || exit 9
