#!/bin/sh
# json_parse.sh
# Usage:  See usage_exit() below.
#
# Copyright (c) 2016, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
#   Parse a JSON file (on Red Hat Enterprise Linux Server release 6).
#   Alternatively, add a syntax highlighter to your favourite editor.
#   Eg. https://github.com/elzr/vim-json for the vim editor.
#
##############################################################################
# usage_exit(error_code, error_msg="")
##############################################################################
usage_exit() {
  error_code="$1"
  msg="$2"

  [ "$msg" != "" ] && echo "$msg" >&2
  echo "`basename $0` [ -1 | -2 ] JSON_FILE" >&2
  exit "$error_code"
}

##############################################################################
# main()
##############################################################################
[ "$1" = -h -o "$1" = --help ] && usage_exit 0

parser_num="-1"
if [ "$1" = -1 -o "$1" = -2 ]; then
  parser_num=$1
  shift
fi

[ $# != 1 ] && usage_exit 1 "Incorrect number of arguments."
fname="$1"
[ ! -f "$fname" ] && usage_exit 2 "File not found: '$fname'"

# Do it!
if [ $parser_num = -1 ]; then
  # Gives line number & char number of syntax error
  python -mjson.tool "$fname"
else
  # Shows syntax error & points to problem char
  json_verify < "$fname"
fi

