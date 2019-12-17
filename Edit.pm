package Ops::Edit;
use Moose::Role;
use Method::Signatures::Simple;

#### METHODS FOR EDITING FILES

# String
has 'from'     	=> ( isa => 'Str|Undef', is => 'rw' );
has 'to'       	=> ( isa => 'Str|Undef', is => 'rw' );
has 'inputfile'	=> ( isa => 'Str|Undef', is => 'rw' );
has 'outputfile'=> ( isa => 'Str|Undef', is => 'rw' );

use YAML::Tiny;
use JSON;
use TryCatch;

method convert {
	my $inputfile = $self->inputfile();
	my $outputfile = $self->outputfile();
	my $from = $self->from();
	my $to = $self->to();
	$self->logDebug("inputfile", $inputfile);
	$self->logDebug("outputfile", $outputfile);
	$self->logDebug("from", $from);
	$self->logDebug("to", $to);
	
	#### CHECK INPUTS
	print "'from' not supported: $from\n" and return if not $from =~ /^(json|yaml)$/;
	print "'to' not supported: $to\n" and return if not $to =~ /^(json|yaml)$/;
	print "'from' $from and 'to' $to must differ\n" and return if $from eq $to;

	#### PARSE FILE
	if ( $from eq "json" ) {
		$self->convertJsonToYaml($inputfile, $outputfile);
	}
	elsif ( $from eq "yaml" ) {
		$self->convertJsonToYaml($inputfile, $outputfile);
	}
}

method convertJsonToYaml ($inputfile, $outputfile) {
	my $data = $self->parseJsonFile($inputfile);
	$self->printYamlFile($outputfile, $data);
}

method convertYamlToJson ($inputfile, $outputfile) {
	my $data = $self->parseYamlFile($inputfile);	
	$self->printJsonFile($outputfile, $data);
}

method parseYamlFile ($inputfile) {
	try {
		my $yaml = YAML::Tiny->read($inputfile);
		return $$yaml[0];
	}
	catch {
		 $self->logCritical("Can't open inputfile: $inputfile");
		 return undef
	}
}

method parseJsonFile ($inputfile) {
	$self->logDebug("inputfile", $inputfile);
	open(FILE, $inputfile) or die "Can't open inputfile: $inputfile\n";
	my $temp = $/;
	$/ = undef;
	my $contents = <FILE>;
	close(FILE) or die "Can't close inputfile: $inputfile\n";
	
	my $parser = JSON->new();
	try {
		return $parser->decode($contents);
	}
	catch {
		return undef;
	}
}

method writeJsonFile ($outputfile, $data) {
	$self->logDebug("outputfile", $outputfile);

	my $parser = JSON->new();
	try {
		my $contents = $parser->encode($data);
		return $self->toFile($outputfile, $contents);
	}
	catch {
		$self->logError("Can't write to outputfile: $outputfile");
		return undef;
	}
}

method writeYamlFile ($outputfile, $data) {
	$self->logDebug("outputfile", $outputfile);
	my $yaml = YAML::Tiny->new();
	try {
		$$yaml[0] = $data;
		return $yaml->write($outputfile);
	}
	catch {
		$self->logError("Can't write to outputfile: $outputfile");
		return undef;
	}
}

method toFile ($file, $text) {
#### SIMPLE ECHO REDIRECT TO FILE
	$self->logCaller("");

	my ($dir) = $file =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("dir", $dir);
	my $found = -d $dir;
	$self->logDebug("BEFORE COMMAND dir found", $found);
	
	$self->logDebug("file", $file);
	$self->logDebug("text", $text);
	my $command = qq{echo "$text" > $file};
	$self->logDebug("command", $command);
	
	return $self->runCommand($command);
}

method verifyContents ($file, $text) {
	$self->logDebug("file", $file);
	$self->logDebug("text", $text);
	my ($contents, $error) = $self->util()->fileContents($file);
	$self->logDebug("contents", $contents);
	my $chomped = $contents;
	$chomped = chomp($chomped);

$self->logDebug("contents", $contents);
$self->logDebug("chomped", $chomped);
	return 0 if $text ne $contents and $text ne $chomped;	
	return 1;
}

method writeFile ($file, $text) {
#### WRITE TEMP FILE TO /tmp THEN COPY TO DESTINATION
	my $tempdir = $self->tempdir() || "/tmp";
	my ($filename) = $file =~ /([^\/]+)$/;
	$self->logDebug("filename", $filename);
	my $tempfile = "$tempdir/$filename.$$." .rand(1000000);
	$self->logDebug("tempfile", $tempfile);
	open(OUT, ">$tempfile") or die "Can't open tempfile: $tempfile\n";
	print OUT $text;
	close(OUT) or die "Can't close tempfile: $tempfile\n";

	#### OPTIONAL BACKUP
	if ( $self->backup() )
	{
		my $backupfile = $self->incrementFile($file);
	    $self->logDebug("backupfile", $backupfile);
		$self->backupFile($file, $backupfile);
	}

	return $self->copyFile($tempfile, $file) if not defined $self->ssh();
	return $self->uploadFile($tempfile, $file);
}

method removeLines ($lines, $removes) {
#### EXCISE LINES CONTAINING TEXT LINES TO BE REMOVED
	$self->logDebug("Ops::removeLines(lines, removes)");
	$removes = [ $removes ] if ref($removes) eq '';
	
	$self->logError("lines is not defined") and exit if not defined $lines;	
	return $lines if not defined $removes or $removes == [];
	for ( my $i = 0; $i < @$lines; $i++ )
	{
		foreach my $remove ( @$removes )
		{
			if ( $$lines[$i] =~ /^$remove$/ )
			{
				splice @$lines, $i, 1;
				$i--;
			}
		}
	}
	
	return $lines;
}
	
method pushLines ($lines, $pushlines) {
#### PUSH LINEST END OF TEXT
	$self->logError("lines is not defined") and exit if not defined $lines;	
	return $lines if not defined $pushlines or $pushlines == [];
	foreach my $pushline ( @$pushlines )
	{
		push @$lines, $pushline . "\n";
	}

	return $lines;
}




method replaceInFile ($file, $removes, $inserts) {
#### REPLACE TEXT IN FILE WITH INSERTS
	$self->logDebug("Ops::replaceInFile(file, removes, inserts)");
	my $contents = $self->runCommand("cat $file"); 
	$self->logDebug("BEFORE", $contents);
	
	#### REMOVE EXISTING ENTRY FOR THESE VOLUMES
	my $lines;
	@$lines = split "\n", $contents;
	$lines = $self->replaceLines($lines, $removes, $inserts);
	$self->logDebug("AFTER lines @$lines");
	my $output = join "\n", @$lines;
	
	return $self->toFile($file, $output);
}

method replaceLines ($lines, $removelines, $insertlines) {
#### EXCISE LINES CONTAINING TEXT LINES TO BE REMOVED
	$self->logError("lines is not defined") and exit if not defined $lines;	
	$self->logError("removelines is not defined") and exit if not defined $removelines;	
	$self->logError("insertlines is not defined") and exit if not defined $insertlines;	
	$self->logError("removelines (", scalar(@$removelines), ") is not the same length as insertlines(" . scalar(@$insertlines) . ")") and exit if not scalar(@$removelines) == scalar(@$insertlines);	
	for ( my $i = 0; $i < @$lines; $i++ )
	{
		for ( my $k = 0; $k < @$insertlines; $k++ )
		{
			use re 'eval';
			splice @$lines, $i, 1, $$insertlines[$k] if $$lines[$i] =~ /$$removelines[$k]/;
			no re 'eval';
		}
	}
	return $lines;
}

method removeInsertFile ($file, $removes, $inserts) {
#### REPLACE TEXT IN FILE WITH INSERTS
	$self->logDebug("Ops::removeInsertFile(file, removes, inserts)");
	$self->logDebug("removes: @$removes");
	$self->logDebug("inserts: @$inserts");

	my $lines = $self->fileLines($file);
	$lines = $self->removeLines($lines, $removes);
	$lines = $self->pushLines($lines, $inserts);
	my $output = join "\n", @$lines;
	
	return $self->writeFile($file, $output);
}

method fileLines ($file) {
#### GET THE LINES FROM A FILE
	my $contents = $self->fileContents($file); 
	
	return if not defined $contents;
	my @lines = split "\n", $contents;

	return \@lines;
}

method fileContents ($file) {

	my ($dir) = $file =~ /^(.+?)\/[^\/]+$/;
	$self->logDebug("dir", $dir);
	my $dirfound = -d $dir;
	$self->logDebug("BEFORE COMMAND dirfound", $dirfound);
	
	$self->logNote("file", $file);
	my ($found) = $self->foundFile($file);
	
	$self->logNote("found", $found);
	return undef if not $found;
	
	my ($contents) = $self->runCommand("cat $file");
	$self->logNote("contents", $contents);
	
	return $contents;
}

method addToFile ($file, $inserts, $nodups) {
	my $lines = $self->fileLines($file);
	$lines = $self->addNoDups($lines, $inserts) if defined $nodups;
	$lines = $self->pushLines($lines, $inserts) if not defined $nodups;
	my $text = join "\n", $lines;

	return $self->writeFile($file, $text);	
}

method addNoDups ($lines, $inserts) {
#### ADD TEXT TO FILE: ADD NON-DUPLICATES AT END OF FILE
	#### remotehost IS THE HOST MOUNTING THE SHARE
	$self->logDebug("lines: @$lines");
	
	$inserts = [ $inserts ] if ref($inserts) eq '';
	$self->logDebug("inserts: @$inserts");
	
	#### REMOVE DUPLICATES FROM inserts
	for ( my $i = 0; $i < @$lines; $i++ )
	{
		for ( my $k = 0; $k < @$inserts; $k++ )
		{
			if ( $$lines[$i] =~ /^$$inserts[$k]$/ )
			{
				splice @$inserts, $k, 1; 
				$k--;
			}
		}
	}
	$self->logDebug("non-duplicate lines: @$lines");
	$lines = $self->pushLines($lines, $inserts);
	
	return $lines;
}


1;
