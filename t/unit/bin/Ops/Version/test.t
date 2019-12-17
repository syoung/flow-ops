#!/usr/bin/perl -w

#### TEST MODULES
use Test::More  tests => 41; #qw(no_plan);
use Getopt::Long;
use FindBin qw($Bin);

#### USE LIBS
use lib "$Bin/../../../lib";
use lib "$Bin/../../../../../..";

#### INTERNAL MODULES
use Test::Ops::Version;

#### SET LOG
my $log         =   2;
my $printlog    =   4;
my $logfile = "$Bin/outputs/test.log";
my $help;
GetOptions (
    'log=i'         => \$log,
    'printlog=i'    => \$printlog,
    'help'          => \$help
) or die "No options specified. Try '--help'\n";
usage() if defined $help;

#### SET CONF
my $configfile  =   "$Bin/../../../../../../../conf/config.yml";
my $conf = Conf::Yaml->new(
    memory      =>  1,
    inputfile   =>  $configfile,
    log         =>  $log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;

my $object = new Test::Ops::Version(
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);

$object->testHigherSemVer();
$object->testVersionSort();
$object->testParseSemVer();
$object->testSameHigherVersion();
$object->testIncrementSemVer();

sub usage {
    print qq{
        
OPTIONS:

--log     Integer from 1 (least) to 5 (most) to display log information
--printlog    Integer from 1 (least) to 5 (most) to print log info to file

    };
}