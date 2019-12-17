use MooseX::Declare;

=head2

    PACKAGE        Ops
    
    PURPOSE
    
        CARRY OUT COMMON SYSTEM COMMANDS, INSTALL PACKAGES AND OTHER OPERATIONS

=cut

class Ops::Main with (Util::Logger,
    Ops::Ec2,
    Ops::Edit,
    Ops::Files,
    Ops::Git,
    Ops::GitHub,
    Ops::Install,
    Ops::Nfs,
    Ops::Sge,
    Ops::Ssh,
    Ops::Version) {


    # REMOVED ROLES:
    # Package::Main
    # Web::Base
    # Web::Group::Source,
    # Web::Cloud::Aws,
    # Web::Cloud::Cluster


use FindBin qw($Bin);
use lib "$Bin/..";

#### EXTERNAL MODULES
use Data::Dumper;
use File::Path;
use Getopt::Simple;
use Moose::Util qw(apply_all_roles);

#### INTERNAL MODULES
use Ops::Info;
use Conf::Yaml;
use Table::Main

# Boolean
has 'warn'            => ( isa => 'Bool', is     => 'rw', default    =>    1    );
has 'help'            => ( isa => 'Bool', is  => 'rw', required    =>    0, documentation => "Print help message"    );
has 'backup'          => ( isa => 'Bool', is  => 'rw', default    =>    0, documentation => "Automatically back up files before altering"    );

# Int
has 'log'             => ( isa => 'Int', is => 'rw', default     =>     2     );  
has 'printlog'        => ( isa => 'Int', is => 'rw', default     =>     2     );
has 'sleep'           => ( is  => 'rw', 'isa' => 'Int', default    =>    600    );
has 'upgradesleep'    => ( is  => 'rw', 'isa' => 'Int', default    =>    600    );

# Str
has 'opsrepo'         => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'database'        => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'user'            => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'password'        => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'host'            => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'conffile'        => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );

has 'logfile'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'envfile'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'hostname'        => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'username'        => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'cwd'             => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'envars'          => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'tempdir'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'hubtype'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0     );
has 'remote'          => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );

#### Object
has 'db'              => ( isa => 'Any', is => 'rw', required => 0 );
has 'ssh'             => ( isa => 'Util::Ssh', is => 'rw', required    =>    0    );
has 'jsonparser'      => ( isa => 'JSON', is => 'rw', lazy => 1, builder => "setJsonParser" );

#### INITIALIZATION VARIABLES FOR Ops::GitHub
has 'owner'           => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'packagename'=> ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'login'           => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'token'           => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'password'        => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'installdir'      => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'version'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'treeish'         => ( isa => 'Str|Undef', is => 'rw', required    =>    0    );
has 'branch'          => ( isa => 'Str|Undef', is => 'rw', default    =>    "master");
has 'keyfile'         => ( isa => 'Str|Undef', is => 'rw', default    =>    ''    );

#### Object
has 'db'              => ( isa => 'Any', is => 'rw', required => 0 );
has 'ssh'             => ( isa => 'Util::Ssh', is => 'rw', required    =>    0    );
has 'jsonparser'      => ( isa => 'JSON', is => 'rw', lazy => 1, builder => "setJsonParser" );
has 'opsinfo'         => (
    is          =>    'rw',
    isa         => 'Ops::Info'
);


has 'conf'            => ( 
    is          => 'rw', 
    isa         => 'Conf::Yaml', 
    lazy        => 1, 
    builder     => "setConf" 
);

method setConf {
    my $conf     = Conf::Yaml->new({
        backup        =>    1,
        log        =>    $self->log(),
        printlog    =>    $self->printlog()
    });
    
    $self->conf($conf);
}

has 'table'        =>    (
    is             =>    'rw',
    isa         =>    'Table::Main',
    # lazy        =>    1,
    # builder    =>    "setTable"
);

method setTable {
    $self->log(4);
    $self->logCaller("");
    $self->logDebug("self->table()", $self->table());

    return $self->table() if $self->table();

    my $table = Table::Main->new({
        conf            =>    $self->conf(),
        log                =>    $self->log(),
        printlog    =>    $self->printlog()
    });

    $self->table($table);    
}


has 'util'        =>    (
    is             =>    'rw',
    isa         =>    'Util::Main',
    lazy        =>    1,
    builder    =>    "setUtil"
);

method setUtil () {
    my $util = Util::Main->new({
        conf            =>    $self->conf(),
        log                =>    $self->log(),
        printlog    =>    $self->printlog()
    });

    $self->util($util);    
}

method BUILD ($args) {
    #$self->logDebug("");
    $self->initialise($args);
    # $self->logDebug("self->table()", $self->table());
    $self->setTable() if not defined $self->table();
}

method initialise ($args) {
    $self->logDebug("");
    
    #### OPEN LOGFILE IF DEFINED
    my $logfile = $self->logfile();
    $self->startLog($logfile) if defined $logfile;
    $self->logNote("logfile", $logfile)  if defined $logfile;

    $self->setEnv();

    $self->setSsh();
    
    $self->applyRoles();

    $self->setTable() if not defined $self->table();
}

method applyRoles {
    Moose::Util::apply_all_roles($self, 'Ops::GitHub');
}

method args {
    my $meta = $self->meta();

    my %option_type_map = (
        'Bool'     => '!',
        'Str'      => '=s',
        'Int'      => '=i',
        'Num'      => '=f',
        'ArrayRef' => '=s@',
        'HashRef'  => '=s%',
        'Maybe'    => ''
    );
    
    my $attributes = $self->fields();
    my $args = {};
    foreach my $attribute_name ( @$attributes )
    {
        my $attr = $meta->get_attribute($attribute_name);
        my $attribute_type  = $attr->{isa};
        $attribute_type =~ s/\|.+$//;
        $args -> {$attribute_name} = {  type => $option_type_map{$attribute_type}  };
    }

    return $args;
}

#### SET METHODS

method setDbObject {
    $self->logCaller("");
    my $database     = $self->database() || $self->conf()->getKey("database:DATABASE");
    my $user        = $self->user() || $self->conf()->getKey("database:USER");
    my $password    = $self->password() || $self->conf()->getKey("database:PASSWORD");
    my $host    = $self->host() || $self->conf()->getKey("database:HOST");
    $self->logDebug("database", $database);
    $self->logDebug("user", $user);
    my $dbtype = $self->conf()->getKey("database:DBTYPE");
    $self->logDebug("dbtype", $dbtype);
    my $dbfile = $self->conf()->getKey("core:INSTALLDIR") . "/" .$self->conf()->getKey("database:DBFILE");
    $self->logDebug("dbfile", $dbfile);

    #$self->logDebug("password", $password);

   #### CREATE DB OBJECT USING DBASE FACTORY
    my $db = DBase::Factory->new( $dbtype,
        {
            database    =>    $database,
      dbuser      =>  $user,
      dbpassword  =>  $password,
      dbhost      =>  $host,
      dbfile      =>  $dbfile,
            logfile        =>    $self->logfile(),
            log            =>    2,
            printlog    =>    2
        }
    ) or die "Can't create database object to create database: $database. $!\n";

    $self->db($db);
}

method setSsh () {
    my $username    =    $self->username();
    my $hostname     =    $self->hostname();
    my $keyfile     =     $self->keyfile();

    $self->logDebug("username", $username);
    $self->logDebug("hostname", $hostname);
    $self->logDebug("keyfile", $keyfile);
    
    return if not defined $self->username() or not $self->username();
    return if not defined $self->hostname() or not $self->hostname();
    return if not defined $self->keyfile() or not $self->keyfile();

    return $self->_setSsh($username, $hostname, $keyfile);
}

method setEnv {
    return if not defined $self->envfile();
    my $envfile = $self->envfile();
    my $lines = $self->fileLines($envfile);
    my $envars = '';
    foreach my $line ( @$lines )
    {
        next if not $line =~ /^\s*(\S+)\s+(\S+)\s*$/;
        my $key = $1;
        my $value = $2;
        $envars .= "$key=$value";
    }
    $self->envars($envars);
}

#### COMMAND METHODS

method localCommand ($command) {
#### RUN COMMAND LOCALLY
    $self->logDebug("command", $command);
    return `$command`;
}

method clearChangeDir () {
    $self->logNote();
    $self->cwd("");    
}
method changeDir ($directory) {
    $self->logDebug("directory", $directory);

    my $pwd = `pwd`;
    $self->logDebug("pwd", $pwd);

    my $cwd = $self->cwd();
    $self->logDebug("cwd", $cwd);
    if ( defined $cwd and $cwd ne "" and $directory !~ /^\// ) {
        $cwd =~ s/\/$//;
        $cwd = "$cwd/$directory";
        $self->logDebug("cwd", $cwd);

        return 0 if not $self->foundDir($cwd);
        return 0 if not chdir($cwd);
        $self->cwd($cwd);
        $self->logDebug("self->cwd()", $self->cwd());
    }
    else {
        return 0 if not $self->foundDir($directory);
        return 0 if not chdir($directory);
        $self->cwd($directory);
        $cwd = $directory;
    }
    
    return 1;
}

method runCommand ($command) {
    $self->logDebug("command", $command);
    
    my $pwd = $self->getPwd();
    # $self->logDebug("FIRST pwd", $pwd);

    #### ADD ENVARS
    $command = $self->envars() . $command if defined $self->envars();

    #### EXECUTE REMOTELY IF ssh
    if ( defined $self->ssh() ) {
        $self->logDebug("DOING ssh->execute($command)");
        return $self->ssh()->execute($command);
    }

    if ( defined $self->cwd() and $self->cwd() ) {
        chdir( $self->cwd() );
    }

    my $stdoutfile = "/tmp/$$.out";
    my $stderrfile = "/tmp/$$.err";
    my $output = '';
    my $error = '';
    
    #### TAKE REDIRECTS IN THE COMMAND INTO CONSIDERATION
    if ( $command =~ />\s+/ ) {
        #### DO NOTHING, ERROR AND OUTPUT ALREADY REDIRECTED
        if ( $command =~ /\s+&>\s+/
            or ( $command =~ /\s+1>\s+/ and $command =~ /\s+2>\s+/)
            or ( $command =~ /\s+1>\s+/ and $command =~ /\s+2>&1\s+/) ) {
            print `$command`;
        }
        #### STDOUT ALREADY REDIRECTED - REDIRECT STDERR ONLY
        elsif ( $command =~ /\s+1>\s+/ or $command =~ /\s+>\s+/ ) {
            $command .= " 2> $stderrfile";
            print `$command`;
            $error = `cat $stderrfile`;
        }
        #### STDERR ALREADY REDIRECTED - REDIRECT STDOUT ONLY
        elsif ( $command =~ /\s+2>\s+/ or $command =~ /\s+2>&1\s+/ ) {
            $command .= " 1> $stdoutfile";
            print `$command`;
            $output = `cat $stdoutfile`;
        }
    }
    else {
        $command .= " 1> $stdoutfile 2> $stderrfile";
        print `$command`;
        $output = `cat $stdoutfile`;
        $error = `cat $stderrfile`;
    }
    
    $self->logNote("output", $output) if $output;
    $self->logNote("error", $error) if $error;
    
    ##### CHECK FOR PROCESS ERRORS
    $self->logError("Error with command: $command ... $@") and exit if defined $@ and $@ ne "" and $self->can('warn') and not $self->warn();

    #### CLEAN UP
    `rm -fr $stdoutfile`;
    `rm -fr $stderrfile`;
    chomp($output);
    chomp($error);
    
    # $self->logDebug("LAST pwd", $pwd);
    if ( defined $self->cwd() and $self->cwd() ) {
        chdir($pwd);
    }

    return $output, $error;
}

method chompCommand ($command) {
#### RETURN CHOMPED RESULT OF runCommand
    my ($output, $error) = $self->runCommand($command);
    return if not defined $output;
    $self->logNote("output", $output);
    $self->logNote("error", $error);
    $output =~ s/\s+$//;
    $error =~ s/\s+$//;
    $self->logNote("Returning '$output', '$error'");
    return ($output, $error);
}


method repeatCommand ($command, $sleep, $tries, $errorregex) {
#### REPEATEDLY TRY SYSTEM CALL UNTIL A NON-ERROR RESPONSE IS RECEIVED
    $errorregex = "(error|Error|ERROR)" if not defined $errorregex; 
    $self->logDebug("command", $command);
    $self->logDebug("sleep", $sleep);
    $self->logDebug("tries", $tries);
    $self->logDebug("errorregex", $errorregex);
    
    my $output;
    my $error;
    my $error_message = 1;
    while ( $error_message and $tries )
    {
        ($output, $error) = $self->runCommand($command);
        $self->logDebug("output", $output);
        $self->logDebug("error", $error);
        
        use re 'eval';    # EVALUATE AS REGEX
        $error_message = $output =~ /$errorregex/;
        $self->logDebug("error_message", $error_message) if not $output;
        no re 'eval';# STOP EVALUATING AS REGEX

        #### DECREMENT TRIES AND SLEEP
        $tries--;
        $self->logDebug("$tries tries left.")  if not $output and not $error;
        $self->logDebug("sleeping $sleep seconds") and sleep($sleep) if $error_message;
    }
    $self->logDebug("Returning output", $output);
    $self->logDebug("Returning error", $error);
    
    return $output, $error;
}

#### CONTROL METHODS
method timeoutCommand ($command, $timeout) {
    eval {
        local %SIG;
        $SIG{ALRM}=    sub{ print "timeout reached, after $timeout seconds!\n"; die; };
        alarm $timeout;
        return $self->runCommand($command);
        
        alarm 0;
    };

    $self->logDebug("end of timeout returning 0");
    alarm 0;
    
}

method repeatTry ($command, $regex, $tries, $sleep) {
#### REPEAT COMMAND UNTIL NON-ERROR RETURNED OR LIMIT REACHED
    $self->logDebug("Ops::repeatTry(command)");
    $self->logDebug("command", $command);
    $self->logDebug("sleep", $sleep);
    $self->logDebug("tries", $tries);
    
    my $result = '';    
    my $error = 1;
    while ( $error and $tries )
    {
        open(COMMAND, $command) or die "Can't exec command: $command\n";
        while(<COMMAND>) {
            $result .= $_;
        }
        close (COMMAND);
        $self->logDebug("result", $result);

        use re 'eval';    # EVALUATE AS REGEX
        $error = $result =~ /$regex/;
        $self->logDebug("error", $error);
        no re 'eval';# STOP EVALUATING AS REGEX

        #### DECREMENT TRIES AND SLEEP
        $tries--;
        $self->logDebug("$tries tries left. Sleeping $sleep seconds") if $error;
        $self->logDebug("current datetime: ");
        $self->logDebug(`date`);

        sleep($sleep) if $error;
    }
    $self->logDebug("Returning result", $result);
    
    return $result;
}

####s USER INPUT METHODS
method yes ($message, $max_times) {    
    $/ = "\n";
    my $input = <STDIN>;
    my $counter = 0;
    while ( $input !~ /^Y$/i and $input !~ /^N$/i )
    {
        if ( $counter > $max_times )    {
            $self->logCritical("Exceeded 10 tries. Exiting.");
        }
        
        $self->logCritical("$message");
        $input = <STDIN>;
        $counter++;
    }    

    if ( $input =~ /^N$/i )    {    return 0;    }
    else {    return 1;    }
}

method getLines ($file) {
    $self->logDebug("file", $file);
    $self->logWarning("file not defined") and return if not defined $file;
    my $temp = $/;
    $/ = "\n";
    open(FILE, $file) or $self->logCritical("Can't open file: $file\n") and exit;
    my $lines;
    @$lines = <FILE>;
    close(FILE) or $self->logCritical("Can't close file: $file\n") and exit;
    $/ = $temp;
    
    for ( my $i = 0; $i < @$lines; $i++ ) {
        if ( $$lines[$i] =~ /^\s*$/ ) {
            splice @$lines, $i, 1;
            $i--;
        }
    }
    
    return $lines;
}



}

