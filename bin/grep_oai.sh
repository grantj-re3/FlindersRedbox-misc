#!/bin/bash
# Usage:  See usage_exit() below.
#
# Copyright (c) 2016, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
# Grep apache or jetty web-server logs for ReDBox or Mint OAI-PMH requests.
# - Optionally filter by National Library of Australia (NLA) harvester
#   or Research Data Australia (RDA) harvester.
# - Optionally filter by redbox or mint source URL.
# - Optionally filter by OAI-PMH metadata prefix (RIF-CS or EAC-CPF)
# - Optionally limit output to the most recent N lines of the log.
#
# See https://www.openarchives.org/OAI/openarchivesprotocol.html
#
##############################################################################
app=`basename $0`
web_svr_log_default="/var/log/httpd/redbox/access_log"

# Full regex = [A] B [C] [D]; where B is mandatory & A,C,D are optional
# Portion of URL (regex part A)
match_redbox="/redbox/.*"
match_mint="/mint/.*"

# Portion of URL (regex part B)
match_oai="/oai\?verb="

# Portion of URL (regex part C)
match_rif=".*metadataPrefix=rif"		# RIF-CS XML format
match_eaccpf=".*metadataPrefix=eac-cpf"		# EAC-CPF XML format

# User agent (regex part D)
match_nla=".*NLAHarvester"
match_rda=".*Python-urllib"

##############################################################################
# usage_exit(error_code, error_msg="")
##############################################################################
usage_exit() {
  error_code="$1"
  msg="$2"
  [ "$msg" != "" ] && echo "$msg" >&2

  common_opts="[--rif|--eac-cpf] [--log FILE] [--max-lines N]"
  cat <<-EOM_USAGE >&2
		Usage:
		  $app [--rda] [--redbox|--mint] $common_opts
		  $app --nla $common_opts
		  $app --help|-h

		Default option: --log "$web_svr_log_default"

		ReDBox & Mint also have web-server log files at
		REDBOX_MINT_HOME/home/logs/jetty/YYYY_MM_DD.request.log

		Prefix this program with 'sudo' if required to access the log file.

		If FILE is hyphen ("-") the log file content will be read from STDIN.
		Hence you can use this program in a manner such as:
		  gunzip -c access_log.1.gz |grep_oai.sh --log - --rif

	EOM_USAGE
  exit "$error_code"
}

##############################################################################
# Get command line options
##############################################################################
get_clopts() {
  match_harvester=""		# User agent
  match_source=""		# Portion of URL
  match_metadata=""		# OAI-PMH metadata prefix

  web_svr_log="$web_svr_log_default"
  lines_max=-1			# The maximum number of (recent) lines

  while [ $# -gt 0 ]; do
    case "$1" in
      --nla)    match_harvester="$match_nla" ;;
      --rda)    match_harvester="$match_rda" ;;

      --redbox) match_source="$match_redbox" ;;
      --mint)   match_source="$match_mint" ;;

      --rif)     match_metadata="$match_rif" ;;
      --eac-cpf) match_metadata="$match_eaccpf" ;;

      --log)
        shift
        web_svr_log="$1"	# Hyphen will read content from stdin (due to GNU egrep behaviour)
        ;;

      --max-lines)
        shift
        lines_max="$1"
        if ! echo "$lines_max" |egrep -q "^[0-9]+$"; then
          usage_exit 2 "ERROR: Maximum number of lines '$lines_max' is not a non-negative integer."
        fi
        ;;

      --help|-h) usage_exit 0 ;;
      *)         usage_exit 1 "ERROR: Unrecognised argument '$1'." ;;
    esac
    shift
  done

  regex="$match_oai$match_metadata$match_harvester"
  [ "$match_harvester" != "$match_nla" ] && regex="$match_source$regex"
}

##############################################################################
# main()
##############################################################################
get_clopts "$@"
cmd="egrep \"$regex\" \"$web_svr_log\""
[ $lines_max -ge 0 ] && cmd="$cmd |tail -$lines_max"
echo "COMMAND: $cmd" >&2
eval $cmd

