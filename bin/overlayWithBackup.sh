#!/bin/sh
# Usage: overlayWithBackup.sh  BASEPATH [ 2>&1 |tee logYYMMDD_HHMM ]
#   where  BASEPATH.tgz gives the files to overlay
#   and    BASEPATH.list.x gives the files/dirs to backup (before overlaying)
#
# Copyright (c) 2013, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
##############################################################################
# Q: Why can't you simply use the tar-archive list specified by BASEPATH
# (eg. tar tvzf BASEPATH.tgz) instead of BASEPATH.list.x? Then BASEPATH.list.x
# would not be needed.
#
# A: You can, however sometimes you may want to replace a whole directory
# in which case BASEPATH.list.x can have one entry for the whole directory
# rather than many (say 30) files contained within that dir which exist in
# the tarball BASEPATH.tgz.
#
# Q: Why can't you simply use BASEPATH.list instead of BASEPATH.list.x?
#
# A: You can, but typically you will want to change (usually remove) some
# files in the list so it is recommended that you do not alter the file
# created by overlayPrep.sh (ie. BASEPATH.list) but instead make a copy
# of it (BASEPATH.list.x) and use the copy to overlay/extract files from
# the tarball. (Note .x = 'extract'.)
#
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin;  export PATH
MOVE_ARGS=-fv
TAR_CREATE_ARGS=cvzf
TAR_EXTRACT_ARGS=zxvpf

ORIG_LIST_SUFFIX=.list		# File extension/suffix containing list of files previously saved
EXTRACT_LIST_SUFFIX=.list.x	# File extension/suffix containing list of files to be extracted

app=`basename $0`

##############################################################################
# displayUsageExit(msg="")
# - Display usage then exit
# - Returns N/A (since script always exits)
displayUsageExit() {
  [ "$1" != "" ] && echo "$1" >&2
  cat <<-EOM_USAGE >&2
	Usage: $app  BASEPATH [ 2>&1 |tee logYYMMDD_HHMM ]
	  where  BASEPATH.tgz gives the files to overlay
	  and    BASEPATH$EXTRACT_LIST_SUFFIX lists the files/dirs to backup (before overlaying)
	         and to overlay (ie. extract)

	Note:
	- This script extracts/overlays files into a ReDBox or Mint filesystem area
	  from files backed up by the script overlayPrep.sh.
	- BASEPATH$EXTRACT_LIST_SUFFIX is typically a manual copy of BASEPATH$ORIG_LIST_SUFFIX with some
	  filenames removed to suit your purposes (eg. with POM files removed).
	- Any files which appear within BASEPATH.renamed must be manually renamed
	  or removed.
	EOM_USAGE
  exit 1
}

##############################################################################
# doCmd($cmd, $msg="")
# - Display optional message; display command; execute command
# - Returns nil
doCmd() {
  cmd="$1"
  msg="$2"
  [ "$msg" != "" ] && echo -e "$msg"
  [ "$cmd" != "" ] && echo "COMMAND: $cmd"
  eval $cmd
}

##############################################################################
# displayWarningsCollectCounts(fnameList)
# - Check file-list & issue any appropriate warnings.
# - Returns "$countFiles", "$countPresent", "$countBackedUp"
displayWarningsCollectCounts() {
  fnameList="$1"
  echo

  countFiles=0
  countPresent=0
  countBackedUp=0
  while read relPath; do
    isPresent=0
    isBackedUp=0
    countFiles=`expr $countFiles + 1`
    if [ -f "$relPath" -o -d "$relPath" ]; then
      isPresent=1
      countPresent=`expr $countPresent + 1`
    else
      echo "File/dir not found: '$relPath'"
    fi
    relPathBackup="$relPath.dist"
    if [ -f "$relPathBackup" -o -d "$relPathBackup" ]; then
      isBackedUp=1
      countBackedUp=`expr $countBackedUp + 1`
      echo "File/dir is already backed up (to '$relPathBackup')"
    fi
    echo "  countFiles=$countFiles countPresent=$countPresent countBackedUp=$countBackedUp [$isPresent,$isBackedUp]-- $relPath"
  done < "$fnameList"
}

##############################################################################
# askUserContinueOrExit("$countFiles", "$countPresent", "$countBackedUp")
# - Ask user if she wants to continue (based on warnings/counts)
# - Returns (nil) if user wants to continue (else exits script)
askUserContinueOrExit() {
  countFiles=$1
  countPresent=$2
  countBackedUp=$3
  fnameList=$4
  fnameListBase=`basename "$fnameList"`

  userAnswer=dummy
  while [ "$userAnswer" != y -a "$userAnswer" != n ]; do
    cat <<-EOM_ASK

	BEWARE: This script will extract and overwrite files. Use with CAUTION!

	Ensure that you do NOT overlay ReDBox files into a Mint directory or vice versa.
	The current directory is:                `pwd`
	Files to extract are listed in:          $fnameList

	Number of files/dirs to overwrite/extract:          $countFiles
	Number of files/dirs NOT found in filesystem:       `expr $countFiles - $countPresent`
	Number of files/dirs already backed up (to .dist):  $countBackedUp

	If you wish to overlay different (usually less) files/dirs, then:
	- quit this script
	- remove unwanted file paths from $fnameListBase
	  (but the paths must exist in the .tgz file)
	- run this script again
	EOM_ASK
    if [ $countPresent = 0 ]; then
    cat <<-EOM_WARN

	WARNING: None of the files/dirs in the backup are found within the current directory!
	         The correct dir is expected to contain: home portal server solr
	         Eg. /opt/ands/redbox-builds/VERSION or /opt/ands/mint-builds/VERSION
	         Please check that you are in the correct directory.
	EOM_WARN
    fi
    echo
    echo -n "Do you want to continue? y/n "
    read userAnswer
  done
  if [ $userAnswer = n ]; then
    echo "Quitting without processing"
    exit 0
  fi
}

##############################################################################
# backupListedFilesDirs($fnameList)
# - Backup the files/dirs listed within $fnameList according to the table below.
# - Returns nil
#
# isPresent  = FILE_DIR (from $fnameList) is present in the filesystem.
# isBackedUp = FILE_DIR.dist (derived from FILE_DIR in $fnameList) is present
#              in the filesystem (& assumed to be a backup of FILE_DIR).
#
# isPresent   isBackedUp   Action
# ---------   ----------   ------
#         0            0   Touch FILE_DIR.dist
#         0            1   No action
#         1            0   Move to FILE_DIR.dist
#         1            1   Create the tarball FILE_DIR.dist2.tgz [a]
# where 0=false; 1=true
#
# Note a) If FILE_DIR is a dir, then the original dir remains & so files within 
# shall be overwritten with those extracted from the tarball. However, some
# additional files may remain which were not overwritten. (I would prefer
# this than for this script to recursively delete the dir!)
backupListedFilesDirs() {
  fnameList="$1"

  while read relPath; do
    relPathBackup="$relPath.dist"
    isPresent=0		# Assume file is not present
    isBackedUp=0	# Assume file is not backed up
    [ -f "$relPath" -o -d "$relPath" ] && isPresent=1
    [ -f "$relPathBackup" -o -d "$relPathBackup" ] && isBackedUp=1
    echo -e "\n[isPresent=$isPresent, isBackedUp=$isBackedUp] $relPath"

    if [ $isPresent = 0 ]; then
      if [ $isBackedUp = 0 ]; then
        cmd="touchWithMkdir \"$relPath.dist\""
        doCmd "$cmd" "Flag that a (new) file will be written"
      fi
    else
      if [ $isBackedUp = 0 ]; then
        cmd="mv $MOVE_ARGS \"$relPath\" \"$relPath.dist\""
        doCmd "$cmd" "Backup the existing file/dir"
      else
        cmd="tar $TAR_CREATE_ARGS \"$relPath.dist2.tgz\" \"$relPath\""
        doCmd "$cmd" "Backup the existing file/dir (without overwriting other backup)"
      fi
    fi
  done < "$fnameList"
}

##############################################################################
# touchWithMkdir($filePath)
# - Touch a path making any parent dirs as required.
# - Returns nil (future: exit code of touch)
touchWithMkdir() {
  filePath="$1"
  parentPath=`dirname "$filePath"`
  [ ! -d "$parentPath" ] && mkdir -p "$parentPath"
  touch "$filePath"
}

##############################################################################
# Main()
##############################################################################
[ "$1" = "" ] && displayUsageExit "BASEPATH argument must be specified for the .tgz/$EXTRACT_LIST_SUFFIX files."

fnameList="$1$EXTRACT_LIST_SUFFIX"
fnameArchive="$1.tgz"
[ ! -r "$fnameList" ] && displayUsageExit "Error: '$fnameList' does not exist or is not readable"
[ ! -r "$fnameArchive" ] && displayUsageExit "Error: '$fnameArchive' does not exist or is not readable"

# Loop thru files looking for problems
displayWarningsCollectCounts "$fnameList"

# Ask user if she wants to continue
askUserContinueOrExit "$countFiles" "$countPresent" "$countBackedUp" "$fnameList"

# Do backups of all listed files/dirs
backupListedFilesDirs "$fnameList"

echo
echo "Overlay with files from tarball (if present within $EXTRACT_LIST_SUFFIX file)"
# Loop below has similar functionality to the gnu-tar -T option. ie.
#   tar $TAR_EXTRACT_ARGS "$fnameArchive" -T $fnameList
cat $fnameList |while read relPath; do
  cmd="tar $TAR_EXTRACT_ARGS \"$fnameArchive\" \"$relPath\""
  doCmd "$cmd" "\nExtract & overlay some files from tarball"
done

