use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Ops::S3 with (Test::Common) extends Ops::Main {

use Data::Dumper;
use Test::More;
use Test::DatabaseRow;
use DBase::Factory;
#use DBase::MySQL;
use Ops::Main;
use Engine::Instance;
use Conf::Yaml;
use FindBin qw($Bin);

# Int
has 'log'		=>  ( isa => 'Int', is => 'rw', default => 2 );  
has 'printlog'		=>  ( isa => 'Int', is => 'rw', default => 5 );

# String
has 'logfile'       => ( isa => 'Str|Undef', is => 'rw' );

method setUp () {
	#### SET LOG FILE
	my $logfile			=	"$Bin/outputs/s3.log";
	$self->logfile($logfile);
}

method cleanUp () {
	#### REMOVE outputs FILESYSTEM
	my $outputdir 		= 	"$Bin/outputs";
	$self->setUpRepo($outputdir, $repository);
	`rm -fr $outputdir/$repository`;
}

method testListFiles {
	diag("Test listFiles");

	my $filepaths = [	
		"",
		"myNewProject",
		"myNewProject/Workflow1"
	];
	
	my $expected = [
		{
			"myNewProject" => {
				"Workflow1"	=> {},
				"Workflow2"	=> {}
			]
							   ,
		[1, 0, 0, "alpha.1", ""],
		[1, 0, 0, "beta.2", ""],
		[1, 0, 0, "beta.11", ""],
		[1, 0, 0, "rc.1", ""],
		[1, 0, 0, "rc.1", "build.1"],
		[1, 0, 0, "", ""],
		[1, 0, 0, "", "0.3.7"],
		[1, 3, 7, "", "build"],
		[1, 3, 7, "", "build.2"],
		[1, 3, 7, "", "build.11"]
	];

	for ( my $i = 0; $i < @$versions; $i++ ) {
		my ($major, $minor, $patch, $release, $build) = $self->parseSemVer($$versions[$i]);

		my $matched = 0;
		if ( $major == $$expected[$i][0]
			and $minor == $$expected[$i][1]
			and $patch == $$expected[$i][2]
			and $release eq $$expected[$i][3]
			and $build eq $$expected[$i][4]
		) { $matched = 1; }
		ok ($matched, "parseSemVer    $$versions[$i]");
	}
}

method getS3File ($versionfile) {
	my $contents = $self->fileContents($versionfile);
	$contents =~ s/\s+$//;
	
	return $contents;
}

method getS3Directory ($versionfile) {
	my $contents = $self->fileContents($versionfile);
	$contents =~ s/\s+$//;
	
	return $contents;
}


}