#!/bin/sh
# Usage:  nullrotate_wrap.sh
#
# Copyright (c) 2013, Flinders University, South Australia. All rights reserved.
# Contributors: eResearch@Flinders, Library, Information Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
# 
##############################################################################
# PURPOSE
#   A wrapper script to perform all zipping/deleting using nullrotate.sh
#   within a cron job.
#
# EXAMPLE CRON USAGE
#   25  7 * * 1   $HOME/opt/misc/bin/nullrotate_wrap.sh >/dev/null
#
##############################################################################
PATH=/bin:/usr/bin:/usr/local/bin:$HOME/opt/misc/bin;  export PATH
HISTDIR=/opt/home/MYHOME/opt/url2ingest/download/history

KEEP_NUM_FILES=1
KEEP_NUM_DAYS=90

NR_ZIP_OPTS="-a zip -f $KEEP_NUM_FILES -v"
NR_DELETE_OPTS="-a delete -d $KEEP_NUM_DAYS -v"

##############################################################################
# Main
##############################################################################
# Zip people files
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/people\.csv\.[0-9]{6}-[0-9]{6}$'                $NR_ZIP_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/filtered_people\.csv\.[0-9]{6}-[0-9]{6}$'       $NR_ZIP_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/final_people\.csv\.[0-9]{6}-[0-9]{6}$'          $NR_ZIP_OPTS

# Delete people files (which have already been zipped)
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/people\.csv\.[0-9]{6}-[0-9]{6}\.gz$'            $NR_DELETE_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/filtered_people\.csv\.[0-9]{6}-[0-9]{6}\.gz$'   $NR_DELETE_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/final_people\.csv\.[0-9]{6}-[0-9]{6}\.gz$'      $NR_DELETE_OPTS

# Zip project files
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/projects\.csv\.[0-9]{6}-[0-9]{6}$'              $NR_ZIP_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/filtered_projects\.csv\.[0-9]{6}-[0-9]{6}$'     $NR_ZIP_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/final_projects\.csv\.[0-9]{6}-[0-9]{6}$'        $NR_ZIP_OPTS

# Delete project files (which have already been zipped)
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/projects\.csv\.[0-9]{6}-[0-9]{6}\.gz$'          $NR_DELETE_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/filtered_projects\.csv\.[0-9]{6}-[0-9]{6}\.gz$' $NR_DELETE_OPTS
nullrotate.sh $HISTDIR '^/opt/home/MYHOME/opt/url2ingest/download/history/final_projects\.csv\.[0-9]{6}-[0-9]{6}\.gz$'    $NR_DELETE_OPTS

