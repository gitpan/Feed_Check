#!/bin/env perl

use strict;
use Data::Dumper;
use Getopt::Std;
use vars qw(%opts);

my $VERSION='1.0.0';

$|=1;

=information

Author                  : Sanjoga Sahu.
Date of Modification    : 21st, Mar, 2013. (v1.0.0)
                          
                          21st, Mar, 2013
Operating System(s)     : Linux

Description             : Wrapper for Check feed script.

Execution Method        : 

run_chk_feeds.pl -d 20100222 -r ASIA -y USD
run_chk_feeds.pl -d 20100218 -l /ppb/data/LATEST/historical_vols/ASIA
run_chk_feeds.pl -d 20100219 -l /path/ASIA -x/path/cfg/HV_ASIA_AMER/ -s/path/chk_feeds.pl -k/path/ -c/path/cfg/run_chk_feeds.cfg

Example command: run_chk_feeds.pl -c run_chk_feeds.cfg -d 20141016 -r RISKCO_NA -s /script/location/chk_feeds.pl -x /config/location
                 run_chk_feeds.pl -c run_chk_feeds.cfg -d 20141016 -r RISKCO_NA   --- best use
#__IMP__ : Chnage where neccesary


=cut

#####################################################################
#Defining Variables 

getopts('c:d:e:l:k:r:s:x:y:wh', \%opts);

&usage() if($opts{h});

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


my %LOCK_SU;
my %LOCK_SK;
my %LOCK_SK_MAN;
my %LOCK_FA;
my %LOCK_RU;
my %LOCK_SP;

my ($escape_holiday,$location,$region,$currency,$date,$write_to_file_flg);

$write_to_file_flg=0;

	$location=$opts{l} if($opts{l});
	$region=$opts{r} if($opts{r});
	usage()	unless(defined $region || $location);
	unless($opts{d}){ usage(); } else {	$date=$opts{d};	}
	$currency=$opts{y} if($opts{y});
	$config_file=$opts{c} if($opts{c});
	$lock_file_loc=$opts{k} if($opts{k});
	$xml_loc=$opts{x} if($opts{x});
	$chk_script=$opts{s} if($opts{s});
	$escape_holiday=$opts{e} if($opts{e});
	$write_to_file_flg=$opts{w} if($opts{w});

	if(defined $escape_holiday)
	{
		unless(-f $escape_holiday)
		{
		print "Holoday File ($escape_holiday) Not Found!\n";
		&usage();
		}
	}

	if(defined $location)
	{
	$location=~ s|/$||g;
	&check_dir_exist($location,"Feeds Directory");
	}

$xml_loc=~ s|/$||g;
&check_dir_exist($xml_loc,"Feeds Config XML Directory");

	unless(-f $chk_script)
	{
	print "Check Script Not Found!\n";
	&usage();
	}
	
$lock_file_loc=~ s|/$||g;
&check_dir_exist($lock_file_loc,"Lock File Directory");

my $lock_file=$lock_file_loc."/lock_file";

	if(defined $location)
	{
	my $loc=$location;
	$loc=~ s|/|_|g;
	$loc=~ s/^_|_$//g; 
	$lock_file .="_".$loc;
	}
	if(defined $region)
	{
	my $reg_u=uc($region);
	$lock_file .="_".$reg_u;
	}
	if(defined $currency)
	{
	my $cur_u=uc($currency);
	$lock_file .="_".$cur_u;
	}

	$lock_file .=".".$date;

print "Feed Location : $location\n" if(defined $location);
print "Feed Region   : $region\n" if(defined $region);
print "Run Date      : $date\n";
print "Lock File     : $lock_file [Remove the lock file for a Fresh Run]\n";
print "Config File   : $config_file\n";


my %CONFIG;

	if(-f $config_file)
	{
	print "\nReading Configuration Information...\n";
	%CONFIG=&read_config($config_file, $location,$region,$currency,$date,$xml_loc,$chk_script);
	print "Reading Configuration Information done.\n";
	}
	else
	{
	print "\nConfiguration File Not Found!\n\n";
	&usage();
	}

my @con=(sort {$a<=> $b} keys %CONFIG);
my $tot=scalar(@con);
my $stp_fst=shift(@con);
my $stp_lst=pop(@con);
$stp_lst=$stp_fst	if(!defined $stp_lst);
																
print "\nScheduled to Execute [Step $stp_fst To Step $stp_lst] --> $tot No(s).\n"; 
my $lock_flg=0;
my $abnor_flg=0;

	if(-f $lock_file)
	{
	print "\nLock File Found...\n";
	my $any_step=&read_lock_file($lock_file);
		if($any_step !=0)
		{
	 	$lock_flg=1;
		my @lock=(sort {$a<=>$b} keys %LOCK_RU);
		my @stop=(sort {$a<=>$b} keys %LOCK_SP);

		my $chk_step=pop(@lock);
		my $chk_stop=pop(@stop);
		my $skk=scalar(keys %LOCK_SK);
		
		print "Lock File will be used for Further Processing...\n";
		
		print "Step : ($chk_step) [Process will be Started from $chk_step Onwards as per Lock File]\n" if(defined $chk_step);
		print "Step : ($chk_stop) [Process will be Stopped as per Lock File]\n" if(defined $chk_stop);
			if($skk > 0)
			{
			my ($sss,$cn)=&get_comm_sep(\%LOCK_SK);
			print "Step : ($sss) [Process will be Skipped as per Lock File] --> $cn No(s).\n" ;
			}

		open (LOCK,">>$lock_file") || die "can't open for appending $lock_file : $!\n";
	
			foreach my $ct (sort {$a <=> $b} keys %CONFIG)
			{
				if(defined $LOCK_SU{$ct})
				{
				print "\nSkipping   : Step : $ct : $LOCK_SU{$ct}\n";
				next;
				}
				elsif(defined $LOCK_SK{$ct})
				{
				print "\nSkipping   : Step : $ct : $LOCK_SK{$ct}\n";
				next;
				}
				elsif(defined $chk_stop && $chk_stop == $ct)
				{
				$abnor_flg=1;
				print "\nStopping   : Step : $ct : [Stop at Process as per Lock File]\n";
				last;
				}
				elsif(defined $chk_step && $chk_step > $ct)
				{
				$abnor_flg=1;
				$LOCK_SK_MAN{$ct}="[Process from $chk_step Onwards as per Lock File]";
				print "\nSkipping   : Step : $ct : [Process from $chk_step Onwards as per Lock File]\n";
				next;
				}
			&execute_step($ct,$CONFIG{$ct});
			}
		close LOCK;
		}
		else
		{
		print "\nNo Good information Found in the Lock File...\n";
		print "Lock File will Not be used for Further Processing...\n";
		my $dd=system("rm -rf $lock_file");
			if($dd eq '0')
			{
			print "SUCCESS: Deleting Old Lock File : $lock_file\n";
			}
			else
			{
			print "FAILED: Deleting Old Lock File : $lock_file\n";
			print "\nLock File : $lock_file [Remove the lock file for a Fresh Run]\n\n";
			exit(11);
			}
		}		
	}
	else
	{
	print "\nLock File Not found...\n";
	}

	if($lock_flg==0)
	{
	print "Creating New Lock File and will Start a Fresh Processing...\n";
	
	open (LOCK,">$lock_file") || die "can't open for writing $lock_file : $!\n";
	
	print LOCK "#Feed Location : $location\n" if(defined $location);
	print LOCK "#Feed Region   : $region\n" if(defined $region);
	print LOCK "#Run Date      : $date\n";
	print LOCK "#Lock File     : $lock_file\n";
	print LOCK "#Config File   : $config_file\n";
	print LOCK "#Example 1: [Step : 110 : skip] --> Skips the particular Step 110\n";
	print LOCK "#Example 2: [Step : 115 : start] --> Skips upto 114 and starts from 115 Step\n";
	print LOCK "#Example 3: [Step : 120 : stop] --> Stops at step 120\n";

	#print "\nFeeds to Process as Per Config:\n";
		foreach my $cnt (sort {$a<=>$b} keys %CONFIG)
		{
		&execute_step($cnt,$CONFIG{$cnt});
		}
	close LOCK;
	}


print "\n-------------------- SUMMARY --------------------\n";
%LOCK_SU=();
%LOCK_SK=();
%LOCK_FA=();
%LOCK_RU=();
my %pend;
my %compl;

my $ll=&read_lock_file($lock_file);
	
	my $count_p=1;
	my $count_c=1;
	foreach my $stp (sort {$a<=>$b} keys %CONFIG)
	{
		if(!defined $LOCK_SU{$stp})
		{
		$pend{$stp}=1	
		}
		else
		{
		$compl{$stp}=1;	
		}
	}

my $su=scalar(keys %compl);
my $fa=scalar(keys %LOCK_FA);
my $ru=scalar(keys %LOCK_RU);
my $sk=scalar(keys %LOCK_SK);
my $skm=scalar(keys %LOCK_SK_MAN);
my $sp=scalar(keys %LOCK_SP);
my $pn=scalar(keys %pend);

	if($fa == 0 && $ru ==0 && $pn==0 && $abnor_flg==0)
	{
	print "\nProcessing of All the Steps Completed\n";
		
		if($su > 0)
		{
		my ($suu,$cn)=&get_comm_sep(\%compl);
		print "Completed :: Step : [$suu] --> $cn No(s).\n";
		}

		if($sk >0)
		{
		my	($fff,$cn)=&get_comm_sep(\%LOCK_SK);
		print "Skipped   :: Step : [$fff] --> $cn No(s).\n";
		}
	
	my $dd=system("rm -rf $lock_file");
			if($dd eq '0')
			{
			print "\nDeleting Lock File [SUCCESS] : $lock_file\n";
			print "Exiting Normally...\n";
			print "\n---------------------- END ----------------------\n\n";
			exit(0);
			}
			else
			{
			print "\nDeleting Lock File [FAIL] : $lock_file\n";
			print "\nLock File : $lock_file [Remove the lock file for a Fresh Run]\n\n";
			exit(18);
			}
	}
	else
	{
	print "\nProcessing of All the Steps NOT Completed\n";
		if($su > 0)
		{
		my ($suu,$cn)=&get_comm_sep(\%compl);
		print "Completed :: Step : [$suu] --> $cn No(s).\n";
		}

		if($fa >0)
		{
		my ($fff,$cn)=&get_comm_sep(\%LOCK_FA);
		print "Failed    :: Step : [$fff] --> $cn No(s).\n";
		}
		if($sk >0)
		{
		my ($kkk,$cn)=&get_comm_sep(\%LOCK_SK);
     	print "Skipped   :: Step : [$kkk] --> $cn No(s).\n";
		}
		
		if($skm >0)
		{
		my @all_skm=sort {$a<=>$b} keys %LOCK_SK_MAN;
		my $fst=shift(@all_skm);
		my $lst=pop(@all_skm);
		$lst=$fst	if(!defined $lst);
		print "Skipped   :: Step : $fst to $lst $LOCK_SK_MAN{$fst}\n";
		}

		if($sp >0)
		{
		my ($sss,$cn)=get_comm_sep(\%LOCK_SP);
		print "Stopped   :: Step : [$sss] --> $cn No(s).\n";
		}
		if($pn > 0)
		{
		my ($ppx,$cn)=&get_comm_sep(\%pend);
		print "pending   :: Step : [$ppx] --> $cn No(s).\n";
		}
	print "\nNOT Deleting Lock File : $lock_file [Remove the lock file for a Fresh Run]\n";
	print "\n---------------------- END ----------------------\n\n";
	exit(21);
	}
		
#__END__

#####################################################################

sub execute_step
{
my ($step,$comm)=@_;

	if($write_to_file_flg)
	{
	$comm="$comm -w";
	}
print "\nProcessing : Step : $step : $comm\n";
print LOCK "\n#Step : $step : $comm\n";
print LOCK "Step : $step : START\n";
my $res;
$res=system("$comm");
	
	if($res >= 256)
	{
	$res=$res/256;
	}

	if($res eq '0')
	{
	print LOCK "Step : $step : SUCCESS\n";
	print "Step : $step : SUCCESS\n";
	}
	else
	{
	print LOCK "Step : $step : FAIL\n";
	print "\nStep : $step : FAILED --> Exit Code [$res]\n\nLock File : $lock_file [Remove the lock file for a Fresh Run]\n\n";
	exit($res);
	}
return;
}

#####################################################################

sub get_comm_sep
{
my ($hash)=@_;
my %hash=%{$hash};
my $str="";	
	my $count=0;
	foreach my $pp (sort {$a<=>$b} keys %hash)
	{
	$str .="$pp ,";
	$count++;
	}

chop $str;
$str=&trim($str);
return ($str,$count);
}

#####################################################################

sub read_config
{
my ($config_file, $location,$region,$currency,$run_date,$xml_loc,$chk_script_loc)=@_;

my %conf;
my $hol="";
$location=&trim($location); 

$location=".*" unless(defined $location);
$region=".*" unless(defined $region);

	if(defined $escape_holiday)
	{
	$hol="-e $escape_holiday";
	}
	elsif(defined $currency && $currency !~/GEN/i)
	{
	my $curr=uc($currency);
	$hol="-e $holiday_dir/holidaylist.txt";
	}

$currency=".*" unless(defined $currency);


open(CON, $config_file) || die "Can't Open for Reading : $config_file : $!\n";
my $count=100;

	foreach my $con (<CON>)
	{
	my $con_orig=$con;
	$con=&trim($con);
	next if($con=~ /^\#|^$/);
		if($con=~ /\@\@/)
		{
		my ($reg,$loc, $curr, $feed,$xml)=split(/\@\@/,$con,5);
		$reg=&trim($reg);
		$loc=&trim($loc);
		$curr=&trim($curr);
		$feed=&trim($feed);
		$xml=&trim($xml);

		#chk_feeds.pl -f /ppb/data/LATEST/Prices/sobratePrices.dat -d 20091119 -c cfg/chk_feeds_config_sobrate_govtPrices.xml

			if(defined $reg && $reg ne "" && defined $loc && $loc ne "" && defined $curr && $curr ne ""
				&& defined $xml && $xml ne ""	&& defined $feed && $feed ne "")
			{
				if($loc=~ /^$location$/i && $reg=~ /^$region$/i && $curr=~ /^$currency$/i)
				{
					
					if($curr !~ /USD/i)
					{
					$conf{$count}="$chk_script -f $loc/$feed -d $run_date -c $xml_loc/$xml -p $curr $hol";
					$count++;
					}
					else
					{
					$conf{$count}="$chk_script -f $loc/$feed -d $run_date -c $xml_loc/$xml $hol";
					$count++;
					}
				}
		
			}
			else
			{
			print "Error: Incorrect Config Information Provided\n";
			print "==>$con_orig<==\n\n";
			exit(12);
			}
		}
		else
		{
		print "Error: Incorrect Config Information Provided\n";
		print "==>$con_orig<==\n\n";
		exit(13);
		}
	}
close CON;

my $nom=scalar(keys %conf);
	
	if($nom==0)
	{
	print "\n";
	print "No Feeds found with ";
	print "[Location : $location] " if($location ne '.*');
	print "[Region : $region] " if($region ne '.*');
	print "[Currency : $currency] " if($currency ne '.*');
	print "\n";
	print "\nNothing to Process, Exiting Normally...\n\n";
	exit(0);
	}

return %conf;
}

#####################################################################

sub read_lock_file
{
my ($lock_file)=@_;

open(LOC, $lock_file) || die "Can't Open for Reading : $lock_file : $!\n";
my $any_step=0;

	foreach my $con (<LOC>)
	{
	chomp $con;
	my $con_orig=$con;
	$con=&trim($con);
	next if($con=~ /^\#|^$/);

		if($con=~ /^step\s*\:\s*(\d+)\s*\:\s*(.+)/i)
		{
		my $step=$1;
		my $info=$2;
		$step=&trim($step);
		$info=&trim($info);
		my $stp_fst_t=$stp_fst-1;
		my $stp_lst_t=$stp_lst+1;
			
			if(defined $step && $step ne "" && defined $info && $info ne "" && $stp_fst_t < $step && $stp_lst_t > $step) 
			{
			$any_step=1;
			
				if($info=~ /^succ/i)
				{
				$LOCK_SU{$step}=$info;
				}
				elsif($info=~ /^skip/i)
				{
				$LOCK_SK{$step}=$info;
				}
				elsif($info=~ /^fail/i)
				{
				$LOCK_FA{$step}=$info;
				}
				elsif($info=~ /^stop/i)
				{
				$LOCK_SP{$step}=$info;
				}
				else
				{
				$LOCK_RU{$step}=$info;
				}
			}
			else
			{
			print "Error: Incorrect Config Information Provided in the Lock File\n";
			print "==>$con_orig<==\n";
			&usage_lock(15);
			}
		}
		else
		{
		print "Error: Incorrect Config Information Provided in the Lock File\n";
		print "==>$con_orig<==\n";
		&usage_lock(16);
		}
	}
close LOC;

	foreach my $stp (keys %LOCK_SU)
	{
		if(defined $LOCK_RU{$stp})
		{
		delete $LOCK_RU{$stp};
		}
		if(defined $LOCK_FA{$stp})
		{
		delete $LOCK_FA{$stp};
		}
	}
	foreach my $stp (keys %LOCK_SK)
	{
		if(defined $LOCK_RU{$stp})
		{
		delete $LOCK_RU{$stp};
		}
		if(defined $LOCK_FA{$stp})
		{
		delete $LOCK_FA{$stp};
		}
	}

return $any_step;
}

#####################################################################

sub check_dir_exist
{
my ($dir, $info)=@_;
	unless(-d $dir)
	{
	print "$info : $dir [Directory doesn't exist!]\n\n";
	exit(19);
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

sub usage
{
print "\nUsage :\n";
print "$0 <cdhklrsxyw>\n";
print "$0 -d <run_date> -l <absolute_path_of_feed>\n";
print "$0 -d <run_date> -r <region>\n";
print "\nNOTE: [ -d ] , [ -r Or -l ] are Mendatory\n";

print "-c : Configuration File                     [/absolute_path/file_name]\n";
print "-d : Rundate                                [YYYYMMDD]\n";
print "-e : Escape Holoday File                    [/absolute_path/holiday_file_name]\n";  
print "-k : Lock File Location                     [/absolute_path]\n";
print "-l : Check Feed Location                    [/absolute_path]\n";
print "-r : Feed Check Region                      [ASIA|EMEA etc...]\n";
print "-s : Feed Check Script                      [/absolute_path/script_name]\n";
print "-x : Feed Check Config XML File Location    [/absolute_path]\n";
print "-y : Feed Check Currency                    [USD|CNY etc...]\n";
print "-w : Feed Compare Write to file Flag\n";
print "-h : Help\n\n";

exit(17);
}

#####################################################################

sub usage_lock
{
my ($exit_code)=@_;
print "\nUsage Lock File: $lock_file\n";
print "Step : <step_number> : <start|skip|stop>\n";
print "Example of Lock File Entry [Case In-sensitive] :\n";
print "STEP : 102 : SKIP      [Note: Skips the Specific Step]\n";
print "STEP : 105 : START     [Note: Starts from the Sepecified Step Onwards]\n";
print "STEP : 110 : STOP      [Note: Stops at the Sepecified Step]\n";

print "\nNOTE : Remove the Lock file for a Fresh Run\n\n";
exit($exit_code);
}

