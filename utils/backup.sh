#!/bin/sh

archive="br2-external_config_$(date +%Y%m%d-%H%M).tar.bz2"
source=""
source="$source board/"
source="$source configs/"
source="$source package/"
source="$source patches/"
source="$source scripts/"
source="$source skeleton/"
source="$source utils/"

source="$source Config.in"
source="$source Config.in.linux"
source="$source external.*"
source="$source LICENSE"
source="$source local.mk"
source="$source README"

source="$source _backup/s87localopt/"

tar cjf $archive $source
