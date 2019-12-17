package Test::Ops::Common;
use Moose::Role;
use Method::Signatures::Simple;

use FindBin qw($Bin);

method BUILD ($hash) {
	$self->logDebug("");
}


#### REPOS
method setUpRepo {
	$self->branch("master");
	$self->repository("testversion");
	$self->packagename("testversion");
	$self->opsdir("$Bin/inputs/ops");
	$self->installdir("$Bin/outputs/target");	
	$self->sourcedir("$Bin/outputs/source");
	$self->privacy("public");
	
	$self->logGroup("");
	
  #### REPO VARIABLES
  my $remoterepo  = $self->remoterepo();
  my $sourcedir   = $self->sourcedir();
  my $login    	= $self->login();
  my $repository  = $self->repository();
  my $hubtype    	= $self->hubtype();
  my $branch      = $self->branch();
  my $privacy     = $self->privacy();
  
  #### CREATE TEMPORARY REPOSITORY ON GITHUB
  $self->deleteRepo($login, $repository);
  $self->createPublicRepo($login, $repository);

	#### PREPARE DIRECTORY
	if ( -d $sourcedir ) {
		$self->logDebug("Removing contents of sourcedir: $sourcedir");
		`rm -fr $sourcedir/* $sourcedir/.git`;	
	} else {
		$self->logDebug("Creating sourcedir: $sourcedir");
		my $command = "mkdir -p $sourcedir";
		$self->logDebug("command", $command);
		`$command`;
		$self->logError("Can't create sourcedir", $sourcedir) and exit if not -d $sourcedir;
	}
	$self->logCritical("Can't create sourcedir: $sourcedir") and exit if not -d $sourcedir;
	
	#### POPULATE LOCAL REPO
  $self->populateRepo();

  #### SET REMOTE
  $self->changeToRepo($sourcedir);
	my $isremote = $self->isRemote($login, $repository, $branch);
	$self->logDebug("isremote", $isremote);
	$self->addRemote($login, "github", $branch) if not $isremote;	

	#### SET SSH KEYFILE
	my $keyfile 	= $self->keyfile();

	#### PUSH TO REMOTE
	$self->logDebug("PUSHING TO REMOTE");
  $self->pushToRemote($login, "github", "github", $branch, $keyfile, $privacy);
  $self->pushTags($login, "github", "github", $branch, $keyfile, $privacy);

	$self->logGroupEnd("");
}

method populateRepo {
	$self->logGroup("");

  my $login    	=   $self->login();
  my $repository  =   $self->repository();
  my $sourcedir   =   $self->sourcedir();
  
  #### CHANGE INTO REPO DIR 
  $self->changeToRepo($sourcedir);

  #### INITIALISE REPO
  $self->initRepo($sourcedir);
  
  #### ADD REMOTE
  $self->addRemote($login, $repository, "github");

  #### POPULATE REPO WITH FILES AND TAGS    
  for ( 1 .. 5 ) {
      $self->toFile("$sourcedir/0.$_.0", "tag 0.$_.0");
      $self->addToRepo();
      $self->commitToRepo("Commit 0.$_.0");
      $self->addLocalTag("0.$_.0", "TAG 0.$_.0");
  }

	$self->logGroupEnd("");
}


1;
