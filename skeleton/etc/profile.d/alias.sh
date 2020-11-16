list_rt_priorities()
{
	ps | \
	awk '/[[:digit:]+]/{ if ($5 != "ps") { cmd = "chrt -p " $1 " | sed \"s/.*: //g\" | tr \"\n\" \" \""; print $5; system(cmd); } }' | \
	grep SCHED_FIFO
}

alias psr=list_rt_priorities

