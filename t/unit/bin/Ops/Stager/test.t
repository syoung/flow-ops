#!/usr/bin/perl -w

#### EXTERNAL MODULES
use Test::More  tests => 1; #qw(no_plan);
use Getopt::Long;
use FindBin qw($Bin);

#### USE LIBS
use lib "$Bin/../../../lib";
use lib "$Bin/../../../../../..";

#### INTERNAL MODULES
use Test::Ops::Stager;

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

my $object = new Test::Ops::Stager(
    conf        =>  $conf,
    log			=>	$log,
    printlog    =>  $printlog,
    logfile     =>  $logfile
);
isa_ok($object, "Test::Ops::Stager");


##### TEST RUN STAGER
$object->testRunStager();


