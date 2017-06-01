#!/usr/bin/ruby
#
# Copyright (c) 2017, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# PURPOSE
# Extract summary info regarding ReDBox records for which DOIs have been
# minted. Show the info in a CSV-like format, with one record per line
# (with a header line). Extract the info from the ReDBox storage tree.
#
# ALGORITHM
# - Find ReDBox records which contain ReDBox-minted DOIs.
# - Extract metadata for each record.
# - Represent metadata in CSV-like format.
# - Sort records so they are in a repeatable record-order.
# - Write CSV header and records to STDOUT.
#
# GOTCHAS
# - The Ruby JSON gem was unable to parse ReDBox JSON files, so the
#   Ruby YAML stdlib class was used instead. See get_pkg_metadata()
#   for more details.
#
# TEST ENVIRONMENT
# - ruby 1.8.7 (2013-06-27 patchlevel 374) [x86_64-linux]
# - ReDBox 1.6.1; java version 1.6.0_30
# - Red Hat Enterprise Linux Server release 6.9 (Santiago)
# - Linux 2.6.32-642.13.1.el6.x86_64 #1 SMP Wed Nov 23 16:03:01 EST 2016 x86_64 x86_64 x86_64 GNU/Linux
#
##############################################################################
require "yaml"
require "find"

##############################################################################
class RedboxDoiDataset
  DEBUG = false

  FPATH_REDBOX_STORAGE = "/PATH/TO/REDBOX/storage"
  OBJECT_FNAME = "TF-OBJ-META"
  CSV_DELIM = "|"
  NEWLINE = "\n"

  ############################################################################
  def initialize(fpath_obj)
    @fpath_obj = fpath_obj
    if @fpath_obj.nil? || @fpath_obj.empty?
      STDERR.puts "ERROR: Object '#{self.class}' has an empty/nil file path to #{OBJECT_FNAME}."
      exit 1
    end

    @fpath_pkg = get_filepath_pkg
    @metadata = {}

    if DEBUG
      puts "OBJ Path: #{@fpath_obj.inspect}"
      puts "PKG Path: #{@fpath_pkg.inspect}" 
      puts
    end
  end

  ############################################################################
  def get_filepath_pkg
    obj_strings = File.open(@fpath_obj).read.split(NEWLINE)
    fpath_other_pkg = self.class.get_field(obj_strings, "file.path")
    "%s/%s" % [File.dirname(@fpath_obj), File.basename(fpath_other_pkg)]
  end

  ############################################################################
  def extract_metadata
    get_obj_metadata
    get_pkg_metadata
  end

  ############################################################################
  def get_obj_metadata
    obj_strings = File.open(@fpath_obj).read.split(NEWLINE)

    @metadata[:doi] = self.class.get_field(obj_strings, "andsDoi")
    @metadata[:owner] = self.class.get_field(obj_strings, "owner")
    @metadata[:handle] = self.class.get_field(obj_strings, "handle").to_s.gsub(/\\/, "")
  end

  ############################################################################
  def get_pkg_metadata
    # FIXME: The JSON gem parse() method in Ruby 1.8.7 throws an exception
    # if newlines are in JSON field values. YAML 1.2 is a superset of JSON,
    # so tried YAML (although Ruby 1.8.7 uses YAML 1.0). Newlines seem to be
    # converted into spaces, which is ok for me.
    pkg_str = File.open(@fpath_pkg).read
    pkg_json = YAML.load(pkg_str)		# Convert JSON to a hash

    @metadata[:package_type] = pkg_json["packageType"]
    @metadata[:citation] = pkg_json["dc:biblioGraphicCitation.skos:prefLabel"].gsub(/ *\{ID_WILL_BE_HERE\}/, "")
    @metadata[:record_created] = pkg_json["dc:created"]
  end

  ############################################################################
  def to_csv_line
    self.class.csv_out_fields.inject([]){|a,key| a << @metadata[key]}.join(CSV_DELIM)
  end

  ############################################################################
  # Class methods
  ############################################################################
  def self.get_field(string_list, field_name)
    regex = /^#{Regexp.escape(field_name)}=/

    # string_list is an array of strings with format:  key=value
    line = string_list.find{|s| s.match(regex)}
    line ? line.gsub(regex, "") : nil
  end

  ############################################################################
  def self.csv_out_fields
  [
    :doi,
    :record_created,
    :package_type,
    :owner,
    :handle,
    :citation,
  ]
  end

  ############################################################################
  def self.csv_header_line
    csv_out_fields.inject([]){|a,key| a << key.to_s}.join(CSV_DELIM)
  end

  ############################################################################
  def self.get_object_files
    fpaths_obj = []
    Find.find(FPATH_REDBOX_STORAGE){|fpath|
      next unless File.basename(fpath) == OBJECT_FNAME
      obj_strings = File.open(fpath).read.split(NEWLINE)
      fpaths_obj << fpath if get_field(obj_strings, "andsDoi")
    }
    fpaths_obj
  end

end

##############################################################################
# Main
##############################################################################
# Extracting info from datasets with DOIs
lines = RedboxDoiDataset.get_object_files.inject([]){|list, fpath_obj|
  obj = RedboxDoiDataset.new(fpath_obj)
  obj.extract_metadata
  list << obj.to_csv_line
}
puts RedboxDoiDataset.csv_header_line
lines.sort.each{|csv_line| puts csv_line}

