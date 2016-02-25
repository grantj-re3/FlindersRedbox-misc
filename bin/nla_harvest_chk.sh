#!/bin/sh
# nla_harvest_chk.sh
# Usage:  nla_harvest_chk.sh [--email|-e]
#
# Copyright (c) 2016, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
# Check Mint jetty web-logs for NLA harvests.
#
# Note that jetty web-logs:
# - have timestamps in UTC
# - are rotated around 0:00 UTC (ie. 10:30 ACDT)
# Hence to check *all* of yesterday's logs without any gaps from one
# day to the next, it is best to run this script after 10:30 ACST/ACDT
# each day after the scheduled harvest.
#
# Apache web-logs are better but require root access to read (which is
# problematic when running script from cron as an unprivileged user).
# Apache logs are better than the jetty (localhost) logs because they give:
# - external IP address
# - User agent (ie. NLAHarvester/1.0 on 25/02/2016)
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin; export PATH

days_ago=1		# Intended to check yesterday's logs (UTC) ie. days_ago=1
datestamp=`date '+%d/%b/%Y' -d "12:00 $days_ago days ago"`	# Eg. 25/Feb/2016
mint_log_dir="$HOME/mintlogs"			# CUSTOMISE

# Destination email address list (space separated for mailx)
email_list="user@example.com"			# CUSTOMISE
email_subject="NLA harvest check for $datestamp UTC; $days_ago day(s) ago"

msg_expect_time="Expected NLA harvest time is approx 19:30:00 ACDT (09:00:00 UTC)"	# CUSTOMISE

##############################################################################
# Get email-message and email-subject
##############################################################################
get_msg_subject() {
  web_logs="`ls -1 $mint_log_dir/jetty/*.request.log |tail`"
  lines=`cat $web_logs |egrep "\[$datestamp:.*/NLA_Harvest/.*/oai\?verb="`

  if [ `echo "$lines" |wc -w` = 0 ]; then
    email_subject="WARNING: $email_subject"
    msg=`cat <<-EOMSG_WARN
		WARNING: No Mint harvests were detected from NLA for $datestamp.
		Note: $msg_expect_time
	EOMSG_WARN
`
  else
    msg=`cat <<-EOMSG_OK
		Mint harvests (perhaps from NLA) shown below for $datestamp.
		Notes:
		- OAI-PMH harvests from /mint/NLA_Harvest/... are not necessarily
		  from the NLA Harvester.
		- $msg_expect_time

		$lines
	EOMSG_OK
`
  fi
}

##############################################################################
# main()
##############################################################################
get_msg_subject
if [ "$1" = --email -o "$1" = -e ]; then
  echo "$msg" |mailx -s "$email_subject" $email_list
else
  echo "$msg"
fi

