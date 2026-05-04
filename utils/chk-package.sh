#!/bin/sh

buildroot=~/buildroot
output=/tmp/pkg-list.html

pwd=$(pwd)
cd $buildroot || exit
pkg_list=$(for f in dl/*; do printf "%s," $(basename $f); done)
support/scripts/pkg-stats --html $output -p $pkg_list
cd "$pwd" || exit
