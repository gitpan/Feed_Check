#!/usr/bin/perl -w 

use strict;
use XML::Parser;
use Data::Dumper;
use Getopt::Std;
use vars qw(%opts);
use Time::localtime;

#__IMP__: add library path if neeedd
use lib ('/apps/perl/5.8.8/lib/site_perl/5.8.8');
use BusDayUtil;

my $VERSION= "1.0.0";

$|=1;

my $debug=1;  #set to 1 if Want to Print all output check on screen

BEGIN
{
my $libpath=$0;
$libpath=~ s/^(.+)\/.+/$1/;
push(@INC,$libpath);
}


=information

Author                  : Sanjoga Sahu.
Date of Modification    : 5th, Aug, 2014. (v1.0.0)


Operating System(s)     : Linux

Description             : Checks the Market Data feeds for the correctness of data.

Types of Checks Perfomed 
========================

1.  Feed Stale Check              
2.  Feed Time Stamp Date Check    
3.  Feed Arrival Time Stamp Check 
4.  Feed Size Check               
5.  Feed Number of Records Check  
6.  Header Line Check             
7.  Header Line Date Check        
8.  Number of Columns Check       
9.  All Records Check             
10. Duplicate Record Check        
11. Trailer Line Check             
12. Trailer Line Date Check
13. Feed Variance Check       

Execution Method        : 

Note:
The Config File Location in  Prod : /apps/config//chk_feeds/chk_feeds_config.xml (Default) 
The Script Location in  prod      : /apps//batch/bin/chk_feeds.pl
The Wrapper Script Location in  prod      : /apps//batch/bin/_run_chk_feeds.pl
The Wrapper Config File Location in  Prod : /apps/config//chk_feeds/_run_chk_feeds.cfg (Default) 


1. chk_feeds.pl -f /ppb/data/LATEST/Prices/sobratePrices.dat 

                i. No need to Provide run date if the execution date is same as business date.
                ii. The feed name provided should be the absolute.
                iii. NOTE : <-f> Option is Mandatory

2.  chk_feeds.pl -f /ppb/data/LATEST/Prices/sobratePrices.dat -d 20091119

				i. Provide run date if the execution date Not same as business date.
 
3. chk_feeds.pl -f /ppb/data/LATEST/yield_history/EMEA/MCBenchmarks.dat -d 20091119 -p DEM -e /apps/rvg/lib/holidays/DEM.HOL
                
				i. Provide the prefix of the feed if the config file is same for multiple currency (case Sensitive)
				ii. -e escape the holidays for the currency

4. chk_feeds.pl -f /ppb/data/LATEST/Prices/sobratePrices.dat -d 20091119 -c cfg/chk_feeds_config_sobrate_govtPrices.xml
                
				i. specify the config file if one want to use a particular config file of interest.
                ii. NOTE : default config file is "chk_feeds_config.xml"

----------------------------------
Execution from own directory:
Ex:

$SCRIPTSROOT/market_feeds/_run_chk_feeds.pl -rGLOBAL -yGENERAL -d 20110207 -x /home/n209263/dev/chkfeeds/ -c /home/n209263/dev/chkfeeds/run_chk_feeds.cfg -s /home/n209263/dev/chkfeeds/chk_feeds.pl -k /home/n209263/dev/chkfeeds/log/
$SCRIPTSROOT/market_feeds/_run_chk_feeds.pl -rASIA -yGENERAL -x /home/n209263/dev/chkfeeds/ -c /home/n209263/dev/chkfeeds/run_chk_feeds.cfg -s /home/n209263/dev/chkfeeds/chk_feeds.pl -k /home/n209263/dev/chkfeeds/log/ -d 201103221 


/apps/rvg/bin/market_feeds/_run_chk_feeds.pl -rASIA -yTHB  -x /home/n209263/dev/chkfeeds/ -c /home/n209263/dev/chkfeeds/run_chk_feeds.cfg -s /home/n209263/dev/chkfeeds/chk_feeds.pl -k /home/n209263/dev/chkfeeds/log/ -d 20110503 

----------------------------------

Sending Check Report E-mail :  /apps/config//chk_feeds/chk_feeds_config.xml (Default)              
				<feed_check_email check="y">
                        <send_email_always>Y</send_email_always>		----> Always sends Check Report E-mail.  ("N" for Not always) 
                        <send_email_when_fail>Y</send_email_when_fail>	----> Sends Check Report if Any Check Fails. ("N" NO E-mail if fail)
                        <feed_check_email_to>abc@xyz.com</feed_check_email_to>
                        <feed_check_email_cc>sanjogsahu@xyz.com</feed_check_email_cc>	---> update "NA" if no cc required
                </feed_check_email>

=cut

#####################################################################
#Defining Variables 

getopts('c:d:e:f:p:wvh', \%opts);
my (%CONF, %CHECKS, %FEED_NAME)=();
my ($bus_date,$xml_element,$prefix);
my ($feed_name,$feed_name_actual,$feed_name_actual_prev,$feed_name_compare_actual);
my ($feed_prev_name_actual_ls_lrt,$feed_name_actual_ls_lrt);
my $mail_body='';
my $log_dump='';


my $stale_file_check_flg=0;

#####################################################################
# Default Config/log Path
#__IMP__: add chnages if needed
my $config_path="$ENV{'HOME'}/config";
#__IMP__: add chnages if needed
my $config=$config_path.'/chk_feeds_config.xml';

#__IMP__: add chnages if needed
# Dafault log Path
my $log_path="$ENV{'HOME'}/log";

my $log_date=`date +%Y%m%d`;
chomp $log_date;

# Default Master log file
my $log=$log_path."/chk_feeds_master_"."$log_date".".log";

open (logFH,">>$log") or die "Cannot open file $log for writing: $!";
print logFH "\n*******************************************************************************\n\n";
usage() if	 ($opts{h} || $opts{v}) ;



#####################################################################
# Check tags for core feed file 
my @feed_chk_core=qw(
feed_prefix_str
feed_postfix_date
);

# Check tags if Stale Check is Enabled in config file
my @feed_chk_prev=qw( 
feed_prev_prefix_str
feed_prev_postfix_date
);

my @feed_chk_core_stale=qw(
feed_stale_check
);

# General checker tags
my @feed_chk_general=qw(
feed_time_stamp_date
feed_time_stamp
feed_size
feed_num_lines
feed_header_line
feed_header_line_date
feed_num_column
feed_all_line_check
feed_duplicate_line
feed_tailer_line
feed_tailer_line_date
);

# optional checker tags
my @feed_chk_optional=qw(
feed_variance_check
);

my @feed_chk_conclude=qw(
feed_check_email
);

my %escape_days;
my %holiday;

# Error Exit codes and description
my %error_code_desc=(
'1'   => 'Invalid Command Line Argument Provided',
'3'   => 'Mandatory Arguments Not Provided',
'100' => 'Config file Not Found',
'101' => 'Configuration Information Not Found',
'102' => 'Invalid tag in config file',
'103' => 'Feed is Stale (Old/Same as Pevious Day\'s Feed)',
'104' => 'Feed "Date" on the Disk Miss-Match',
'105' => 'Feed Arrival Time Stamp on the Disk Miss-Match',
'106' => 'Feed Size on the Disk Miss-Match',
'107' => 'Feed Header Line Not Correct',
'108' => 'Feed Number of Columns Per Line Miss-Match',
'109' => 'Feed All Records are Not Correct',  
'110' => 'Feed Trailer Line Not Correct',
'111' => 'Feed Record "Date" Not Correct',
'112' => 'Feed Not Found on the Disk',
'113' => 'Invalid Date Type defined in the Config file (Should be bus_date/cur_date)',
'114' => 'Feed Number of Records Miss-Match',
'115' => 'Sending mail Failed',
'116' => 'Wrong Prefix Provided',
'117' => 'Duplicate Record Found',
'118' => 'Variance Found while Comparing Feeds',
'119' => 'Feed is Not Latest baseed on Buffer Time Provided'
);

#####################################################################
# getting Command Line arguments

my $comp_conf=$opts{c};		# Optional (Config file to use)
my $comp_date=$opts{d};		# Optional (Rundate : Bussiness Date)
my $comp_feed=$opts{f};		# mandatory	(full path + feed's name)
my $comp_prefix=$opts{p};	# Optional but mandatory if Config prefix with | separated string  
my $holiday_file=$opts{e};  # Escape holiday

my $write_to_file_flg;
	if(defined $opts{w})
	{
	$write_to_file_flg=1;
	}
	else
	{
	$write_to_file_flg=0;
	}

	unless(defined $comp_feed)
	{
	#&writeLog("err","No Option Provided!");
	&usage();
	}

	if(defined $holiday_file)
	{
		unless(-f $holiday_file)
		{
		&writeLog("warn","$0 <-e> Option (Holiday File : $holiday_file) Not Found!");
		&usage();
		}
	}

&writeLog("info","Check Feed Name Provided   : $comp_feed");

	unless(defined $comp_date)
	{
	&writeLog("warn","$0 <-d> Option (Business Date) Not Provided!");
	my $date_set=`date +%Y%m%d`;
	chomp $date_set;
	$bus_date=$date_set;
	&writeLog("info","Setting Bussiness Date     : $bus_date");
	}
	
	if(defined $comp_date)
	{
	&validate_date($comp_date,'yyyymmdd');
	$bus_date=$comp_date;
	&writeLog("info","Check Date Provided        : $comp_date");
	}
	
	if(defined $comp_conf)
	{
	$config=$comp_conf;
	}
	else
	{
	&writeLog("warn","$0 <-c> Option (Config File) Not Provided!");
	&writeLog("info","Setting Default Config File : $config");
	}

	unless (-f $config)
	{
	&writeLog("err","Coundn't find Config file  : $config");
	&append_mail_body("Coundn't find Config file : $config\n");
	&exit_prog(100);
	}
	else
	{
	&writeLog("info","Config File Used for Check : $config");
	&append_mail_body("Config File Used for Check : $config");
	}

	
#####################################################################
# Parsing Config File

my $parser = new XML::Parser;

$parser->setHandlers(      Start => \&startElement,
                           End => \&endElement,
                           Char => \&characterData,
                           Default => \&default);

$parser->parsefile($config);

#print Dumper(%FEED_NAME);
#print Dumper(%CONF);
#print Dumper(%CHECKS);

#####################################################################

	if(defined $FEED_NAME{$comp_feed})
	{
	&writeLog("conf","Feed Check Config Information Found for Feed : $comp_feed");
	#&append_mail_body("Feed Check Config Information Found for Feed : $comp_feed");
	}
	else
	{
	&writeLog("err","Unknown Feed :$comp_feed");
	&writeLog("info", "Please Set Configuration Information on $config");
	&append_mail_body("Please Set Configuration Information on $config");	
	&exit_prog(101);
	}

	if(defined $comp_prefix)
	{
	$prefix=$comp_prefix;
	}

$feed_name_actual=$comp_feed;
$feed_name_actual_prev=$comp_feed;

#####################################################################
# Checking and setting code current feed information 

#print Dumper(\%CHECKS);
		
		if(defined $CHECKS{$comp_feed}{'feed_postfix_str'}{'check'})
		{
			if($CHECKS{$comp_feed}{'feed_postfix_str'}{'check'} eq 'y')
			{
			push(@feed_chk_core,'feed_postfix_str');
			}
		}

		if(defined $CHECKS{$comp_feed}{'feed_prev_postfix_str'}{'check'})
		{
			if($CHECKS{$comp_feed}{'feed_prev_postfix_str'}{'check'} eq 'y')
			{
			push(@feed_chk_prev,'feed_prev_postfix_str');
			}
		}


&redirect_check(\@feed_chk_core,$comp_feed);
&file_exist($feed_name_actual,'this_day');

# Checking and setting previous day's feed information 
&redirect_check(\@feed_chk_core_stale,$comp_feed);
 	
	if($stale_file_check_flg==1)
	{
	&redirect_check(\@feed_chk_prev, $comp_feed);
	
		if(defined $feed_name_actual_prev)
		{
		&writeLog("dum","");
		&writeLog("info","Actual Feed Name ( Previous Day's ) : $feed_name_actual_prev");
		&file_exist($feed_name_actual_prev,'prev_day');
		}
	}
 
&writeLog("dum","");
	
	if($stale_file_check_flg==1)
	{
	&writeLog("info","Actual Feed Name ( Current ) : $feed_name_actual");
	&writeLog("info","Feed On Disk : $feed_name_actual_ls_lrt");
	&append_mail_body("Feed On Disk :$feed_name_actual_ls_lrt\n\nFeed Check Summary\n===================\n");	

	&check_feed_stale($feed_name_actual,$feed_name_actual_prev);
	}
	else
	{
	&writeLog("info","Actual Feed Name : $feed_name_actual");
	&append_mail_body("Feed On Disk :$feed_name_actual_ls_lrt\n\nFeed Check Summary\n===================\n");	
	}

# General feed checks 
&redirect_check(\@feed_chk_general,$comp_feed);

# Optional feed checks 
&redirect_check_optional(\@feed_chk_optional,$comp_feed);

&redirect_check_optional(\@feed_chk_conclude,$comp_feed);

# Prints the Summary of Checks 
&show_summary();

close logFH;

my $feed_log=&get_feed_log_name($feed_name_actual);

print "\nMaster Log File  (All Feeds) : $log\n";
print "Feed Log File (Current Feed) : $feed_log\n\n";  

# Genarate unique Feed Log of for the current feed. 
&generate_feed_log($feed_log);

exit(0);

#__END__

#####################################################################
=head

This subroutine basically checks the main (parent) Check tag
and redirects the check to "check_action" subroutine for further processing if the check is "y"

=cut

sub redirect_check
{
my ($chk_arr, $comp_feed)=@_;

my @chk_arr=@{$chk_arr};
	foreach my $checker_tag (@chk_arr)
	{
	 &writeLog("dum","");
		if(defined $CHECKS{$comp_feed}{$checker_tag}{'check'})
		{
			if($CHECKS{$comp_feed}{$checker_tag}{'check'} eq 'y')
			{
			&writeLog("conf","$comp_feed->$checker_tag->check : Yes");
			$stale_file_check_flg=1 if($checker_tag eq 'feed_stale_check');
			&check_action($comp_feed,$checker_tag);
			}
			elsif($CHECKS{$comp_feed}{$checker_tag}{'check'} eq 'n')
			{
			&writeLog("conf","$comp_feed->$checker_tag->check : No");
			}
			else
			{
			&writeLog("err","Invalid $comp_feed->$checker_tag->check : $CHECKS{$feed_name}{$checker_tag}{'check'}");
			&append_mail_body("Invalid $comp_feed->$checker_tag->check : $CHECKS{$feed_name}{$checker_tag}{'check'}");
			&exit_prog(102);
			}
		}	
		else
		{
		&writeLog("err","$comp_feed->$checker_tag->check : undef (Check Not Defined!)");
		&writeLog("info", "Please Set Configuration Information on $config");
		&append_mail_body("Please Set Configuration Information on $config");
		&exit_prog(101);
		}
	}
return;
}


#####################################################################
=head

This subroutine basically checks the main (parent) Check tag
and redirects the check to "check_action" subroutine for further processing if the check is "y"

=cut

sub redirect_check_optional
{
my ($chk_arr, $comp_feed)=@_;

my @chk_arr=@{$chk_arr};
	foreach my $checker_tag (@chk_arr)
	{
	 &writeLog("dum","");
		if(defined $CHECKS{$comp_feed}{$checker_tag}{'check'})
		{
			if($CHECKS{$comp_feed}{$checker_tag}{'check'} eq 'y')
			{
			&writeLog("conf","$comp_feed->$checker_tag->check : Yes");
			$stale_file_check_flg=1 if($checker_tag eq 'feed_stale_check');
			&check_action($comp_feed,$checker_tag);
			}
			elsif($CHECKS{$comp_feed}{$checker_tag}{'check'} eq 'n')
			{
			&writeLog("conf","$comp_feed->$checker_tag->check : No");
			}
			else
			{
			&writeLog("err","Invalid $comp_feed->$checker_tag->check : $CHECKS{$feed_name}{$checker_tag}{'check'}");
			&append_mail_body("Invalid $comp_feed->$checker_tag->check : $CHECKS{$feed_name}{$checker_tag}{'check'}");
			&exit_prog(102);
			}
		}	
		else
		{
		&writeLog("info","$comp_feed->$checker_tag->check : undef (Check Not Defined) : Skipping...");
		}
	}
return;
}

#####################################################################
=head

This Subroutine routes the correct subrotine to a particular feed check task   

=cut

sub check_action
{
my ($comp_feed,$checker_tag)=@_;

	if($checker_tag eq 'feed_prefix_str')
	{
	&check_feed_prefix_str($comp_feed,$checker_tag,'this_day');
	}

	if($checker_tag eq 'feed_postfix_date' )
	{
	&check_feed_postfix_date($comp_feed,$checker_tag,'this_day');
	}
	
	if($checker_tag eq 'feed_postfix_str')
	{
	&check_feed_postfix_str($comp_feed,$checker_tag,'this_day');
	}

	if($checker_tag eq 'feed_prev_prefix_str')
	{
	&check_feed_prefix_str($comp_feed,$checker_tag,'prev_day');
	}
	
	if($checker_tag eq 'feed_prev_postfix_date')
	{
	&check_feed_postfix_date($comp_feed,$checker_tag, 'prev_day');
	}

	if($checker_tag eq 'feed_prev_postfix_str')
	{
	&check_feed_postfix_str($comp_feed,$checker_tag,'prev_day');
	}

	if($checker_tag eq 'feed_time_stamp_date')
	{
	&check_feed_attr($feed_name_actual, $comp_feed,'date');
	}

	if($checker_tag eq 'feed_time_stamp')
	{
	&check_feed_attr($feed_name_actual, $comp_feed,'time');
	}
	
	if($checker_tag eq 'feed_size')
	{
	&check_feed_attr($feed_name_actual, $comp_feed,'size');
	}

	if($checker_tag eq 'feed_num_lines')
	{
	&check_feed_num_lines($feed_name_actual, $comp_feed);
	}

	if($checker_tag eq 'feed_header_line')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_header_line');
	}

	if($checker_tag eq 'feed_header_line_date')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_header_line_date');
	}
	
	if($checker_tag eq 'feed_num_column')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_num_column');
	}
	
	if($checker_tag eq 'feed_all_line_check')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_all_line_check');
	}
	
	if($checker_tag eq 'feed_duplicate_line')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_duplicate_line');
	}	 
		 
	if($checker_tag eq 'feed_tailer_line')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_tailer_line');
	}

	if($checker_tag eq 'feed_tailer_line_date')
	{
	&check_read_feed_eval($feed_name_actual, $comp_feed, 'feed_tailer_line_date');
	}
	
	if($checker_tag eq 'feed_variance_check')
	{
	&check_variance($feed_name_actual, $comp_feed, 'feed_variance_check');
	}

	if($checker_tag eq 'feed_compare_prefix_str')
	{
	&feed_compare_prefix_str($comp_feed,'feed_compare_prefix_str' );
	}

	if($checker_tag eq 'feed_compare_postfix_date')
	{
	&feed_compare_postfix_date($comp_feed,'feed_compare_postfix_date');
	}

	if($checker_tag eq 'feed_check_email')
	{
	&send_email($feed_name_actual, $comp_feed, 'feed_check_email');
	}


return;
}


#####################################################################
=head 

This Subroutine compare between two feeds of similar nature

Arguments:
1. $feed_name_actual (Feed name with prefix and postfix)
2. $comp_feed (feed name without prefix and postfix) 
3. $check (feed_variance_check)

=cut

sub check_variance
{
my ($feed_name_actual, $comp_feed, $check)=@_;

my $variance_mail_body="";
my $variance_mail_body_stale="";
my $variance_mail_body_stale_pre="";
my $feed_variance_count=0;
my $feed_stale_count=0;

my @var_chk_tags=qw(
feed_compare_prefix_str
feed_compare_postfix_date
);

my $write_file;
	if($write_to_file_flg)
	{
	$write_file=&get_xml_conf_value($comp_feed, 'feed_compare_write_to_file', "Feed Compare Write to File Name","conf");	
	$write_file=$write_file.".".$comp_prefix if(defined $comp_prefix);
	&writeLog("info","Feed Compare Write File Name  (Actual) : $write_file");
	}

my $compare_feed_name=&get_xml_conf_value($comp_feed, 'feed_name_compare', "Compare Feed Name","conf");	
my $comp_feedname=get_dir_filename($compare_feed_name);

$feed_name_compare_actual=$compare_feed_name;

&redirect_check_optional(\@var_chk_tags,$comp_feed);

my $compare_feed_delim=&get_xml_conf_value($comp_feed, 'feed_compare_delim', "Compare Feed Delimitter             ","conf");	

my $feed_comp_key_col=&get_xml_conf_value($comp_feed, 'feed_compare_key_column_num', "Feed Compare Key Column Numbers     ","conf");	
my $feed_comp_col=&get_xml_conf_value($comp_feed, 'feed_compare_column_num', "Feed Compare Column Number          ","conf");	

my $feed_compare_escape_regex;

	if(&check_xml_tag_exist(\%CONF,$comp_feed,'feed_compare_escape_regex') )
	{
	$feed_compare_escape_regex=&get_xml_conf_value($comp_feed, 'feed_compare_escape_regex', "Feed Compare Escape Regex           ","conf");
	$feed_compare_escape_regex=undef if($feed_compare_escape_regex=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
	}

my $feed_compare_identify_stale_key='No';
my $feed_compare_identify_stale_key_separate_mail='No';

	if(&check_xml_tag_exist(\%CONF,$comp_feed,'feed_compare_identify_stale_key') )
	{
	$feed_compare_identify_stale_key=&get_xml_conf_value($comp_feed, 'feed_compare_identify_stale_key', "Feed Compare Identify Stale Key     ","conf");
	$feed_compare_identify_stale_key='No' if($feed_compare_identify_stale_key=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
	}

	if(&check_xml_tag_exist(\%CONF,$comp_feed,'feed_compare_identify_stale_key_separate_mail') )
	{
	$feed_compare_identify_stale_key_separate_mail=&get_xml_conf_value($comp_feed, 'feed_compare_identify_stale_key_separate_mail', "Feed Compare Identify Stale Key Separate Mail","conf");
	$feed_compare_identify_stale_key_separate_mail='No' if($feed_compare_identify_stale_key_separate_mail=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
	}

my $feed_compare_key_column_name="";
	if(&check_xml_tag_exist(\%CONF,$comp_feed,'feed_compare_key_column_name') )
	{
	$feed_compare_key_column_name=&get_xml_conf_value($comp_feed, 'feed_compare_key_column_name', "Feed Compare Key Column Name        ","conf");
	$feed_compare_key_column_name='' if($feed_compare_key_column_name=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
	}

my $feed_compare_type="NUMERIC";
	if(&check_xml_tag_exist(\%CONF,$comp_feed,'feed_compare_type') )
	{
	$feed_compare_type=&get_xml_conf_value($comp_feed, 'feed_compare_type', "Feed Compare Type                   ","conf");
	$feed_compare_type='NUMERIC' if($feed_compare_type=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
	}
	
my $feed_comp_abs_diff_lim;
	if($feed_compare_type eq 'NUMERIC')
	{
	$feed_comp_abs_diff_lim=&get_xml_conf_value($comp_feed, 'feed_compare_absolute_diff_lim', "Feed Absolute Diffrence Threshold   ","conf");	
	}

my $variance_fail_job='Yes';

	if(&check_xml_tag_exist(\%CONF,$comp_feed,'variance_fail_job') )
	{
	$variance_fail_job=&get_xml_conf_value($comp_feed, 'variance_fail_job', "Job Fail if Variance Seen           ","conf");
	$variance_fail_job='Yes' if($variance_fail_job=~ /y|yes/i);
	}
	$variance_fail_job='No' if($variance_fail_job=~ /n|no/i);

my $mail_body_header=&get_xml_conf_value($comp_feed, 'feed_variance_header_column_names', "Feed Compare Header Columns","conf");

my @head=split(/\|/,$mail_body_header);

my $header_write_to_file=$mail_body_header;
$header_write_to_file=~ s/\|/,/g;
$header_write_to_file=~ s/\s+\,/,/g;
$header_write_to_file="Currency,File Name,".$header_write_to_file;

$feed_comp_key_col=~ s/\s+//g;

my @keys=split(/\,/,$feed_comp_key_col);

&writeLog("info","Compare Feed Name (Actual) : $feed_name_compare_actual");							   
&writeLog("info","Performing Compare Between [$feed_name_actual Vs. $feed_name_compare_actual]");							   
$variance_mail_body .="\nToday's Feed     : $feed_name_actual\nYesterday's Feed : $feed_name_compare_actual\n";
$variance_mail_body_stale_pre .="\nToday's Feed     : $feed_name_actual\nYesterday's Feed : $feed_name_compare_actual\n";

$variance_mail_body .="\n";
$variance_mail_body_stale_pre .="\n";

my $space_delim="     ";
my $header=join($space_delim,@head);
my $len_h=length($header);
my $underline=sprintf ("~" x ${len_h},"");
$variance_mail_body .="\n$header\n";
$variance_mail_body_stale_pre .="\n$header\n";
$variance_mail_body .="$underline\n";
$variance_mail_body_stale_pre .="$underline\n";

my %len=();
	my $i=0;
	foreach my $cc (@head)
	{
	my $le=length($cc);
	$len{$i}=$le;
	$i++;
	}	

my %feed_original=();
my %feed_compare=();

open(FD_ORG,$feed_name_actual)|| die "Can't Open for Reading [$feed_name_actual]: $!\n"; 
open(FD_COM,$feed_name_compare_actual)|| die "Can't Open for Reading [$feed_name_compare_actual]: $!\n"; 

	foreach my $lno (<FD_ORG>)
	{
	$lno=&trim($lno);
	next if ($lno=~ /^$|^\d{8}$/);
		if(defined $feed_compare_escape_regex)
		{
		next if ($lno=~ /$feed_compare_escape_regex/);
		}
	my @FD_ORG=split(/$compare_feed_delim/,$lno);
	unshift(@FD_ORG,"DUM");
	my $key_str="";		
		foreach my $c (@keys)
		{
		my $val=$FD_ORG[$c];
		$key_str .="$val|";
		}
	chop $key_str;
	#print "===$key_str===$FD_ORG[$feed_comp_col]\n";
	$feed_original{$key_str}=$FD_ORG[$feed_comp_col];
	}
close FD_ORG;

	foreach my $lno (<FD_COM>)
	{
	$lno=&trim($lno);
	next if ($lno=~ /^$|^\d{8}$/);
		if(defined $feed_compare_escape_regex)
		{
		next if ($lno=~ /$feed_compare_escape_regex/);
		}
	my @FD_COM=split(/$compare_feed_delim/,$lno);
	unshift(@FD_COM,"DUM");
	my $key_str="";		
		foreach my $c (@keys)
		{
		my $val=$FD_COM[$c];
		$key_str .="$val|";
		}
	chop $key_str;
	#print "===$key_str===$FD_ORG[$feed_comp_col]\n";
	$feed_compare{$key_str}=$FD_COM[$feed_comp_col];
	}
close FD_COM;

	if($write_to_file_flg)
	{
		if(-f $write_file)
		{
		system("rm -f $write_file");
		}
	open(WRT_F,">$write_file") || die "Can't open file for Writing : $!\n";
	print WRT_F "$header_write_to_file\n";
	}

	if($feed_compare_type eq 'NUMERIC')
	{
		foreach my $key (keys %feed_original)
		{
			if(defined $feed_compare{$key})
			{
			my $today_val=abs($feed_original{$key});
			my $prev_val=abs($feed_compare{$key});
			my $diff_val=abs($today_val-$prev_val);
			#print "$key -->$today_val==$prev_val==$diff_val==\n";
				
				if($diff_val > $feed_comp_abs_diff_lim )
				{
				$feed_variance_count++;
    			my $print_str="$key|$prev_val|$today_val|$diff_val";
				my @keys_comp=split(/\|/,$print_str);
	
				my $i=0;
				my $key_bk="";
					foreach my $k (@keys_comp)
					{
					my $kkp=sprintf("%-$len{$i}s",$k);
					$key_bk .="$kkp$space_delim";    
					$i++;
					}
				chomp $key_bk;
				#print "---$key_bk===\n";
				$variance_mail_body .="$key_bk\n";

				my $wrt_file="$comp_prefix,$comp_feedname,$key,$prev_val,$today_val,$diff_val\n";
				print WRT_F $wrt_file if($write_to_file_flg);
				&writeLog("err","Key [$key] -> YD [$prev_val] - TD [$today_val] - Abs.Diff. [$diff_val]");
				}
				elsif($feed_compare_identify_stale_key=~/Y/i && $diff_val==0)
				{
				$feed_stale_count++;
    			my $print_str="$key|$prev_val|$today_val|$diff_val";
				my @keys_comp=split(/\|/,$print_str);
	
				my $i=0;
				my $key_bk="";
					foreach my $k (@keys_comp)
					{
					my $kkp=sprintf("%-$len{$i}s",$k);
					$key_bk .="$kkp$space_delim";    
					$i++;
					}
				chomp $key_bk;
				#print "---$key_bk===\n";
				$variance_mail_body_stale .="$key_bk\n";
				
				my $wrt_file="$comp_prefix,$comp_feedname,$key,$prev_val,$today_val,$diff_val\n";
				print WRT_F $wrt_file if($write_to_file_flg);

				&writeLog("err","Key [$key] -> YD [$prev_val] - TD [$today_val] - Abs.Diff. [$diff_val]");
				}
			}
		}
	}
	else	
	{
	&writeLog("dum","");
	&writeLog("info","Comparision Type [$feed_compare_type], So Variance Check is Disabled...");
	&writeLog("dum","");

	$feed_variance_count=0;
		foreach my $key (keys %feed_original)
		{
			if(defined $feed_compare{$key})
			{
			my $today_val=$feed_original{$key};
			my $prev_val=$feed_compare{$key};
			my $diff_val="";	
				if($today_val eq $prev_val)
				{
				$diff_val="Identical"; 
				}
				else
				{
				$diff_val="Different"; 
				}
				
				if($feed_compare_identify_stale_key=~/Y/i && $diff_val eq 'Identical')
				{
				$feed_stale_count++;
				my $print_str="$key|$prev_val|$today_val|$diff_val";
				my @keys_comp=split(/\|/,$print_str);
			    
				my $i=0;
				my $key_bk="";
					foreach my $k (@keys_comp)
					{
					my $kkp=sprintf("%-$len{$i}s",$k);
					$key_bk .="$kkp$space_delim";    
					$i++;
					}
				chomp $key_bk;
				#print "---$key_bk===\n";
				$variance_mail_body_stale .="$key_bk\n";
				my $wrt_file="$comp_prefix,$comp_feedname,$key,$prev_val,$today_val,$diff_val\n";
				print WRT_F $wrt_file if($write_to_file_flg);
				
				&writeLog("err","Key [$key] -> YD [$prev_val] - TD [$today_val] - Abs.Diff. [$diff_val]");
				}
			}
		}
	}

close WRT_F if($write_to_file_flg);
	
	if($feed_variance_count == 0 && $feed_stale_count==0)
	{
	&writeLog("info","Feed Variance Check is (Good) Passed...");
	&append_mail_body("Feed Variance Check", 'OK','Current Feed Vs Pervious day\'s Feed');
	}
	else
	{
	&writeLog("err","Feed Variance Check is (Bad) Failed...");
	&append_mail_body("Feed Variance Check",'Failed','Current Feed Vs Perviousday\'s Feed');
	&writeLog("dum","");
	
		if($feed_stale_count !=0 && $feed_compare_identify_stale_key_separate_mail=~/Y/i)
		{
		$variance_mail_body_stale =$variance_mail_body_stale_pre.$variance_mail_body_stale;
		&send_email_variance($feed_name_actual, $comp_feed,'feed_variance_check_email',$variance_mail_body_stale,"Stale $feed_compare_key_column_name");
		}
		elsif($feed_stale_count !=0 && $feed_compare_identify_stale_key_separate_mail=~/N/i)
		{
		$variance_mail_body =$variance_mail_body.$variance_mail_body_stale;
		}

	#print "====$variance_mail_body---\n";
		if($feed_variance_count != 0 || ($feed_stale_count !=0 && $feed_compare_identify_stale_key_separate_mail=~/N/i))
		{
		&send_email_variance($feed_name_actual, $comp_feed,'feed_variance_check_email',$variance_mail_body);
		}
		
		if($variance_fail_job eq 'Yes')
		{
		&exit_prog(118);
		}
	}

return;
}

#####################################################################

=head 

This Subroutine sends e-mail

Arguments:

1. $feed_name_actual (Actual feed name with pre-post fix)
2. $comp_feed  (feed name without pre-post fix)
3. $tag	(Checker tag) 

=cut


sub send_email_variance
{
my ($feed_name_actual, $comp_feed, $tag,$mail_body_variance,$sub_append)=@_;


	if($tag eq 'feed_variance_check_email')
	{
	my $info='Send E-mail Variance';
	my ($dr,$fd_name_only)=get_dir_filename($feed_name_actual);

	my $mail_always=&get_xml_conf_value($comp_feed, 'variance_send_email_always', "$info Always          ","conf");
	$mail_always=uc($mail_always);
	
	my $mail_chk_fail=&get_xml_conf_value($comp_feed, 'variance_send_email_when_fail', "$info when Check Fails","conf");
	$mail_chk_fail=uc($mail_chk_fail);
	my $fail_flg=0;

		if($mail_chk_fail eq 'Y')
		{
			if($mail_body=~/fail|exit\s+code/i)
			{
			$fail_flg=1;
			}
			else
			{
				if($mail_always eq 'N')
				{
				&writeLog('info',"No Feed Checks Failed (Not Sending E-mail)");
				}
			}
		}

		if($fail_flg==1 || $mail_always eq 'Y')
		{
		my $mail_sub=&get_xml_conf_value($comp_feed, 'variance_feed_check_email_subject', "$info Subject         ","conf");
	
		$mail_sub .=" $fd_name_only";
		
		my $mail_to=&get_xml_conf_value($comp_feed, 'variance_feed_check_email_to', "$info TO              ","conf");
		my $mail_cc=&get_xml_conf_value($comp_feed, 'variance_feed_check_email_cc', "$info CC              ","conf");
	
		$mail_cc="" if(!defined $mail_cc);
		$mail_cc="" if($mail_cc=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
		my $cc;

		if(defined $sub_append)
		{
		$mail_sub .=" [$sub_append]";
		}

my $mail_body_f="Hi,\n\nPlease find the Feed Compare Summary of $fd_name_only\n\n".$mail_body_variance;

my $feed_log=&get_feed_log_name($feed_name_actual);

$mail_body_f .="

Thanks & Regards,
Sanjog Sahu 

Note: This is an Auto-generated E-mail, Please Do Not Reply.

EOF";
#&writeLog('info',"Mail Subject : $mail_sub");
#&writeLog('info',"\n--------------------- MAIL BODY ---------------------\n$mail_body\n--------------------- MAIL END ----------------------\n");

			if($mail_cc eq "")
			{
			$cc=system("mailx -s \'$mail_sub\' $mail_to <<EOF\n$mail_body_f");
			}
		    else
			{
			$cc=system("mailx -s \'$mail_sub\' -c $mail_cc $mail_to <<EOF\n$mail_body_f");
			}
		
			if($cc != 0)
			{
			&writeLog('err', "Sending mail Failed!");
			&exit_prog(115);
			}
			else
		    {
			&writeLog('info',"Sending mail Successful...");
			}
		}
	}
		
return;
}

#####################################################################
=head 

This Subroutine adds prefix to the feed 

Arguments:
1. $comp_feed (Feed Name)
2. $check (Cheker tag) 
3. $type (this_day | prev_day)

=cut

sub feed_compare_prefix_str
{
my ($comp_feed, $check)=@_;
my $info="Feed Compare PreFix String";

&writeLog("info","Adding $info in the Feed : $feed_name_compare_actual");							   
my $prefix_final=&chk_prefix_valid($comp_feed,'compare_prefix_str',$info);
#my $prefix_final=&get_xml_conf_value($comp_feed, 'compare_prefix_str', "$info           " ,"conf");

my $prefix_delim=&get_xml_conf_value($comp_feed, 'compare_prefix_str_delim', "$info Delimitter","conf"); 

my ($dir,$file_name)=&get_dir_filename($feed_name_compare_actual);
$feed_name_compare_actual=$dir."/".$prefix_final.$prefix_delim.$file_name;
&writeLog("info","Feed Name after Adding $info : $feed_name_compare_actual");							   
		
return;

}

#####################################################################
=head 

This Subroutine adds post fix date to the feed

Arguments:
1. $comp_feed (Feed Name)
2. $checker_tag (Cheker tag) 
3. $type (this_day | prev_day)

=cut


sub feed_compare_postfix_date
{
my ($comp_feed,$checker_tag, $type)=@_;
$type=&trim(lc($type));
my $info="Feed Compare PostFix Date";

my $date;
my $format_date;	

&writeLog("info","Adding $info in the Feed : $feed_name_compare_actual");							   
my ($dir,$file_name)=&get_dir_filename($feed_name_compare_actual);
my $date_type=&get_xml_conf_value($comp_feed, 'compare_postfix_date_type', "$info Type      " ,"conf", 'date_type_print');

	
$date_type="$date_type-0" if($date_type=~ /^bus_date$|^cur_date$/i);
$date=&addsub_buscur_days($bus_date,$date_type,$holiday_file);
		
my $date_form=&get_xml_conf_value($comp_feed, 'compare_postfix_date_format', "$info Format    " ,"conf");
my $postfix_delim=&get_xml_conf_value($comp_feed, 'compare_postfix_date_delim', "$info Delimitter" ,"conf");

$format_date=my_format_date($date,'yyyymmdd',$date_form);
&writeLog("info","$info        (Expected) : $format_date");							   

$feed_name_compare_actual=$dir."/".$file_name.$postfix_delim.$format_date;

&writeLog("info","Feed Name after Adding $info : $feed_name_compare_actual");							   

return; 
}

#####################################################################
=head 

This Subroutine adds prefix to the feed 

Arguments:
1. $comp_feed (Feed Name)
2. $check (Cheker tag) 
3. $type (this_day | prev_day)

=cut

sub check_feed_prefix_str
{
my ($comp_feed, $check, $type)=@_;
$type=&trim(lc($type));
my $info="PreFix String";


	if($type eq	'this_day')
	{
	&writeLog("info","Adding $info in the ( Current ) Feed : $feed_name_actual");							   
	
	my $prefix_final=&chk_prefix_valid($comp_feed,'prefix_str',$info);

	my $prefix_delim=&get_xml_conf_value($comp_feed, 'prefix_str_delim', "$info Delimitter","conf"); 

	my ($dir,$file_name)=&get_dir_filename($feed_name_actual);
	$feed_name_actual=$dir."/".$prefix_final.$prefix_delim.$file_name;
	&writeLog("info","Feed Name after Adding $info : $feed_name_actual");							   
	}
	elsif($type eq 'prev_day')
	{
	&writeLog("info","Adding $info in the ( Previous Day's ) Feed : $feed_name_actual_prev");							   

	my $prefix_final=&chk_prefix_valid($comp_feed,'prev_prefix_str',$info);

	my $prefix_delim=&get_xml_conf_value($comp_feed, 'prev_prefix_str_delim', "$info Delimitter","conf"); 

	my ($dir,$file_name)=&get_dir_filename($feed_name_actual_prev);
	$feed_name_actual_prev=$dir."/".$prefix_final.$prefix_delim.$file_name;
	&writeLog("info","Feed Name after Adding $info : $feed_name_actual_prev");							   
	}
		
return;

}


#####################################################################
=head 

This Subroutine adds postfix to the feed 

Arguments:
1. $comp_feed (Feed Name)
2. $check (Cheker tag) 
3. $type (this_day | prev_day)

=cut

sub check_feed_postfix_str
{
my ($comp_feed, $check, $type)=@_;
$type=&trim(lc($type));
my $info="PostFix String";


	if($type eq	'this_day')
	{
	&writeLog("info","Adding $info in the ( Current ) Feed : $feed_name_actual");							   
	
	my $postfix_final=&chk_prefix_valid($comp_feed,'postfix_str',$info);

	my $postfix_delim=&get_xml_conf_value($comp_feed, 'postfix_str_delim', "$info Delimitter","conf"); 

	my ($dir,$file_name)=&get_dir_filename($feed_name_actual);
	$feed_name_actual=$dir."/".$file_name.$postfix_delim.$postfix_final;
	&writeLog("info","Feed Name after Adding $info : $feed_name_actual");							   
	}
	elsif($type eq 'prev_day')
	{
	&writeLog("info","Adding $info in the ( Previous Day's ) Feed : $feed_name_actual_prev");							   

	my $postfix_final=&chk_prefix_valid($comp_feed,'prev_postfix_str',$info);

	my $postfix_delim=&get_xml_conf_value($comp_feed, 'prev_postfix_str_delim', "$info Delimitter","conf"); 

	my ($dir,$file_name)=&get_dir_filename($feed_name_actual_prev);
	$feed_name_actual_prev=$dir."/".$file_name.$postfix_delim.$postfix_final;
	&writeLog("info","Feed Name after Adding $info : $feed_name_actual_prev");							   
	}
		
return;

}


#####################################################################
=head 

This Subroutine validates whether the prefix provided in command line <-p> is a valid one or not 

if the prefix sring in config is like 
Example: <prev_prefix_str>DEM|GBP|EUR|CHF|AUD|JPY|CAD|SEK|HKD|NOK|NZD|DKK</prev_prefix_str> 
then have to provide the -p option in commad line the propper prifix (case sensitive)

Arguments:
1. $comp_feed (Feed Name)
2. $check (Cheker tag) 
3. $info (information string to print)

=cut

sub chk_prefix_valid
{
my ($comp_feed, $check, $info)=@_;
my $prefix_chk=&get_xml_conf_value($comp_feed, $check, "$info           ","conf"); 
my $prefix_final;	

	if($prefix_chk=~ /\|/)
	{
	my %pref=&get_hash($prefix_chk,"|");

		if(defined $prefix)
		{
			unless(defined $pref{$prefix})
			{
			&writeLog("err","Invalid Prefix Provided ($prefix) [Allowed Prefixes ($prefix_chk)]");
			&append_mail_body("Invalid Prefix Provided ($prefix) [Allowed Prefixes ($prefix_chk)]");
			&exit_prog(116);
			}
			else
			{
			&writeLog("info","$info        (Provided) : $prefix");
			$prefix_final=$prefix;
			}
		}
		else
		{
		&writeLog("err","$0 <-p> Option Not Provided! (Please Provide Correct Prefix for Feed)");
		&usage();
		}
	}
	else
	{
		if(defined $prefix)
		{
			if($prefix eq $prefix_chk)
			{
			&writeLog("conf","$info        (Expected) : $prefix_chk");
			$prefix_final=$prefix;
			}
			else
			{
			&writeLog("conf","$info        (Expected) : $prefix");
			&writeLog("err","Invalid Prefix Provided ($prefix) [Allowed Prefix ($prefix_chk)]");
			&append_mail_body("Invalid Prefix Provided ($prefix) [Allowed Prefix ($prefix_chk)]");
			&exit_prog(116);
			}
		}
		else
		{
		&writeLog("conf","$info        (Expected) : $prefix_chk");
		$prefix_final=$prefix_chk;
		}
	}

return $prefix_final;
}

#####################################################################
=head 

This Subroutine adds post fix date to the feed

Arguments:
1. $comp_feed (Feed Name)
2. $checker_tag (Cheker tag) 
3. $type (this_day | prev_day)

=cut


sub check_feed_postfix_date
{
my ($comp_feed,$checker_tag, $type)=@_;
$type=&trim(lc($type));
my $info="PostFix Date";

my $date;
my $format_date;	

	if($type eq	'this_day')
	{
	&writeLog("info","Adding PostFix Date in the Feed : $comp_feed");							   

	my ($dir,$file_name)=&get_dir_filename($feed_name_actual);
		if(defined $bus_date)
		{
		$date=$bus_date;
		}
		else
		{
		my $date_type=&get_xml_conf_value($comp_feed, 'postfix_date_type', "$info Type" ,"conf", 'date_type_print');
		$date_type="$date_type-0" if($date_type=~ /^bus_date$|^cur_date$/i);
		$date=&addsub_buscur_days($bus_date,$date_type,$holiday_file);
		}

	my $date_form=&get_xml_conf_value($comp_feed, 'postfix_date_format', "$info Format    " ,"conf");
	my $postfix_delim=&get_xml_conf_value($comp_feed, 'postfix_date_delim', "$info Delimitter" ,"conf");

	$format_date=my_format_date($date,'yyyymmdd',$date_form);
	&writeLog("info","$info        (Expected) : $format_date");							   

	$feed_name_actual=$dir."/".$file_name.$postfix_delim.$format_date;

	my $extn="";
	my $feed_extn_delim="";
	my $feed_extn="";

		if(&check_xml_tag_exist(\%CONF,$comp_feed,'postfix_extn') )
		{
		$feed_extn=&get_xml_conf_value($comp_feed, 'postfix_extn', "Feed Extension         " ,"conf");
		
			if(&check_xml_tag_exist(\%CONF,$comp_feed,'postfix_extn_delim') )
			{
			$feed_extn_delim=&get_xml_conf_value($comp_feed, 'postfix_extn_delim', "Feed Extension Delimitter" ,"conf");
			}
		$extn=$feed_extn_delim.$feed_extn;
		$feed_name_actual=$feed_name_actual.$extn;
		}

	&writeLog("info","Feed Name after Adding $info : $feed_name_actual");							   
	}
	elsif($type eq 'prev_day')
	{
	&writeLog("info","Adding PostFix Date in the [Prev Feed] : $comp_feed");							   
	my ($dir,$file_name)=&get_dir_filename($feed_name_actual_prev);
	my $date_type=&get_xml_conf_value($comp_feed, 'prev_postfix_date_type', "$info Type       [Prev Feed]" ,"conf", 'date_type_print');
	
	$date_type="$date_type-0" if($date_type=~ /^bus_date$|^cur_date$/i);
	#print "-----$bus_date,$date_type---$holiday_file\n";
	$date=&addsub_buscur_days($bus_date,$date_type,$holiday_file);
	#print "--Date--$date--\n";	
	
	my $date_form=&get_xml_conf_value($comp_feed, 'prev_postfix_date_format', "$info Format     [Prev Feed]" ,"conf");
	my $postfix_delim=&get_xml_conf_value($comp_feed, 'prev_postfix_date_delim', "$info Delimitter [Prev Feed]" ,"conf");

	$format_date=my_format_date($date,'yyyymmdd',$date_form);
	&writeLog("info","$info        [Prev Feed] (Expected) : $format_date");							   

	$feed_name_actual_prev=$dir."/".$file_name.$postfix_delim.$format_date;
	
	my $extn="";
	my $feed_extn_delim="";
	my $feed_extn="";

		if(&check_xml_tag_exist(\%CONF,$comp_feed,'prev_postfix_extn') )
		{
		$feed_extn=&get_xml_conf_value($comp_feed, 'prev_postfix_extn', "Feed Extension         " ,"conf");
		
			if(&check_xml_tag_exist(\%CONF,$comp_feed,'prev_postfix_extn_delim') )
			{
			$feed_extn_delim=&get_xml_conf_value($comp_feed, 'prev_postfix_extn_delim', "Feed Extn Delimitter" ,"conf");
			}
		$extn=$feed_extn_delim.$feed_extn;
		$feed_name_actual=$feed_name_actual.$extn;
		}
	
	&writeLog("info","Feed Name after Adding $info [Prev Feed] : $feed_name_actual_prev");							   
	}

return; 
}

#####################################################################

=head 

This Subroutine checks whether the feed is stale or not ( current feed vs Previous Days Feed)
if there is not difference between current and provious feed,  then the check fails 

Arguments:
1. $feed_today (Current Feed)
2. $feed_prev  (Previous Days' Feed [bussiness Date])

=cut

sub check_feed_stale
{
my ($feed_today,$feed_prev)=@_;

&writeLog("dum","");

&writeLog("info","Checking \"Current\" Feed against \"Previous Day's\" Feed");

my $diff=`diff $feed_today $feed_prev`;
chomp $diff;

	if($diff ne "")
	{
	&writeLog("info","Feed Stale Check is (Good) Passed...");
	&append_mail_body("Feed Stale Check", 'OK','Current Feed Vs Pervious day\'s Feed');
	}
	else
	{
	&writeLog("err","Feed Stale Check is (Bad) Failed...");
	&append_mail_body("Feed Stale Check",'Failed','Current Feed Vs Perviousday\'s Feed');
	&exit_prog(103);
	}

return;
}


#####################################################################
=head 

This Subroutine checks all feed attribute  like "date", "size", "time" of feed on the disk

Arguments:
1. $feed_name_actual (Feed name with prefix and postfix)
2. $comp_feed (feed name without prefix and postfix) 
3. $check (date | size | time)

=cut


sub check_feed_attr
{
my ($feed_name_actual, $comp_feed, $check)=@_;
$check=&trim(lc($check));


my $feed=$feed_name_actual_ls_lrt;
#print "$feed\n";
my ($file_size_byte,$date_file,$time_stamp)=&get_file_attr($feed);
my $date;	

	if($check eq 'date')
	{
	my $info="Feed Date";
	&writeLog("info","Checking for \"$info\" on the Disk : $feed_name_actual");							   
	&writeLog("info","Feed Properties : $feed_name_actual_ls_lrt");							   
	

	$date=$bus_date;
	my $expt_date=$bus_date;
	my $date_type=&get_xml_conf_value($comp_feed, 'feed_time_stamp_date_type', "$info Type" ,"conf",'date_type_print');
	$date_type="$date_type-0" if($date_type=~ /^bus_date$|^cur_date$/i);
	my $date_calc=&addsub_buscur_days($bus_date,$date_type,$holiday_file);	

		if($date_calc ne $expt_date && $date_type ne 'bus_date' && $date_type ne 'cur_date' )
		{
		$date=$date_calc;
		}
	
	my $date_calc_final=&my_format_date($date,'yyyymmdd',"YYYY-MM-DD");
	my $date_feed_final=&my_format_date($date_file,'yyyy-mm-dd',"YYYYMMDD");
	&writeLog("info","$info    (Actual) : $date_feed_final");
	&writeLog("info","$info  (Expected) : $date");
	

		if($date_file eq $date_calc_final)
		{
		&writeLog("info","Feed Time Stamp Date \"$date_feed_final\" (Good) Passed...");
		&append_mail_body("Feed Time Stamp Date Check", 'OK', "Actual ($date_feed_final) Vs Expected ($date)");
		}
		else
		{
		&writeLog("err","Feed Time Stamp Date \"$date_feed_final\" (Bad) Failed...");
		&append_mail_body("Feed Time Stamp Date Check",'Failed', "Actual ($date_feed_final) Vs Expected ($date)");
		&exit_prog(104);
		}
	
	}
#####################################################################

	if($check eq 'time')
	{
	my $info="Feed Arrival Time";
	&writeLog("info","Checking for \"$info\" on the Disk : $feed_name_actual");							   
	&writeLog("info","Feed Properties : $feed_name_actual_ls_lrt");							   
	my ($min_arr_time,$max_arr_time,$latest_buffer,$job_fail_flag,$send_mail_flg);

	$min_arr_time=&get_xml_conf_value($comp_feed, 'min_arraival_time', "$info Minimum" ,"conf");
	$max_arr_time=&get_xml_conf_value($comp_feed, 'max_arraival_time', "$info Maximum" ,"conf");


	&writeLog("info","$info       (Actual) : $time_stamp");
	my $time_stamp_bkp=$time_stamp;
	my ($date_min, $date_max, $date_feed);
	my $min_arr_time_t=$min_arr_time;
	$min_arr_time_t=~ s/://g;
	my $max_arr_time_t=$max_arr_time;
	$max_arr_time_t=~ s/://g;
	my $time_stamp_t=$time_stamp;
	$time_stamp_t=~ s/://g;

		
	$min_arr_time_t=sprintf("%d",$min_arr_time_t);
	$max_arr_time_t=sprintf("%d",$max_arr_time_t);
	$time_stamp_t=sprintf("%d",$time_stamp_t);
		
		if($min_arr_time_t > $max_arr_time_t)
		{
		my ($day_min_t,$date_min_t)=&addsub_buscur_days($bus_date,'bus_date-1',$holiday_file);
		$date_min=&my_format_date($date_min_t,'yyyymmdd',"YYYY-MM-DD");
		my ($day_max_t,$date_max_t)=&addsub_buscur_days($bus_date,'bus_date-0',$holiday_file);
		$date_max=&my_format_date($date_max_t,'yyyymmdd',"YYYY-MM-DD");
		}
		elsif($time_stamp_t < $min_arr_time_t)
		{
		&writeLog("err","Feed Arrival Time Stamp \"$time_stamp_bkp\" (Bad) Failed...");
		&append_mail_body("Feed Arrival Time Stamp Check",'Failed',"Actual ($time_stamp_bkp) Vs Threshold ($min_arr_time<->$max_arr_time)");
		&exit_prog(105);
		}
		else
		{
		my ( $day_min_t,$date_min_t)=&addsub_buscur_days($bus_date,'bus_date-0',$holiday_file);
		$date_min=&my_format_date($date_min_t,'yyyymmdd',"YYYY-MM-DD");
		$date_max=$date_min;
		}
   
    my ($dd_conf,$hh_conf,$mm_conf,$ss_conf)=&time_taken(date1 => "$date_min $min_arr_time" ,date2 => "$date_max $max_arr_time");
	my $conf_duration=$dd_conf.$hh_conf.$mm_conf.$ss_conf;

	my ($dd_actu,$hh_actu,$mm_actu,$ss_actu)=&time_taken(date1 => "$date_min $min_arr_time" ,date2 => "$date_max $time_stamp");
	my $actu_duration=$dd_actu.$hh_actu.$mm_actu.$ss_actu;
		#print "CONF   DURATION :$conf_duration\n";
		#print "ACTUAL DURATION :$actu_duration\n";
		if($actu_duration !~ /^\d+$/ || $conf_duration !~ /^\d+$/)
		{
		print "Error In Time Stamp Calculation\n";
		exit(1);
		}
		else
		{
		#print "CONF   DURATION :$conf_duration\n";
		#print "ACTUAL DURATION :$actu_duration\n";
		}
	$actu_duration=sprintf("%d",$actu_duration);
	$conf_duration=sprintf("%d",$conf_duration);
	
		
		if($actu_duration <= $conf_duration)
		{
		&writeLog("info","Feed Arrival Time Stamp \"$time_stamp_bkp\" (Good) Passed...");
		&append_mail_body("Feed Arrival Time Stamp Check",'OK',"Actual ($time_stamp_bkp) Vs Threshold ($min_arr_time<->$max_arr_time)");
		}
		else
		{
		&writeLog("err","Feed Arrival Time Stamp \"$time_stamp_bkp\" (Bad) Failed...");
		&append_mail_body("Feed Arrival Time Stamp Check",'Failed',"Actual ($time_stamp_bkp) Vs Threshold ($min_arr_time<->$max_arr_time)");
		&exit_prog(105);
		}
		
		if(&check_xml_tag_exist(\%CONF,$comp_feed,'latest_time_stamp_buffer_minute') )
		{
		&writeLog("dum","");
		$latest_buffer=&get_xml_conf_value($comp_feed, 'latest_time_stamp_buffer_minute', "$info Latest File Time Stamp Check Buffer Minute","conf");
		}
	

		if(defined $latest_buffer)
		{
		my $curr_date=&trim(`date +%Y-%m-%d`);
		my $curr_time=&trim(`date +%H:%M:%S`);

		my $job_fail_flag='Yes';

			if(&check_xml_tag_exist(\%CONF,$comp_feed,'check_fail_nolatest_timestamp') )
			{
			$job_fail_flag=&get_xml_conf_value($comp_feed, 'check_fail_nolatest_timestamp', "Job Fail if Feed Crossed Latest TimeStamp Buffer min        ","conf");
			$job_fail_flag='Yes' if($job_fail_flag=~ /y|yes/i);
			$job_fail_flag='No' if($job_fail_flag=~ /n|no/i);
			}
		
		my $send_mail_flg='Yes';
	
			if(&check_xml_tag_exist(\%CONF,$comp_feed,'send_mail_nolatest_timestamp') )
			{
			$send_mail_flg=&get_xml_conf_value($comp_feed, 'send_mail_nolatest_timestamp', "Send Mail if Feed Crossed Latest TimeStamp Buffer min       ","conf");
			$send_mail_flg='Yes' if($send_mail_flg=~ /y|yes/i);
			$send_mail_flg='No' if($send_mail_flg=~ /n|no/i);
			}
		
		#print "---$curr_date--$curr_time---\n";

		my ($dd_actu,$hh_actu,$mm_actu,$ss_actu)=&time_taken(date2 => "$curr_date $curr_time" ,date1 => "$date_file $time_stamp");
		#print "---$curr_date $curr_time---$date_max $time_stamp---==$dd_actu,$hh_actu,$mm_actu,$ss_actu==\n";
		
		my $time_sec=($dd_actu * 24 * 60 *60) + ($hh_actu * 60 *60) + ($mm_actu * 60) + $ss_actu;
		my $comp_conf_time=(0 * 24 * 60 *60) + (0 * 60 * 60) + ($latest_buffer *60) + $ss_actu;
		
		&writeLog("info","Feed File Time Stamp       : $date_file $time_stamp");
		&writeLog("info","Current Check Time Stamp   : $curr_date $curr_time");
		&writeLog("info","Threshhold Time Difference (Expected) : $comp_conf_time Sec.");
		&writeLog("info","Latest Feed Time Difference  (Actual) : $time_sec Sec.");
		
			if($time_sec > $comp_conf_time)
			{
			#print "ACTUAL--$time_sec-----CONF--$comp_conf_time--\n";
			
				if($job_fail_flag eq 'Yes')
				{
				&writeLog("err","Latest Feed Time Stamp \"$date_file $time_stamp\" (Bad) Failed...");
				&append_mail_body("Latest Feed Time Stamp Check",'Failed',"Feed TimeStamp ($date_file $time_stamp) Vs Check TimeStamp ($curr_date $curr_time) [Threshold $latest_buffer Min.]");
				&exit_prog(119);
				}
				elsif($send_mail_flg eq 'Yes')
				{
				&writeLog("err","Latest Feed Time Stamp \"$date_file $time_stamp\" (Bad) Failed...");
				&append_mail_body("Latest Feed Time Stamp Check",'Failed',"Feed TimeStamp ($date_file $time_stamp) Vs Check TimeStamp ($curr_date $curr_time) [Threshold $latest_buffer Min.]");
				&alert_chkfail(119);
				}
			}
			else
			{
			&writeLog("info","Latest Feed Time Stamp \"$date_file $time_stamp\" (Good) Passed...");
			&append_mail_body("Latest Feed Time Stamp Check",'OK',"Feed TimeStamp ($date_file $time_stamp) Vs Check TimeStamp ($curr_date $curr_time) [Threshold $latest_buffer Min.]");
			}
		}
	}
#####################################################################
		
	if($check eq 'size')
	{
	my $info="Feed Size";
	&writeLog("info","Checking for \"$info\" on the Disk : $feed_name_actual");							   
	&writeLog("info","Feed Properties : $feed_name_actual_ls_lrt");							   

	my ($min_size,$max_size);

	$min_size=&get_xml_conf_value($comp_feed, 'min_file_size', "$info Minimum" ,"conf");
	$max_size=&get_xml_conf_value($comp_feed, 'max_file_size', "$info Maximum" ,"conf");


	&writeLog("info","Feed Size       (Actual) : $file_size_byte");
	
		if($file_size_byte >= $min_size &&  $file_size_byte <= $max_size)
		{
		&writeLog("info","Feed Size \"$file_size_byte\" (Good) Passed...");
		&append_mail_body("Feed Size Check",'OK',"Actual ($file_size_byte) Vs Threshold ($min_size<->$max_size)");
		}
		else
		{
		&writeLog("err","Feed Size \"$file_size_byte\" (Bad) Failed...");
		&append_mail_body("Feed Size Check",'Failed',"Actual ($file_size_byte) Vs Threshold ($min_size<->$max_size)");
		&exit_prog(106);
		}
	}
return;
}

#####################################################################

=head 

This Subroutine checks Number of Lines in the feed 

Arguments:
1. $feed_name_actual (Feed name with prefix and postfix)
2. $comp_feed (feed name without prefix and postfix) 

=cut


sub check_feed_num_lines
{
my ($feed_name_actual, $comp_feed)=@_;
my $info="Number of Records";
&writeLog("info","Checking for \"$info\" in the Feed : $feed_name_actual");							   
my ($min_lines,$max_lines);


$min_lines=&get_xml_conf_value($comp_feed, 'min_num_lines', "$info Minimum","conf");
$max_lines=&get_xml_conf_value($comp_feed, 'max_num_lines', "$info Maximum","conf");

my $wc_num_lines=`wc -l $feed_name_actual`;
chomp $wc_num_lines;
my ($actual_num_lines, $ff)=split(/\s+/,$wc_num_lines,2);

	&writeLog("info","$info       (Actual) : $actual_num_lines");
	
		if($actual_num_lines >= $min_lines &&  $actual_num_lines <= $max_lines)
		{
		&writeLog("info","$info in the Feed \"$actual_num_lines\" (Good) Passed...");
		&append_mail_body("Feed $info Check",'OK', "Actual ($actual_num_lines) Vs Threshold ($min_lines<->$max_lines)");
		}
		else
		{
		&writeLog("err","$info in the Feed \"$actual_num_lines\" (Bad) Failed...");
		&append_mail_body("Feed $info Check",'Failed', "Actual ($actual_num_lines) Vs Threshold ($min_lines<->$max_lines)");
		&exit_prog(114);
		}

return;
}

#####################################################################

=head 

This Subroutine checks and evalute all records, basically 
(header line, all line of feed, trailer line etc.)

Arguments:
1. $feed_name_actual (Feed name with prefix and postfix)
2. $comp_feed (feed name without prefix and postfix) 
3. $check (feed_header_line | feed_header_line_date | feed_num_column | feed_all_line_check | 
   feed_duplicate_line | feed_tailer_line | feed_tailer_line_date) 

=cut

sub check_read_feed_eval
{
my ($feed_name_actual, $comp_feed, $check)=@_;
my $chk_type="Feed";

my @all_lines=();
open(READ,$feed_name_actual)|| die "Couldn't Open File for Reading : $feed_name_actual : $!\n";
		foreach my $line (<READ>)
		{
		chomp $line;
		push(@all_lines,$line);
		}

 close READ;

	if($check eq 'feed_header_line')
	{
	my $date;
	my $info="Header Line";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");							   

	my $h_line_num=&get_xml_conf_value($comp_feed, 'header_line_num', "Check $info No.","conf"); 
	my %line_index=&get_index(\@all_lines,$h_line_num);
		
	my $header_line_regex=&get_xml_conf_value($comp_feed, 'header_line_regex', "$info RegExp   ","conf");
	my @error_line=&chk_all_feed_lines(\@all_lines, \%line_index,$header_line_regex, 'n','only_match');

		if(scalar @error_line == 0)
		{
		&writeLog("info","$info is (Good) Passed...");
		&append_mail_body("$info Check", 'OK',"Actual Vs Regular Expression");
		}
		else
		{
		&writeLog("err","$info is (Bad) Failed...");
		&append_mail_body("$info Check", 'Failed',"Actual Vs Regular Expression");
		&exit_prog(107);
		}
	}

	if($check eq 'feed_header_line_date')
	{
	my $info="Header Line Date";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");

	&check_line_date('header_line_date_type','header_line_date_format','header_line_date_regex','header_line_date_num',\@all_lines,$info);
	}	
	

	if($check eq 'feed_num_column')
	{
	my $date;
	my $info="Number of Columns";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");							   
	
	my $chk_line_num=&get_xml_conf_value($comp_feed, 'chk_column_line_num', "Check Columns Line Number    ","conf"); 
	my %line_index=&get_index(\@all_lines,$chk_line_num);
	
	my $min_cols=&get_xml_conf_value($comp_feed, 'min_num_column', "$info Minimum    ","conf"); 
	my $max_cols=&get_xml_conf_value($comp_feed, 'max_num_column', "$info Maximum    ","conf"); 
	my $cols_delim=&get_xml_conf_value($comp_feed, 'column_delim', "$info Delimitter ","conf"); 
	
	$cols_delim='\|'	if($cols_delim eq '|');
	my $chk_flg=1;
	my $num_col;	
		foreach my $index (sort keys %line_index)
		{
		my $feed_chk_line=$all_lines[$index];
		&writeLog("info","Check $info (Line No. $line_index{$index}) : -->$feed_chk_line<--");							   
		my @cols=split(m|$cols_delim|,$feed_chk_line);
		$num_col=scalar(@cols);	
		
		&writeLog("info","$info           (Actual) : $num_col");							   
	
			if($num_col >= $min_cols && $num_col <= $max_cols)
			{
			&writeLog("info","$info is (Good) Passed...");
			}
			else
			{
			$chk_flg=0;
			&writeLog("err","$info is (Bad) Failed...");
			}
		}
	
		if($chk_flg==1)
		{
		&append_mail_body("$info Check", 'OK',"Actual ($num_col) Vs Threshold ($min_cols<->$max_cols)");
		}
		else
		{
		&append_mail_body("$info Check",'Failed', "Actual ($num_col) Vs Threshold ($min_cols<->$max_cols)");
		&exit_prog(108);
		}
	
	}
	
	if($check eq 'feed_all_line_check')
	{
	my $date;
	my $info="All Records";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");							   

	my $chk_line_num=&get_xml_conf_value($comp_feed, 'chk_escape_line_num', "Check Escape Line No.  ","conf"); 

	my %escape_index=&get_index(\@all_lines,$chk_line_num);
	my $chk_line_regex=&get_xml_conf_value($comp_feed, 'feed_line_chk_regex', "$info RegExp     ","conf"); 
	my $case=&get_xml_conf_value($comp_feed, 'feed_line_chk_case_senc', "$info CaseSence  ","conf");
	my $err_lmt=&get_xml_conf_value($comp_feed, 'feed_line_chk_error_limit', "$info Error Limit","conf");
	
	my $escape_line_regex;
	
	if(&check_xml_tag_exist(\%CONF,$comp_feed,'chk_escape_line_regex') )
	{
	$escape_line_regex=&get_xml_conf_value($comp_feed, 'chk_escape_line_regex', "$info Escape Line Regex","conf");
	}
	
	$case=&trim(lc($case));

	my @error_line=&chk_all_feed_lines(\@all_lines, \%escape_index,$chk_line_regex, $case,'escape',$escape_line_regex);

		my $err_allline_flg=0;
		my $num_err=scalar @error_line;
		&writeLog("info","Number of Errors Found (Actual): $num_err");
		
		if($num_err > 0 )
		{
		$err_allline_flg=1;	
			foreach my $err (@error_line) 
			{
			&writeLog("err","$err");							   
			}
		}
	
		if($num_err <= $err_lmt)
		{
		$err_allline_flg=0;	
		}
		if($err_allline_flg==0)
		{
		&writeLog("info","$info are (Good) Passed...");
		&append_mail_body("$info Check", 'OK',"Actual Errors ($num_err) Vs Threshold (0<->$err_lmt)" );
		}
		else
		{
		&writeLog("err","$info Check is (Bad) Failed...");
		&append_mail_body("$info Check", 'Failed',"Actual Errors ($num_err) Vs Threshold (0<->$err_lmt)");
		&exit_prog(109);
		}
	}

	if($check eq 'feed_duplicate_line')
	{
	my $date;
	my $info="Duplicate Record";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");							   

	my $total_dupl_lmt=&get_xml_conf_value($comp_feed, 'total_nos_duplicate_limit', "$info Threshold","conf"); 
	
	my %DUPL=();
	my %DUPL_LINE_NOS=();	
	my $count_print=1;
	my $total_dup_calc=0;
		foreach my $line (@all_lines)
		{
			if(!defined $DUPL{$line})
			{
			my $ct=0;
			$DUPL{$line}=$ct;
				if(!defined $DUPL_LINE_NOS{$line})
				{
				my $ct_l="$count_print ,";
				$DUPL_LINE_NOS{$line}=$ct_l;
				}
			}
			else
			{
			my $ct=$DUPL{$line} + 1;
			$DUPL{$line}=$ct;
			my $ct_l=$DUPL_LINE_NOS{$line}."$count_print ,";
			$DUPL_LINE_NOS{$line}=$ct_l;
			$total_dup_calc++;
			}
		$count_print++;
		}
		
		foreach my $chk_l (keys %DUPL)
		{
			if($DUPL{$chk_l} > 0)
			{
			&writeLog("warn","Duplicate Record : -->$chk_l<--");							   
			my $dup=$DUPL_LINE_NOS{$chk_l};
			chop $dup;
			chop $dup;
			&writeLog("info","Duplicate Record Nos. : ($dup)");
			&writeLog("dum","");
			}
		}

		&writeLog("info","$info Found   (Actual) : $total_dup_calc");
		
		if($total_dup_calc <= $total_dupl_lmt)
		{
		&writeLog("info","$info is (Good) Passed...");
		&append_mail_body("$info Check", 'OK',"Actual Dulicates ($total_dup_calc) Vs Threshold (0<->$total_dupl_lmt)" );
		}
		else
		{
		&writeLog("err","$info is (Bad) Failed...");
		&append_mail_body("$info Check", 'Failed',"Actual Dulicates ($total_dup_calc) Vs Threshold (0<->$total_dupl_lmt)");
		&exit_prog(117);
		}
	}


	if($check eq 'feed_tailer_line')
	{
	my $date;
	my $info="Trailer Line";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");							   

	my $line_num=&get_xml_conf_value($comp_feed, 'tailer_line_num', "$info No.   ","conf"); 
	my %line_index=&get_index(\@all_lines,$line_num);
		
	my $tailer_line_regex=&get_xml_conf_value($comp_feed, 'tailer_line_regex', "$info RegExp","conf");
	my @error_line=&chk_all_feed_lines(\@all_lines, \%line_index,$tailer_line_regex, 'n','only_match');

		if(scalar @error_line == 0)
		{
		&writeLog("info","$info is (Good) Passed...");
		&append_mail_body("$info Check", 'OK', "Actual Vs Regular Expression");
		}
		else
		{
		&writeLog("err","$info is (Bad) Failed...");
		&append_mail_body("$info Check", "Failed", "Actual Vs Regular Expression");
		&exit_prog(110);
		}
	}

	
	if($check eq 'feed_tailer_line_date')
	{
	my $info="Trailer Line Date";
	&writeLog("info","Checking for \"$info\" in the $chk_type : $feed_name_actual");
	&check_line_date('tailer_line_date_type','tailer_line_date_format','tailer_line_date_regex','tailer_line_date_num',\@all_lines,$info);
	}	
	

return;
}

#####################################################################

=head 

This Subroutine checks the date in the feed line given

Arguments:
1. $date_type_tag  (date type tag defeind in config.)
2. $date_format_tag	(Date format tag defined in the config)
3. $date_regex_tag (regular Expression tag defined in config.) 
4. $date_line_num_tag (line number to check tag defined in config.)
5. $all_lines (reference of @all_lines)
6. $info (information to print)

=cut

sub check_line_date
{
my ($date_type_tag,$date_format_tag,$date_regex_tag,$date_line_num_tag,$all_lines,$info)=@_;
	
my @all_lines=@{$all_lines};
my $date;
my $date_calc;

my $date_type=&get_xml_conf_value($comp_feed, $date_type_tag, "$info Type     " ,"conf", 'date_type_print');
$date_type=&trim(lc($date_type));
my $date_format=&get_xml_conf_value($comp_feed, $date_format_tag, "$info Format   " ,"conf");
	
	if($date_type eq 'bus_date' && defined $bus_date)
	{
	$date=$bus_date;
	}
	else
	{
	$date_type="$date_type-0" if($date_type=~ /^bus_date$|^cur_date$/i);
	$date=&addsub_buscur_days($bus_date,$date_type,$holiday_file);
	}

$date=&my_format_date($date,'YYYYMMDD',$date_format);
	
my $date_regex=&get_xml_conf_value($comp_feed, $date_regex_tag, "$info RegExp   ","conf");
	
$date_regex=~s /$date_format/$date/gi;
&writeLog("info","$info Expected         : $date");

my $line_num=&get_xml_conf_value($comp_feed, $date_line_num_tag, "Check Header Date Line No.","conf"); 
my %index=&get_index(\@all_lines,$line_num);
	
	foreach my $ind (sort keys %index)
	{
	my $feed_line=$all_lines[$ind];
	&writeLog("info","$info  (Line No. $index{$ind}) : -->$feed_line<--");							   
	#print "----$date_regex----\n";	
		if($feed_line=~ /($date_regex)/i)
		{
		$date_calc=$1;
		}
		else
		{
		$date_calc=$feed_line;
		}

		&writeLog("info","$info         (Actual) : $date_calc");

		if($date_calc eq $date)
		{
		&writeLog("info","$info \"$date_calc\" is (Good) Passed...");
		&append_mail_body("$info Check",'OK',"Actual ($date_calc) Vs Expected ($date)");
		}
		else
		{
		&writeLog("err","$info is \"$date_calc\" (Bad) Failed...");
		&append_mail_body("$info Check", 'Failed',"Actual ($date_calc) Vs Expected ($date)");
		&exit_prog(111);
		}
	}
return;
}

#####################################################################

=head 

This Subroutine checks all the line of feed with escape line and matching string given 

Arguments:

1. $all_lines (reference of @all_lines)
2. $index_hash (Hash Reference which contains all escape line index number)
3. $chk_line_regex (Regular Expression to match lines)
4. $case  (Case Sensitivity while matching lines) 
5. $type (escape)

=cut
	

sub chk_all_feed_lines
{
my ($all_lines, $index_hash,$chk_line_regex, $case,$type,$escape_line_regex)=@_;
$type=&trim(lc($type));
my $count=0;
my $count_print=1;
my @error_line=();
my @all_lines=@{$all_lines};
my %index_hash=%{$index_hash};
#print "($all_lines, $index_hash,$chk_line_regex, $case,$type,--$escape_line_regex==)\n";

	foreach my $line (@all_lines)
	{
		if(defined $index_hash{$count} && $type eq 'escape')
		{
		&writeLog("info","Escaping (Line No. $index_hash{$count}) : -->$line<--");
		$count++;
		$count_print++;
		next;
		}

		if(defined $escape_line_regex && $escape_line_regex ne "")
		{
			if($line=~ /$escape_line_regex/)
			{
			&writeLog("info","Escaping (Line No. $count) : -->$line<--");
			$count++;
			$count_print++;
			next;
			}
		}
		
		if(defined $index_hash{$count} && $type eq 'only_match')
		{
		&writeLog("info","Matching Line $index_hash{$count} -->$line<--");
			if($case eq 'y')
			{
				unless($line =~ /$chk_line_regex/)
				{
				push(@error_line,"Error in (Line No. $count_print) -->$line<--"); 
				}
			}
			else
			{
				unless($line =~ /$chk_line_regex/i)
				{
				push(@error_line,"Error in (Line No. $count_print) -->$line<--"); 
				}
			}
		}

		if($type eq 'escape')
		{
			if($case eq 'y')
			{
				unless($line =~ /$chk_line_regex/)
				{
				push(@error_line,"Error in (Line No. $count_print) -->$line<--"); 
				}
			}
			else
			{
				unless($line =~ /$chk_line_regex/i)
				{
				push(@error_line,"Error in (Line No. $count_print) -->$line<--"); 
				}
			}
		}
	$count++;
	$count_print++;
	} 

return @error_line;
}

#####################################################################
=head 

This Subroutine gets the Value of the cheker tag provided 

Arguments:

1. $comp_feed (feed name without prefix and postfix)
2. $chk_tag (tag name)
3. $info (information to print)
4. $type (conf | any  String) to print. 
5. $type_print (date_type_print) to print curent date or bussiness date (optional) 

=cut

sub get_xml_conf_value
{
my ($comp_feed,$chk_tag,$info, $type,$type_print)=@_;
#print "---$comp_feed,$chk_tag,$info, $type,$type_print--\n";

my $val;
my $log_type;

	if($type=~/conf/i)
	{
	$log_type='conf' ;
	}
	else
	{
	$log_type='info';
	}

$type=ucfirst(lc($type));
$type="(".$type.")";


	if(defined $CONF{$comp_feed}{$chk_tag})
	{
	$val=$CONF{$comp_feed}{$chk_tag};
		if(defined $type_print && $type_print eq 'date_type_print')
		{		
		my $t_print=&date_type($CONF{$comp_feed}{$chk_tag});
		&writeLog($log_type,"$info $type : $val $t_print");
		}
		else
		{
		&writeLog($log_type,"$info $type : $val");
		}
	}
	else
	{
	&writeLog("err","Not defined $info $type : $comp_feed -> $chk_tag");
	&writeLog("info", "Please Set Configuration Information on $config");
	&append_mail_body("Not defined $info $type : $comp_feed -> $chk_tag");
	&exit_prog(101);
	}
return $val; 
}

#####################################################################

=head 

This Subroutine checks whether the file exists on the disck or not

Arguments:

1. $feed_name (Actual feed name with pre-post fix)
2. $type (this_day | prev_day)

=cut

sub file_exist
{
my ($feed_name, $type)=@_;
$type=&trim(lc($type));
my $feed_type;	
	if(-f $feed_name)
	{
	my $ls_lrt=get_year_month_date_time($feed_name);
	&writeLog("info","Feed Found on the Disk : $feed_name");
	&writeLog("info","Feed on Disk : $ls_lrt");
		if($type eq 'this_day')
		{
		$feed_type="Current";
		$feed_name_actual_ls_lrt=$ls_lrt;
		}
		elsif($type eq 'prev_day')
		{
		$feed_prev_name_actual_ls_lrt=$ls_lrt;
		}	
	}
	else
	{
	$feed_type="Previous Day's" if($type eq 'prev_day');
	$feed_type="Current" if($type eq 'this_day');

	&writeLog("warn","No such file on the Disk [$feed_type] : $feed_name");
	&append_mail_body("No such file on the Disk [$feed_type] : $feed_name");
	&exit_prog(112);
	}
return;
}

#####################################################################

=head 

This Subroutine trims pre-post white Spaces/new line from the string

Arguments:

1. $var (input String)

=cut

sub trim
{
my ($var)=@_;
return unless (defined $var);
$var=~s /^\s+|\s+$//g;
return $var;
}


#####################################################################
=head 

This Subroutine parses the xml config file (start tag)

Arguments:

1. $parseinst (class reference) 
2. $element	(xml tag of interest)
3. %attrs (all xml tags from config and it's values) 

=cut
 
sub startElement
{
my ($parseinst, $element, %attrs) = @_;
my $count_key=scalar(keys %attrs);
$element=&trim($element);
$element=lc($element);
$xml_element=$element;

	if($count_key != 0)
	{
		foreach my $check_attr (keys %attrs)
		{
		$check_attr=lc($check_attr);
			if($check_attr ne 'check')
			{
			&writeLog("err","Wrong Tag : $feed_name->$element->$check_attr");
			&writeLog("info", "Please Set Configuration Information on $config");
			&append_mail_body("Wrong Tag : $feed_name->$element->$check_attr");
			&exit_prog(101);
			}
		$CHECKS{$feed_name}{$element}{$check_attr}=&trim(lc($attrs{$check_attr}));
		} 
	}
}


#####################################################################
=head 

This Subroutine parses the xml config file (values of tag)

Arguments:

1. $parseinst (class reference) 
2. $data (tag of interest)

=cut

sub characterData
{
my( $parseinst, $data ) = @_;
$data=&trim($data);
	if($data ne '')
	{
		if($xml_element	eq 'feed_name')
		{
		$feed_name=$data;
		$FEED_NAME{$data}=1;
		}
		else
		{
		$CONF{$feed_name}{$xml_element}=$data;
		}
	}
}
#####################################################################
=head 

This Subroutine parses the xml config file	(end tag)

Arguments:

1. $parseinst (class reference) 
2. $element (tag of interest)

=cut

sub endElement
{
my( $parseinst, $element ) = @_;
$element =&trim($element);
}

#####################################################################
=head 

This Subroutine parses the xml config file	escape lines (Comment lines new lines)

Arguments:
1. $parseinst (class reference) 
2. $element (tag of interest)

=cut

sub default
{
my( $parseinst, $data) = @_;
#print "====$data======\n";
}

#####################################################################
=head 

This Subroutine returns the directory name and the file name of given file name having absolute path

Arguments:
1. $feed (feed name with absolute path) 

=cut

sub get_dir_filename
{
my ($feed)=@_;
my $dir=`dirname $feed`;
chomp $dir;

my $file_name=`basename $feed`;
chomp $file_name;

return ($dir, $file_name);
}


#####################################################################
=head 

This Subroutine returns feed Properties like below: 
Ex: Feed Properties : -rw-rw-r--  1 pvmuser primus 74450 2009-11-17 20:13:55 /ppb/data/LATEST/Prices/sobratePrices.dat.20091117

Arguments:

1. $feed_name (Actual feed name with pre-postfix)

=cut


sub get_year_month_date_time
{
my ($feed_name)=@_;
my $str=`ls -lrt $feed_name`;
chomp $str;

#drwxr-xr-x   2 ssahu    asp           96 Dec 13  2007 MirrorUp
#drwxrwxr-x   2 tricom tricom 4096 2007-03-29 20:26 MirrorUp_current_week

my %month=(	'Jan' => '01', 'Feb' => '02', 'Mar' => '03',
			'Apr' => '04', 'May' => '05', 'Jun' => '06',
			'Jul' => '07', 'Aug' => '08', 'Sep' => '09',
			'Oct' => '10', 'Nov' => '11', 'Dec' => '12'
		);

my @arr_for_index=split(/\s+/,$str);
my $index=scalar(@arr_for_index);
	
my @arr_for_file_name=split(/\s+/,$str,9);
my $file_name=pop(@arr_for_file_name);

my $rev=reverse($str);
my $num_split=($index-9)+5;
my @attr=split(/\s+/,$rev,$num_split);
	
my $file_initial_attr=reverse(pop(@attr));
$file_initial_attr=~ s/\d+$//g;
	

	my $file_name_with_path=$file_name;
	my %attr_hash;

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
		$mtime,$ctime,$blksize,$blocks)=stat("$file_name_with_path");

	my $now = ctime($mtime);
	#Thu May  8 03:42:15 2008
	my ($year, $month, $day, $time);
		if($now=~ /^\w{3}\s+(\w{3})\s+(\d+)\s+(\d{2}:\d{2}:\d{2})\s+(\d{4})/)
		{
		$month=$month{$1};
		$day=sprintf("%02d", $2);
		$time=$3;
		$year=$4;
		}
	my $timestamp=$year."-".$month."-".$day." ".$time;

	#drwxr-xr-x   2 ssahu    asp           96 Dec 13  2007 MirrorUp
	#print "##$file_initial_attr==$size##$timestamp==$file_name##\n";

	my $ls_lrt_str=$file_initial_attr."$size $timestamp".' '.$file_name_with_path;
	#print "$ls_lrt_str\n";

return $ls_lrt_str;
}

#####################################################################
=head 

This Subroutine returns "file size in bytes", "date" and "time stamp" of the given input like below: 
-rw-rw-r--  1 pvmuser primus 74450 2009-11-17 20:13:55 /ppb/data/LATEST/Prices/sobratePrices.dat.20091117

Arguments:

1. $file (Actual feed name with pre-post fix)

=cut

sub get_file_attr
{
my ($file)=@_;
my ($dir_and_perm,$links_file,$owner,$group,$file_size_byte,$date,$time_stamp,$file_name)=split(/\s+/,$file,9);
#print "dr:$dir_and_perm,ln:$links_file,ow:$owner,gr:$group,si:$file_size_byte,dt:$date,ti:$time_stamp,fi:$file_name\n";
return ($file_size_byte,$date,$time_stamp);
}

#####################################################################
=head 

This Subroutine whether date type provided is Bussness date or Current date

Arguments:

1. $str (cur_date... | bus_date...)

=cut

sub date_type
{
my ($str)=@_;
$str=&trim(lc($str));
my $var;
	if($str=~/cur_date/i)
	{
	$var='(Current Date)';
	}
	elsif($str=~/bus_date/i)
	{
	$var='(Bussiness Date)';
	}
	else
	{
	$var='(Invalid Date Type)';
	}
return $var;
}

#####################################################################

=head
Calculates the Duration.

input string :
key1 : Start date   => value1 : YYYY-MM-DD hh:mm:ss
key2 : End date     => value2 : YYYY-MM-DD hh:mm:ss

returns :
days, hours, min, and sec.

=cut

sub time_taken (%) {
	my %args = @_;
	my @offset_days = qw(0 31 59 90 120 151 181 212 243 273 304 334);

	my $year1  = substr($args{'date1'}, 0, 4);
	my $month1 = substr($args{'date1'}, 5, 2);
	my $day1   = substr($args{'date1'}, 8, 2);
	my $hh1    = substr($args{'date1'},11, 2) || 0;
	my $mm1    = substr($args{'date1'},14, 2) || 0;
	my $ss1    = substr($args{'date1'},17, 2) if (length($args{'date1'}) > 16);
	   $ss1  = 0 unless (defined $ss1);
#print "$args{'date1'}\n";
#print "---$year1--$month1--$day1--$hh1--$mm1--$ss1--\n";

	my $year2  = substr($args{'date2'}, 0, 4);
	my $month2 = substr($args{'date2'}, 5, 2);
	my $day2   = substr($args{'date2'}, 8, 2);
	my $hh2    = substr($args{'date2'},11, 2) || 0;
	my $mm2    = substr($args{'date2'},14, 2) || 0;
	my $ss2    = substr($args{'date2'},17, 2) if (length($args{'date2'}) > 16);
	   $ss2  = 0 unless (defined $ss2);
#print "---$year2--$month2--$day2--$hh2--$mm2--$ss2--\n";

	my $total_days1 = $offset_days[$month1 - 1] + $day1 + 365 * $year1;
	my $total_days2 = $offset_days[$month2 - 1] + $day2 + 365 * $year2;
	my $days_diff   = $total_days2 - $total_days1;

	my $seconds1 = $total_days1 * 86400 + $hh1 * 3600 + $mm1 * 60 + $ss1;
	my $seconds2 = $total_days2 * 86400 + $hh2 * 3600 + $mm2 * 60 + $ss2;

	my $ssDiff = $seconds2 - $seconds1;

	my $dd     = int($ssDiff / 86400);
	my $hh     = int($ssDiff /  3600) - $dd *    24;
	my $mm     = int($ssDiff /    60) - $dd *  1440 - $hh *   60;
	my $ss     = int($ssDiff /     1) - $dd * 86400 - $hh * 3600 - $mm * 60;

$dd=sprintf("%02s",$dd);
$hh=sprintf("%02s",$hh);
$mm=sprintf("%02s",$mm);
$ss=sprintf("%02s",$ss);

return ($dd, $hh, $mm , $ss);
}

#####################################################################

=head 

This Subroutine displayes the Usage information about the script

=cut

sub usage
{
print STDERR "\nUsage:\n\n$0 : Checks Feeds Version $VERSION...\n";
print STDERR "$0 <cdefhpvw>\n\n";
print STDERR "Example $0 -f <Feed Name> [<-f> Mandatory]\n";
print STDERR "Example $0 -f <Feed Name> -d <Bussiness Date> -c <Config File> -p <Prefix Feed> -e <holiday_file>\n";
print STDERR "\n[Note: Prefix is Mandatory if config info is Applicable for Multiple Feeds]\n\n";

print STDERR "-c : Configuration File  [/absolute_path/config_file_name]\n";
print STDERR "-d : Run Date            [YYYYMMDD]\n";
print STDERR "-e : Escape Holiday File [/absolute_path/holiday_file_name]\n";
print STDERR "-f : Check Feed Name     [/absolute_path/feed_name (without Pre/Post Fix)]  [Mandatory Option]\n";
print STDERR "-p : Prefix Feed         [Have to supply Prefix for Feed if config (.xml) is defined for multiple feeds]\n";
print STDERR "-w : Feed Compare Write to file Flag\n";
print STDERR "-v : Version and Help\n";
print STDERR "-h : Help\n";

print STDERR "\n";

exit(3);
}

#####################################################################

=head 

This Subroutine write master log file

Arguments:

1. $log_type [prefix the messasge type](info | dum |err | conf)  [ dum-> prefixes nothing)
2. $message (printing messaxge) 

=cut


sub writeLog
{
my($log_type, $message) = @_;

my $TimeStamp=`date +[%Y-%m-%d' '%H:%M:%S]`;
chomp $TimeStamp;
	
$log_type='<INFO>' if($log_type=~/info/i);
$log_type='<WARN>' if($log_type=~/warn/i);
$log_type='<ERROR>' if($log_type=~/err/i);
$log_type='<CONF>' if($log_type=~/conf/i);
$log_type='' if($log_type=~/dum/i);

my $message_bkp = $log_type." ".$message;

$message = $TimeStamp." ".$log_type." ".$message;
$log_dump .="$message\n";

	if($debug==1)
	{
	print STDOUT "$message\n";
	}

print logFH "$message\n";

return;
}
# End of write to log module

#####################################################################

=head 

This Subroutine retuns the hash having index number of the array to be used for checking records

Arguments:

1. $array (reference of the array)
2. $chk_line_num (1,2... | L , L-1...) 

=cut

sub get_index
{
my ($array,$chk_line_num)=@_;
my @num=split(/\,/,$chk_line_num);
my $total_lines=scalar(@{$array});

my %arr_index=();

	foreach my $li_n (sort @num)
	{
	$li_n=&trim(uc($li_n));
		if($li_n=~ /l-(\d+)/i)
		{
		my $last=$1;
		$last++;
		my $index=$total_lines-$last;
		$arr_index{$index}=$li_n; 	
		}
		elsif($li_n=~ /^l$/i)
		{
		my $last=1;
		my $index=$total_lines-$last;
		$arr_index{$index}=$li_n;
		}
		elsif($li_n=~ /^(\d+)$/i)
		{
		my $index=$1;
		$index--;
		$arr_index{$index}=$li_n;
		}
 	}
return %arr_index;
}


#####################################################################

=head 

This Subroutine sends e-mail

Arguments:

1. $feed_name_actual (Actual feed name with pre-post fix)
2. $comp_feed  (feed name without pre-post fix)
3. $tag	(Checker tag) 

=cut


sub send_email
{
my ($feed_name_actual, $comp_feed, $tag)=@_;

	if($tag eq 'feed_check_email')
	{
	my $info='Send E-mail';
	
	my $mail_always=&get_xml_conf_value($comp_feed, 'send_email_always', "$info Always          ","conf");
	$mail_always=uc($mail_always);
	
	my $mail_chk_fail=&get_xml_conf_value($comp_feed, 'send_email_when_fail', "$info when Check Fails","conf");
	$mail_chk_fail=uc($mail_chk_fail);
	my $fail_flg=0;

		if($mail_chk_fail eq 'Y')
		{
			if($mail_body=~/fail|exit\s+code/i)
			{
			$fail_flg=1;
			}
			else
			{
				if($mail_always eq 'N')
				{
				&writeLog('info',"No Feed Checks Failed (Not Sending E-mail)");
				}
			}
		}

		if($fail_flg==1 || $mail_always eq 'Y')
		{
		my $mail_sub=&get_xml_conf_value($comp_feed, 'feed_check_email_subject', "$info Subject         ","conf");
	
		$mail_sub .=" $feed_name_actual";
		my $mail_to=&get_xml_conf_value($comp_feed, 'feed_check_email_to', "$info TO              ","conf");
		my $mail_cc=&get_xml_conf_value($comp_feed, 'feed_check_email_cc', "$info CC              ","conf");
	
		$mail_cc="" if(!defined $mail_cc);
		$mail_cc="" if($mail_cc=~ /__na__|^\s*$|^\s*na\s*$|^\s*n\s*\/\s*a\s*$/i);
		my $cc;

my $mail_body_f="Hi,\n\nPlease find the Feed Check Summary of $feed_name_actual\n\n".$mail_body;


my $feed_log=&get_feed_log_name($feed_name_actual);

$mail_body_f .="

For More Details Please Refer the Below Log Files : 
Master Log File  (All Feeds) : $log
Feed Log file (Current Feed) : $feed_log  



Thanks & Regards,
Sanjog Sahu

Note: This is an Auto-generated E-mail, Please Do Not Reply.

EOF";
#&writeLog('info',"Mail Subject : $mail_sub");
#&writeLog('info',"\n--------------------- MAIL BODY ---------------------\n$mail_body\n--------------------- MAIL END ----------------------\n");

			if($mail_cc eq "")
			{
			$cc=system("mailx -s \'$mail_sub\' $mail_to <<EOF\n$mail_body_f");
			}
		    else
			{
			$cc=system("mailx -s \'$mail_sub\' -c $mail_cc $mail_to <<EOF\n$mail_body_f");
			}
		
			if($cc != 0)
			{
			&writeLog('err', "Sending mail Failed!");
			&exit_prog(115);
			}
			else
		    {
			&writeLog('info',"Sending mail Successful...");
			}
		}
	}
		
return;
}

#####################################################################

=head 

This Subroutine creates the e-mail Body	(appending mode)

Arguments:

1. $msg (message to append in the body)
2. $status (OK | Failed)
3. $info	(information regarding feed) 

=cut

sub append_mail_body
{
my ($msg,$status,$info)=@_;

$status=''	unless(defined $status);
$info=''	unless(defined $info);

	if($status ne '')
	{
	$status=": $status";
	$status=sprintf("%-8s",$status);
	}	

	if($info ne '')
	{
	$info='['.$info.']';
	}

my $len=length($msg);
	if($len < 31)
	{
	$msg=sprintf("%-30s",$msg);
	}

my $mail_line="$msg $status $info";				
$len=length($mail_line);

	if($len < 61)
	{
	$mail_line=sprintf("%-60s",$mail_line);
	}
	
	if($mail_line=~/^Exit/i)
	{
	$mail_line="\n".$mail_line;
	}

$mail_body .=$mail_line."\n";  
	
return;
}		

#####################################################################

=head 

This Subroutine get all valid prefixes provided in the config file in a hash)

Arguments:

1. $str (feed prefix string)
2. $delim (delimitter used to separate the pre fixes of feed in the config file)

=cut

sub get_hash
{
my ($str,$delim)=@_;
my %hash;
$delim='\|' if ($delim eq '|');


my @elem=split(/$delim/,$str);

	foreach my $ll (@elem)
	{
	$ll=&trim($ll);
	next if ($ll eq '');
	$hash{$ll}=$str;
	}

return %hash;
}

#####################################################################

=head 

This Subroutine generates unique string using the absolute path of the feed

Arguments:

1. $feed_dir (actual feed name with pre-postfix)

=cut

sub generate_feed_dirname
{
my ($feed_dir)=@_;
my @dirs=split(/\//, $feed_dir);
my $name="";

my $num=scalar(@dirs);

	if($num==0)
	{
	$name="su_root";
	}
	else
	{
		shift @dirs;
		my $back_dir=pop(@dirs);
		foreach my $na (@dirs)
		{
		#print "###$na###\n";
		my $sub_name=substr($na, 0, 4);
		$name .=$sub_name."_";
		}
	$name .=$back_dir;
	}

return $name;
}
#####################################################################

=head 

This Subroutine generates unique feed log name

Arguments:

1. $feed_name (actual feed name with pre-postfix)

=cut


sub get_feed_log_name
{
my ($feed_name)=@_;
my ($dir, $file)=&get_dir_filename($feed_name);
my $feed_dir_name=&generate_feed_dirname($dir);
my $date=`date +%Y%m%d`;
chomp $date;
my $feed_log=$log_path."/$feed_dir_name"."_$file".".log.".$date;
return $feed_log;
}
#####################################################################
=head 

This Subroutine generates unique feed log file (contains only current feed check information)

Arguments:

1. $feed_log (log for individual feed)

=cut

sub generate_feed_log
{
my ($feed_log)=@_;

open (logFEED,">$feed_log") or die "Cannot open file $feed_log for writing: $!";
print logFEED "$log_dump";
close logFEED;
$log_dump='';
return;
}

#####################################################################
=head 

This Subroutine shows the summary of all checks

=cut

sub show_summary
{
&writeLog('info',"\nFeed Checks\n============\n\n$mail_body\n");
$mail_body='';
return;
}
#####################################################################

=head 

This Subroutine exits the programe by displaying  the proper reason of exit)
Also handles the loging , email and summary of check

Arguments:
$exit_code (input exit code)

=cut

sub exit_prog
{
my ($exit_code)=@_;
my $feed_log;
	if(defined $error_code_desc{$exit_code})
	{
	&writeLog('info',"Exit Code ($exit_code) Description : $error_code_desc{$exit_code}");
	&append_mail_body("Exit Code ($exit_code) Description : $error_code_desc{$exit_code}");
	&writeLog('dum',"");
		
		if($exit_code ne '1' && $exit_code ne '100' && $exit_code ne '101' && $CHECKS{$comp_feed}{'feed_check_email'}{'check'} eq 'y')
		{
		&send_email($feed_name_actual, $comp_feed, 'feed_check_email');
		}
	}
	else
	{
	&writeLog('info',"Exit Code ($exit_code) Description Not Defined\n");
	}

&show_summary();
close logFH;

	if($exit_code ne '1' && $exit_code ne '100' && $exit_code ne '101')
	{
	$feed_log=&get_feed_log_name($feed_name_actual);
	&generate_feed_log($feed_log);
	}

print "Master Log File  (All Feeds) : $log\n";
	if(defined $feed_log)
	{
	print "Feed Log File (Current Feed) : $feed_log\n";  
	}

print "\n";
exit($exit_code);
}



#####################################################################

=head 

This Subroutine Alerts by sending e-mail and displaying  the proper reason of failure)
Also handles the loging , email and summary of check

Arguments:
$exit_code (input exit code)

=cut

sub alert_chkfail
{
my ($exit_code)=@_;
my $feed_log;
	if(defined $error_code_desc{$exit_code})
	{
	&writeLog('info',"Fail Code ($exit_code) Description : $error_code_desc{$exit_code}");
	&append_mail_body("Fail Code ($exit_code) Description : $error_code_desc{$exit_code}");
	&writeLog('dum',"");
		
		if($exit_code ne '1' && $exit_code ne '100' && $exit_code ne '101' && $CHECKS{$comp_feed}{'feed_check_email'}{'check'} eq 'y')
		{
		&send_email($feed_name_actual, $comp_feed, 'feed_check_email');
		}
	}
	else
	{
	&writeLog('info',"Exit Code ($exit_code) Description Not Defined\n");
	}

&show_summary();

	if($exit_code ne '1' && $exit_code ne '100' && $exit_code ne '101')
	{
	$feed_log=&get_feed_log_name($feed_name_actual);
	}

print "Master Log File  (All Feeds) : $log\n";
	if(defined $feed_log)
	{
	print "Feed Log File (Current Feed) : $feed_log\n";  
	}

print "\n";
}



#####################################################################
=head 

This Subroutine checks xml tags exists or not 

Arguments:

1. $feed (feed name)
2. $chk_tag (tag name)
&check_xml_tag_exist($hash,$feed,'feed_column_name_line_num')
=cut

sub check_xml_tag_exist
{
my ($hash,$comp_feed,$chk_tag)=@_;

my %HASH=%{$hash};

my $val;
	if(defined $HASH{$comp_feed}{$chk_tag})
	{
	return 1;
	}
	else
	{
	return 0;
	}
}

