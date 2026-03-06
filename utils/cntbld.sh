#!/bin/bash

# workflow for continuous build

set -e

update_buildroot_repositories() {
	br2-external/br-pull.sh
	cd buildroot
	log_text="automatic build $(date --iso-8601="seconds")"
	git merge -m "$log_text" origin/master
	cd
	}

update_kernel_versions() {
	br2-external/scripts/kupdate.py
	}

build_and_deploy() {
	br2-external/mkall.sh --build --deploy --purge
	}

update_buildroot_repositories
update_kernel_versions
build_and_deploy
