package Ops::Install;
use Moose::Role;
use Method::Signatures::Simple;

=head2

  PACKAGE    Ops::Install
  
  PURPOSE
  
    ROLE FOR GITHUB REPOSITORY ACCESS AND CONTROL

=cut

use FindBin qw($Bin);
use lib "$Bin/../..";

#### EXTERNAL MODULES
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use File::Copy;

# Bool
has 'force'    => ( isa => 'Bool|Undef', is => 'rw', default    =>  0  );
has 'showreport'   => ( isa => 'Bool|Undef', is => 'rw', default    =>  1  );
has 'opsmodloaded' => ( isa => 'Bool|Undef', is => 'rw', default  =>  0  );

# String
has 'status'     => ( isa => 'Str|Undef', is => 'rw' );
has 'repository'   => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'url'      => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'privacy'    => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'opsfile'    => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'pmfile'     => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'arch'     => ( isa => 'Str|Undef', is => 'rw', required  =>   0  );
has 'random'     => ( isa => 'Str|Undef', is => 'rw', required  =>   0  );
has 'pwd'      => ( isa => 'Str|Undef', is => 'rw', required  =>   0  ); # TESTING
has 'opsdir'     => ( isa => 'Str|Undef', is => 'rw', default => '' );
has 'appdir'     => ( isa => 'Str|Undef', is => 'rw', required  =>  0  );
has 'report'     => ( isa => 'Str|Undef', is => 'rw', required  =>  0  );

requires 'opsrepo';
requires 'version';

# Object
has 'dependencies' => ( 
  isa => 'HashRef', 
  is => 'rw', 
  required  =>  0,  
  default  =>  sub { {} }
);
has 'opsfields'  => ( 
  isa => 'ArrayRef', 
  is => 'rw', 
  required  =>  0  , 
  default  =>  sub {[
    "packagename",
    "repository",
    "version",
    "treeish",
    "branch",
    "privacy", 
    "owner",
    "login",
    "hubtype"
  ]}
);
has 'opsdata'  => ( 
  isa => 'HashRef',
  is => 'rw',
  required  =>  0  
);
has 'opsinfo'  => ( 
  isa => 'Ops::Info',
  is => 'rw',
 required  =>  0  
);
has 'dependents'=> ( 
  isa => 'ArrayRef',
  is => 'rw',
  required  =>  0,
  default  =>  sub { [] }
);

# # #### PACKAGE INSTALLATION
method install {
  $self->logDebug("DOING setUpInstall");
  $self->setUpInstall();

  #### SET INSTALLDIR
  my $installdir    =  $self->installdir();
  $installdir     =   $self->installdir($self->collapsePath($installdir));
  $self->logDebug("installdir", $installdir);

  #### SET OPSDIR
  my $opsdir        =  $self->opsdir();
  $opsdir       =   $self->opsdir($self->collapsePath($opsdir));
  $self->logDebug("opsdir", $opsdir);

  my $packagename    =  $self->packagename();
  my $version      =  $self->version();
  my $url       =  $self->url();
  $self->logDebug("version", $version);
  $self->logDebug( "url", $url );
  
  #### RUN INSTALL
  $self->logDebug("installdir", $installdir);
  $self->logDebug("DOING runInstall");

  return $self->runInstall( $installdir, $packagename, $version, $url );
}

method runInstall ($installdir, $packagename, $version, $url ) {
  $self->logDebug("installdir", $installdir);
  $self->logDebug("packagename", $packagename);
  $self->logDebug("version", $version);
  $self->logDebug( "url", $url );
  $self->version($version);

  #### USE originalversion FOR STATUS
  my $originalversion = $version;

  #### PRE-INSTALL
  $self->logDebug("BEFORE preInstall");
  my $report = $self->preInstall($installdir, $version) if $self->can('preInstall');
  #$self->updateReport([$report]) if defined $report;
  #$report = undef;
  #$self->logDebug("AFTER self->preInstall");

  #### SET VARIABLES
  my $repository  =  $self->repository();
  my $owner       =   $self->owner();
  my $login        =  $self->login();
  my $keyfile      =  $self->keyfile();
  my $hubtype      =  $self->hubtype();
  my $username    =  $self->username();
  $self->logDebug("repository", $repository);
  $self->logDebug("owner", $owner);

  #### DO INSTALL
  $self->logDebug("DOING self->doInstall");
  return 0 if $self->can('doInstall') and not $self->doInstall($installdir, $version);
  $self->logDebug("CONTINUING PAST self->can('doInstall')");

  #### POST-INSTALL
  $version = $self->version();
  $self->logDebug("version", $version);
  return 0 if $self->can('postInstall') and not $self->postInstall($installdir, $version);
  $self->logDebug("CONTINUING PAST self->can('postInstall')");
  
  ##### UPDATE REPORT
  #$self->updateReport([$report]) if defined $report;
  
  #### SET .envars
  my $envartext = $self->setEnvars( $packagename, $version );
  $self->logDebug( "envartext", $envartext );

  #### UPDATE PACKAGE IN DATABASE
  #$self->logger()->write("Updating 'package' table");
  $self->updatePackage($owner, $username, $packagename, $version, $originalversion, $envartext);
  
  #### REPORT VERSION
  #$self->logger()->write("Completed installation, version: $version");

  #### TERMINAL INSTALL
  #$self->logger()->write("BEFORE terminalInstall method");
  $version = $self->version();
  print "Installed package '$packagename' (version $version) to $installdir/$version\n" if defined $version;
  print "Installed package '$packagename'\n" if not defined $version;

  return 0 if not $self->terminalInstall($installdir, $version);
  #$self->updateReport([$report]) if defined $report and $report;
  
  #### E.G., DEBUG/TESTING
  #return $self->logger->report();
}

method envarTextToArray ( $text ) {
  $self->logDebug( "text", $text );
  my @lines = split "\n", $text;
  $self->logDebug( "lines", \@lines );    
  my $array = [];
  foreach my $line ( @lines ) {
    my ( $key, $value ) = $line =~ /^\s*export\s+([^=]+)=(\S+)/;
    $value =~ s/;$//;
    $self->logDebug( "PUSHING $key", $value );

    push @$array, { $key => $value };
  }
  $self->logDebug( "array", $array );

  return $array;
}

method setEnvars ( $packagename, $version ) {
  my $envars = $self->opsinfo()->envars();
  $self->logDebug( "envars", $envars );
  
  return if not defined $envars or not $envars;

  my $text = "";
  my $appsdir = $self->conf()->getKey( "biorepo:APPSDIR" );
  my $versiondir = "$appsdir/$packagename/$version";
  foreach my $envar ( @$envars ) {
    $self->logDebug( "envar", $envar );
    foreach my $key ( keys %$envar ) {
      $envar->{ $key } =~ s/<VERSIONDIR>/$versiondir/g;
      $text .= "export $key=$envar->{ $key };\n";
    }
  }

  my $file = "$versiondir/.envars";
  $self->util()->printToFile( $file, $text );
  print "Printed envar file: $file\n";

  return $text;
}

method setUpInstall {
  my $opsfile      = $self->opsfile();
  my $pmfile      = $self->pmfile();
  my $opsdir      = $self->opsdir();
  my $installdir    =  $self->installdir();
  my $packagename    =  $self->packagename();
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("packagename", $packagename);

  #### LOAD OPS MODULE IF PRESENT
  $self->logDebug("self->opsmodloaded()", $self->opsmodloaded());
  $self->loadOpsModule($pmfile, $opsdir, $packagename) if not $self->opsmodloaded();
  
  #### LOAD OPS INFO IF PRESENT
  $self->loadOpsInfo($opsfile, $opsdir, $packagename) if not defined $self->opsinfo();
  
  #### NOTIFY
  my $version = $self->version();
  if ( $version and $version ne "" ) {
    print "Installing package '$packagename' (version $version)\n";
  }
  else {
    print "Installing package '$packagename'\n";
  }

  #### SET USERNAME
  my $username    =  $self->username();
  if ( not defined $username ) {
    $username = $self->conf()->getKey("core:ADMINUSER");
    $self->username($username);
  }

  #### SET PWD - USED IN TESTING
  $self->pwd($Bin) if not defined $self->pwd();

  #### CHECK DEPENDENCIES
  $self->installDependencies($opsdir, $installdir);
}

method getVersions () {
  my $opsfile = $self->opsfile();
  my $packagename = $self->packagename();
  my $opsdir = $self->opsdir();
  $self->logDebug("opsfile", $opsfile);
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("packagename", $packagename);

  #### LOAD OPS INFO IF PRESENT
  $self->loadOpsInfo( $opsfile, $opsdir, $packagename ) if not defined $self->opsinfo();
  my $repository = $self->opsinfo()->repository();
  my $owner = $self->opsinfo()->owner();

  #### TO DO: ADD PRIVATE REPOS
  my $privacy = "";
  $self->logDebug("owner", $owner);
  $self->logDebug("repository", $repository);
  $self->logDebug("privacy", $privacy);

  my $versions = [];
  my $source = "opsfile";
  if ( $self->opsinfo()->hubtype() ) {
    $source = $self->opsinfo()->hubtype();
    my $versionsarray   =  $self->getRemoteTags( $owner, $repository, $privacy );
  $self->logDebug( "versions", $versions );
    foreach my $version ( @$versionsarray ) {
      push ( @$versions, $version->{name} );
    }
  }
  elsif ( $self->opsinfo()->versions() ) {
    $versions = $self->opsinfo()->versions();
  }

  return ( $versions, $source );
}

method installDependencies ($opsdir, $installdir) {
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("installdir", $installdir);

  return if not defined $self->opsinfo();

  my $envars = $self->envars() || "";
  my $parent = $self->packagename();
  my $parentversion = $self->version();

  my $applications  =  $self->opsinfo()->dependencies();
  $self->logDebug("applications", $applications);
  $applications = [] if not defined $applications;
  
  my $username = $self->username();
  $self->logDebug("username", $username);

  my $dependencies = $self->dependencies();  
  my $missing  =  [];
  foreach my $application ( @$applications ) {
    $self->logDebug("application", $application);
    
    if ( not $self->satisfiedDependency($application) ) {
      push @$missing, $application
    }
    else {
      my $dependencyversion =  $application->{version};

      my $query = "SELECT * FROM package
WHERE packagename='$application->{packagename}'
AND version='$dependencyversion'";
      $self->logDebug("query", $query);
      my $package = $self->table()->db()->queryhash( $query );
      $self->logDebug("package", $package);
      $dependencies->{$application->{packagename}} = $package;
    }
  }
  $self->logDebug("missing", $missing);
  $self->logDebug("dependencies", $dependencies);

  foreach my $missed ( @$missing ) {
    my $packagename  =  $missed->{packagename};
    my $version  =  $missed->{version};
    my $treeish  =  $missed->{treeish} || $version;
    my $targetdir;
    $self->logDebug("packagename", $packagename);
    $self->logDebug("version", $version);
    if ( $missed->{installdir} ) {
      $targetdir  =  "$missed->{installdir}/$packagename";
      $targetdir =~ s/%INSTALLDIR%/$installdir/g;
    }
    else {
      my $basedir  =  $self->getBaseDir($installdir);
      $targetdir  =  "$basedir/$packagename";
    }

    my $opsfile  =  "$opsdir/$packagename/$packagename.ops";
    my $pmfile  =  "$opsdir/$packagename/$packagename.pm";
    $self->logDebug("opsfile", $opsfile);
    $self->logDebug("pmfile", $pmfile);
    
    $self->logDebug("DOING object = Ops::Main->new()");
    my $object = Ops::Main->new({
      conf     =>  $self->conf(),
      table    =>  $self->table(),
      opsrepo    =>  $self->opsrepo(),
      opsdir     =>  $opsdir,
      installdir   =>  $targetdir,
      packagename  =>  $packagename,
      version    =>  $version,
      treeish    =>  $treeish,
      opsfile    =>  $opsfile,
      pmfile     =>  $pmfile,
      dependencies =>  $dependencies,
      repository   =>  $missed->{repository},
      owner    =>  $missed->{owner},

      status     =>   "dependency:$parent:$parentversion",  

      login      =>  $self->login(),
      token      =>  $self->token(),
      keyfile    =>  $self->keyfile(),
      password  =>  $self->password(),
    
      log     =>  $self->log(),
      printlog  =>  $self->printlog(),
      logfile   =>  $self->logfile()
    });

    $object->install();
    
    my $installedversion = $object->version();
    $self->logDebug("installedversion", $installedversion);

    $dependencies->{$packagename} = {
      version  => $object->version(),
      installdir => $object->installdir()
    };

  }

  $self->dependencies( $dependencies );
  $self->logDebug( "self->dependencies()", $self->dependencies() );
}

method satisfiedDependency ($dependency) {
  $self->logDebug("dependency", $dependency);
  
  my $packagename    =  $dependency->{packagename};
  my $version      =  $dependency->{version};
  my $username    = $self->username();
  my $query  =  qq{SELECT version FROM package
WHERE packagename='$packagename'};
  $self->logDebug("query", $query);

  my $versions = $self->table()->db()->queryarray($query);
  $self->logDebug("versions", $versions);

  foreach my $installedversion ( @$versions ) {
    my $comparison = $self->higherSemVer( $version, $installedversion );
    $self->logDebug("comparison", $comparison);
    return 1 if $comparison == 0;
  }

  return 0;
}


#### INSTALL TYPES
method gitInstall ($installdir, $version) {

  my $repository    =  $self->repository();
  my $branch      =  $self->branch();
  my $treeish      =  $self->treeish();
  my $owner       =   $self->owner();
  my $login      =  $self->login();
  my $keyfile      =  $self->keyfile() || "";
  my $privacy     =   $self->privacy();
  my $credentials   =   $self->credentials();
  my $username    =  $self->username();
  my $hubtype      =  $self->hubtype();
  my $url        =  $self->url();
  my $force       =   $self->force();

  my $cloneurl     =  $self->opsinfo()->cloneurl();
  $self->logDebug( "cloneurl", $cloneurl );

  #### ENSURE MINIMUM DATA IS AVAILABLE
  $self->logCritical("repository not defined") and exit if not defined $repository;
  $self->logCritical("owner not defined") and exit if not defined $owner;
  $self->logCritical("hubtype not defined") and exit if not defined $hubtype;

  $self->logDebug("version", $version);
  $self->logDebug("installdir", $installdir);
  $self->logDebug("repository", $repository);
  $self->logDebug("owner", $owner);
  $self->logDebug("login", $login);
  $self->logDebug("username", $username);
  $self->logDebug("hubtype", $hubtype);
  $self->logDebug("privacy", $privacy);
  $self->logDebug("keyfile", $keyfile);
  $self->logDebug( "url", $url );
  
  my $tag    =  $treeish;
  $tag    =  $version if not defined $tag or $tag eq "";

  if ( $version eq "latest" ) {
    my $versions = $self->opsinfo()->versions();
    $version  =  $self->highestListedVersion( $versions );
    $self->version( $version );
    $tag = $version;
  }
  elsif ( not defined $tag ) {
    $version  =  $self->latestVersion($owner, $repository, $privacy, $hubtype);
    $version  =  $treeish if not defined $version;
    $tag    =  $version;
  }
  elsif ( $tag eq "latest" ) {
    $version  =  $self->latestVersion($owner, $repository, $privacy, $hubtype);
    $version  =  $treeish if not defined $version;
    $tag    = $version;
  }
  $self->logDebug( "version", $version );

  #### FIX FOR bamtools "v2.5.1"
  $tag = $self->customTag( $tag ) if $self->can( 'customTag' );

  #### REASONS WHY VERSION NOT DEFINED:
  ####   1. USER DID NOT PROVIDE VERSION (OR JUST PROVIDED 'max'), AND
  ####   2. latestVersion METHOD CAN'T ACCESS API TO GET TAGS
  ####    E.G., REPO IS PRIVATE, CLONING WITH DEPLOY KEY
  ####
  #### IF VERSION NOT DEFINED:
  ####   1. CLONE REPO TO DIRECTORY latest 
  ####   2. GET LATEST VERSION FROM CLONED REPO
  ####  3. rm EXISTING "LATEST VERSION" DIRECTORY
  ####  4. mv DIRECTORY latest TO LATEST VERSION

  #### SET VERSION
  $self->version($version) if defined $version;

  $self->logDebug("tag", $tag);
  $self->logDebug("version", $version);

  if ( not defined $version or $version eq "" ) {
    print "Installing latest version of repository '$repository' (version not defined)\n";
  }
  elsif ( $tag ne "max" ) {
    print "Installing version '$version' from repository '$repository'\n";
  }
  else {
    print "Installing latest build of version '$version' from repository '$repository'\n";
  }
  
  #### MAKE INSTALL DIRECTORY
  $self->makeDir($installdir) if not -d $installdir;  
  $self->logCritical("Can't create installdir", $installdir) and return 0 if not -d $installdir;

  # #### SET DEFAULT KEYFILE
  # $keyfile = $self->setKeyfile($username, $hubtype) if $privacy ne "public" and $keyfile eq "";
  # $self->logDebug("keyfile", $keyfile);
  
  #### SET CLONE DIR target
  my $target = $self->getTarget( $version );
  $self->logDebug("target", $target);
  my $targetdir = "$installdir/$target";

  #### DELETE TARGET DIRECTORY IF EXISTS
  if ( -f $targetdir ) {
    print "Target directory is a file: $targetdir\n";
    return 0;
  }
  $self->logDebug( "DOING remove_tree ( $targetdir )\n" );
  remove_tree( $targetdir ) if -d $targetdir;
  $self->logCritical("Can't delete targetdir: $targetdir") and return 0 if -d $targetdir;

  #### CLONE FROM LOCAL REPO
  if ( $url and $url ne "" ) {
    $self->logDebug("Cloning from local repo: $repository");
    if ( $url !~ /^(http|git)/ ) {
      $self->cloneFromUrl
    }
    $self->cloneLocalRepo( $url, $installdir, $target, $branch )
  }  
  #### CLONE FROM REMOTE REPO
  else {
    #### ADD HUB TO /root/.ssh/authorized_hosts FILE
    $self->addHubToAuthorizedHosts($login, $hubtype, $keyfile, $privacy);  

    #### UPDATE REPORT
    #$self->updateReport(["Cloning from remote repo: $repository (owner: $owner, login: $login)"]);
    $self->logDebug("Cloning from remote repo: $repository");
    print "Cloning from remote repo: $repository\n";

    #### CLONE REPO
    $self->logDebug("Doing self->changeDir()");
    $self->changeToRepo($installdir);
    if ( $url ) {
      ( $hubtype ) = $url =~ /^.+?:\/\/([^\.]+)/;
      # https://bitbucket.astrazeneca.net/scm/so/sdf-px-maxquant.git
      ( $owner ) = $url =~ /^.+?:\/\/.+\/([^\.\/]+)\/([^\.\/]+)(\.git)?$/;
      ( $repository ) = $url =~ /^.+?:\/.+?([^\/]+)(\.git)?$/;
    }

    my $cloneurl = $self->opsinfo()->cloneurl();
    $self->logDebug( "cloneurl", $cloneurl );

    $self->logDebug( "url", $url );
    $self->logDebug( "hubtype", $hubtype );
    $self->logDebug( "owner", $owner );
    $self->logDebug( "repository", $repository );

    $self->logDebug("Doing self->cloneRemoteRepo()");
    my $success = $self->cloneRemoteRepo($owner, $repository, $branch, $hubtype, $login, $privacy, $keyfile, $target, $cloneurl );
    $self->logDebug("success", $success);
    $self->logDebug("FAILED to clone repo. Returning 0") and return 0 if not $success;
  }

  ##### CHECKOUT SPECIFIC VERSION
  $self->logDebug( "########################## version: $version\n" );

  if ( not defined $version or $version eq "" ) {
    #print "Version not defined. Getting latest version from cloned repo\n";
    $self->logDebug("Doing changeToRepo targetdir", "$targetdir");
    my $change     =   $self->changeToRepo($targetdir);
    $self->logDebug("change", $change);
    $version    =  $self->currentLocalTag();
    # $self->logDebug("version", $version);
    $self->version($version);

    #### REPORT STATUS
    print "Latest version: $version\n" if defined $version;

    if ( not defined $version ) {
      $self->logDebug("version not defined. Exiting");
      print "Can't find latest version. Exiting\n";
      exit;
    }    
    
    #### IF DEFINED VERSION, CHANGE TARGET DIRECTORY NAME FROM latest TO version
    my $versiondir  =  "$installdir/$version";
    if ( defined $version ) {
      remove_tree( $versiondir );
      $self->logDebug( "DOING mv $targetdir $versiondir" );

      move( $targetdir, $versiondir);
      $self->changeToRepo($versiondir);
    }

    #### LINK THE TARGET DIRECTORY TO latest, IF 'latest' VERSION SPECIFIED
    if ( $target eq "latest" ) {
      symlink( $versiondir, $targetdir );
    }
  }
  elsif ( $tag eq "max") {
    print "Skipping checkout so repo is at latest commit\n";
    $self->logDebug("Skipping checkout as tag is 'max'");
  }
  else {
    $self->logDebug("Doing changeToRepo targetdir", "$targetdir");
    my $change = $self->changeToRepo($targetdir);
    $self->logDebug("change", $change);
    $self->checkoutTag($targetdir, $tag);
    #$self->logger()->write("Checked out version: $version");
    $self->logDebug("checked out version", $version);

    #### VERIFY CHECKED OUT VERSION == DESIRED VERSION
    $self->verifyVersion($targetdir, $version) if $self->foundGitDir($targetdir) and defined $version and $version ne "";
    $self->version($version);
  }  
  
  return 1;
}

method getTarget ( $version ) {
  $self->logDebug("version", $version);
  my $target  =  $version || "latest";

  return $target;
}


method zipInstall ($installdir, $version) {
  my $fileurl = $self->setFileUrl($version);
  my ($filename)  =  $fileurl  =~ /^.+?([^\/]+)$/;
  $self->logDebug("filename", $filename);
  
  if ( $version eq "latest" ) {
    my $versions = $self->opsinfo()->versions();
    $version  =  $self->highestListedVersion( $versions );
    $self->version( $version );
  }
  $self->logDebug( "version", $version );

  #### DELETE EXISTING DOWNLOAD
  my $filepath  =  "$installdir/$filename";
  $self->logDebug("filepath", $filepath);
  remove_tree( $filepath ) if -f $filepath;

  #### CHECK IF FILE IS AVAILABLE
  my $exists   =  $self->remoteFileExists($fileurl);
  $self->logDebug("exists", $exists);
  if ( not $exists ) {
    $self->logDebug("Remote file does not exist. Exiting");
    print "Remote file does not exist: $fileurl\n";
    return 0;
  }
  
  #### DELETE DIRECTORY AND ZIPFILE IF EXIST
  my $targetdir = "$installdir/$version";
  my $targetfile  =  "$installdir/$filename";
  $self->logDebug("targetdir", $targetdir);
  $self->logDebug("targetfile", $targetfile);
  remove_tree( $targetdir ) if $targetdir;
  $self->logCritical("Can't delete targetdir: $targetdir") and exit if -d $targetdir;
  remove_tree( $targetfile ) if -f $targetfile;
  $self->logCritical("Can't delete targetfile: $targetfile") and exit if -d $targetfile;

  #### MAKE INSTALL DIRECTORY IF NOT EXISTS
  $self->makeDir($installdir) if not -d $installdir;  

  #### DOWNLOAD ZIPFILE
  $self->changeDir($installdir);
  print "Downloading file: $fileurl\n";
  $self->runCommand("wget -c $fileurl --output-document=$filename --no-check-certificate");
  
  $self->logDebug("filepath", $filepath);
  if ( -z $filepath ) {
    $self->logDebug("file is empty", $filepath);
    print "File is empty: $filepath\n";

    return 0;
  }

  if ( not -f $filepath ) {
    $self->logDebug("filepath not found", $filepath);
    print "Filepath not found: $filepath\n";

    return 0;
  }

  #### GET ZIPTYPE
  my $ziptype =   "tar";
  $ziptype  =  "tgz" if $filename =~ /\.tgz$/;
  $ziptype  =  "bz" if $filename =~ /\.bz2$/;
  $ziptype  =  "zip" if $filename =~ /\.zip$/;
  $self->logDebug("ziptype", $ziptype);

  #### GET UNZIPPED FOLDER NAME
  my ($unzipped) =  $filename  =~ /^(.+)\.tar\.gz$/;
  ($unzipped)  =  $filename  =~ /^(.+)\.tgz$/ if $ziptype eq "tgz";
  ($unzipped)  =  $filename  =~ /^(.+)\.tar\.bz2$/ if $ziptype eq "bz";
  ($unzipped)  =  $filename  =~ /^(.+)\.zip$/ if $ziptype eq "zip";
  if ( defined $self->opsinfo()->unzipped() ) {
    $unzipped  =  $self->opsinfo()->unzipped();
    $unzipped  =~ s/\$version\s*/$version/g;
  }
  $self->logDebug("unzipped", $unzipped);

  #### REMOVE UNZIPPED IF EXISTS AND NO 'asterisk'
  # remove_tree( $unzipped ) if $unzipped !~ /\*/;

  #### SET UNZIP COMMAND
  $self->changeDir($installdir);
  my $command  =  "tar xvfz $filename"; # tar.gz AND tgz
  $command  =  "tar xvfj $filename" if $ziptype eq "bz";
  $command  =  "unzip $filename" if $ziptype eq "zip";
  $self->logDebug("command", $command);

  #### UNZIP AND CHANGE UNZIPPED TO VERSION
  $self->runCommand($command);  
  move( $unzipped, $version );  
  
  #### REMOVE ZIPFILE
  remove_tree( $filename );
  
  ### CHECK !!!
  # my $packagename  =  $self->opsinfo()->packagename();
  #$self->logger()->write("Completed installation of $packagename, version $version");
  
  $self->version($version);
  
  return 1;
}

method setFileUrl ($version) {
  my $fileurl  =  $self->opsinfo()->url();
  $fileurl =~ s/\$version\s*/$version/g;
  $self->logDebug("fileurl", $fileurl);
  
  my ($subversion) = $version =~ /^(.+?)\.[^\.]+$/;
  $self->logDebug("subversion", $subversion);
  $fileurl =~ s/\$subversion\s*/$subversion/g;
  
  return $fileurl;
}

method downloadInstall ($installdir, $version) {
  $self->logDebug("self->opsinfo", $self->opsinfo());
  my $fileurl  =  $self->opsinfo()->url();
  $fileurl =~ s/\$version/$version/g;
  $self->logDebug("fileurl", $fileurl);
  
  my ($filename)  =  $fileurl  =~ /^.+?([^\/]+)$/;
  $self->logDebug("filename", $filename);
  
  #### CHECK IF FILE IS AVAILABLE
  my $exists   =  $self->remoteFileExists($fileurl);
  $self->logDebug("exists", $exists);
  if ( not $exists ) {
    $self->logDebug("Remote file does not exist. Exiting");
    print "Remote file does not exist: $fileurl\n";
    exit;
  }
  
  #### MAKE INSTALL DIRECTORY
  my $targetdir  =  "$installdir/$version";
  $self->makeDir($targetdir) if not -d $targetdir;  

  #$self->logger()->write("Changing to targetdir: $targetdir");
  $self->changeDir($targetdir);

  #$self->logger()->write("Downloading file: $filename");
  $self->runCommand("wget -c $fileurl --output-document=$filename --no-check-certificate");
  
  #### CHANGE NAME IF downloaded DEFINED
  if ( defined $self->opsinfo()->downloaded() ) {
    my $downloaded  =  $self->opsinfo()->downloaded();
    $downloaded  =~ s/\$version/$version/g;
    $self->logDebug("downloaded", $downloaded);
  
    $self->runCommand("mv $filename $downloaded");
  }

  #my $packagename  =  $self->opsinfo()->packagename();
  #$self->logger()->write("Completed installation of $packagename, version $version");
  
  return $version;  
}

method configInstall ($installdir, $version) {
  $self->logDebug("version", $version);
  $self->logDebug("version", $version);

  #### CHANGE DIR
  $self->changeDir("$installdir/$version");
  
  #### MAKE
  $self->runCommand("./configure");
  $self->runCommand("make");
  $self->runCommand("make install");

  return 1;
}

method makeInstall ($installdir, $version) {
  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);

  #### CHANGE DIR
  $self->changeDir("$installdir/$version");
  
  #### MAKE
  my ($out, $err) = $self->runCommand("make");
  $self->logDebug("out", $out);
  $self->logDebug("err", $err);
  ($out, $err) = $self->runCommand("make install");
  $self->logDebug("out", $out);
  $self->logDebug("err", $err);

  return 1;
}

method perlmakeInstall ($installdir, $version) {
  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);

  #### CHANGE DIR
  $self->changeDir("$installdir/$version");
  
  #### MAKE
  my ($out, $err) = $self->runCommand("perl Makefile.PL");
  $self->logDebug("out", $out);
  $self->logDebug("err", $err);
  ($out, $err) = $self->runCommand("make");
  $self->logDebug("out", $out);
  $self->logDebug("err", $err);
  ($out, $err) = $self->runCommand("make install");
  $self->logDebug("out", $out);
  $self->logDebug("err", $err);

  return 1;
}

method confirmInstall ($installdir, $version) {
  $self->logDebug("version", $version);
  $self->logDebug("installdir", $installdir);
  my $packagename = $self->packagename();
  $self->logDebug("packagename", $packagename);

  my $opsdir    =  $self->opsdir();
  $self->logDebug("opsdir", $opsdir);
  my $file    =  "$opsdir/$packagename/t/$version/output.txt";
  $self->logDebug("file", $file);
  return 1 if not -f $file;

  my $lines    =  $self->fileLines($file);
  my $command   =  shift @$lines;
  $command    =~ s/^#//;
  my $executor  =  "";
  if ( $$lines[0] =~ /^#/ ) {
    $executor  =  shift @$lines;
    $executor    =~ s/^#//;
  }
  $self->logDebug("command", $command);
  $self->logDebug("executor", $executor);

  $command   =  "cd $installdir/$version; $executor $command";
  $self->logDebug("FINAL command", $command);

  my ($output, $error)  =  $self->runCommand($command);
  $output    =  $error if not defined $output or $output eq "";
  my $actual;
  @$actual  =  split "\n", $output;
  # print "actual: ", join "\n", @$actual, "\n";

  for ( my $i = 0; $i < @$lines; $i++ ) {
    my $got  =  $$actual[$i] || ""; #### EXTRA EMPTY LINES
    my $expected  =  $$lines[$i];
    next if $expected =~ /^SKIP/;
    
    if ( $got ne $expected ) {
      $self->logDebug("FAILED TO INSTALL. Mismatch between expected and actual output!\nExpected:\n$expected\n\nGot:\n$got\n\n");
      return 0;
    }
  }
  $self->logDebug("**** CONFIRMED INSTALLATION ****");
  print "Confirmed installed executable: $command\n";

  return 1;
}

method perlInstall ($opsdir, $installdir) {
#### PUT PERL MODS ONE PER LINE IN FILE perlmods.txt
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("installdir", $installdir);

  $self->installCpanm();

  my $arch = $self->getArch();
  $self->logDebug("arch", $arch);
  if ( $arch eq "centos" ){
    $self->runCommand("yum install perl-devel");
    $self->runCommand("yum -y install gd gd-devel");
  }
  elsif ( $arch eq "ubuntu" ) {
    $self->runCommand("apt-get -y install libperl-dev");
    $self->runCommand("apt-get -y install libgd2-xpm");
    $self->runCommand("apt-get -y libgd2-xpm-dev");
  }
  else {
    print "Architecture not supported: $arch\n" and exit;
  }

  my $modsfile  =  "$opsdir/perlmods.txt";
  $self->logDebug("modsfile", $modsfile);
  
  my $perlmods =  $self->getLines($modsfile);
  $self->logDebug("perlmods", $perlmods);
  foreach my $perlmod ( @$perlmods ) {
    next if $perlmod =~ /^#/;
    $self->runCommand("cpanm install $perlmod");
  }
  
  return 1;
}

method remoteFileExists ($url) {
  $self->logDebug("url", $url);
  my $checkurl  =  $self->opsinfo()->checkurl();
  $self->logDebug("checkurl", $checkurl);
  return 1 if $checkurl eq "false";
  
  my ($output, $error) =  $self->runCommand("wget --spider $url");
  $self->logDebug("output", $output);
  $self->logDebug("error", $error);
  
  if ( $error =~ /Remote file exists.$/ms ) {
    return 1;
  }
  
  return 0;
}

method preInstall ($installdir, $version) {
  #### OVERRIDE THIS METHOD

  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);

  #### CHECK INPUTS
  $self->logCritical("installdir not defined", $installdir) and exit if not defined $installdir;
}

method doInstall ( $installdir, $version ) {
  #### OVERRIDE THIS METHOD
  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);
  #$self->logger()->write("Doing doInstall");
  
  return $self->gitInstall($installdir, $version);
}

method postInstall ($installdir, $version) {
  #### OVERRIDE THIS METHOD
  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);
  #$self->logger()->write("Doing postInstall");  
  
  return 1;
}

method terminalInstall ($installdir, $version) {
  #### OVERRIDE THIS METHOD
  $self->logDebug("installdir", $installdir);
  $self->logDebug("version", $version);
  #$self->logger()->write("Doing terminalInstall");  
  
  return 1;
}

#### UTILS

method loadSamples ($username, $project, $table, $sqlfile, $tsvfile) {
  $username  =  $self->username() if not defined $username;
  $project  =  $self->project() if not defined $project;
  $table    =  $self->table() if not defined $table;
  $sqlfile    =  $self->sqlfile() if not defined $sqlfile;
  $tsvfile    =  $self->tsvfile() if not defined $tsvfile;
  
  $self->logError("username not defined") and return if not defined $username;
  $self->logError("project not defined") and return if not defined $project;
  $self->logError("table not defined") and return if not defined $table;
  $self->logError("sqlfile not defined") and return if not defined $sqlfile;
  $self->logError("tsvfile not defined") and return if not defined $tsvfile;

  $self->logDebug("username", $username);
  $self->logDebug("project", $project);
  $self->logDebug("table", $table);
  $self->logDebug("sqlfile", $sqlfile);
  $self->logDebug("tsvfile", $tsvfile);
  
  $self->logError("Can't find sqlfile: $sqlfile") and return if not -f $sqlfile;
  $self->logError("Can't find tsvfile: $tsvfile") and return if not -f $tsvfile;

  #### LOAD SQL
  my $query  =  $self->fileContents($sqlfile);
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);

  #### DELETE FROM TABLE
  $query    =  qq{DELETE FROM $table
WHERE project='$project'
AND username='$username'};
  $self->logDebug("query", $query);
  $self->table()->db()->do($query);
  
  #### CREATE TSV
  my $tempfile  =  $self->createTempTsvFile($username, $project, $tsvfile);

  #### LOAD TSV
  my $success  =  $self->loadTsvFile($table, $tempfile);
  $self->logDebug("success", $success);

  #### CLEAN UP
  `rm -fr $tempfile`;
  
  #### ADD ENTRY TO sampletable TABLE
  if ( $self->table()->db()->hasTable($table) ) {
    $query  =  qq{SELECT 1 FROM sampletable
WHERE username='$username'
AND projectname='$project'
AND sampletable='$table'};
    $self->logDebug("query", $query);
    my $exists = $self->table()->db()->query($query);
    $self->logDebug("exists", $exists);
    
    return if $exists;
  }

  $query  =  qq{INSERT INTO sampletable VALUES
  ('$username', '$project', '$table')};
  $self->logDebug("query", $query);
  $success  =  $self->table()->db()->do($query);
  $self->logDebug("success", $success);

    
  return $success;  
}

method createTempTsvFile ($username, $project, $tsvfile) {
  $self->logDebug("username", $username);
  $self->logDebug("project", $project);
  $self->logDebug("tsvfile", $tsvfile);

  my $userhome = $self->conf()->getKey( "core:USERDIR" ) . "/$username";
  $self->logDebug("userhome", $userhome);
  
  my $lines    =  $self->getLines($tsvfile);
  my $tempfile  =  "$tsvfile.temp";
  my $outputs  =  [];
  foreach my $line ( @$lines ) {
    next if $line =~ /^\s*sample\s+/;
    next if $line =~ /^#/;
    $line = "$username\t$project\t$line";
    $line =~ s/<USERHOME>/$userhome/g;
    push @$outputs,  $line;
  }
  
  open(OUT, ">", $tempfile) or die "Can't open tempfile: $tempfile\n";
  foreach my $output ( @$outputs ) {
    print OUT $output;
  }
  close(OUT) or die "Can't close tempfile: $tempfile\n";

  return $tempfile;
}

method loadTsvFile ($table, $file) {
  $self->logCaller("");
  $self->logDebug("table", $table);
  $self->logDebug("file", $file);  

  # my $dbtype = $self->conf()->getKey("database:DBTYPE");
  # $self->logDebug("dbtype", $dbtype);
  # my $query = qq{LOAD DATA LOCAL INFILE '$file' INTO TABLE $table};
  # if ( $dbtype eq "SQLite" ) {
  #   $query = ".mode tabs $table; .import $file $table";
  # }
  # $self->logDebug("query", $query);
  my $success = $self->table()->db()->importFile( $table, $file );
  $self->logCritical("load data failed") if not $success;
  
  return $success;  
}

method installedVersions ($packagename) {
  my $query  =  qq{SELECT packagename,installdir, version
FROM package
WHERE packagename='$packagename'};
  $self->logDebug("query", $query);
  
  return $self->table()->db()->queryhasharray($query);
}

method getDependencyVersion ($packagename) {
  $self->logDebug("packagename", $packagename);
  
  my $dependencies = $self->opsinfo()->dependencies();
  $self->logDebug("dependencies", $dependencies);

  foreach my $dependency ( @$dependencies ) {
    return $dependency->{version} if $dependency->{packagename} eq $packagename;
  }
  
  return undef;
}

method checkInputs () {
  $self->logDebug("");

  my  $username     = $self->username();
  my  $version    = $self->version();
  my  $packagename  = $self->packagename();
  my  $repotype     = $self->repotype();
  my  $owner      = $self->owner();
  my  $privacy    = $self->privacy();
  my  $repository   = $self->repository();
  my  $installdir   = $self->installdir();
  my  $random     = $self->random();

  if ( not defined $packagename or not $packagename ) {
    $packagename = $self->repository();
    $self->packagename($packagename);
  }
  $self->logError("owner not defined") and exit if not defined $owner;
  $self->logError("packagename not defined") and exit if not defined $packagename;
  $self->logError("version not defined") and exit if not defined $version;
  $self->logError("username not defined") and exit if not defined $username;
  $self->logError("installdir not defined") and exit if not defined $installdir;
  
  $self->logDebug("owner", $owner);
  $self->logDebug("packagename", $packagename);
  $self->logDebug("username", $username);
  $self->logDebug("repotype", $repotype);
  $self->logDebug("repository", $repository);
  $self->logDebug("installdir", $installdir);
  $self->logDebug("privacy", $privacy);
  $self->logDebug("version", $version);
  $self->logDebug("random", $random);
}

method installPackage ($packagename) {
  $self->logDebug("packagename", $packagename);
  return 0 if not defined $packagename or not $packagename;
  $self->logDebug("packagename", $packagename);
  
  if ( -f "/usr/bin/apt-get" ) {
    remove_tree( "/var/lib/dpkg/lock");
    $self->runCommand("dpkg --configure -a");
    $self->runCommand("rm -fr /var/cache/apt/archives/lock");
    $ENV{'DEBIAN_FRONTEND'} = "noninteractive";
    $self->runCommand("/usr/bin/apt-get -q -y install $packagename");
  }
  elsif ( -f "/usr/bin/yum" ) {
      $self->runCommand("rm -fr /var/run/yum.pid");
      $self->runCommand("/usr/bin/yum -y install $packagename");
  }  
}

method getPackageManager() {

  if ( -f "/usr/bin/apt-get" ) {
    return "apt";  
  }
  elsif ( -f "/usr/bin/yum" ) {
    return "yum";  
  }
  elsif ( -f "/usr/local/bin/brew" ) {
    return "brew";
  }

  return undef;
}


method saveChanges ($installdir, $version) {
  $self->changeToRepo($installdir);
  my $stash = $self->stashSave("before upgrade to $version");
  $self->logDebug("stash", $stash);
  if ( $stash ) {
    #$self->logger()->write("Stashed changes before checkout version: $version");
  }  
}

method runCustomInstaller ($command) {
  $self->logDebug("command", $command);
  print $self->runCommand($command);
}

method verifyVersion ($installdir, $version) {
  $self->logDebug("version", $version);
  $self->logDebug("installdir", $installdir);

  $version = $self->customTag( $version ) if $self->can( "customTag" );

  return if not -d $installdir;
  $self->changeToRepo($installdir);  
  my ($currentversion) = $self->currentLocalTag();
  
  if ( $version eq "latest" or $version eq "max" and defined $currentversion ) {
    return $self->version($currentversion);
  }

  return if not defined $currentversion or not $currentversion;
  $currentversion =~ s/\s+//g;
  if ( $currentversion ne $version ) {
    #### UPDATE PACKAGE STATUS
    $self->updateStatus("error");
    $self->logCritical("Current version ($currentversion) does not match the requested version ($version). Are you sure the requested version is correct?");
  }
}

method reducePath ($path) {
  while ( $path =~ s/[^\/]+\/\.\.\///g ) { }
  
  return $path;
}

method getArch {
  my $arch = $self->arch();
  $self->logDebug("STORED arch", $arch) if defined $arch;

  return $arch if defined $arch;
  
  $arch   =   "linux";
  my $command = "uname -a";
  my $output = `$command`;
  #$self->logDebug("output", $output);
  
  #### Linux ip-10-126-30-178 2.6.32-305-ec2 #9-Ubuntu SMP Thu Apr 15 08:05:38 UTC 2010 x86_64 GNU/Linux
  $arch  =   "ubuntu" if $output =~ /ubuntu/i;
  #### Linux ip-10-127-158-202 2.6.21.7-2.fc8xen #1 SMP Fri Feb 15 12:34:28 EST 2008 x86_64 x86_64 x86_64 GNU/Linux
  $arch  =   "centos" if $output =~ /fc\d+/;
  $arch  =   "centos" if $output =~ /\.el\d+\./;
  $arch  =   "debian" if $output =~ /debian/i;
  $arch  =   "freebsd" if $output =~ /freebsd/i;
  $arch  =   "osx" if $output =~ /darwin/i;

  $self->arch($arch);
  $self->logDebug("FINAL arch", $arch);
  
  return $arch;
}
method installCpanm {
  $self->changeDir("/usr/bin");
  $self->runCommand("curl -LOk http://xrl.us/cpanm");
  $self->runCommand("chmod 755 cpanm");
}

method installAnt {
  my $arch = $self->getArch();
  $self->logDebug("arch", $arch);
  $self->runCommand("apt-get -y install ant") if $arch eq "ubuntu";
  $self->runCommand("yum -y install ant") if $arch eq "centos";  
}

method getBaseDir ($installdir) {
  $self->logDebug("installdir", $installdir);  
  my ($basedir)   =   $installdir  =~  /^(.+?)\/[^\/]+$/;

  return $basedir;
}

#### LOAD FILES
method loadOpsModule ($pmfile, $opsdir, $repository) {
  $self->logCaller("");
  $self->logDebug("pmfile", $pmfile);
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("repository", $repository);

  return if not defined $opsdir;
  
  my $modulename = lc($repository);
  $modulename =~ s/[\-]+//g;
  $self->logDebug("modulename", $modulename);

  if ( not defined $pmfile or $pmfile eq "" ) {
    $pmfile   =   "$opsdir/$modulename/$modulename.pm";
  }
  $self->logDebug("pmfile: $pmfile");

  
  if ( -f $pmfile ) {
    $self->logDebug("Found modulefile: $pmfile");
    # $self->logDebug("Doing require $modulename");
    unshift @INC, $opsdir;
    my ($olddir) = `pwd` =~ /^(\S+)/;
    $self->logDebug("olddir", $olddir);

    my $moduledir = "$opsdir/$modulename";
    eval "use lib '$moduledir'";
    Moose::Util::apply_all_roles( $self, $modulename );
  }
  else {
    $self->logDebug("\nCan't find pmfile: $pmfile\n");
    print "Install::loadOpsModule  Can't find pmfile: $pmfile\n";
    if ( not $repository ) {
      exit;
    }
    print "Install::loadOpsModule   Using repository: $repository\n";
  }
  $self->opsmodloaded(1);
}

method loadOpsInfo ($opsfile, $opsdir, $packagename) {
  $self->logDebug("opsfile", $opsfile);
  $self->logDebug("opsdir", $opsdir);
  $self->logDebug("packagename", $packagename);
  
  return if not defined $opsdir or not $opsdir;

  #### REMOVE -
  $packagename =~ s/[\-]+//g;
  $self->logDebug("packagename", $packagename);

  if ( not defined $opsfile or $opsfile eq "" ) {
    $opsfile   =   "$opsdir/" . lc($packagename) . "/" . lc($packagename) . ".ops";
  }
  $self->logDebug("opsfile: $opsfile");
  
  if ( -f $opsfile ) {
    $self->logDebug("Found modulefile: $opsfile");
    $self->logDebug("Parsing opsfile");
    my $opsinfo = $self->setOpsInfo($opsfile);
    # $self->logDebug("opsinfo", $opsinfo);
    $self->opsinfo($opsinfo);
    
    #### LOAD VALUES FROM INFO FILE
    $self->packagename($opsinfo->packagename()) if not defined $self->packagename();
    $self->repository($opsinfo->repository()) if not defined $self->repository();
    $self->version($opsinfo->version()) if not defined $self->version();

    #### SET PARAMS
    my $params = $self->opsfields();
    foreach my $param ( @$params ) {
      # $self->logDebug("param", $param);
      # $self->logDebug("self->$param()", $self->$param());
      if ( $self->can($param)
        and (not defined $self->$param()
          or  $self->$param() eq "" )
        and $self->opsinfo()->can($param)
        and defined $self->opsinfo()->$param() ) {
        $self->logDebug("Setting self->$param using opsinfo->$param", $self->opsinfo()->$param());
        $self->$param($self->opsinfo()->$param())
      }
    }
  }
  else { 
    $self->logDebug("Can't find opsfile", $opsfile);
    
    print "Can't find opsfile: $opsfile\n";
  }
  
  #### SET GITHUB AS DEFAULT HUB TYPE
  $self->hubtype("github") if not defined $self->hubtype() or $self->hubtype() eq "";
  
}

method updateTable ($object, $table, $required, $updates) {
  $self->logCaller("object", $object);
  $self->logDebug("required", $required);

  #### SET DEFAULT OBJECT
  $object->{owner} = $object->{username} if not defined $object->{owner};
  
  my $where = $self->table()->db()->where($object, $required);
  my $query = qq{SELECT 1 FROM $table $where};
  $self->logDebug("query", $query);
  my $exists = $self->table()->db()->query($query);
  $self->logDebug("exists", $exists);

  if ( not $exists ) {
    my $fields = $self->table()->db()->fields($table);
    my $insert = $self->table()->db()->insert($object, $fields);
    $query = qq{INSERT INTO $table VALUES ($insert)};
    $self->logDebug("query", $query);
    $self->table()->db()->do($query);
  }
  else {
    my $set = $self->table()->db()->set($object, $updates);
    $query = qq{UPDATE package $set$where};
    $self->logDebug("query", $query);
    $self->table()->db()->do($query);
  }
}

method updateReport ($lines) {
  $self->logWarning("non-array input") if ref($lines) ne "ARRAY";
  return if not defined $lines or not @$lines;
  my $text = join "\n", @$lines;
  
  $self->logReport($text);
  print "$text\n" if $self->showreport();
  
  my $report = $self->report();
  $report .= "$text\n";
  $self->report($report);
}

method updatePackage ($owner, $username, $packagename, $version, $originalversion, $envartext ) {
  $self->logDebug("owner", $owner);
  $self->logDebug("username", $username);
  $self->logDebug("packagename", $packagename);
  $self->logDebug("version", $version);
  # $self->logDebug( "self", $self );

  my $description = "";
  $description = $self->opsinfo()->description() if defined $self->opsinfo();
  my $website = "";
  $website = $self->opsinfo()->website() if defined $self->opsinfo();

  my $privacy = $self->privacy();
  if ( not $privacy and $self->opsinfo() ) {
    $privacy = $self->opsinfo()->privacy();
  }

  $self->logDebug( "self->status()", $self->status() );
  my $status = $self->status() || "ok";
  if ( $originalversion eq "latest" ) {
    $status = $originalversion;
  }
  if ( $self->status() ) {
    $status = $self->status();
  }

  #### UPDATE DATABASE    
  my $object = {
    owner       =>    $owner,
    username    =>    $username,
    packagename =>    $packagename,
    repository  =>    $self->repository() || "",
    status      =>    $status,
    envars      =>    $envartext,
    version     =>    $version,
    opsdir      =>    $self->opsdir() || '',
    installdir  =>    $self->installdir() . "/$version",
    privacy     =>    $privacy,
    description =>    $description,
    website     =>    $website
  };
  $self->logDebug("object", $object);

  my $table = "package";
  my $fields  =  $self->table()->db()->fields($table);
  $self->logDebug("fields", $fields);
  my $required = ["username", "packagename", "version"];
  
  return $self->updateTable($object, $table, $required, $fields);
}
method deletePackage ($owner, $username, $packagename) {
  $self->logDebug("owner", $owner);
  $self->logDebug("username", $username);
  $self->logDebug("packagename", $packagename);

  #### UPDATE DATABASE
  my $object = {
    owner        =>  $owner,
    username    =>  $username,
    packagename    =>  $packagename
  };
  $self->logDebug("object", $object);

  my $table = "package";
  my $fields  =  $self->table()->db()->fields($table);
  my $required = ["owner", "username", "packagename"];
  
  return $self->table()->db()->_removeFromTable($table, $object, $required);  
}
method updateStatus ($status) {

  $self->logDebug("status", $status);
  #### UPDATE DATABASE
  my $object = {
    username    =>  $self->username(),
    owner      =>  $self->owner(),
    packagename    =>  $self->packagename(),
    repository    =>  $self->repository(),
    status      =>  $status,
    version      =>  $self->version(),
    opsdir      =>  $self->opsdir() || '',
    installdir    =>  $self->installdir()
  };
  $self->logDebug("object", $object);
  
  my $table = "package";
  my $required = ["username", "packagename"];
  my $updates = ["status", "installed"];
  
  return $self->updateTable($object, $table, $required, $updates);
}

method updateVersion ($version) {
  #### UPDATE DATABASE
  my $object = {
    username    =>  $self->username(),
    owner        =>  $self->owner(),
    packagename    =>  $self->packagename(),
    repository    =>  $self->repository(),
    version      =>  $version,
    opsdir      =>  $self->opsdir() || '',
    installdir    =>  $self->installdir()
  };
  $self->logNote("object", $object);
  
  my $table = "package";
  my $required = ["username", "packagename"];
  my $updates = ["version"];
  
  return $self->updateTable($object, $table, $required, $updates);
}

method validateVersion ($login, $repository, $privacy, $version) {
#### VALIDATE VERSION IF SUPPLIED, OTHERWISE SET TO LATEST VERSION
  $self->logCaller("");
  $self->logDebug("login", $login);
  $self->logDebug("repository", $repository);
  $self->logDebug("privacy", $privacy);
  
  my $tags = $self->getRemoteTags($login, $repository, $privacy);
  $self->logDebug("tags", $tags);

  return if not defined $tags or not @$tags;

  foreach my $tag ( @$tags ) {
    return 1 if $tag->{name} eq $version;
  }

  return 0;
}

method getHighestVersion ( $packagename ) {
  my $username = $self->username();
  $self->logDebug("username", $username);

  my $query = "SELECT version FROM package
WHERE packagename='$packagename'
AND username='$username'";
  $self->logDebug("query", $query);
  my $versions = $self->table()->db()->queryarray( $query );
  $self->logDebug("versions", $versions);

  $versions = $self->sortVersions( $versions );
  $self->logDebug("SORTED versions", $versions);
  return undef if not defined $versions;

  my $version = $$versions[ scalar( @$versions ) - 1 ];

  return $version;
}

method getLatestVersion ($login, $repository, $privacy) {
#### VALIDATE VERSION IF SUPPLIED, OTHERWISE SET TO LATEST VERSION
  $self->logCaller("");
  $self->logDebug("login", $login);
  $self->logDebug("repository", $repository);
  $self->logDebug("privacy", $privacy);
  
  my $tags = $self->getRemoteTags($login, $repository, $privacy);
  #$self->logDebug("tags", $tags);

  return if not defined $tags or not @$tags;
  
  #### SORT VERSIONS
  my $tagarray;
  $tagarray = $self->hasharrayToArray($tags, "name");
  $tagarray = $self->sortVersions($tagarray);
  $self->logDebug("tagarray", $tagarray);

  ##### ORDER: FIRST TO LAST
  #@$tagarray = reverse(@$tagarray);
  
  return $$tagarray[scalar(@$tagarray) - 1];
}

#### GET/SETTERS 
method getParentChildDirs ($directory) {
  my ($parent, $child) = $directory =~ /^(.+)*\/([^\/]+)$/;
  $parent = "/" if not defined $parent;

  return if not defined $child;
  return $parent, $child;
}

method setOpsInfo ($opsfile) {  
  my $opsinfo = Ops::Info->new({
    inputfile  =>  $opsfile,
    logfile    =>  $self->logfile(),
    # log    =>  4,
    # printlog  =>  4,
    # db         => $self->table()->db()
    log    =>  $self->log(),
    printlog  =>  $self->printlog()
  });
  #$self->logDebug("opsinfo", $opsinfo);

  return $opsinfo;
}

method getFileExports ($file) {
  open(FILE, $file) or die "Can't open file: $file: $!";

  my $exports  =  "";
  while ( <FILE> ) {
    next if $_  =~ /^#/ or $_ =~ /^\s*$/;
    chomp;
    $exports .= "$_; ";
  }

  return $exports;
}

method collapsePath ($string) {
  return if not defined $string;
  
  while ($string =~ s/\/[^\/^\.]+\/\.\.//g ) { }
  
  return $string;
}

method getPwd {
  my $pwd = `pwd`;
  $pwd =~ s/\s+$//;

  return $pwd;
}

1;


# method setConfigVersion ($packagename, $version) {
# #### UPDATE VERSION IN CONFIG FILE
#   $self->logDebug("packagename", $packagename);
#   $self->logDebug("version", $version);

#   $self->logDebug("Setting version in conf file, version", $version);
#   $self->conf()->setKey("$packagename:VERSION", $version);
# }


# method loadConfig ($configfile, $mountpoint, $installdir) {
#   my $packageconf = Conf::Yaml->new({
#     inputfile  =>  $configfile,
#     log    =>  2
#   });

#   $self->logNote("packageconf: $packageconf");
  
#   my $sectionkeys = $packageconf->getSectionKeys();
#   foreach my $sectionkey ( @$sectionkeys ) {
#     $self->logNote("sectionkey", $sectionkey);
#     my $keys = $packageconf->getKeys($sectionkey);
#     $self->logNote("keys", $keys);
    
#     #### NB: WILL NOT TRANSFER COMMENTS!!
#     foreach my $key ( @$keys ) {
#       my $value = $packageconf->getKey("$sectionkey:$key");
#       $value =~ s/<MOUNTPOINT>/$mountpoint/g;
#       $value =~ s/<INSTALLDIR>/$installdir/g;
#       $self->logNote("value", $value);
#       $self->conf()->setKey("$sectionkey:$key", $value);
#     }
#   }
# }

# #### UPDATE
# method updateConfig ($sourcefile, $targetfile) {
#   $self->logDebug("sourcefile", $sourcefile);
#   $self->logDebug("targetfile", $targetfile);

#   my $sourceconf = Conf::Yaml->new({
#     inputfile  =>  $sourcefile,
#     log    =>  2
#   });
#   $self->logNote("sourcefile: $sourcefile");

#   my $targetconf = Conf::Yaml->new({
#     inputfile  =>  $targetfile,
#     log    =>  2
#   });
#   $self->logNote("targetconf: $targetconf");

#   my $sectionkeys = $sourceconf->getSectionKeys();
#   foreach my $sectionkey ( @$sectionkeys ) {
#     $self->logNote("source sectionkey", $sectionkey);
#     my $keys = $sourceconf->getKeys($sectionkey);
#     $self->logNote("source keys", $keys);
    
#     #### NB: WILL NOT TRANSFER COMMENTS!!
#     foreach my $key ( @$keys ) {
#       my $value = $sourceconf->getKey("$sectionkey:$key");
#       if ( not $targetconf->hasKey("$sectionkey:$key") ) {
        
#         $self->logNote("key $key value", $value);
        
#         $targetconf->setKey("$sectionkey:$key", $value);
#       }
#     }
#   }
# }

# method setConfKey ($installdir, $packagename, $version, $opsinfo) {
#   $self->logDebug("packagename", $packagename);
#   $self->logDebug("version", $version);
#   #$self->logDebug("opsinfo", $opsinfo);
#   print "Can't update config file - 'version' not defined\n" and exit if not defined $version;

#   my $current  =  $self->conf()->getKey("packages:$packagename");
#   undef $current->{$version};
#   $current->{$version} = {
#     #AUTHORS   =>   $opsinfo->authors(),
#     #PUBLICATION  =>  $opsinfo->publication(),
#     INSTALLDIR  =>  "$installdir/$version",
#   };

#   $self->conf()->setKey("packages:$packagename", $current);
# }

