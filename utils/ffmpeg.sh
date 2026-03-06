#/bin/sh

keywords="decoders encoders hwaccels demuxers muxers parsers protocols bsfs indevs outdevs filters"

for kwd in $keywords;
do
	echo "### $kwd"
	./configure --list-$kwd | grep $1
done
