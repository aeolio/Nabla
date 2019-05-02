#!/bin/sh

# start interbench without console interaction
interbench -r -u -W Audio < /dev/zero > /dev/null 2>&1 &
