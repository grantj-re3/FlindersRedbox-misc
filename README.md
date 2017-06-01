FlindersRedbox-misc
===================

Helper scripts, etc for ReDBox-Mint.

Purpose
-------
"ReDBox is a metadata registry application for describing research data.
The Mint is an name-authority and vocabulary service that complements ReDBox."
See http://www.redboxresearchdata.com.au/. The purpose of these scripts is to
assist in the ICT administration of the ReDBox-Mint application.

Notes
-----
NA

Application environment
-----------------------
Read the INSTALL file.

Installation
------------
Read the INSTALL file.

Features
--------
* *extractRedboxDois.rb* extracts summary info regarding ReDBox records
  for which DOIs have been minted. The info is shown in a CSV-like format.
* *extractRedboxDois_wrap.sh* shows "new" ReDBox DOIs - which were minted
  since the last run of this script. The info can be optionally sent via
  email.
* *grep_oai.sh* greps web-server logs for ReDBox or Mint OAI-PMH requests.
* *json_parse.sh* parses a JSON file (on RHEL).
* *nla_harvest_chk.sh* checks Mint jetty web-logs for NLA harvests.
* *nla_unmatched.sh* will extract from Mint logs any person objects which are
  awaiting an NLA ID and send a list of the corresponding Mint record URLs
  to the specified email address.
* *nullrotate.sh* zips or deletes files whose filename matches a particular
  regular expression (regex). It was developed to provide some flexibility
  in zipping or deleting data files which had already been "rotated" (ie.
  had a datestamp or timestamp applied) but which logrotate could not
  adequately handle.
* *nullrotate_wrap.sh* is a wrapper script to perform all zipping/deleting
  using nullrotate.sh within a cron job.
* *overlayPrep.sh* will perform backups of ReDBox-Mint institutional build
  config/script _changes_ __provided__ it is managed according to the rules
  and guidelines specified (by running "overlayPrep.sh -h")
* *overlayWithBackup.sh* will extract/overlay files into a ReDBox or Mint
  filesystem area from files backed up by overlayPrep.sh.

Todo
----
NA

