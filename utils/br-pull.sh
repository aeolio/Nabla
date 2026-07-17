#!/bin/sh

instances="test/buildroot staging/buildroot buildroot"

FG_RED="\33[31m"
FG_GREEN="\33[32m"
FG_BLUE="\33[94m"
RESET="\33[0m"

git_status="Your branch is ahead of 'origin/master' by .* commits."

backup_wip() {
	if ! git diff-index --quiet HEAD -- ; then
		git stash push || exit 10
		export BACKUP_CREATED=1
	fi
}

restore_wip() {
	if [ "$BACKUP_CREATED" = 1 ]; then
		git stash pop || exit 11
		unset BACKUP_CREATED
	fi
}

pull_instance() {
	current_branch=$(git branch --show)
	if [ "$current_branch" != 'master' ]; then
		git checkout master || exit 1
		git pull || exit 2
		git checkout "$current_branch" || exit 3
		export NEEDS_MERGING=1
	elif ! git status | grep -q "$git_status"; then
		git pull || exit 2
	else
		printf "${FG_BLUE}  skipped due to open change requests${RESET}\n"
	fi
}

merge_instance() {
	current_branch=$(git branch --show)
	if [ "$current_branch" != 'master' ]; then
		printf "${FG_GREEN}Merge %s${RESET}\n" "$1"
		log_text="auto merge $(date --iso-8601='seconds')"
		git merge -m "$log_text" origin/master || exit 4
		unset NEEDS_MERGING
	fi
}

BACKUP_CREATED=0
NEEDS_MERGING=0
current_dir=$(pwd)

for d in $instances
do
	cd "$HOME/$d" || exit 5
	printf "${FG_RED}Pull %s${RESET}\n" "$d"
	backup_wip
	pull_instance "$d"
	if [ "$NEEDS_MERGING" = 1 ]; then
		merge_instance "$d"
	fi
	restore_wip
	cd "$current_dir" || exit 6
done
