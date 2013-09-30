#!/bin/sh
# Usage: nla_unmatched.sh
#
# Copyright (c) 2013, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
# Short description:
# Extract from Mint log any person objects which are awaiting an NLA ID.
# If there are any objects, send a list of their URLs to $email_dest_list.
#
##############################################################################
PATH=/bin:/usr/bin;	export PATH
mint_log=/opt/ands/mint-builds/current/home/logs/main.log
target_time="08:00"
datestamp=`date +%Y-%m-%d`

# mailx: Space separated list of destination email addresses
email_dest_list="me@example.com you@example.com"
email_subject="Mint notification: List of NLA records awaiting matching in TIM"

url_prefix=https://MY_SERVER.example.com/mint/default/detail/
url_suffix=/

##############################################################################
# Extract any Mint person objects which are awaiting an NLA ID
obj_list=`egrep "^$datestamp $target_time.*does not yet have a national Identity in NLA" $mint_log |
  sed "s/^.*Object '//; s/' does not.*$//"`
[ -z "$obj_list" ] && exit 0	# Silently quit if no objects found

# Send stdout in the block below as an email
{
  echo "Below is the list of Mint person records awaiting an NLA Identity at $datestamp $target_time."
  echo
  obj_count=0
  echo "$obj_list" |
    sort |
    while read object; do
      obj_count=`expr $obj_count + 1`
      echo "  Record #$obj_count: $url_prefix$object$url_suffix"
    done

	cat <<-EOMSG

		This means that either the records awaiting publication have not yet been harvested by NLA Trove or they are awaiting someone at this institution to match them using the Trove Identities Manager (TIM).

		-----
		This is an automatic email. Please do not reply
	EOMSG
} |mailx -s "$email_subject" $email_dest_list

