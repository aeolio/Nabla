list_rt_priorities()
{
	ps | \
	awk '/[[:digit:]+]/{ if ($5 != "ps") { cmd = "chrt -p " $1 " | sed \"s/.*: //g\" | tr \"\n\" \" \""; system(cmd); print "\t" $5; } }' | \
	grep SCHED_FIFO
}

alias psr=list_rt_priorities
alias mrw='mount -o remount,rw /media/boot && mount -o remount,rw /media/NABLA'
alias mro='mount -o remount,ro /media/boot && mount -o remount,ro /media/NABLA'
