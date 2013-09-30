#!/bin/sh
# Usage:  overlayPrep.sh [-h|-help|--help]
#
# Copyright (c) 2013, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
# Long description:
#   See how_to_manage_changes text below.
#
# Short description:
#   Backs up files/dirs within redbox-mint 'current' tree which have been
# modified. Modified files/dirs (eg. FILE_DIR) are identified because
# the person who modified them has created a file called FILE_DIR.dist
# (which is usually but not necessarily a copy of the original file
# distributed with the app).
# 
# - Modified to backup FILE_DIR* (instead of only FILE_DIR) if FILE_DIR exists.
# - Modified to cope with spaces in filenames eg. "Data Management Plan.vm".
# - Modified to list FILE_DIR.dist in *.renamed if FILE_DIR does not exist.
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin;  export PATH
LC_ALL=C;  export LC_ALL	# Set a POSIX locale for sort & comm
DEBUG=0		# 0=Suppress debug info; 1=Show debug info
timestamp=`date +%y%m%d.%H%M%S`
host=`hostname -s`
outDir=$HOME/backup/overlay/${host}_$timestamp

how_to_manage_changes=`cat <<-EOMSG
	This script backs up objects (ie. files and directories) and provides info
	according to the following rules. In the discussion below, FILE_DIR is the
	basename of the (usually original distributed) file or directory being
	_considered_ for backup.
	 - These rules apply to the directories which are symbolicly linked to
	   /opt/ands/mint-builds/current & /opt/ands/redbox-builds/current.
	 - Only file and directory names matching *.dist are _considered_ for backup
	   and information purposes.
	 - If FILE_DIR.dist and FILE_DIR objects both exist, then FILE_DIR shall
	   be added to the list of objects to be backed up (ie. added to the output
	   file *.list).
	 - After the list of objects to be backed up is completed, the 'tar'
	   command will backup FILE_DIR* for each FILE_DIR in the backup list. Eg.
	   FILE_DIR, FILE_DIR.dist & FILE_DIR.xyz will be backed up if FILE_DIR
	   appears in the backup list.
	 - If FILE_DIR.dist exists but FILE_DIR does not, then the script
	   assumes that FILE_DIR is unwanted. Hence, FILE_DIR is _not_ added to the
	   list of files to backup & correspondingly none of the objects matching
	   FILE_DIR* will be backed up. However, the existence of FILE_DIR.dist
	   may indicate an important change eg. someone renamed FILE_DIR
	   (perhaps instead of deleting it). Hence such changes _are_ listed as
	   FILE_DIR in the output file *.renamed.

	Hence guidelines to managing the Mint & ReDBox trees include the following.
	 - Before making any changes to an original distributed file FILE_DIR,
	   make a copy and call it FILE_DIR.dist. At a later time, you may also
	   make other copies of FILE_DIR -- if those copies match FILE_DIR* then
	   this script will backup them up.
	 - If you wish to backup a whole directory tree (eg. because you have created
	   a new directory such as home/handle or home/language-files-CHANGES or
	   portal/dashboard/local) then either create an empty file FILE_DIR.dist
	   (eg. 'touch FILE_DIR.dist') for a newly created directory or perform a
	   recursive copy of the original FILE_DIR to FILE_DIR.dist.
	 - If making a copy of an original file to FILE_DIR.dist causes side
	   effects (eg. ReDBox home/language-files where multiple definitions of
	   the same variable will cause the Language Service to use the first one it
	   finds within the whole directory) then one solution is to create another
	   directory (eg. home/language-files-CHANGES) then create a symlink from
	   the original directory file to the new directory file & keep copies
	   within the new directory. Eg.
	   * mkdir home/language-files-CHANGES
	   * touch home/language-files-CHANGES.dist  # Will backup new dir
	   * mv -vi home/language-files/MYFILE to home/language-files-CHANGES
	   * ln -s ../language-files-CHANGES/MYFILE home/language-files/MYFILE
	   * touch home/language-files/MYFILE.dist  # Will backup symlink
	   * Keep copies of MYFILE as home/language-files-CHANGES/MYFILE*
	   * Only one copy of MYFILE (ie. home/language-files-CHANGES/MYFILE)
	     will be read by the ReDBox Language Service
	 - This script does not track deleted files or directories.
	 - If you need to delete a file or directory, where possible rename it
	   instead so that such changes are tracked within the *.renamed backup
	   file.
EOMSG
`

##############################################################################
# eval_command(cmd [, msg])
##############################################################################
eval_command() {
  cmd="$1"
  msg="$2"
  [ "$DEBUG" = 1 -o ! -z "$msg" ] && echo

  [ ! -z "$msg" ] && echo -e "$msg"		# Show message
  [ "$DEBUG" = 1 ] && echo "COMMAND: $cmd"	# Show command
  eval $cmd
}

##############################################################################
# Main
##############################################################################
if [ "$1" = -h -o "$1" = -help -o "$1" = --help ]; then
  echo "Usage:  `basename $0` [-h|-help|--help]"
  echo "$how_to_manage_changes"
  exit 0
fi

for webApp in redbox mint; do
  echo -e "\n### $webApp ###"
  topPath=/opt/ands/${webApp}-builds/current
  cd "$topPath"
  pathSubst=`pwd -P |sed 's:/:%:g'`
  outBaseName="overlay_${host}_${pathSubst}_${timestamp}"
  outListPath="$outDir/$outBaseName.list"
  outListPathTemp="$outDir/$outBaseName.temp"
  outListPathRenamed="$outDir/$outBaseName.renamed"
  outBackupPath="$outDir/$outBaseName.tgz"

  # Files/dirs of the form FILE_DIR.dist imply that FILE_DIR has been modified.
  # Hence backup all the FILE_DIRs.
  mkdir -p $outDir
  res=$?
  if [ $res -ne 0 ]; then
    echo "Quitting: Unable to create dir '$outDir'"
    exit $res
  fi

  # Remember all FILE_DIR (whether FILE_DIR exists or not) for which FILE_DIR.dist exists
  cmd="find . -name '*.dist' |egrep -v '^\./storage' |sed 's/\.dist$//' |sort > \"$outListPathTemp\""
  eval_command "$cmd"

  # If FILE_DIR.dist exists but FILE_DIR does not, then *exclude* it from the backup list.
  cmd="cat \"$outListPathTemp\" |while read f; do ls -1d \"\$f\"; done 2>/dev/null > \"$outListPath\""
  eval_command "$cmd" "Creating list of files & directories to backup at:\n  $outListPath"

  # If FILE_DIR.dist exists but FILE_DIR does not, include it in this list
  cmd="comm -23 \"$outListPathTemp\" \"$outListPath\" > \"$outListPathRenamed\""
  eval_command "$cmd" "Creating list of files & directories which have been renamed (& will not be backed up):\n  $outListPathRenamed"

  # Cleanup temporary file(s)
  cmd="[ -f \"$outListPathTemp\" ] && rm -f \"$outListPathTemp\""
  eval_command "$cmd"

  # For each file or dir (FILE_DIR) in the list, backup: "FILE_DIR"*
  cmd="tar czf \"$outBackupPath\" `sed 's/^/"/; s/$/"*/' \"$outListPath\"`"
  eval_command "$cmd" "Creating the backup at:\n  $outBackupPath"
done

