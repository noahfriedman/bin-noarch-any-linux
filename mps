#!/bin/sh
# $Id: mps,v 1.1 2001/02/19 21:46:51 friedman Exp $

h='user
   pid
   ppid
   nlwp=#T
   %cpu
   %mem
   ni
   vsz
   rss
   tty=TTY
   stat=ST
   cpuid=P
   stime
   bsdtime
   args
'

nfields=`echo -n "$h" | wc -l`

PS_FORMAT=`echo $h | sed -e 's/ /,/g'`
PS_PERSONALITY=linux
export PS_FORMAT PS_PERSONALITY

ps www ${1+"$@"} \
 | fmtcols -r 1,2,3,4,5,6,7,8,11,13 -n $nfields

# eof
