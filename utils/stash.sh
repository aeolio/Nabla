#/bin/sh

tmpdir=/tmp/br2-external
mkdir -p $tmpdir

for f in $(git status | awk '/modified:/ { print $2 }')
do
	rsync -R $f $tmpdir
done
