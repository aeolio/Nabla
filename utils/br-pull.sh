#/bin/sh

instances="test/buildroot staging/buildroot buildroot"
instance_to_merge="buildroot"
branch_to_merge="nabla"

BACKUP_CREATED=0

FG_RED="\33[31m"
FG_GREEN="\33[32m"
RESET="\33[0m"

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
	if [ $current_branch != 'master' ]; then
		git checkout master || exit 1
		git pull || exit 2
		git checkout $current_branch || exit 3
	else
		git pull || exit 2
	fi
}

merge_instance() {
	current_branch=$(git branch --show)
	if [ $current_branch != 'master' ]; then
		printf "${FG_GREEN}Merge %s${RESET}\n" $1
		log_text="auto merge $(date --iso-8601='seconds')"
		git merge -m "$log_text" origin/master || exit 4
	fi
}

current_dir=$(pwd)

for d in $instances
do
	cd ~/$d
	printf "${FG_RED}Pull %s${RESET}\n" $d
	backup_wip
	pull_instance $d
	if [ $d == $instance_to_merge ]; then
		merge_instance $d
	fi
	restore_wip
	cd $current_dir
done
