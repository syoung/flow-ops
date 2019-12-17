use MooseX::Declare;

=head2

    PACKAGE        OpsInfo
    
    PURPOSE
    
        READ AND WRITE INFORMATION FROM/INTO *.ops FILE

        OPS (Open Package Schema) is a resource description format for installing software applications and data packages. OPS is implemented as a JSON *.ops file containing the following key-value pairs  (values are scalars unless otherwise noted):

owner                      Account name of owner of repository
repository              Repository containing package
privacy                    Privacy setting of repository: "public" or "private"
packagename                Name of package to be installed
type                   Package type - application, data, reference, workflow, etc.
version                Version number of package
history                Array of previous versions

opsfile                URL of github or private git repository providing this *.ops file
installfile            Git URL of fabric/ops deployment file
installtype            Type of installation - ops, fabric, shell, etc.
licensefile            Location in repository of licence file
resources                Array of application-specific installation resources (e.g., tsvfiles, appfiles, EC2 snapshots, etc.)

authors             Array of author objects
email                  Author's email address
keywords               Array of keywords relating to the package
description            Description of the package
website                URL of website for package
publication          Array of paper/abstract/etc. objects
organisations       Array of organisation objects
ISA                    Hash of experiment information conforming to ISA standard
acknowledgements     Array of organisation objects
citations              Array of paper/abstract/etc. objects
meta                   Hash of additional metadata


The complete contents of the *.ops file are available as variables of the OpsInfo object inside *.pm so the installer can access important information required to install the application. The 'resources' entry in the *.ops file serves as a convenient store for all application-specific installation information.

For more details, see: http://www.aguadev.org

=cut

class Ops::Info extends Conf::Json {

use FindBin qw($Bin);
use lib "$Bin/..";

#### EXTERNAL MODULES
use Data::Dumper;
use JSON;
use YAML::Tiny;

# Bool
has 'blocked'      => ( isa => 'Bool', is => 'rw' );  

# Int
has 'log'          => ( isa => 'Int', is => 'rw', default     =>     2     );  
has 'printlog'     => ( isa => 'Int', is => 'rw', default     =>     5     );

# String
has 'cloneurl'     => ( isa => 'Str|Undef', is => 'rw' );
has 'format'       => ( isa => 'Str|Undef', is => 'rw', default    =>     "yaml"    );
has 'download'     => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'owner'        => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'login'        => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'repository'   => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'hubtype'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'privacy'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'packagename'  => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'type'         => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'version'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'branch'       => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'treeish'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'history'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'url'          => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'checkurl'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0, default    => "true"    );
has 'unzipped'      => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'downloaded'=> ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'linkurl'       => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );

has 'installtype'   => ( isa => 'Str|Undef', is => 'rw', required    =>     0, default    =>    'ops'    );
has 'opsfile'       => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'installfile'   => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'licensefile'   => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'readmefile'    => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );

has 'description'   => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );
has 'website'       => ( isa => 'Str|Undef', is => 'rw', required    =>     0    );

# Object
has 'envars'          => ( isa => 'ArrayRef|Undef', is => 'rw'    );
has 'versions'        => ( isa => 'ArrayRef|Undef', is => 'rw'    );
has 'dependencies'    => ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );
has 'authors'         => ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );
has 'publication'     => ( isa => 'HashRef|Undef', is => 'rw', required    =>     0    );
has 'organisations'   => ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );
has 'ISA'             => ( isa => 'HashRef|Undef', is => 'rw', required    =>     0    );
has 'acknowledgements'=> ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );
has 'citations'       => ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );
has 'resources'       => ( isa => 'HashRef|Undef', is => 'rw', required    =>     0    );
has 'keywords'        => ( isa => 'ArrayRef|Undef', is => 'rw', required    =>     0    );

has 'savefields'    => ( isa => 'ArrayRef|Undef', is => 'rw', default => sub { ['packagename', 'version', 'type', 'branch', 'treeish', 'history', 'installtype', 'opsfile', 'installfile', 'licensefile', 'readmefile', 'description', 'website', 'authors', 'publication', 'organisations', 'ISA', 'acknowledgements', 'citations']    });

=head2

    SUBROUTINE        BUILD
    
    PURPOSE

        GET AND VALIDATE INPUTS, AND INITIALISE OBJECT

=cut

method BUILD ($hash) {
    $self->initialise();
}

method initialise () {
    ##### OPEN inputfile IF DEFINED
    $self->parseFile($self->inputfile()) if $self->inputfile();
}

method parseFile ($inputfile) {
    #$self->logDebug("inputfile", $inputfile);
    $self->inputfile($inputfile);
    my $format    =    $self->format();
    my $opshash;
    if ( $format eq "json" ) {
        open(FILE, $inputfile) or die "Can't open inputfile: $inputfile\n";
        my $temp = $/;
        $/ = undef;
        my $contents = <FILE>;
        close(FILE) or die "Can't close inputfile: $inputfile\n";
        
        my $parser = JSON->new();
        my $opshash = $parser->decode($contents);
    }
    elsif ( $format eq "yaml") {
        my $yaml = YAML::Tiny->read($inputfile);
        $opshash = $$yaml[0];
    }
    
    #$self->logDebug("opshash", $opshash);
    return $self->parseOps($opshash);
}

method parseOps ($opshash) {
    #$self->logDebug("opshash", $opshash);

    foreach my $key ( %$opshash ) {
        $self->$key($opshash->{$key}) if $self->can($key);
    }
    
    return 1;
}

method set ($key, $value) {
    $self->logNote("key", $key);
    $self->logNote("value", $value);
    $self->logWarning("key is null") and return if not defined $key;
    $self->logWarning("value is null") and return if not defined $value;

    $self->logDebug("not a supported attribute: $key") and return 0 if not $self->isKey($key);    

    $self->$key($value);
    return $self->insertKey($key, $value, undef);
}

method isKey ($key) {
    return 0 if not defined $key;
    foreach my $field ( @{$self->savefields} ) {
        return 1 if $field eq $key;
    }
    
    return 0;
    
}

method get ($key) {
    return $self->$key() if $self->can($key);
    return;
}

method generate {
    my $file = $self->outputfile();
    $file = $self->inputfile() if not defined $file;
    $self->logWarning("file not defined") if not defined $file;

    my %option_type_map = (
        'Bool'     => undef,
        'Str'      => '',
        'Int'      => undef,
        'Num'      => undef,
        'ArrayRef' => [],
        'HashRef'  => {},
        'Maybe'    => undef
    );

    my $meta = OpsInfo->meta();
    my $fields = $self->savefields();
    @$fields = reverse (@$fields);
    foreach my $field ( @$fields ) {
        #$self->logDebug("field", $field);
        my $attr = $meta->get_attribute($field);
        my $attribute_type  = $attr->{isa};
        $attribute_type =~ s/\|.+$// if defined $attribute_type;
        #$self->logDebug("attribute_type", $attribute_type);
        my $value = $option_type_map{$attribute_type};
        #$self->logDebug("value", $value);

        $self->insertKey($field, $value, undef);    
    }
    
    $self->write($file);
}


}

