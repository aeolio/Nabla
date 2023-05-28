list_rt_priorities()
{
	ps | \
	awk '/[[:digit:]+]/{ if ($5 != "ps") { cmd = "chrt -p " $1 " | sed \"s/.*: //g\" | tr \"\n\" \" \""; system(cmd); print "\t" $5; } }' | \
	grep SCHED_FIFO
}

mount_system_disks()
{
	_partitions="boot NABLA"
	mode=$1
	for p in $_partitions; do
		mount -o remount,$mode /media/$p || exit 1
	done
}

alias psr=list_rt_priorities
alias mrw='mount_system_disks rw'
alias mro='mount_system_disks ro'
