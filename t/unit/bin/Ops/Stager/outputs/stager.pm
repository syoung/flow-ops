package stager;
use Moose::Role;
use Method::Signatures::Simple;

method preTargetCommit ($mode, $repodir, $message) {
    $self->logDebug("mode", $mode);
    $self->logDebug("repodir", $repodir);
    $self->logDebug("message", $message);
    return if $mode ne "1-2";

    $self->logDebug("Carrying out mode $mode preTargetCommit procedures");
    my $source = "$repodir/syoung";
    my $target = "$repodir/agua";
    $self->logDebug("source", $source);
    $self->logDebug("target", $target);
    
    #### RETURN IF SOURCE DIRECTORY NOT FOUND
    return if not -d $source;

    #### CREATE TARGET IF MISSING
    `mkdir -p $target` if not -d $target;
    $self->logDebug("Can't create target dir", $target) if not -d $target;

    #### SYNC SOURCE TO TARGET
    my $command = "rsync -av --safe-links $source/* $target";
    $self->logDebug("command", $command);
    my $result = `$command`;
    $self->logDebug("result", $result);
    
    #### REMOVE SOURCE SUBDIR
    $command = "rm -fr $source";
    $self->logDebug("command", $command);
    $result = `$command`;
    $self->logDebug("result", $result);
    
    #### CONVERT OWNER TO 'agua'
    $command = qq{perl -pi -e 's/"owner"\\s*:\\s*"\\S+"/"owner" : "agua"/g' $target/workflows/projects/*/*.proj};
    $self->logDebug("command", $command);
    `$command`;
    $command = qq{perl -pi -e 's/"owner"\\s*:\\s*"\\S+"/"owner" : "agua"/g' $target/workflows/projects/*/*.work};
    $self->logDebug("command", $command);
    `$command`;
}

1;