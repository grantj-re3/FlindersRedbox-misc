#!/bin/sh
#
# Copyright (c) 2017, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
# Show "new" ReDBox DOIs - which were minted since last run of this script.
#
# ALGORITHM
# - Create a sorted list of DOIs (by invoking a custom program).
# - Show new/updated DOIs by comparing to previous sorted list of DOIs.
# - Output results to STDOUT.
# - If selected, also email the results.
#
##############################################################################
export PATH=/bin:/usr/bin:/usr/local/bin

APP_DIR_TEMP=`dirname "$0"`		# Might be relative (eg "." or "..") or absolute
APP_DIR=`cd "$APP_DIR_TEMP" ; pwd`	# Absolute path of dir containing app
EXTRACT_PROG="$APP_DIR/extractRedboxDois.rb"

DEST_DIR=`cd "$APP_DIR/../var" ; pwd`
FNAME_NOW="$DEST_DIR/extractRedboxDois_now.psv"		# Snapshot of records now
FNAME_PREV="$DEST_DIR/extractRedboxDois_prev.psv"	# Previous snapshot of records
FNAME_DIFF="$DEST_DIR/extractRedboxDois_diff.psv"	# New/updated (difference) records

DATE_STAMP=`date "+%F %T"`
MAIL_SUBJECT="New or updated ReDBox DOIs: $DATE_STAMP"
MAIL_LIST="user@example.com"

##############################################################################
# usage_exit(error_code, error_msg="")
##############################################################################
usage_exit() {
  error_code="$1"
  msg="$2"

  [ "$msg" != "" ] && echo "$msg" >&2
  echo "Usage: `basename $0`  [-h|--help]  [-e|--email]" >&2
  exit "$error_code"
}

##############################################################################
# Main
##############################################################################
# Process command line options
[ "$1" = -h -o "$1" = --help ] && usage_exit 0
will_email=""
[ "$1" = -e -o "$1" = --email ] && {
  will_email="1"
  shift
}
[ $# != 0 ] && usage_exit 1 "Incorrect arguments."


echo "Extract new ReDBox DOIs"
echo "-----------------------"

# Prepare by remembering the output of previous run
[ -f "$FNAME_DIFF" ] && rm -f "$FNAME_DIFF"
[ -f "$FNAME_PREV" ] && rm -f "$FNAME_PREV"
[ -f "$FNAME_NOW" ] && mv -f "$FNAME_NOW" "$FNAME_PREV"

# Create output for this run
"$EXTRACT_PROG" > "$FNAME_NOW"

# Extract new or updated "records"; where a "record" corresponds to our
# CSV fields. Updates to other fields will not be detected.
head -1 "$FNAME_NOW" > "$FNAME_DIFF"		# CSV header line

[ -f "$FNAME_PREV" ] && {
  comm -23 "$FNAME_NOW"  "$FNAME_PREV" >> "$FNAME_DIFF"
  cat "$FNAME_DIFF"

  # If email configured & if any new DOIs, then send email
  numLines=`wc -l < "$FNAME_DIFF"`
  [ "$will_email" -a "$numLines" -gt 1 ] && {
    awk '{printf " [%d] %s\n", NR-1, $0}' "$FNAME_DIFF" |
      mailx -a "$FNAME_DIFF" -s "$MAIL_SUBJECT" $MAIL_LIST
  }
}
exit 0

