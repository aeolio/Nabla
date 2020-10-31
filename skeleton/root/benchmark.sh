#!/bin/sh

# run the usual tests
echo -n "uname = " && uname -r
echo -n "tasks = " && ps | wc -l
echo -n "free = " && free | awk '/Mem:/ { print $3 " /" ($2 - $7) }'
case "$1" in
  -i)
    # start interbench without console interaction
    interbench -r -u -W Audio < /dev/zero > /dev/null 2>&1 &
    ;;
  *)
    # start interbench normally
    interbench -r -u -W Audio
    ;;
esac

