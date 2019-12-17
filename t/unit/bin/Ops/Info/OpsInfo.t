#!/usr/bin/perl -w

use Test::More tests => 24;

use FindBin qw($Bin);

use lib "$Bin/../../../lib";
BEGIN
{
    my $installdir = $ENV{'installdir'} || "/a";
    unshift(@INC, "$installdir/extlib/lib/perl5");
    unshift(@INC, "$installdir/extlib/lib/perl5/x86_64-linux-gnu-thread-multi/");
    unshift(@INC, "$installdir/lib");
    unshift(@INC, "$installdir/lib/external/lib/perl5");
}

#### CREATE OUTPUTS DIR
my $outputsdir = "$Bin/outputs";
`mkdir -p $outputsdir` if not -d $outputsdir;

BEGIN {
    use_ok('Test::Ops::Info');
}
require_ok('Test::Ops::Info');

use Test::Ops::Info;

#### SET $Bin
my $installdir  =   $ENV{'installdir'} || "/a";
$Bin =~ s/^.+bin/$installdir\/t\/bin/;

my $logfile = "$Bin/outputs/opsinfo.log";
my $log     =   2;
my $printlog    =   5;

my $inputfile =   "$Bin/inputs/fastqc.ops";
my $outputfile =   "$Bin/outputs/fastqc.ops";

my $object = Test::Ops::Info->new(
    logfile         =>  $logfile,
    log			=>	$log,
    printlog        =>  $printlog,
    inputfile       =>  $inputfile,
    outputfile      =>  $outputfile
);
isa_ok($object, "Test::Ops::Info");

$object->testNew();

exit;

$object->testSet();
$object->testGenerate();

my $object2 = Test::Ops::Info->new(
    logfile     =>  $logfile,
    log			=>	$log,
    printlog    =>  $printlog
);

$object2->testParseFile();

$object->testIsKey();

__END__
