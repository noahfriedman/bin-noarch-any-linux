#!/bin/sh
# $Id: fix-run-mozilla.sh,v 1.1 2010/01/21 19:52:16 friedman Exp $

find_scripts()
{
  rpm -ql "$@" | egrep 'run-mozilla.sh|/lib.+/thunderbird$'
}

make_backup_file_name()
{
  VERSION_CONTROL=numbered make-backup-file-name "$@"
}

edit_script()
{
  bup=`make_backup_file_name "$1"`
  cp -p "$1" "$bup"

  sed -e 's=^\([ 	]*\)\("\$prog\"\)=\1exec \2=' \
      -e 's=^\([ 	]*\)\("\$dist_bin/run-mozilla.sh\"\)=\1exec \2=' \
      "$bup" > "$1"

  if cmp -s "$bup" "$1" ; then
    mv "$bup" "$1"
    echo "$1 unchanged"
  else
    echo "$1"
  fi
}

main()
{
  case $# in
    0 ) set firefox thunderbird ;;
  esac

  for script in `find_scripts "$@"`; do
    edit_script "$script"
  done
}

main "$@"

# eof
