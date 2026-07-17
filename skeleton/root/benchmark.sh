#!/bin/sh

# check if PREEMPT_RT is enabled
if ! dmesg | grep -q PREEMPT_RT; then echo 'PREEMPT_RT is OFF'; fi

# run the usual tests
printf "  uname = %s\n" $(uname -r)
printf "  tasks = %s\n" $(ps | wc -l)
# busybox's free calculation differs from procps-ng
printf "  u.ram = %s\n" $(free | awk '/Mem:/ { print ($2 - $7) }')
case "$1" in
  -c)
    # start interbench without console interaction
    interbench -r -u -W Audio < /dev/zero > /dev/null 2>&1 &
    ;;
  -u)
    # start interbench with processor affinity
    interbench -r -u -W Audio
    ;;
  *)
    # start interbench normally
    interbench -r -W Audio
    ;;
esac
