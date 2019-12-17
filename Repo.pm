use MooseX::Declare;
use Method::Signatures::Simple;

=head2

	PACKAGE		Ops::Repo
	
	PURPOSE
	
		LOCAL GITHUB REPOSITORY CLASS

=cut

class Ops::Repo with (Util::Logger, Ops::Version) {

has 'reponame'	=> ( isa => 'Str|Undef', is => 'rw', required => 1	);
has 'branch'		=> ( isa => 'Str|Undef', is => 'rw', default => "master"	);
has 'basedir'		=> ( isa => 'Str|Undef', is => 'rw', required => 1	);
has 'tmpdir'		=> ( isa => 'Str|Undef', is => 'rw', default => "/tmp"	);

use FindBin qw($Bin);
use lib "$Bin/../..";

#### EXTERNAL MODULES
use Data::Dumper;
use File::Path;
use JSON;

method changeToRepo ($directory) {
	#### DO NOTHING BECAUSE runCommand CHANGES TO REPO DIR AND BACK
}

method createVersionFile ($repodir, $message, $version, $versiontype, $versionformat, $versionfile, $branch, $releasename) {
#### CREATE/INCREMENT VERSION FILE AND ADD GIT TAG OF VERSION IN REPOSITORY

	$self->logDebug("repodir", $repodir);
	$self->logDebug("message", $message);
	$self->logDebug("version", $version);
	$self->logDebug("versiontype", $versiontype);
	$self->logDebug("versionfile", $versionfile);
	$self->logDebug("versionformat", $versionformat);
	$self->logDebug("branch", $branch);

	#### SET VERSION IF DEFINED
	if ( defined $version ) {
		my ($result, $error) = $self->setVersion($versionformat, $repodir, $versionfile, $branch, $version, $message);
		$self->logDebug("result", $result);
		$self->logDebug("error", $error);
		#print "\n\n$error\n\n" and exit if not $result;
		$self->logDebug("\nCreated new version: $version\n\n");
	}
	#### OTHERWISE, INCREMENT VERSION
	else {
		$version = $self->incrementVersion($versionformat, $versiontype, $repodir, $versionfile, $releasename, $message, $branch);
		$self->logDebug("Created new version", $version);
	}
	
	return $version
}

method exitRepo () {
	$self->logNote("");
	$self->clearChangeDir();
}
method foundGitDir ($directory) {
	$self->logCritical("directory not defined") and exit if not defined $directory;
	my $gitrefs = "$directory/.git";
	$self->logDebug("gitrefs", $gitrefs);
	my $lines = `find $gitrefs -type d -name refs 2> /dev/null`;
	return 1 if $lines;
	return 0;	
}

#### LOGS
method gitLog ($branch) {
	$branch = "HEAD" if not defined $branch;
	return $self->repoCommand("git log $branch");
}

method gitLogShort ($branch) {
	$branch = "HEAD" if not defined $branch;
	return $self->repoCommand("git log --short $branch");
}

method gitStatus {	
	#### FORCE ERROR OUTPUT TO STDERR
	my $oldwarn = $self->warn();
	$self->warn(1);
	my ($result, $error) = $self->repoCommand("git status");
	$self->warn($oldwarn);

	#### fatal: Not a git repository (or any of the parent directories): .git
	return 0 if $error =~ /Not a git repository/;
	return 1;	
}

#### CREATE/ADD/COMMIT TO REPO
method initRepo {
	$self->logDebug("");
	my ($result, $error) = $self->runCommand("git init");
	return 0 if defined $error and $error;
	return 1;	
}

method createBasedir {
	my $targetdir = $self->{basedir};
	my $command = "mkdir -p $targetdir";
	$self->runCommand($command);
	$self->logError("Can't create target repo directory: $targetdir. Exiting.") and exit if not -d $targetdir;
}

method addToRepo {
	my ($result, $error) = $self->runCommand("git add --ignore-errors .");
	$self->logDebug("result", $result);
	$self->logDebug("error", $error);
}

#### COMMIT/PUSH
method commitToRepo ($message) {
	$self->logDebug("message", $message);
	$message =~ s/\n/ \\\n/msg;
	$self->logDebug("message", $message);

	my $command = "git commit -a";
	$command .= qq{ -m "$message" --cleanup=verbatim } if $message ne ""; 
	$self->logDebug("command", $command);
	my ($result, $error) = $self->runCommand($command);	
	$self->logDebug("result", $result) if $result;
	$self->logDebug("error", $error) if $error;

	return $result, $error;
}

#### TAGS
method addLocalTag ($tag, $description) {
	$description =~ s/\n/ /msg;
	$self->logDebug("tag", $tag);
	$self->logDebug("description", $description);
	my $command = qq{git tag -a $tag};
	$command .= qq{ -m "[$tag] $description"} if defined $description;

	$self->runCommand($command);
}

method pushTags ($login, $hubtype, $remote, $branch, $keyfile) {
	$self->logDebug("remote", $remote);
	$self->logDebug("branch", $branch);
	$branch = '' if not defined $branch;

	my $gitssh = $self->setGitSsh($login, $hubtype, $keyfile);
	my $command = "export GIT_SSH=$gitssh; git push -u $remote $branch --tags";
	$self->logDebug("command", $command);
	$self->repoCommand($command);
}

method getLocalTags () {
	my ($output) = $self->repoCommand("git tag");
	my @tags = split "\n", $output;
	return \@tags;
}

method currentLocalTag () {
	my $command = "git describe --abbrev=0 --tags";
	$self->logDebug("command", $command);
	my ($output) = $self->repoCommand($command);
	$output	=~	s/\s+$//;
	$self->logDebug("output", $output);
	
	return $output;
}

method checkoutTag($repodir, $tag) {
	$self->logCaller("");
	$self->logDebug("repodir", $repodir);
	$self->logDebug("tag", $tag);

	my $gitdir = "$repodir/.git";
	$self->logError("Can't find gitdir: $gitdir") and exit if not -d $gitdir;
	chdir($gitdir);

	my $command = "git checkout $tag --force";
	$self->logDebug("command", $command);
	my ($output, $error) = $self->repoCommand($command);
	$output = "" if not defined $output;
	#$self->logDebug("output", $output);
	my @tags = split "\n", $output;
	return \@tags;
}

method stashSave($message) {
	#my $command = qq{git stash save --keep-index "$message"};
	my $command = qq{git stash save "$message"};
	$self->logDebug("command", $command);
	my ($result) = $self->repoCommand($command);
	$self->logDebug("result", $result);
	return 0 if $result =~ /No local changes to save/;
	
	return 1;
}
#### BRANCH
method checkoutBranch ($branch) {	
	$self->logDebug("branch", $branch);

	#### VERIFY git REPO
	$self->logError("Can't find .git directory. Not a git repo? Exiting.") and exit if not $self->isGitRepo();

	my $command = "git checkout $branch";
	$self->logDebug("command", $command);
	my ($output, $error) = $self->runCommand($command);
	$self->logDebug("output", $output);
	$self->logDebug("error", $error);
}

method createBranch ($branch) {	
	$self->logDebug("branch", $branch);

	#### VERIFY git REPO
	$self->logError("Can't find .git directory. Not a git repo? Exiting.") and exit if not $self->isGitRepo();

	my $command = "git checkout -b $branch";
	$self->logDebug("command", $command);
	my ($output, $error) = $self->runCommand($command);
	$self->logDebug("output", $output);
	$self->logDebug("error", $error);
}

method isGitRepo {
	my $basedir = $self->basedir();
	my $gitdir = "$basedir/.git";
	return 1 if -d $gitdir;
	return 0;
}
#### VERSION
method currentIteration  {
	my ($iteration) = $self->repoCommand("git log --oneline | wc -l");
	$iteration =~ s/\s+//g;	
	$iteration = "0" x ( 5 - length($iteration) ) . $iteration;
	return $iteration;
}

method currentBuild {
	my ($build) = $self->repoCommand("git rev-parse --short HEAD");
	$build =~ s/\s+//g;
	
	return $build;
}

method currentVersion  {
	my ($version, $error) = $self->runCommand("git tag -l");
	$self->logDebug("version", $version);
	$self->logDebug("error", $error);
	
	return $version;
}

method lastRepoVersion ($tags) {
	$self->logDebug("tags", $tags);

	sub sort_tags {
		my ($aa) = $a->{name} =~ /([\.\d]+)/;
		my ($bb) = $b->{name} =~ /([\.\d]+)/;
	}

	@$tags = sort sort_tags (@$tags);
	$self->logDebug("tags", $tags);
	
	my $latest = shift @$tags;
	
	return $latest->{name};
}


#### GET/SETTERS
method getUserName {
	my $command = " git config --global user.name";
	my ($name) = $self->repoCommand($command);
	return $name;
}

method setUserName ($name) {
	my $command = " git config --global user.name $name";
	return $self->repoCommand($command);
}

method getUserEmail {
	my $command = " git config --global user.email";
	my ($email) = $self->repoCommand($command);
	return $email;
}

method setUserEmail ($email) {
	my $command = " git config --global user.email $email";
	return $self->repoCommand($command);
}

#### UTIL

# method runCommand ($command) {
# 	$self->logDebug("XXXXXXXXXXXXX XXXXXXXXX command", $command);
	
# 	my $pwd = $self->getPwd();
# 	$self->logDebug("**** INITIAL pwd", $pwd);
# 	$self->logDebug("**** CHANGING TO self->basedir()", $self->basedir());
# 	chdir($self->basedir());

# 	my $tmpdir = $self->tmpdir();
# 	my $stdoutfile = "/$tmpdir/$$.out";
# 	my $stderrfile = "/$tmpdir/$$.err";
# 	my $output = '';
# 	my $error = '';
	
# 	#### TAKE REDIRECTS IN THE COMMAND INTO CONSIDERATION
# 	if ( $command =~ />\s+/ ) {
# 		#### DO NOTHING, ERROR AND OUTPUT ALREADY REDIRECTED
# 		if ( $command =~ /\s+&>\s+/
# 			or ( $command =~ /\s+1>\s+/ and $command =~ /\s+2>\s+/)
# 			or ( $command =~ /\s+1>\s+/ and $command =~ /\s+2>&1\s+/) ) {
# 			print `$command`;
# 		}
# 		#### STDOUT ALREADY REDIRECTED - REDIRECT STDERR ONLY
# 		elsif ( $command =~ /\s+1>\s+/ or $command =~ /\s+>\s+/ ) {
# 			$command .= " 2> $stderrfile";
# 			print `$command`;
# 			$error = `cat $stderrfile`;
# 		}
# 		#### STDERR ALREADY REDIRECTED - REDIRECT STDOUT ONLY
# 		elsif ( $command =~ /\s+2>\s+/ or $command =~ /\s+2>&1\s+/ ) {
# 			$command .= " 1> $stdoutfile";
# 			print `$command`;
# 			$output = `cat $stdoutfile`;
# 		}
# 	}
# 	else {
# 		$command .= " 1> $stdoutfile 2> $stderrfile";
# 		print `$command`;
# 		$output = `cat $stdoutfile`;
# 		$error = `cat $stderrfile`;
# 	}
	
# 	$self->logNote("output", $output) if $output;
# 	$self->logNote("error", $error) if $error;
	
# 	##### CHECK FOR PROCESS ERRORS
# 	$self->logError("Error with command: $command ... $@") and exit if defined $@ and $@ ne "" and $self->can('warn') and not $self->warn();

# 	#### CLEAN UP
# 	`rm -fr $stdoutfile`;
# 	`rm -fr $stderrfile`;
# 	chomp($output);
# 	chomp($error);
	
# 	$self->logDebug("*** self->getPwd()", $self->getPwd());
# 	$self->logDebug("*** FINAL pwd", $pwd);
# 	chdir($pwd);

# 	return $output, $error;
# }

method getPwd {
	my $pwd = `pwd`;
	$pwd =~ s/\s+$//;

	return $pwd;
}

method printToFile ($file, $text) {
	$self->logDebug("file", $file);

	$self->createParentDir($file);
	
	#### PRINT TO FILE
	open(OUT, ">$file") or $self->logCaller() and $self->logCritical("Can't open file: $file") and exit;
	print OUT $text;
	close(OUT) or $self->logCaller() and $self->logCritical("Can't close file: $file") and exit;	
}

method createParentDir ($file) {
	#### CREATE DIR IF NOT PRESENT
	my ($directory) = $file =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("directory", $directory);
	mkpath( $directory ) if $directory and not -d $directory;
	
	return -d $directory;
}



}