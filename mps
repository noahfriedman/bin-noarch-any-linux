#!/bin/sh
# $Id$

ps -wwwo user,pid,ppid,s,%cpu,%mem,vsz,rss,tty,stime,args ${1+"$@"} \
 | fmtcols -r 1,2,4,5,6,7 -n 11

# eof
