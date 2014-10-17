require 5.8.8;

package BusDayUtil;



=information

Module Name             : BusDayUtil.pm
Author                  : Sanjoga Sahu.


Operating System(s)     : Linux

Description             : This Subroutine Adds, substracts days from given days [business day/Current Day]
                          It considers Holiday cal and escape days [non business days :sat,sun] while calculating Business day


=cut

use strict;
use Data::Dumper;
use base 'Exporter';
#use lib "/opt/rvg/lib/perl";
use Time::localtime;
use Date::Business;

our $debug=0; ##set to 1 if Want to Print all output check on screen
our $VERSION="1.0.0";

use vars qw (@EXPORT);

@EXPORT = qw (
$VERSION
$debug
&is_holiday
&my_format_date
&is_busday
&get_eod
&addsub_buscur_days
&is_valid_day
&validate_date
&get_day
);

my %escape_days=(
			'sat' => 1,
			'sun' => 1
			);

my %holiday=();

#####################################################################

=head 

This Subroutine parse the holiday file  and populate %holiday Hash

Arguments:
$holiday_file (absolute_path/holiday_file_name)

=cut

sub get_holidays
{
my ($holiday_file)=@_;
	if(defined $holiday_file)
	{
		unless(-f $holiday_file)
		{
		print STDERR "Holiday File Not Found on Disk : $holiday_file at ", __FILE__," line ", __LINE__, ".\n";
		exit(1);
		}
	open(HOL,$holiday_file) || die "Can't Open file to read : $holiday_file : $!\n";

		foreach my $hh (<HOL>)
		{
		$hh=&trim($hh);
		next if($hh !~ /^(\d{8})$/);
		&validate_date($hh,'yyyymmdd');
			if($hh=~ /^(\d{8})$/)
			{
			$holiday{$1}=1;
			}
		}
	close HOL;
	}

return (\%holiday );
}

#####################################################################

sub is_holiday
{
my($date, $holiday_file) = @_;
  
my %holiday=%{&get_holidays($holiday_file)};		

	if(defined $holiday{$date})
	{
	return 1;
	}
	else
	{
	return 0;
	}
}
#####################################################################

=head1 HOLIDAYS

Optionally, a reference to a function that counts the number of
holidays in a given date range can be passed. Business date addition,
subtraction, and difference functions will consider holidays.

Sample holiday function:

 # MUST BE NON-WEEKEND HOLIDAYS !!!
=cut
sub holiday($$)
{
my($start, $end) = @_;
    
my($numHolidays) = 0;
my @holidays=(keys %holiday);

    foreach my $holiday (@holidays)
	{
	$numHolidays++ if ($start le $holiday && $end ge $holiday);
    }

return $numHolidays;
}

#####################################################################

sub validate_date
{
my ($date, $date_format)=@_;
	unless(defined $date_format)
	{
	print STDERR "The DATE FORMAT [Ex:yyyymmdd] Not Provided at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}
$date=&my_format_date($date,$date_format,'yyyymmdd');

	if($date !~ /^\d{8}$/)
	{
	print STDERR "Invalid Date Provided : $date at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

my $yyyy = substr($date,0,4);
my $mm = substr($date,4,2);
    if($mm < 1 || $mm > 12)
	{
	print STDERR "Invalid Month [$mm] Provided : $date at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

my $dd = substr($date,6,2);
my $rc = &is_valid_day($yyyy, $mm, $dd);
	if($rc)
	{
	print STDERR "Invalid Day [$dd] Provied : $date at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
    }
return;
}

#####################################################################

sub is_valid_day
{
my ($year, $month, $day) = @_;

my %month_days =(
				
'01' => '31',
'02' => '28',
'03' => '31',
'04' => '30',
'05' => '31',
'06' => '30',
'07' => '31',
'08' => '31',
'09' => '30',
'10' => '31',
'11' => '30',
'12' => '31'
);

	if(($year % 4 == 0 && $year % 100 != 0) || $year % 400 == 0 )
	{
	$month_days{'02'} = '29';
	}

return ($day > $month_days{$month} || $day < 1) ? 1 : 0;
}

#####################################################################
=head 

This Subroutine returns the date as required in yyyymmdd format

Arguments:
1. $opt ( Ex: bus_date | cur_date | bus_date-1 | cur_date-1 ...) 

=cut

sub addsub_buscur_days
{
my ($bus_date,$opt,$holiday_file)=@_;
$opt=&trim(lc($opt));

#print "-------$bus_date===$opt----$holiday_file=====\n";
my ($date, $day);
	unless(defined $opt)
	{
	print STDERR "ERROR : Invalid Date Type Provided : $opt at ", __FILE__," line ", __LINE__, ".\n";
	print STDERR "INFO  : Please Provide Correct date Type, Ex : bus_date/cur_date\n";
	exit(1);
	}
	
	if($opt !~/bus_date|cur_date/i)
	{
	print STDERR "ERROR : Invalid Date Type Provided : $opt at ", __FILE__," line ", __LINE__, ".\n";
	print STDERR "INFO  : Please Provide Correct date Type, Ex : bus_date/cur_date\n";
	exit(1);
	}

	if($opt=~ /bus_date\s*(\-)\s*(\d+)/i)
	{
	my $symb=$1;
	my $d=$2;
	my $offset=$symb.$d;
	($day,$date)=&get_bday($bus_date,$offset,$holiday_file);
	}
	
	if($opt=~ /bus_date\s*(\+)\s*(\d+)/i)
	{
	my $symb=$1;
	my $d=$2;
	my $offset=$symb.$d;
	($day,$date)=&get_bday($bus_date,$offset,$holiday_file);
	}

	if($opt eq 'cur_date')
	{
	$date=`date +%Y%m%d`;
	$day=`date +%a`;
	chomp $date;
	chomp $day;
	}
	if($opt=~/cur_date\s*\-\s*(\d+)/)
	{
	my $b=$1;
	$day=`date --date="-$b days" +%a`;
	$date=`date --date="-$b days" +%Y%m%d`;
	chomp $date;
	chomp $day;
	}
	if($opt=~/cur_date\s*\+\s*(\d+)/)
	{
	my $b=$1;
	$day=`date --date="+$b days" +%a`;
	$date=`date --date="+$b days" +%Y%m%d`;
	chomp $date;
	chomp $day;
	}

	unless(defined $date)
	{
	print STDERR "Unexpected Error Occured While Getting Desired Date at ", __FILE__," line ", __LINE__, ".\n";
	print STDERR "Provided Arguments : Date : \"$bus_date\", Date_Option: \"$opt\", Holiday_File: \"$holiday_file\"\n\n";
	print STDERR "Usage : Subroutine   : (Day, Date) = addsub_buscur_days( Date, Date_Option, Holiday_File )\n";
	print STDERR "\tDate         : [yyyymmdd] Ex: 20100921\n\tDate Option  : [bus_date+<NumDaysAdd>|bus_date-<NumDaysSub>|cur_date+<NumDaysAdd>|cur_date-<NumDaysAdd>] Ex: bus_date-2\n\tHoliday File : /absolutePath/holidayfilename\n\n"; 
	exit(1);
	}
	
&validate_date($date,'yyyymmdd');
$day=lc($day);	
return ($day, $date);
}

#####################################################################

sub is_busday
{
my ($bus_date,$holiday_file)=@_;
#print "IS_busday: $bus_date,$escape_days_href,$holidays_href\n";

&validate_date($bus_date,'yyyymmdd');

my $holiday_ref=&get_holidays($holiday_file);
my %holiday=%{$holiday_ref};

my $DAY=&get_day($bus_date,'yyyymmdd');

#print "===$DAY==\n";

	if(defined $escape_days{$DAY})
	{
	#print "ESCAPE DAY\n";
	return 0;
	}
	
	if(defined $holiday{$bus_date})
	{
	#print "HOLIDAY\n";
	return 0;
	}
	
return 1;
}

#####################################################################

sub get_day 
{
my ($date,$date_format)=@_;

	unless(defined $date_format)
	{
	print STDERR "The DATE FORMAT Not Specified [Ex: yyyymmdd] at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}
$date=&my_format_date($date,$date_format,'yyyymmdd');

my $y=substr($date,0,4);
my $m=substr($date,4,2);
my $d=substr($date,6,2);


if($m !~ /[\d]{1,2}/ || $m > 12  || $m < 1 ){ return "ERR"; }
if($d !~ /[\d]{1,2}/ || $d > 31  || $d < 1 ){ return "ERR"; }
if($y !~ /[\d]+/ || $y < 1 ){ return "ERR"; }

my %month=(1,0,2,3,3,2,4,5,5,0,6,3,7,5,8,1,9,4,10,6,11,2,12,4,);
my %weekday=(0,'sun',1,'mon',2,'tue',3,'wed',4,'thu',5,'fri',6,'sat',);

if($m == 1){ $y--; }
if($m == 2){ $y--; }

$m = int($m);
$d = int($d);
$y = int($y);

my $wday = (($d+$month{$m}+$y+(int($y/4))-(int($y/100))+(int($y/400)))%7);
return $weekday{$wday};
}

#####################################################################
=head 

This Subroutine returns the type of formatted date string requred

Arguments:
1. $date (Ex: 20091117)
2. $inp_format (Ex: yyyymmdd)
3. $out_format (Ex: yyyy-mm-dd ->returns 2009-11-17) 

=cut

sub my_format_date
{
my ($date,$inp_format,$out_format)=@_;
#print "$date,$inp_format,$out_format\n";
my $out_date;
my $out_format_orig=$out_format;

my %month=(	'Jan' => '01', 'Feb' => '02', 'Mar' => '03',
			'Apr' => '04', 'May' => '05', 'Jun' => '06',
			'Jul' => '07', 'Aug' => '08', 'Sep' => '09',
			'Oct' => '10', 'Nov' => '11', 'Dec' => '12',

			'01' => 'Jan', '02' => 'Feb', '03' => 'Mar',
			'04' => 'Apr', '05' => 'May', '06' => 'Jun',
			'07' => 'Jul', '08' => 'Aug', '09' => 'Sep',
			'10' => 'Oct', '11' => 'Nov', '12' => 'Dec'

		);

$inp_format=lc($inp_format);
$out_format=lc($out_format);
my $len_date=length($date);
my $len_inp_f=length($inp_format);

	if($len_date ne $len_inp_f)
	{
	print STDERR "INPUT Date [$date] and INPUT Format [$inp_format] Not Maching at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

my @dd=split(/|/,$date);
my @inp=split(/|/,$inp_format);

my ($yy,$mm,$dd)='';
my $i;
my $ct=scalar(@inp);
$ct--;
	for($i=0; $i<=$ct ;$i++)
	{
		if($inp[$i] eq 'y')
		{
		$yy .=$dd[$i];
		}
		if($inp[$i] eq 'm')
		{
		$mm .=$dd[$i];
		}
		if($inp[$i] eq 'd')
		{
		$dd .=$dd[$i];
		}
	}

my $len_yy=length($yy);

#print "--$yy--$mm--$dd--\n";
my $inp_format_temp=$inp_format;
my $len_yy_in=($inp_format_temp=~ s/y/Y/g);
my $len_mm_in=($inp_format_temp=~ s/m/M/g);
my $len_dd_in=($inp_format_temp=~ s/d/D/g);


my $out_format_temp=$out_format;
my $len_yy_out=($out_format_temp=~ s/y/Y/g);
my $len_mm_out=($out_format_temp=~ s/m/M/g);
my $len_dd_out=($out_format_temp=~ s/d/D/g);
#print "==$len_yy_out--$len_mm_out--$len_dd_out==\n";

	if($len_yy < $len_yy_out)
	{
	print STDERR "The INPUT Year Length [$len_yy] and OUTPUT Year Length [$len_yy_out] Not Matching at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}
	
	if($len_yy > 4 || $len_yy < 2)
	{
	print STDERR "The INPUT Year Provided Not Correct at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

	if($len_yy_in == 1 || $len_mm_in == 1 || $len_dd_in ==1)
	{
	print STDERR "The INPUT Date Format [$inp_format] Not Supported at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

	if($len_yy_out == 1 || $len_mm_out == 1 || $len_dd_out ==1)
	{
	print STDERR "The OUTPUT Date Format [$out_format] Not Supported at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

	my $diff=0;

	if($len_yy > $len_yy_out)
	{
	$diff=$len_yy-$len_yy_out;
	}

	if($diff != 0)
	{
	$yy =~ s/^\d{$diff}//;
	}
my $calc_yy=length($yy);

	if($calc_yy != $len_yy_out)
	{
	print STDERR "Exception Occured while Calculating Year at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

	if($len_yy_out == 2)
	{
	$out_format=~ s/yy/$yy/g;
	}
	elsif($len_yy_out == 3)
	{
	$out_format=~ s/yyy/$yy/g;
	}
	elsif($len_yy_out == 4)
	{
	$out_format=~ s/yyyy/$yy/g;
	}

	my $calc_mm_temp=length($mm);

	if($calc_mm_temp != $len_mm_out)
	{
	$mm=lc($mm);
	$mm=ucfirst($mm);
	$mm=$month{$mm};
	}
	
	my $calc_mm=length($mm);

	if($calc_mm != $len_mm_out)
	{
	print "Calculated Month Size :$calc_mm != Output Month Size:$len_mm_out\n";
	print STDERR "Exception Occured while Calculating Month at ", __FILE__," line ", __LINE__, ".\n";
	exit(1);
	}

	if($len_mm_out == 2)
	{
	$out_format=~ s/mm/$mm/g;
	}
	elsif($len_mm_out == 3)
	{
	$out_format=~ s/mmm/$mm/g;
	}

$out_format=~ s/dd/$dd/g;

	if($out_format=~ /y|m|d/i)
	{
	my $sel=$&;
	my $post_sel=$';
	my $str=$sel.$post_sel;
		if($str !~ /jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec/i)
		{
		print STDERR "Exception Occured while getting Desired Date format [$out_format_orig] -> [$out_format] at ", __FILE__," line ", __LINE__, ".\n";
		exit(1);
		}
	}

return $out_format;
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

sub get_bday
{
my ($bus_date,$offset,$holiday_file)=@_;
my $res=&get_holidays($holiday_file);
my $d = new Date::Business(	DATE    => $bus_date,
								OFFSET  => $offset,
								HOLIDAY => \&holiday
							);
my $date=$d->image;
my $day=&get_day($date,'yyyymmdd');
return($day,$date);
}


1;
