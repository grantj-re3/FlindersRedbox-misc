#!/bin/sh
# nullrotate.sh
# Usage:  See usage_exit() below.
#
# Copyright (c) 2013, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
# 
##############################################################################
# PURPOSE
#   The nullrotate.sh script zips or deletes files whose filename
#   matches a particular regular expression (regex). It was developed to
#   provide some flexibility in zipping or deleting data files which
#   had already been "rotated" (ie. had a datestamp or timestamp applied)
#   but which logrotate could not adequately handle.
#
#   Example scenario:
#   - timestamp appended to data filename by an application
#   - timestamped data files may be created zero or many times per day
#   - in order to extract incremental changes from one data file to the
#     next, it is important not to zip or delete the most "recent"
#     timestamped data file
#   - To compress such files (ie. data.z.YYMMDD where YYMMDD is the numeric
#     date) we could use:
#     * nullrotate.sh /x/y '^/x/y/data\.z\.[0-9]{6}$' --action zip --keep-num-files 1
#   - To delete old files which have been zipped using the above
#     nullrotate.sh command (ie. data.z.YYMMDD.gz) we could use:
#     * nullrotate.sh /x/y '^/x/y/data\.z\.[0-9]{6}\.gz$' --action delete --keep-num-days 14
#
# GOTCHAS
#   1) Assumes the files being compressed or deleted are no longer open for
#   writing.
#   2) If you have selected the number of *files* to keep, in verbose mode
#   (--verbose or -v) you will be shown the filenames which match the regex
#   and will be kept. However, if you have selected the number of *days* to
#   keep, in verbose mode you will NOT be shown the filenames which match
#   the regex and will be kept.
#
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin;  export PATH
LC_ALL=C;  export LC_ALL  # Set a POSIX locale for sort
APP=`basename $0`

# GNU find command supports the -maxdepth switch which limits the number of
# directory levels to which find will decend. If your find command does not
# support this switch then it is recommended that the user achieve the same
# effect by specifying the PATH_REGEX more strictly (ie. apply the regex to
# the absolute path).
FIND_OPTS_FIRST="-maxdepth 1 -type f"

# If '-mtime +N' find option is used, it will be inserted between
# $FIND_OPTS_FIRST & $FIND_OPTS_LAST
FIND_OPTS_LAST="-print"

ZIP_CMD="gzip"
DELETE_CMD="rm -f"

##############################################################################
# usage_exit(msg) -- Display specified message, then usage-message, then exit
##############################################################################
usage_exit() {
  msg="$1"
  [ ! -z "$msg" ] && echo -e "$msg\n"
  usage_msg=`cat <<-EOM_USAGE
		Usage:  $APP  DIR  PATH_REGEX  SWITCHES
		where:
		  DIR        = path to directory; shall be used internally by
		               the 'find' command
		  PATH_REGEX = regular expression which shall be used to match
		               file-path names found by the 'find' command;
		               the regex shall be applied internally using the
		               'egrep' command

		Mandatory switches:
		  ACTION switch must be:
		    --action zip|delete (-a zip|delete)

		  KEEP switches must be ONE of the following:
		    --keep-num-files N (-f N)
		    --keep-num-days N  (-d N)

		Optional switches:
		  --help (-h)
		  --test (-t)
		  --verbose (-v)

		WARNING: This program can zip or delete large numbers of files.
		Depending on the 'find' command (version and switches) used, it
		may have the effect of zipping or deleting files recursively.
		Hence:
		- read the documentation/program
		- use caution
		- run using the --test (-t) switch first which does not perform
		  the zip or delete action
		- Seriously consider using an absolute directory path for DIR and
		  matching against the whole absolute file path using PATH_REGEX.
		  Eg. For files data.z.YYMMDD in directory /x/y (where YYMMDD is
		  the numeric date):
		  * Good:  $APP /x/y '^/x/y/data\.z\.[0-9]{6}$' ...
		  * Poor:  $APP /x/y '/data\.z\.[0-9]{6}$' ...
		  * Bad:   $APP /x/y 'data.z.[0-9]{6}' ...
	EOM_USAGE
  `
  echo "$usage_msg" 
  exit 1
}

##############################################################################
# get_cli_option(cli_args) -- Process the command line options; return $copt_*
##############################################################################
get_cli_option() {
  copt_dir=""			# Mandatory command switch (has no default value)
  copt_pathre=''		# Mandatory command switch (has no default value)
  copt_action=''		# Mandatory command switch (has no default value)

  copt_keep_nfiles=''		# Either copt_keep_nfiles or copt_keep_ndays
  copt_keep_ndays=''		# is mandatory (has no default value)

  copt_is_test=0		# Assume this is not a test (dry run)
  copt_is_verbose=0		# Assume this is not verbose

  loop_count=0
  keepsw_count=0
  while [ $# -gt 0 ] ; do
    loop_count=`expr $loop_count + 1`
    case "$1" in
      --action | -a )
        shift
        copt_action="$1"
        shift
        ;;

      --keep-num-files | -f )
        shift
        copt_keep_nfiles="$1"
        shift
        keepsw_count=`expr $keepsw_count + 1`
        ;;

      --keep-num-days | -d )
        shift
        copt_keep_ndays="$1"
        shift
        keepsw_count=`expr $keepsw_count + 1`
        ;;

      --test | -t )
        copt_is_test=1		# This is a test (dry run)
        copt_is_verbose=1	# Will be verbose
        shift
        ;;

      --verbose | -v )
        copt_is_verbose=1	# Will be verbose
        shift
        ;;

      --help | -h)
        usage_exit
        ;;

      *)
        if [ $loop_count = 1 ]; then
          copt_dir="$1"
        elif [ $loop_count = 2 ]; then
          copt_pathre="$1"
        else
          usage_exit "Invalid option '$1'"
        fi
        shift
        ;;

    esac
  done

  # Check presence of mandatory command line switches
  for var in copt_dir copt_pathre copt_action ; do
    cmd="echo \"\$$var\""		# Command to show the shell var's value
    val=`eval $cmd`		# The value
    [ "$val" = '' ] && usage_exit "You must specify each of the mandatory arguments."
  done

  # I prefer to specify exactly one of these switches because:
  # - If they are both omitted by mistake, the consequences of deleting
  #  (or perhaps zipping) all matching files might be disastrous
  # - If they are both permitted simultaneously, then we have to carefully
  #   explain to the user that the "--keep-num-files" filter is applied
  #   after first applying the "--keep-num-days" filter.
  [ $keepsw_count = 0 ] && usage_exit "You must specify either --keep-num-files (-f) or --keep-num-days (-d)."
  [ $keepsw_count -gt 1 ] && usage_exit "You must NOT specify both --keep-num-files (-f) and --keep-num-days (-d)."

  # Validate DIR
  [ ! -d "$copt_dir" ] && usage_exit "'$copt_dir' is not a directory."

  # Validate action value
  if [ "$copt_action" = zip ]; then
    action_cmd="$ZIP_CMD"
  elif [ "$copt_action" = delete ]; then
    action_cmd="$DELETE_CMD"
  else
    usage_exit "Action '$copt_action' is not valid."
  fi

  # Verify that the number of days/files to keep are integers
  for int in "$copt_keep_nfiles" "$copt_keep_ndays"; do
    if ! echo "$int" |egrep -q "^[0-9]+$"; then
      [ "$int" != '' ] && usage_exit "'$int' is not an integer! The number of days or files to keep MUST be an integer."
    fi
  done
}

##############################################################################
# do_command(cmd, is_show_cmd, is_dry_run, msg) -- Execute a shell command
##############################################################################
# - If msg is not empty, write it to stdout else do not.
# - If is_show_cmd==1: write command 'cmd' to stdout else do not.
# - If is_dry_run==1: do not execute 'cmd'; else execute 'cmd'
do_command() {
  cmd="$1"
  is_show_cmd=$2
  is_dry_run="$3"
  msg="$4"

  [ "$msg" != "" ] && echo "$msg"
  [ "$is_show_cmd" = 1 ] && echo "  Command: $cmd"
  if [ "$is_dry_run" = 1 ]; then
    echo "  DRY RUN: Not executing the above command."
  else
    eval $cmd
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "Error returned by command (ErrNo: $retval)" >&2
      exit $retval
    fi
  fi
}

##############################################################################
# Main
##############################################################################
get_cli_option $@
if [ "$copt_is_verbose" = 1 ]; then
  cat <<-EOM_VARS

	ACTION:       '$copt_action'
	DIR:          '$copt_dir'
	PATH_REGEX:   '$copt_pathre'
	Keep files:   '$copt_keep_nfiles'
	Keep days:    '$copt_keep_ndays'
	Action cmd:   '$action_cmd MATCHING_PATH'
	Verbose:      '$copt_is_verbose'
	TEST/DRY RUN: '$copt_is_test'

	EOM_VARS
fi

match_count=0
[ "$copt_keep_ndays" != '' ] && FIND_OPTS_FIRST="$FIND_OPTS_FIRST -mtime +$copt_keep_ndays"


find "$copt_dir" $FIND_OPTS_FIRST $FIND_OPTS_LAST |
  sort -r |
  while read path; do
    if echo "$path" |egrep -q "$copt_pathre"; then
      match_count=`expr $match_count + 1`

      if [ "$copt_keep_nfiles" != '' ]; then
        if [ $match_count -gt $copt_keep_nfiles ]; then
          [ "$copt_is_verbose" = 1 ] && echo "Match #$match_count [$copt_action] $path"
          do_command "$action_cmd \"$path\"" $copt_is_verbose $copt_is_test
        else
          [ "$copt_is_verbose" = 1 ] && echo "Match #$match_count [keep] $path"
        fi
      fi

      if [ "$copt_keep_ndays" != '' ]; then
        [ "$copt_is_verbose" = 1 ] && echo "Match #$match_count [$copt_action] $path"
        do_command "$action_cmd \"$path\"" $copt_is_verbose $copt_is_test
      fi
    else
      [ "$copt_is_test" = 1 ] && echo "No regex match  $path"
    fi
  done

