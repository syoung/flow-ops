use MooseX::Declare;
use Method::Signatures::Simple;

class Test::Ops::Stager with Test::Common extends Ops::Stager {

#### EXTERNAL
use FindBin qw($Bin);
use Test::More;

has 'conf'			=> ( 
	is => 'rw', 
	isa => 'Conf::Yaml', 
	lazy => 1, 
	builder => "setConf" 
);

method setConf {
	my $conf 	= Conf::Yaml->new({
		backup		=>	1,
		log		=>	$self->log(),
		printlog	=>	$self->printlog()
	});
	
	$self->conf($conf);
}


method testRunStager {
	#### SET VARIABLES
	my $mode				=		"1-2";
	my $version			=		"1.4.0";
	my $repository	=		"testrepo";
	my $package			=		"biorepository";
	my $stagefile		=		"$Bin/inputs/stager.pm";
	my $branch			=		"master";
	my $outputdir		=		"$Bin/outputs";
	my $inputdir 		= 	"$Bin/inputs";
	my $stager     	= 	"stager";
	my $message			=		"TEST MULTILINE COMMIT MESSAGE - FIRST LINE

THIRD LINE";

	#### SET UP REPO
	$self->createSourceRepo( $mode, $inputdir, $repository, $stager, $stagefile );

	#### COPY OPSDIR AFRESH
	$self->setUpDirs($inputdir, $outputdir);

	##### SET SLOTS	
	$self->version($version);
	$self->branch($branch);
	$self->packagename($package);
	$self->outputdir($outputdir);

	#### RUN
	my ($sourcerepo, $targetrepo) = $self->stageRepo($stagefile, $mode, $message);	
 	$self->logDebug("sourcerepo", $sourcerepo);
 	$self->logDebug("targetrepo", $targetrepo);

 	#### TEST
 	my $actual = $targetrepo->currentVersion();
 	my $expected = $version;
 	$self->logDebug("actual", $actual);
 	$self->logDebug("expected", $expected);
	ok($actual eq $version, "target and source versions match");

	#### CLEAN UP
	$self->cleanUp( $inputdir, $repository );
}

method createSourceRepo ( $mode, $inputdir, $repository, $stager, $stagefile ) {
	##### CREATE LOCAL REPOSITORY
	$self->logDebug("inputdir", $inputdir);
	$self->logDebug("repository", $repository);
	$self->logDebug("stager", $stager);
	$self->logDebug("stagefile", $stagefile);

	my $repodir = "$inputdir/$repository";
	$self->logDebug("repodir", $repodir);

	#### CLEAN OUT LOCAL REPO
	`rm -fr $repodir/* $repodir/.git` if -d $repodir;
	`mkdir -p $repodir` if not -d $repodir;

	$self->loadOpsConfig( $inputdir, $stager );

	my ($sourceinfo, $targetinfo) = $self->getRepoInfo( $mode, $stagefile );
	$self->logDebug("sourceinfo", $sourceinfo);
	$sourceinfo->{log} = $self->log();
 	my $sourcerepo = Ops::Repo->new($sourceinfo);

  #### INITIALISE REPO
  $sourcerepo->initRepo();

  #### POPULATE REPO WITH FILES AND TAGS    
	my $versions = [	
		"1.0.0-alpha",
		"1.0.0-alpha.1",
		"1.0.0-beta.2",
		"1.0.0-beta.11",
		"1.0.0-rc.2",
		"1.0.0-rc.2+build.5",
		"1.0.0",
		"1.0.0+0.3.7",
		"1.3.7+build",
		"1.3.7+build.2.b8f12d7",
		"1.3.7+build.11.e0f985a"
	];

	for ( my $i = 0; $i < @$versions; $i++ ) {
    $sourcerepo->printToFile("$repodir/$$versions[$i]", $$versions[$i]);
    $sourcerepo->addToRepo();
    $sourcerepo->commitToRepo("Version $$versions[$i]");
    $sourcerepo->addLocalTag($$versions[$i], "TAG $$versions[$i]");
  }
}

method cleanUp ( $inputdir, $repository ) {
	#### REMOVE inputs REPOSITORY
	`rm -fr $inputdir/$repository`;
	
	#### REMOVE outputs REPOSITORY
	my $outputdir 		= 	"$Bin/outputs";
	`rm -fr $outputdir/$repository`;
}



}