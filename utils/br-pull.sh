#/bin/sh

instances="test/buildroot staging/buildroot buildroot"
merge_instance="buildroot"
merge_branch="nabla"

BACKUP_CREATED=0

backup_wip() {
	if ! git diff-index --quiet HEAD -- ; then
		git stash || exit 10
		export BACKUP_CREATED=1
	fi
}

restore_wip() {
	if [ "$BACKUP_CREATED" = 1 ]; then
		git stash apply || exit 11
		unset BACKUP_CREATED
	fi
}

pull_instance() {
	printf "pull %s\n" $1
	cd ~/$1
	current_branch=$(git branch --show)
	if [ $current_branch != 'master' ]; then
		backup_wip
		git checkout master || exit 1
		git pull || exit 2
		git checkout $merge_branch || exit 3
		restore_wip
	else
		git pull || exit 2
	fi
}

merge_instance() {
	cd ~/$1
	current_branch=$(git branch --show)
	if [ $current_branch == $merge_branch ]; then
		printf "merge %s\n" $1
		log_text="auto merge $(date --iso-8601='seconds')"
		git merge -m "$log_text" origin/master
	fi
}

for d in $instances
do
	current_dir=$(pwd)
	pull_instance $d
	if [ $d == $merge_instance ]; then
		merge_instance $d
	fi
	cd $current_dir
done
