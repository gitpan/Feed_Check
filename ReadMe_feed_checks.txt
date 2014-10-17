README Feeds Checks:: 
=====================

perl modules requered (Inbuilt) perl version 5.8*

Date::Business
Time::localtime
Data::Dumper
Getopt::Std
XML::Parser

User defined Module ::
----------------------
BusDayUtil.pm


Scripts::
----------------------

run_chk_feeds.pl  -- wrapper Script calls chk_feeds.pl 

chk_feeds.pl      -- Main feed Chcek Script


Configs::
----------------------
run_chk_feeds.cfg   -- Used for wrapper Script to run checks for mltiple feeds at 1 go

chk_feeds_config.xml  -- Sample Config xml for feed Check 



Default Locations probabaly need to set before running::
--------------------------------------------------------


#__IMP__ : Change where neccesary

run_chk_feeds.pl: 
#_IMP__ : Chnage the path and filenames if needed
my $config_file_loc="$ENV{'HOME'}/config";

#_IMP__ : Chnage the path and filenames if needed
my $config_file=$config_file_loc."/run_chk_feeds.cfg";

#_IMP__ : Chnage the path and filenames if needed
my $xml_loc="$ENV{'HOME'}/config";

#_IMP__ : Chnage the path and filenames if needed
my $chk_script="$ENV{'HOME'}/scripts/chk_feeds.pl";

#_IMP__ : Chnage the path and filenames if needed
my $lock_file_loc="$ENV{'HOME'}/log";

#_IMP__ : Chnage the path and filenames if needed
my $holiday_dir="$ENV{'HOME'}/config";




chk_feeds.pl:
#__IMP__: add library path if neeedd
use lib ('/apps/perl/5.8.8/lib/site_perl/5.8.8');

# Default Config/log Path
#__IMP__: add chnages if needed

my $config_path="$ENV{'HOME'}/config";
#__IMP__: add chnages if needed
my $config=$config_path.'/chk_feeds_config.xml';

#__IMP__: add chnages if needed
# Dafault log Path
my $log_path="$ENV{'HOME'}/log";


Sample Holiday file::
---------------------

20141012
20141225



